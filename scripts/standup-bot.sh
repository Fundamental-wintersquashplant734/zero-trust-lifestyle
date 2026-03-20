#!/bin/bash
#=============================================================================
# standup-bot.sh
# Auto-generate standup updates from git commits and calendar
# "I automated lying about what I did yesterday"
#
# Full-featured standup automation with templates, learning, and scheduling
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

SLACK_WEBHOOK=${SLACK_WEBHOOK:-""}
SLACK_TOKEN=${SLACK_TOKEN:-""}
SLACK_CHANNEL=${SLACK_CHANNEL:-"#standup"}

JIRA_URL=${JIRA_URL:-""}
JIRA_TOKEN=${JIRA_TOKEN:-""}

GIT_REPOS=${GIT_REPOS:-""}  # Comma-separated list of repos to scan
GITHUB_REPO=${GITHUB_REPO:-""}  # owner/repo format

STANDUP_CONFIG="$DATA_DIR/standup_config.json"
STANDUP_HISTORY="$DATA_DIR/standup_history.json"
STANDUP_TEMPLATES="$DATA_DIR/standup_templates.json"

# Template style
CORPORATE_SPEAK=${CORPORATE_SPEAK:-1}
ADD_EMOJIS=${ADD_EMOJIS:-0}
CURRENT_TEMPLATE=${CURRENT_TEMPLATE:-"productive"}

#=============================================================================
# Configuration Management
#=============================================================================

init_config() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$STANDUP_CONFIG" ]]; then
        cat > "$STANDUP_CONFIG" <<'EOF'
{
  "style": {
    "detail_level": "moderate",
    "use_bullet_points": true,
    "include_pr_numbers": true,
    "include_meeting_count": false,
    "use_emoji": false,
    "max_items_per_section": 4
  },
  "content": {
    "include_commits": true,
    "include_prs": true,
    "include_issues": true,
    "include_meetings": false,
    "include_code_reviews": true,
    "mention_blockers": true,
    "mention_pto": true
  },
  "vacation": {
    "enabled": false,
    "start_date": "",
    "end_date": ""
  }
}
EOF
    fi

    if [[ ! -f "$STANDUP_HISTORY" ]]; then
        echo '{"standups": []}' > "$STANDUP_HISTORY"
    fi

    init_templates
}

init_templates() {
    if [[ ! -f "$STANDUP_TEMPLATES" ]]; then
        cat > "$STANDUP_TEMPLATES" <<'EOF'
{
  "productive": {
    "yesterday_intro": "Yesterday:",
    "today_intro": "Today:",
    "blockers_intro": "Blockers:",
    "no_blockers": "None",
    "detail_level": "high",
    "corporate": false
  },
  "vague": {
    "yesterday_intro": "Yesterday:",
    "today_intro": "Today:",
    "blockers_intro": "Blockers:",
    "no_blockers": "None",
    "detail_level": "low",
    "corporate": false,
    "default_yesterday": ["Made progress on ongoing tasks", "Several code reviews"],
    "default_today": ["Continuing previous work", "Some meetings scheduled"]
  },
  "busy": {
    "yesterday_intro": "Yesterday:",
    "today_intro": "Today:",
    "blockers_intro": "Blockers:",
    "no_blockers": "None",
    "detail_level": "high",
    "corporate": false,
    "prefix_verbs": ["Handled", "Addressed", "Resolved", "Managed"]
  },
  "corporate": {
    "yesterday_intro": "*Key Accomplishments:*",
    "today_intro": "*Strategic Priorities:*",
    "blockers_intro": "*Dependencies & Blockers:*",
    "no_blockers": "No impediments at this time",
    "detail_level": "high",
    "corporate": true
  }
}
EOF
    fi
}

config_get() {
    local key=$1
    jq -r "$key" "$STANDUP_CONFIG" 2>/dev/null || echo ""
}

config_set() {
    local key=$1
    local value=$2

    local tmp_file=$(mktemp)
    jq --arg key "$key" --arg val "$value" 'setpath(($key | ltrimstr(".") | split(".")); $val)' "$STANDUP_CONFIG" > "$tmp_file"
    mv "$tmp_file" "$STANDUP_CONFIG"
}

#=============================================================================
# Template Management
#=============================================================================

get_template() {
    local template_name=${1:-"productive"}
    jq -r --arg name "$template_name" '.[$name]' "$STANDUP_TEMPLATES" 2>/dev/null || echo "{}"
}

list_templates() {
    echo -e "${BOLD}Available Templates:${NC}\n"
    jq -r 'keys[]' "$STANDUP_TEMPLATES" 2>/dev/null | while read -r name; do
        local desc=$(jq -r --arg name "$name" '.[$name].detail_level // "unknown"' "$STANDUP_TEMPLATES")
        echo "  $name - Detail level: $desc"
    done
}

