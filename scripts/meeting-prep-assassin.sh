#!/bin/bash
#=============================================================================
# meeting-prep-assassin.sh
# Auto-OSINT meeting attendees 5 minutes before meetings
# Generates briefing with recent activity, conversation starters, intel
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

LINKEDIN_API_KEY=${LINKEDIN_API_KEY:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
TWITTER_BEARER_TOKEN=${TWITTER_BEARER_TOKEN:-""}
GOOGLE_CALENDAR_CREDS=${GOOGLE_CALENDAR_CREDS:-"$HOME/.config/google-calendar-creds.json"}

BRIEFING_DIR="$DATA_DIR/meeting-briefings"
CACHE_DIR="$DATA_DIR/osint-cache"
CACHE_TTL=3600  # 1 hour cache

mkdir -p "$BRIEFING_DIR" "$CACHE_DIR"

#=============================================================================
# Calendar Integration
#=============================================================================

get_upcoming_meetings() {
    local minutes_ahead=${1:-5}
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local later=$(date -u -d "+${minutes_ahead} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                  date -u -v+${minutes_ahead}M +%Y-%m-%dT%H:%M:%SZ)  # macOS fallback

    # Try Google Calendar API first
    if [[ -f "$GOOGLE_CALENDAR_CREDS" ]] && command -v gcalcli &> /dev/null; then
        gcalcli --calendar="primary" agenda "$now" "$later" --tsv 2>/dev/null | \
            awk -F'\t' '{print $1"|"$2"|"$3}' || true
    # Fallback to parsing local calendar files
    elif command -v khal &> /dev/null; then
        khal list now "${minutes_ahead}min" 2>/dev/null || true
    else
        log_warn "No calendar integration found. Install gcalcli or khal."
        return 1
    fi
}

extract_attendees() {
    local meeting_id=$1

    # Extract email addresses from meeting
    if command -v gcalcli &> /dev/null; then
        gcalcli --calendar="primary" search "$meeting_id" 2>/dev/null | \
            grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | \
            grep -v "$(whoami)@" || true
    fi
}

#=============================================================================
# OSINT Functions
#=============================================================================

osint_linkedin() {
    local email=$1
    local cache_file="$CACHE_DIR/linkedin_$(echo "$email" | md5sum | cut -d' ' -f1).json"

    # Check cache
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file"))) -lt $CACHE_TTL ]]; then
        cat "$cache_file"
        return 0
    fi

    log_debug "OSINT: LinkedIn lookup for $email"

    # Real LinkedIn API (requires credentials)
    if [[ -n "$LINKEDIN_API_KEY" ]]; then
        local response=$(curl -s -H "Authorization: Bearer $LINKEDIN_API_KEY" \
            "https://api.linkedin.com/v2/people?q=email&email=$email" 2>/dev/null || echo "{}")
        echo "$response" | tee "$cache_file"
    else
        # Fallback: scrape public profile (be careful with rate limits)
        log_debug "LinkedIn API key not set, skipping"
        echo '{"error": "no_api_key"}' | tee "$cache_file"
    fi
}

osint_github() {
    local username=$1
    local cache_file="$CACHE_DIR/github_${username}.json"

    # Check cache
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file"))) -lt $CACHE_TTL ]]; then
        cat "$cache_file"
        return 0
    fi

    log_debug "OSINT: GitHub lookup for $username"

    local -a curl_args=(-s)
    [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

    # Get user info and recent activity
    local user_info=$(curl "${curl_args[@]}" "https://api.github.com/users/$username" 2>/dev/null || echo "{}")
    local events=$(curl "${curl_args[@]}" "https://api.github.com/users/$username/events/public?per_page=10" 2>/dev/null || echo "[]")

    # Combine data
    jq -n \
        --argjson user "$user_info" \
        --argjson events "$events" \
        '{user: $user, recent_events: $events}' | tee "$cache_file"
}

osint_twitter() {
    local handle=$1
    local cache_file="$CACHE_DIR/twitter_${handle}.json"

    # Check cache
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file"))) -lt $CACHE_TTL ]]; then
        cat "$cache_file"
        return 0
    fi

    log_debug "OSINT: Twitter lookup for @$handle"

    if [[ -n "$TWITTER_BEARER_TOKEN" ]]; then
        local user_data=$(curl -s -H "Authorization: Bearer $TWITTER_BEARER_TOKEN" \
            "https://api.twitter.com/2/users/by/username/$handle?user.fields=description,created_at,public_metrics" \
            2>/dev/null || echo "{}")

        local tweets=$(curl -s -H "Authorization: Bearer $TWITTER_BEARER_TOKEN" \
            "https://api.twitter.com/2/users/by/username/$handle/tweets?max_results=10" \
            2>/dev/null || echo "{}")

        jq -n \
            --argjson user "$user_data" \
            --argjson tweets "$tweets" \
            '{user: $user, recent_tweets: $tweets}' | tee "$cache_file"
    else
        log_debug "Twitter API token not set, skipping"
        echo '{"error": "no_api_token"}' | tee "$cache_file"
    fi
}

extract_username_from_email() {
    local email=$1
    # Common patterns: firstname.lastname@company.com
    local username=$(echo "$email" | cut -d'@' -f1 | tr '.' ' ' | awk '{print tolower($1)$2}')
    echo "$username"
}

search_public_info() {
    local name=$1
    local email=$2

    log_debug "OSINT: Searching public info for $name ($email)"

    # Try to find GitHub username
    local github_username=$(extract_username_from_email "$email")
    local github_data=$(osint_github "$github_username")

    # Try to find Twitter handle (same pattern)
    local twitter_data=$(osint_twitter "$github_username")

    # LinkedIn lookup
    local linkedin_data=$(osint_linkedin "$email")

    # Recent blog posts (simple Google search simulation)
    local blog_query=$(echo "$name" | sed 's/ /+/g')
    local recent_posts=""
    if command -v googler &> /dev/null; then
        recent_posts=$(googler --json -n 5 "$blog_query" 2>/dev/null || echo "[]")
    fi

    # Combine all OSINT data
    jq -n \
        --arg name "$name" \
        --arg email "$email" \
        --argjson github "$github_data" \
        --argjson twitter "$twitter_data" \
        --argjson linkedin "$linkedin_data" \
        --arg posts "$recent_posts" \
        '{
            name: $name,
            email: $email,
            github: $github,
            twitter: $twitter,
            linkedin: $linkedin,
            blog_posts: $posts
        }'
}

#=============================================================================
# Briefing Generation
#=============================================================================

generate_talking_points() {
    local osint_data=$1

    # Extract interesting facts
    local points=()

    # GitHub activity
    local github_activity=$(echo "$osint_data" | jq -r '.github.recent_events[0].type // empty')
    if [[ -n "$github_activity" ]]; then
        case "$github_activity" in
            PushEvent)
                local repo=$(echo "$osint_data" | jq -r '.github.recent_events[0].repo.name')
                points+=("💻 Recently pushed to $repo on GitHub")
                ;;
            CreateEvent)
                local repo=$(echo "$osint_data" | jq -r '.github.recent_events[0].repo.name')
                points+=("🎉 Just created new repo: $repo")
                ;;
            IssuesEvent)
                points+=("🐛 Active in open source - recently worked on issues")
                ;;
        esac
    fi

    # Twitter activity
    local recent_tweet=$(echo "$osint_data" | jq -r '.twitter.recent_tweets.data[0].text // empty')
    if [[ -n "$recent_tweet" ]]; then
        points+=("🐦 Recent tweet: \"${recent_tweet:0:100}...\"")
    fi

    # LinkedIn job change
    local company=$(echo "$osint_data" | jq -r '.linkedin.currentCompany // empty')
    if [[ -n "$company" ]]; then
        points+=("🏢 Works at $company")
    fi

    # Print talking points
    if [[ ${#points[@]} -gt 0 ]]; then
        printf '%s\n' "${points[@]}"
    else
        echo "ℹ️  No recent public activity found (private profiles or no API access)"
    fi
}

create_briefing() {
    local meeting_title=$1
    local meeting_time=$2
    shift 2
    local attendees=("$@")

    local briefing_file="$BRIEFING_DIR/$(date +%Y%m%d_%H%M)_${meeting_title// /_}.md"

    cat > "$briefing_file" <<EOF
# Meeting Brief: $meeting_title
**Time**: $meeting_time
**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

---

EOF

    for attendee in "${attendees[@]}"; do
        log_info "Researching: $attendee"

        # Extract name from email (firstname.lastname@company.com -> Firstname Lastname)
        local name=$(echo "$attendee" | cut -d'@' -f1 | tr '.' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')

        cat >> "$briefing_file" <<EOF
## $name ($attendee)

EOF

        # Gather OSINT
        local osint_data=$(search_public_info "$name" "$attendee")

        # Generate talking points
        local talking_points=$(generate_talking_points "$osint_data")

        if [[ -n "$talking_points" ]]; then
            cat >> "$briefing_file" <<EOF
**Intel:**
$talking_points

**Conversation Starters:**
- Ask about recent GitHub projects
- Reference their latest tweets/posts
- Congratulate on recent achievements

EOF
        else
            cat >> "$briefing_file" <<EOF
**Intel:** Limited public information available

**Approach:** Standard professional introduction

EOF
        fi

        cat >> "$briefing_file" <<EOF
---

EOF
    done

    echo "$briefing_file"
}

#=============================================================================
# Main Logic
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Auto-OSINT meeting attendees and generate briefing

OPTIONS:
    -m, --minutes MINS    Check meetings in next MINS minutes (default: 5)
    -c, --continuous      Run continuously in background
    -f, --force MEETING   Force briefing for specific meeting title
    -l, --list           List upcoming meetings
    -h, --help           Show this help

EXAMPLES:
    # Generate briefing for meetings in next 5 minutes
    $0

    # Check meetings in next 15 minutes
    $0 --minutes 15

    # Run as background daemon (checks every minute)
    $0 --continuous &

    # Force briefing for specific meeting
    $0 --force "Weekly standup"

EOF
}

main() {
    local minutes=5
    local continuous=0
    local force_meeting=""
    local list_only=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--minutes)
                minutes=$2
                shift 2
                ;;
            -c|--continuous)
                continuous=1
                shift
                ;;
            -f|--force)
                force_meeting=$2
                shift 2
                ;;
            -l|--list)
                list_only=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    log_info "Meeting Prep Assassin started"

    # Check dependencies
    check_commands jq curl

    # List mode
    if [[ $list_only -eq 1 ]]; then
        log_info "Upcoming meetings:"
        get_upcoming_meetings "$minutes"
        exit 0
    fi

    # Main loop
    while true; do
        local meetings=$(get_upcoming_meetings "$minutes")

        if [[ -n "$meetings" ]]; then
            while IFS='|' read -r meeting_time meeting_title meeting_id; do
                log_info "Found meeting: $meeting_title at $meeting_time"

                # Extract attendees
                local attendees=$(extract_attendees "$meeting_id")

                if [[ -n "$attendees" ]]; then
                    local attendee_array=()
                    while IFS= read -r attendee; do
                        attendee_array+=("$attendee")
                    done <<< "$attendees"

                    # Create briefing
                    local briefing=$(create_briefing "$meeting_title" "$meeting_time" "${attendee_array[@]}")

                    log_success "Briefing created: $briefing"

                    # Show notification
                    notify "Meeting Prep Ready" "Briefing for '$meeting_title' is ready!"

                    # Display briefing
                    if command -v glow &> /dev/null; then
                        glow "$briefing"
                    else
                        cat "$briefing"
                    fi
                else
                    log_warn "No attendees found for: $meeting_title"
                fi
            done <<< "$meetings"
        else
            log_debug "No upcoming meetings in next $minutes minutes"
        fi

        # Exit if not continuous
        [[ $continuous -eq 0 ]] && break

        # Wait before next check (60 seconds)
        sleep 60
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