create_template() {
    local name=$1

    log_info "Creating template: $name"

    # Interactive template creation
    read -p "Yesterday intro [Yesterday:]: " yesterday_intro
    yesterday_intro=${yesterday_intro:-"Yesterday:"}

    read -p "Today intro [Today:]: " today_intro
    today_intro=${today_intro:-"Today:"}

    read -p "Blockers intro [Blockers:]: " blockers_intro
    blockers_intro=${blockers_intro:-"Blockers:"}

    read -p "Detail level (low/moderate/high) [moderate]: " detail_level
    detail_level=${detail_level:-"moderate"}

    read -p "Corporate speak (true/false) [false]: " corporate
    corporate=${corporate:-"false"}

    local tmp_file=$(mktemp)
    jq --arg name "$name" \
       --arg yi "$yesterday_intro" \
       --arg ti "$today_intro" \
       --arg bi "$blockers_intro" \
       --arg dl "$detail_level" \
       --argjson corp "$corporate" \
       '.[$name] = {
           "yesterday_intro": $yi,
           "today_intro": $ti,
           "blockers_intro": $bi,
           "detail_level": $dl,
           "corporate": $corp,
           "no_blockers": "None"
       }' "$STANDUP_TEMPLATES" > "$tmp_file"

    mv "$tmp_file" "$STANDUP_TEMPLATES"
    log_success "Template '$name' created"
}

#=============================================================================
# Corporate Speak Translation
#=============================================================================

declare -A CORPORATE_TRANSLATIONS=(
    ["fixed bug"]="Resolved a critical system issue"
    ["fixed"]="Addressed"
    ["added feature"]="Delivered new functionality"
    ["added"]="Implemented"
    ["refactored"]="Enhanced code maintainability"
    ["refactor"]="Architectural improvement"
    ["updated"]="Modernized"
    ["deleted"]="Streamlined"
    ["removed"]="Optimized by removing"
    ["changed"]="Evolved"
    ["improved"]="Enhanced"
    ["optimized"]="Improved performance of"
    ["debugged"]="Investigated and resolved"
    ["tested"]="Validated"
    ["reviewed"]="Provided technical oversight for"
    ["merged"]="Integrated"
    ["committed"]="Contributed to"
    ["pushed"]="Delivered"
    ["pulled"]="Synchronized with"
    ["rebased"]="Harmonized"
    ["reverted"]="Strategically rolled back"
    ["hotfix"]="Emergency production stabilization"
    ["workaround"]="Tactical solution"
    ["hack"]="Innovative solution"
    ["TODO"]="Identified future enhancement opportunity"
    ["WIP"]="Ongoing initiative"
)

CORPORATE_VERBS=(
    "Collaborated cross-functionally on"
    "Drove progress on"
    "Spearheaded"
    "Championed"
    "Facilitated"
    "Orchestrated"
    "Streamlined"
    "Enhanced"
    "Optimized"
    "Delivered"
)

translate_to_corporate() {
    local text=$1

    for key in "${!CORPORATE_TRANSLATIONS[@]}"; do
        text=$(echo "$text" | sed "s/$key/${CORPORATE_TRANSLATIONS[$key]}/gi")
    done

    echo "$text"
}

add_corporate_flair() {
    local text=$1

    if [[ $((RANDOM % 3)) -eq 0 ]]; then
        local verb=$(printf '%s\n' "${CORPORATE_VERBS[@]}" | shuf -n 1)
        text="$verb $text"
    fi

    text=$(echo "$text" | sed 's/\bkinda\b/somewhat/gi')
    text=$(echo "$text" | sed 's/\bgonna\b/going to/gi')
    text=$(echo "$text" | sed 's/\bwanna\b/want to/gi')

    echo "$text"
}

#=============================================================================
# Git Commit Analysis
#=============================================================================

get_git_repos() {
    if [[ -n "$GIT_REPOS" ]]; then
        echo "$GIT_REPOS" | tr ',' '\n'
    else
        if git rev-parse --git-dir &>/dev/null; then
            pwd
        fi
    fi
}

get_commits_since() {
    local repo=$1
    local since=${2:-"yesterday"}

    cd "$repo" || return 1

    local author=$(git config user.name 2>/dev/null || echo "")

    git log --author="$author" --since="$since" --pretty=format:"%s|%h|%ar" --no-merges 2>/dev/null || true

    cd - &>/dev/null
}

parse_commit_message() {
    local message=$1
    local use_corporate=${2:-$CORPORATE_SPEAK}

    local issues=$(echo "$message" | grep -oE '([A-Z]+-[0-9]+|#[0-9]+)' | head -1)

    message=$(echo "$message" | sed 's/^Merge.*//')
    message=$(echo "$message" | sed 's/\[[^]]*\]//')
    message=$(echo "$message" | sed 's/([^)]*)//g')

    if [[ $use_corporate -eq 1 ]]; then
        message=$(translate_to_corporate "$message")
        message=$(add_corporate_flair "$message")
    fi

    echo "$message|$issues"
}

summarize_commits() {
    local repos=$1
    local since=${2:-"yesterday"}

    local commits=()

    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue

        while IFS='|' read -r msg hash time; do
            [[ -z "$msg" ]] && continue

            local parsed=$(parse_commit_message "$msg")
            local clean_msg=$(echo "$parsed" | cut -d'|' -f1)
            local issue=$(echo "$parsed" | cut -d'|' -f2)

            if [[ -n "$issue" ]]; then
                commits+=("$clean_msg ($issue)")
            else
                commits+=("$clean_msg")
            fi
        done < <(get_commits_since "$repo" "$since")
    done <<< "$repos"

    printf '%s\n' "${commits[@]}" | sort -u
}

#=============================================================================
# GitHub Integration
#=============================================================================

get_github_prs() {
    local action=${1:-"closed"}  # closed, open, review

    if ! command -v gh &> /dev/null; then
        log_debug "gh CLI not available"
        return 0
    fi

    if [[ -z "$GITHUB_REPO" ]]; then
        log_debug "GITHUB_REPO not configured"
        return 0
    fi

    case $action in
        closed)
            gh pr list --repo "$GITHUB_REPO" --author @me --state closed --limit 5 \
                --json number,title,closedAt --jq '.[] | select(.closedAt | fromdateiso8601 > (now - 86400)) | "#\(.number): \(.title)"' 2>/dev/null || true
            ;;
        open)
            gh pr list --repo "$GITHUB_REPO" --author @me --state open --limit 5 \
                --json number,title --jq '.[] | "#\(.number): \(.title)"' 2>/dev/null || true
            ;;
        review)
            gh pr list --repo "$GITHUB_REPO" --search "review-requested:@me" --state open --limit 5 \
                --json number,title --jq '.[] | "#\(.number): \(.title)"' 2>/dev/null || true
            ;;
    esac
}

get_github_issues() {
    local state=${1:-"all"}

    if ! command -v gh &> /dev/null; then
        return 0
    fi

    if [[ -z "$GITHUB_REPO" ]]; then
        return 0
    fi

    gh issue list --repo "$GITHUB_REPO" --assignee @me --state "$state" --limit 5 \
        --json number,title --jq '.[] | "#\(.number): \(.title)"' 2>/dev/null || true
}

#=============================================================================
# Calendar Integration
#=============================================================================

get_meetings_attended() {
    local since=${1:-"yesterday"}

    if ! command -v gcalcli &> /dev/null; then
        return 0
    fi

    gcalcli --calendar="primary" agenda "$since" "today" --tsv 2>/dev/null | \
        awk -F'\t' '{print $2}' | \
        grep -vE "^$|lunch|break|focus" | \
        sort -u || true
}

get_upcoming_meetings() {
    if ! command -v gcalcli &> /dev/null; then
        return 0
    fi

    gcalcli --calendar="primary" agenda "today" "tomorrow" --tsv 2>/dev/null | \
        awk -F'\t' '{print $2}' | \
        grep -vE "^$|lunch|break|focus" | \
        head -3 || true
}

#=============================================================================
# JIRA Integration
#=============================================================================

get_jira_tickets_worked() {
    if [[ -z "$JIRA_URL" ]] || [[ -z "$JIRA_TOKEN" ]]; then
        return 0
    fi

    local jql="assignee=currentUser() AND updated >= -1d ORDER BY updated DESC"

    curl -s -X GET \
        -H "Authorization: Bearer $JIRA_TOKEN" \
        -H "Content-Type: application/json" \
        "$JIRA_URL/rest/api/2/search?jql=$jql&fields=summary,key,status" 2>/dev/null | \
        jq -r '.issues[]? | "\(.key): \(.fields.summary) [\(.fields.status.name)]"' || true
}

get_jira_tickets_in_progress() {
    if [[ -z "$JIRA_URL" ]] || [[ -z "$JIRA_TOKEN" ]]; then
        return 0
    fi

    local jql="assignee=currentUser() AND status='In Progress' ORDER BY updated DESC"

    curl -s -X GET \
        -H "Authorization: Bearer $JIRA_TOKEN" \
        -H "Content-Type: application/json" \
        "$JIRA_URL/rest/api/2/search?jql=$jql&fields=summary,key" 2>/dev/null | \
        jq -r '.issues[]? | "\(.key): \(.fields.summary)"' || true
}

#=============================================================================
# Blocker Detection
#=============================================================================

detect_blockers() {
    local blockers=()

    # Check for stuck PRs (waiting on review >2 days)
    if command -v gh &> /dev/null && [[ -n "$GITHUB_REPO" ]]; then
        local old_prs=$(gh pr list --repo "$GITHUB_REPO" --author @me --state open \
            --json number,title,createdAt --jq '.[] | select(.createdAt | fromdateiso8601 < (now - 172800)) | "PR #\(.number) waiting on review"' 2>/dev/null || true)

        if [[ -n "$old_prs" ]]; then
            while IFS= read -r pr; do
                blockers+=("$pr")
            done <<< "$old_prs"
        fi
    fi

    # Check JIRA for blocked tickets
    if [[ -n "$JIRA_URL" ]] && [[ -n "$JIRA_TOKEN" ]]; then
        local blocked_jql="assignee=currentUser() AND status='Blocked'"
        local blocked=$(curl -s -X GET \
            -H "Authorization: Bearer $JIRA_TOKEN" \
            -H "Content-Type: application/json" \
            "$JIRA_URL/rest/api/2/search?jql=$blocked_jql&fields=key,summary" 2>/dev/null | \
            jq -r '.issues[]? | "\(.key) is blocked"' || true)

        if [[ -n "$blocked" ]]; then
            while IFS= read -r ticket; do
                blockers+=("$ticket")
            done <<< "$blocked"
        fi
    fi

    printf '%s\n' "${blockers[@]}"
}

#=============================================================================
# Vacation Mode
#=============================================================================

is_on_vacation() {
    local vacation_enabled=$(config_get '.vacation.enabled')

    if [[ "$vacation_enabled" == "true" ]]; then
        local end_date=$(config_get '.vacation.end_date')
        local today=$(date +%Y-%m-%d)

        if [[ "$today" < "$end_date" ]]; then
            return 0
        fi
    fi

    return 1
}

generate_vacation_standup() {
    local end_date=$(config_get '.vacation.end_date')

    cat <<EOF
*Status:* On vacation until $end_date

Will catch up on emails and messages when I return.
EOF
}

#=============================================================================
# Style Learning
#=============================================================================

learn_from_history() {
    if [[ ! -f "$STANDUP_HISTORY" ]]; then
        log_warn "No history to learn from"
        return 1
    fi

    log_info "Analyzing writing style from past standups..."

    # Analyze patterns
    local total=$(jq '.standups | length' "$STANDUP_HISTORY")

    if [[ $total -lt 5 ]]; then
        log_warn "Not enough history (need at least 5 standups, have $total)"
        return 1
    fi

    # Calculate average length
    local avg_length=$(jq '.standups[].content | length' "$STANDUP_HISTORY" | \
        awk '{sum+=$1} END {print int(sum/NR)}')

    # Check emoji usage
    local emoji_count=$(jq -r '.standups[].content' "$STANDUP_HISTORY" | \
        grep -oP '[\x{1F300}-\x{1F9FF}]' | wc -l || echo 0)
    local use_emoji=$([[ $emoji_count -gt 0 ]] && echo "true" || echo "false")

    # Check bullet points
    local bullet_count=$(jq -r '.standups[].content' "$STANDUP_HISTORY" | \
        grep -c "^• \|^- \|^* " || echo 0)
    local use_bullets=$([[ $bullet_count -gt 10 ]] && echo "true" || echo "false")

    log_info "Learned patterns:"
    echo "  Average length: $avg_length characters"
    echo "  Uses emojis: $use_emoji"
    echo "  Uses bullet points: $use_bullets"

    # Update config
    config_set ".style.use_emoji" "$use_emoji"
    config_set ".style.use_bullet_points" "$use_bullets"

    log_success "Style preferences updated"
}

#=============================================================================
# Standup Generation
#=============================================================================

generate_standup() {
    local template_name=${1:-$CURRENT_TEMPLATE}

    # Check vacation mode
    if is_on_vacation; then
        generate_vacation_standup
        return 0
    fi

    local template=$(get_template "$template_name")
    local use_corporate=$(echo "$template" | jq -r '.corporate // false')
    local detail_level=$(echo "$template" | jq -r '.detail_level // "moderate"')

    # Override with global corporate setting if enabled
    [[ $CORPORATE_SPEAK -eq 1 ]] && use_corporate="true"

    local yesterday_date=$(date -d yesterday '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d')
    local today_date=$(date '+%Y-%m-%d')

    log_info "Generating standup for $today_date (template: $template_name)"

    # Get data sources
    local repos=$(get_git_repos)
    local commits=$(summarize_commits "$repos" "yesterday")
    local closed_prs=$(get_github_prs "closed")
    local open_prs=$(get_github_prs "open")
    local jira_tickets=$(get_jira_tickets_worked)
    local jira_in_progress=$(get_jira_tickets_in_progress)
    local meetings=$(get_meetings_attended "yesterday")
    local upcoming_meetings=$(get_upcoming_meetings)
    local blockers=$(detect_blockers)

    # Build sections
    local yesterday_intro=$(echo "$template" | jq -r '.yesterday_intro // "Yesterday:"')
    local today_intro=$(echo "$template" | jq -r '.today_intro // "Today:"')
    local blockers_intro=$(echo "$template" | jq -r '.blockers_intro // "Blockers:"')
    local no_blockers=$(echo "$template" | jq -r '.no_blockers // "None"')

    local standup_text=""

    # YESTERDAY SECTION
    standup_text+="$yesterday_intro\n"

    local yesterday_items=0
    local max_items=$(config_get '.style.max_items_per_section')
    max_items=${max_items:-4}

    # Add closed PRs
    if [[ -n "$closed_prs" ]] && [[ $(config_get '.content.include_prs') == "true" ]]; then
        while IFS= read -r pr; do
            [[ -z "$pr" ]] && continue
            [[ $yesterday_items -ge $max_items ]] && break

            if [[ $use_corporate == "true" ]]; then
                standup_text+="  • Merged $pr\n"
            else
                standup_text+="  • Merged $pr\n"
            fi
            ((yesterday_items++))
        done <<< "$closed_prs"
    fi

    # Add commits
    if [[ -n "$commits" ]] && [[ $(config_get '.content.include_commits') == "true" ]]; then
        while IFS= read -r commit; do
            [[ -z "$commit" ]] && continue
            [[ $yesterday_items -ge $max_items ]] && break

            standup_text+="  • $commit\n"
            ((yesterday_items++))
        done <<< "$commits"
    fi

    # Add JIRA tickets
    if [[ -n "$jira_tickets" ]] && [[ $(config_get '.content.include_issues') == "true" ]]; then
        while IFS= read -r ticket; do
            [[ -z "$ticket" ]] && continue
            [[ $yesterday_items -ge $max_items ]] && break

            if [[ $use_corporate == "true" ]]; then
                standup_text+="  • Advanced work on $ticket\n"
            else
                standup_text+="  • Worked on $ticket\n"
            fi
            ((yesterday_items++))
        done <<< "$jira_tickets"
    fi

    # Add meetings if important
    if [[ -n "$meetings" ]] && [[ $(config_get '.content.include_meetings') == "true" ]]; then
        local important_meetings=$(echo "$meetings" | grep -iE "planning|review|1:1|demo" || true)

        if [[ -n "$important_meetings" ]]; then
            while IFS= read -r meeting; do
                [[ -z "$meeting" ]] && continue
                [[ $yesterday_items -ge $max_items ]] && break

                if [[ $use_corporate == "true" ]]; then
                    standup_text+="  • Participated in $meeting\n"
                else
                    standup_text+="  • Attended $meeting\n"
                fi
                ((yesterday_items++))
            done <<< "$important_meetings"
        fi
    fi

    # Vague template defaults
    if [[ $yesterday_items -eq 0 ]] && [[ "$template_name" == "vague" ]]; then
        standup_text+="  • Made progress on ongoing tasks\n"
        standup_text+="  • Several code reviews\n"
    elif [[ $yesterday_items -eq 0 ]]; then
        standup_text+="  • Code review and planning\n"
    fi

    # TODAY SECTION
    standup_text+="\n$today_intro\n"

    local today_items=0

    # Add in-progress work
    if [[ -n "$jira_in_progress" ]]; then
        while IFS= read -r ticket; do
            [[ -z "$ticket" ]] && continue
            [[ $today_items -ge $max_items ]] && break

            if [[ $use_corporate == "true" ]]; then
                standup_text+="  • Continue driving progress on $ticket\n"
            else
                standup_text+="  • Continue work on $ticket\n"
            fi
            ((today_items++))
        done <<< "$jira_in_progress"
    fi

    # Add open PRs
    if [[ -n "$open_prs" ]]; then
        while IFS= read -r pr; do
            [[ -z "$pr" ]] && continue
            [[ $today_items -ge $max_items ]] && break

            standup_text+="  • Work on $pr\n"
            ((today_items++))
        done <<< "$open_prs"
    fi

    # Add upcoming meetings
    if [[ -n "$upcoming_meetings" ]]; then
        while IFS= read -r meeting; do
            [[ -z "$meeting" ]] && continue
            [[ $today_items -ge 1 ]] && break  # Only show 1 meeting

            standup_text+="  • $meeting\n"
            ((today_items++))
        done <<< "$upcoming_meetings"
    fi

    # Generic today items
    if [[ $today_items -lt 2 ]]; then
        if [[ $use_corporate == "true" ]]; then
            standup_text+="  • Addressing high-priority items from backlog\n"
        else
            standup_text+="  • Continue current tasks\n"
        fi
    fi

    # BLOCKERS SECTION
    standup_text+="\n$blockers_intro\n"

    if [[ -n "$blockers" ]] && [[ $(config_get '.content.mention_blockers') == "true" ]]; then
        while IFS= read -r blocker; do
            [[ -z "$blocker" ]] && continue
            standup_text+="  • $blocker\n"
        done <<< "$blockers"
    else
        standup_text+="  • $no_blockers\n"
    fi

    echo -e "$standup_text"
}

#=============================================================================
# Posting
#=============================================================================

post_to_slack_webhook() {
    local message=$1

    if [[ -z "$SLACK_WEBHOOK" ]]; then
        log_warn "SLACK_WEBHOOK not configured"
        return 1
    fi

    log_info "Posting to Slack..."

    local payload=$(jq -n --arg text "$message" '{text: $text}')

    local response=$(curl -s -X POST "$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if echo "$response" | grep -q "ok"; then
        log_success "Posted to Slack successfully"
        return 0
    else
        log_error "Failed to post to Slack: $response"
        return 1
    fi
}

post_to_slack_channel() {
    local message=$1

    if [[ -z "$SLACK_TOKEN" ]]; then
        log_warn "SLACK_TOKEN not configured"
        return 1
    fi

    log_info "Posting to $SLACK_CHANNEL..."

    local response=$(curl -s -X POST "https://slack.com/api/chat.postMessage" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"channel\": \"$SLACK_CHANNEL\", \"text\": \"$message\"}")

    if echo "$response" | jq -e '.ok == true' &>/dev/null; then
        log_success "Posted to Slack channel"
        return 0
    else
        local error=$(echo "$response" | jq -r '.error // "unknown"')
        log_error "Failed to post to Slack: $error"
        return 1
    fi
}

#=============================================================================
# History
#=============================================================================

save_standup() {
    local standup=$1

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$STANDUP_HISTORY" ]]; then
        echo '{"standups": []}' > "$STANDUP_HISTORY"
    fi

    local tmp_file=$(mktemp)

    jq --arg standup "$standup" \
       --arg date "$(date -Iseconds)" \
       '.standups += [{date: $date, content: $standup}]' \
       "$STANDUP_HISTORY" > "$tmp_file"

    mv "$tmp_file" "$STANDUP_HISTORY"

    # Keep last 30 days
    local cutoff=$(date -d '30 days ago' -Iseconds 2>/dev/null || date -v-30d -Iseconds)
    jq --arg cutoff "$cutoff" \
       '.standups = [.standups[] | select(.date > $cutoff)]' \
       "$STANDUP_HISTORY" > "$tmp_file"

    mv "$tmp_file" "$STANDUP_HISTORY"
}

show_history() {
    if [[ ! -f "$STANDUP_HISTORY" ]]; then
        log_info "No standup history"
        return 0
    fi

    echo -e "\n${BOLD}Recent Standups:${NC}\n"

    jq -r '.standups[-10:] | .[] | "[\(.date | split("T")[0])]:\n\(.content)\n"' "$STANDUP_HISTORY"
}

#=============================================================================
# Statistics
#=============================================================================

show_stats() {
    if [[ ! -f "$STANDUP_HISTORY" ]]; then
        log_info "No standup history"
        return 0
    fi

    echo -e "\n${BOLD}Standup Statistics:${NC}\n"

    local total=$(jq '.standups | length' "$STANDUP_HISTORY")
    echo "Total standups: $total"

    local this_week=$(jq --arg cutoff "$(date -d '7 days ago' -Iseconds 2>/dev/null || date -v-7d -Iseconds)" \
        '[.standups[] | select(.date > $cutoff)] | length' "$STANDUP_HISTORY")
    echo "This week: $this_week"

    local avg_length=$(jq '.standups[].content | length' "$STANDUP_HISTORY" | \
        awk '{sum+=$1} END {if(NR>0) print int(sum/NR); else print 0}')
    echo "Average length: $avg_length characters"

    local with_blockers=$(jq -r '.standups[].content' "$STANDUP_HISTORY" | \
        grep -c "Blockers:" || echo 0)
    local blocker_mentions=$(jq -r '.standups[].content' "$STANDUP_HISTORY" | \
        grep -A 5 "Blockers:" | grep -cv "None\|No impediments" || echo 0)

    echo "Standups with blockers: $blocker_mentions / $total"

    # Most common activities
    echo -e "\n${BOLD}Most Common Activities:${NC}"
    jq -r '.standups[].content' "$STANDUP_HISTORY" | \
        grep "^  • " | \
        sed 's/^  • //' | \
        sed 's/#[0-9]*://' | \
        sed 's/[A-Z]*-[0-9]*://' | \
        awk '{print $1" "$2}' | \
        sort | uniq -c | sort -rn | head -5

    echo
}

#=============================================================================
# Scheduling
#=============================================================================

setup_schedule() {
    local time=${1:-"09:00"}
    local days=${2:-"Mon,Tue,Wed,Thu,Fri"}

    log_info "Setting up cron job for standup automation..."

    # Convert time to cron format
    local hour=$(echo "$time" | cut -d: -f1)
    local minute=$(echo "$time" | cut -d: -f2)

    # Create cron entry
    local script_path="$(realpath "${BASH_SOURCE[0]}")"
    local cron_cmd="$minute $hour * * 1-5 cd $(dirname "$script_path") && source ../config/config.sh && $script_path post"

    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "standup-bot.sh"; echo "$cron_cmd") | crontab - || true

    log_success "Scheduled standup posts:"
    echo "  Time: $time"
    echo "  Days: $days"
    echo "  Command: $cron_cmd"

    # Calculate next post time (try Linux then macOS format, fallback to simple message)
    local next_post=""
    if next_post=$(date -d "tomorrow $time" 2>/dev/null); then
        echo -e "\nNext post: $next_post"
    elif next_post=$(date -v+1d 2>/dev/null); then
        echo -e "\nNext post: $next_post at $time"
    else
        echo -e "\nNext post: Tomorrow at $time"
    fi
}

stop_schedule() {
    log_info "Removing standup cron job..."

    crontab -l 2>/dev/null | grep -v "standup-bot.sh" | crontab - || true

    log_success "Standup automation stopped"
}

#=============================================================================
# Interactive Edit Mode
#=============================================================================

edit_standup() {
    local standup=$1

    local temp_file=$(mktemp)
    echo -e "$standup" > "$temp_file"

    ${EDITOR:-nano} "$temp_file"

    cat "$temp_file"
    rm "$temp_file"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND] [ARGS]

Auto-generate standup updates from git commits, PRs, and calendar

COMMANDS:
    generate [TEMPLATE]      Generate standup (default: productive)
    post [MESSAGE]           Generate and post to Slack
    history                  Show recent standups
    stats                    Show statistics
    test                     Test configuration

    config set-channel CHAN  Set Slack channel
    config set-token TOKEN   Set Slack bot token
    config show              Show current config

    templates                List available templates
    template create NAME     Create custom template

    schedule TIME [DAYS]     Schedule daily posts (e.g., "09:00" "Mon-Fri")
    schedule stop            Stop scheduled posts

    learn                    Learn from writing style
    vacation START END       Set vacation mode

    github set-repo REPO     Set GitHub repo (owner/repo)
    github analyze           Analyze GitHub activity
    jira configure           Configure JIRA

OPTIONS:
    --template NAME          Use specific template
    --corporate              Enable corporate speak
    --casual                 Disable corporate speak
    --emojis                 Add emojis
    --dry-run                Preview without posting
    --edit                   Edit before posting
    -h, --help               Show this help

TEMPLATES:
    productive              Detailed with specific achievements
    vague                   Minimal details, generic updates
    busy                    Overwhelmed tone, many items
    corporate               Maximum business jargon

EXAMPLES:
    # Generate and post standup
    $0 post

    # Use vague template
    $0 --template vague generate

    # Schedule daily at 9 AM
    $0 schedule "09:00"

    # Set vacation mode
    $0 vacation "2025-12-20" "2025-12-27"

    # Post custom message
    $0 post "Yesterday: X, Today: Y, Blockers: None"

    # Learn writing style
    $0 learn

SETUP:
    1. Configure in config/config.sh:
       export SLACK_TOKEN="xoxb-..."
       export GIT_REPOS="/path/to/repo"
       export GITHUB_REPO="owner/repo"

    2. Test configuration:
       $0 test

    3. Generate standup:
       $0 generate

    4. Set up automation:
       $0 schedule "09:00"

EOF
}

main() {
    init_config

    local command="generate"
    local template="$CURRENT_TEMPLATE"
    local auto_post=0
    local dry_run=0
    local edit_mode=0

    # Parse options and command
    while [[ $# -gt 0 ]]; do
        case $1 in
            --template)
                template=$2
                shift 2
                ;;
            --corporate)
                CORPORATE_SPEAK=1
                shift
                ;;
            --casual)
                CORPORATE_SPEAK=0
                shift
                ;;
            --emojis)
                ADD_EMOJIS=1
                shift
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --edit)
                edit_mode=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            generate|post|history|stats|test|config|templates|template|schedule|learn|vacation|github|jira)
                command=$1
                shift
                # Continue parsing for options after command
                ;;
            *)
                # Unknown option - could be argument for command, break
                break
                ;;
        esac
    done

    # Check dependencies
    check_commands jq git

    # Execute command
    case $command in
        generate)
            local standup=$(generate_standup "$template")

            echo -e "\n${BOLD}Generated Standup:${NC}\n"
            echo -e "$standup"
            echo

            if [[ $edit_mode -eq 1 ]]; then
                standup=$(edit_standup "$standup")
            fi

            save_standup "$standup"

            if [[ $auto_post -eq 1 ]] && [[ $dry_run -eq 0 ]]; then
                if [[ -n "$SLACK_WEBHOOK" ]]; then
                    post_to_slack_webhook "$standup"
                elif [[ -n "$SLACK_TOKEN" ]]; then
                    post_to_slack_channel "$standup"
                fi
            fi
            ;;

        post)
            local message="$*"

            if [[ -z "$message" ]]; then
                message=$(generate_standup "$template")

                if [[ $edit_mode -eq 1 ]]; then
                    message=$(edit_standup "$message")
                fi
            fi

            save_standup "$message"

            if [[ $dry_run -eq 1 ]]; then
                echo -e "\n${BOLD}[DRY RUN] Would post:${NC}\n"
                echo -e "$message"
            else
                if [[ -n "$SLACK_WEBHOOK" ]]; then
                    post_to_slack_webhook "$message"
                elif [[ -n "$SLACK_TOKEN" ]]; then
                    post_to_slack_channel "$message"
                else
                    log_error "No Slack configuration found"
                    exit 1
                fi
            fi
            ;;

        history)
            show_history
            ;;

        stats)
            show_stats
            ;;

        test)
            log_info "Testing configuration..."

            echo "Git repos:"
            get_git_repos

            echo -e "\nRecent commits:"
            local repos=$(get_git_repos)
            summarize_commits "$repos" "yesterday" | head -5

            echo -e "\nSlack configuration:"
            if [[ -n "$SLACK_WEBHOOK" ]]; then
                echo "  ✓ Webhook configured"
            elif [[ -n "$SLACK_TOKEN" ]]; then
                echo "  ✓ Bot token configured"
                echo "  Channel: $SLACK_CHANNEL"
            else
                echo "  ✗ Not configured"
            fi

            echo -e "\nGitHub configuration:"
            if command -v gh &>/dev/null; then
                echo "  ✓ gh CLI installed"
                if [[ -n "$GITHUB_REPO" ]]; then
                    echo "  ✓ Repo: $GITHUB_REPO"
                else
                    echo "  ✗ GITHUB_REPO not set"
                fi
            else
                echo "  ✗ gh CLI not installed"
            fi

            echo -e "\nTest complete!"
            ;;

        config)
            local subcommand="${1:-}"; [[ $# -gt 0 ]] && shift

            case $subcommand in
                set-channel)
                    SLACK_CHANNEL=$1
                    log_success "Slack channel set to: $SLACK_CHANNEL"
                    echo "Add to config/config.sh: export SLACK_CHANNEL=\"$SLACK_CHANNEL\""
                    ;;
                set-token)
                    SLACK_TOKEN=$1
                    log_success "Slack token configured"
                    echo "Add to config/config.sh: export SLACK_TOKEN=\"$SLACK_TOKEN\""
                    ;;
                show)
                    echo "Current configuration:"
                    cat "$STANDUP_CONFIG" | jq .
                    ;;
                *)
                    log_error "Unknown config command: $subcommand"
                    echo "Available: set-channel, set-token, show"
                    ;;
            esac
            ;;

        templates)
            list_templates
            ;;

        template)
            local subcommand=$1
            shift

            case $subcommand in
                create)
                    create_template "$1"
                    ;;
                *)
                    log_error "Unknown template command: $subcommand"
                    ;;
            esac
            ;;

        schedule)
            local subcommand=$1
            shift

            case $subcommand in
                stop)
                    stop_schedule
                    ;;
                *)
                    setup_schedule "$subcommand" "$@"
                    ;;
            esac
            ;;

        learn)
            learn_from_history
            ;;

        vacation)
            local start_date=$1
            local end_date=$2

            if [[ -z "$start_date" ]] || [[ -z "$end_date" ]]; then
                log_error "Usage: vacation START_DATE END_DATE"
                exit 1
            fi

            config_set ".vacation.enabled" "true"
            config_set ".vacation.start_date" "$start_date"
            config_set ".vacation.end_date" "$end_date"

            log_success "Vacation mode enabled: $start_date to $end_date"
            ;;

        github)
            local subcommand=$1
            shift

            case $subcommand in
                set-repo)
                    GITHUB_REPO=$1
                    log_success "GitHub repo set to: $GITHUB_REPO"
                    echo "Add to config/config.sh: export GITHUB_REPO=\"$GITHUB_REPO\""
                    ;;
                analyze)
                    echo "Closed PRs (yesterday):"
                    get_github_prs "closed"
                    echo -e "\nOpen PRs:"
                    get_github_prs "open"
                    echo -e "\nNeeding review:"
                    get_github_prs "review"
                    ;;
                *)
                    log_error "Unknown github command: $subcommand"
                    ;;
            esac
            ;;

        jira)
            log_info "JIRA configuration:"
            echo "Set in config/config.sh:"
            echo "  export JIRA_URL=\"https://your-domain.atlassian.net\""
            echo "  export JIRA_TOKEN=\"your-api-token\""
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
