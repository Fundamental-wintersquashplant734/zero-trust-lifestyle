#!/bin/bash
#=============================================================================
# github-contribution-faker.sh
# Keep that GitHub green while on vacation
# "Proof that contribution graphs are meaningless"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

FAKER_CONFIG="$DATA_DIR/github_faker_config.json"
FAKER_HISTORY="$DATA_DIR/github_faker_history.json"
TARGET_REPO=""

# Commit frequency
WEEKDAY_MIN_COMMITS=1
WEEKDAY_MAX_COMMITS=5
WEEKEND_PROBABILITY=20  # 20% chance of weekend commits
VACATION_COMMITS_PER_WEEK=2

# Time windows (format: "HH:MM-HH:MM")
MORNING_WINDOW="09:00-11:30"
AFTERNOON_WINDOW="14:00-17:30"
EVENING_WINDOW="20:00-22:00"
EVENING_PROBABILITY=10  # 10% chance

# Modes
MODE="normal"  # normal, vacation, stealth, learning
DRY_RUN=${DRY_RUN:-1}  # Default to dry run for safety
ENABLE_FAKER=${ENABLE_FAKER:-0}

#=============================================================================
# Commit Message Templates
#=============================================================================

# Documentation updates
DOC_MESSAGES=(
    "Update README"
    "Fix typos in documentation"
    "Improve documentation clarity"
    "Add examples to README"
    "Update installation instructions"
    "Clarify usage examples"
    "Add troubleshooting section"
    "Update API documentation"
    "Fix broken links"
    "Improve formatting"
)

# Maintenance
MAINTENANCE_MESSAGES=(
    "Refactor for clarity"
    "Clean up code"
    "Update dependencies"
    "Improve code organization"
    "Remove unused code"
    "Optimize performance"
    "Fix linting issues"
    "Update configuration"
    "Improve error handling"
)

# Learning/Notes
LEARNING_MESSAGES=(
    "Add daily notes"
    "Update learning journal"
    "Add research notes"
    "Document findings"
    "Add code snippets"
    "Update study notes"
    "Add technical learnings"
    "Document best practices"
    "Add reference materials"
)

# TIL (Today I Learned)
TIL_MESSAGES=(
    "TIL: [TOPIC]"
    "Today I learned about [TOPIC]"
    "New learning: [TOPIC]"
    "Discovered [TOPIC]"
    "Notes on [TOPIC]"
)

TIL_TOPICS=(
    "async programming patterns"
    "database optimization"
    "testing strategies"
    "performance profiling"
    "security best practices"
    "design patterns"
    "algorithm complexity"
    "system design"
    "debugging techniques"
    "git workflows"
    "shell scripting"
    "API design"
    "error handling"
    "code review tips"
    "refactoring patterns"
)

#=============================================================================
# Pattern Analysis
#=============================================================================

analyze_commit_patterns() {
    local repo=$1

    if [[ ! -d "$repo/.git" ]]; then
        log_error "Not a git repository: $repo"
        return 1
    fi

    cd "$repo" || return 1

    log_info "Analyzing your commit patterns..."

    # Get commit times from last 3 months
    local author=$(git config user.name)
    local commits=$(git log --author="$author" --since="3 months ago" --date=format:"%H" --pretty=format:"%ad" 2>/dev/null || echo "")

    if [[ -z "$commits" ]]; then
        log_warn "No recent commits found, using defaults"
        cd - &>/dev/null
        return 0
    fi

    # Analyze time distribution
    local morning=0 afternoon=0 evening=0 night=0

    while IFS= read -r hour; do
        [[ -z "$hour" ]] && continue

        if [[ $hour -ge 6 && $hour -lt 12 ]]; then
            ((morning++))
        elif [[ $hour -ge 12 && $hour -lt 18 ]]; then
            ((afternoon++))
        elif [[ $hour -ge 18 && $hour -lt 23 ]]; then
            ((evening++))
        else
            ((night++))
        fi
    done <<< "$commits"

    local total=$((morning + afternoon + evening + night))

    if [[ $total -gt 0 ]]; then
        log_info "Your commit pattern:"
        log_info "  Morning (6-12):    $morning ($(( morning * 100 / total ))%)"
        log_info "  Afternoon (12-18): $afternoon ($(( afternoon * 100 / total ))%)"
        log_info "  Evening (18-23):   $evening ($(( evening * 100 / total ))%)"
        log_info "  Night (23-6):      $night ($(( night * 100 / total ))%)"
    fi

    cd - &>/dev/null

    # Store pattern for stealth mode
    echo "{\"morning\": $morning, \"afternoon\": $afternoon, \"evening\": $evening, \"night\": $night, \"total\": $total}" > "$DATA_DIR/.commit_pattern"
}

get_preferred_time_window() {
    if [[ ! -f "$DATA_DIR/.commit_pattern" ]]; then
        echo "$AFTERNOON_WINDOW"
        return
    fi

    local pattern=$(cat "$DATA_DIR/.commit_pattern")
    local morning=$(echo "$pattern" | jq -r '.morning')
    local afternoon=$(echo "$pattern" | jq -r '.afternoon')
    local evening=$(echo "$pattern" | jq -r '.evening')

    # Return window with highest frequency
    if [[ $afternoon -ge $morning ]] && [[ $afternoon -ge $evening ]]; then
        echo "$AFTERNOON_WINDOW"
    elif [[ $morning -ge $evening ]]; then
        echo "$MORNING_WINDOW"
    else
        echo "$EVENING_WINDOW"
    fi
}

#=============================================================================
# Time Generation
#=============================================================================

get_random_commit_time() {
    local window=${1:-"$AFTERNOON_WINDOW"}

    # Parse time window
    local start_time=$(echo "$window" | cut -d'-' -f1)
    local end_time=$(echo "$window" | cut -d'-' -f2)

    local start_hour=$(echo "$start_time" | cut -d':' -f1)
    local start_min=$(echo "$start_time" | cut -d':' -f2)
    local end_hour=$(echo "$end_time" | cut -d':' -f1)
    local end_min=$(echo "$end_time" | cut -d':' -f2)

    # Convert to minutes since midnight
    local start_mins=$((start_hour * 60 + start_min))
    local end_mins=$((end_hour * 60 + end_min))

    # Random time in range
    local random_mins=$((start_mins + RANDOM % (end_mins - start_mins)))

    local hour=$((random_mins / 60))
    local min=$((random_mins % 60))

    printf "%02d:%02d" $hour $min
}

should_commit_today() {
    local day_of_week=$(date +%u)  # 1-7 (Monday-Sunday)

    # Weekend check
    if [[ $day_of_week -ge 6 ]]; then
        # Weekend - random chance
        [[ $((RANDOM % 100)) -lt $WEEKEND_PROBABILITY ]]
        return $?
    fi

    # Weekday
    case $MODE in
        vacation)
            # Lower frequency - ~2 per week
            [[ $((RANDOM % 100)) -lt 30 ]]
            return $?
            ;;
        *)
            # Normal - commit most days
            return 0
            ;;
    esac
}

get_num_commits_today() {
    case $MODE in
        vacation)
            echo 1  # One commit only
            ;;
        learning)
            echo 1  # Daily learning entry
            ;;
        *)
            # Random between min and max
            echo $((WEEKDAY_MIN_COMMITS + RANDOM % (WEEKDAY_MAX_COMMITS - WEEKDAY_MIN_COMMITS + 1)))
            ;;
    esac
}

#=============================================================================
# Commit Message Generation
#=============================================================================

get_random_message() {
    local message_type=${1:-"mixed"}

    case $message_type in
        doc)
            printf '%s\n' "${DOC_MESSAGES[@]}" | shuf -n 1
            ;;
        maintenance)
            printf '%s\n' "${MAINTENANCE_MESSAGES[@]}" | shuf -n 1
            ;;
        learning)
            printf '%s\n' "${LEARNING_MESSAGES[@]}" | shuf -n 1
            ;;
        til)
            local template=$(printf '%s\n' "${TIL_MESSAGES[@]}" | shuf -n 1)
            local topic=$(printf '%s\n' "${TIL_TOPICS[@]}" | shuf -n 1)
            echo "$template" | sed "s/\[TOPIC\]/$topic/"
            ;;
        mixed)
            # Mix of all types
            local types=(doc maintenance learning til)
            local random_type=${types[$((RANDOM % ${#types[@]}))]}
            get_random_message "$random_type"
            ;;
        *)
            echo "Update notes"
            ;;
    esac
}

#=============================================================================
# Repository Management
#=============================================================================

init_notes_repo() {
    local repo_name=${1:-"daily-notes"}
    local repo_path="$HOME/code/$repo_name"

    if [[ -d "$repo_path" ]]; then
        log_warn "Repository already exists: $repo_path"
        TARGET_REPO="$repo_path"
        return 0
    fi

    log_info "Creating notes repository: $repo_path"

    mkdir -p "$repo_path"
    cd "$repo_path" || return 1

    # Initialize git
    git init

    # Create README
    cat > README.md <<'EOF'
# Daily Notes

Personal notes, learnings, and code snippets.

## Purpose

This repository serves as my:
- Daily journal for technical learnings
- Code snippet library
- Research notes
- TIL (Today I Learned) entries

All content is personal and for my own reference.
EOF

    git add README.md
    git commit -m "Initial commit: Setup notes repository"

    # Create directory structure
    mkdir -p {til,snippets,research,journal}

    cat > til/README.md <<'EOF'
# Today I Learned (TIL)

Daily learnings and discoveries.
EOF

    git add til/
    git commit -m "Add TIL directory"

    log_success "Repository created: $repo_path"

    # Optionally create GitHub repo
    if command -v gh &> /dev/null; then
        if ask_yes_no "Create private GitHub repository?"; then
            gh repo create "$repo_name" --private --source="$repo_path" --push
            log_success "GitHub repository created"
        fi
    fi

    cd - &>/dev/null

    TARGET_REPO="$repo_path"
}

init_til_repo() {
    local repo_name="TIL"
    local repo_path="$HOME/code/$repo_name"

    if [[ -d "$repo_path" ]]; then
        log_warn "TIL repository already exists: $repo_path"
        TARGET_REPO="$repo_path"
        return 0
    fi

    log_info "Creating TIL repository: $repo_path"

    mkdir -p "$repo_path"
    cd "$repo_path" || return 1

    git init

    # Create structured TIL README
    cat > README.md <<'EOF'
# TIL (Today I Learned)

A collection of concise write-ups on small things I learn day to day across a variety of languages and technologies.

## Categories

- [Bash](bash/)
- [Git](git/)
- [Python](python/)
- [JavaScript](javascript/)
- [DevOps](devops/)
- [Security](security/)

## About

Inspired by [jbranchaud/til](https://github.com/jbranchaud/til) and [thoughtbot/til](https://github.com/thoughtbot/til).

---

_0 TILs and counting..._
EOF

    mkdir -p {bash,git,python,javascript,devops,security}

    git add README.md
    git commit -m "Initial commit: TIL repository"

    log_success "TIL repository created: $repo_path"

    if command -v gh &> /dev/null; then
        if ask_yes_no "Create public GitHub repository?" "y"; then
            gh repo create "$repo_name" --public --source="$repo_path" --push
            log_success "Public TIL repository created"
        fi
    fi

    cd - &>/dev/null

    TARGET_REPO="$repo_path"
}

#=============================================================================
# Commit Creation
#=============================================================================

create_commit() {
    local repo=$1
    local message=$2
    local commit_time=$3

    if [[ ! -d "$repo/.git" ]]; then
        log_error "Not a git repository: $repo"
        return 1
    fi

    cd "$repo" || return 1

    log_info "Creating commit: $message"

    # Determine what to commit
    case $MODE in
        til)
            create_til_entry
            ;;
        learning)
            create_learning_entry
            ;;
        *)
            create_simple_update
            ;;
    esac

    # Set commit date to specific time
    local commit_date=$(date -d "$commit_time" --iso-8601=seconds 2>/dev/null || \
                        date -j -f "%H:%M" "$commit_time" "+%Y-%m-%dT%H:%M:%S%z")

    # Commit with backdated time
    GIT_AUTHOR_DATE="$commit_date" GIT_COMMITTER_DATE="$commit_date" \
        git commit -m "$message" --allow-empty &>/dev/null

    log_success "Commit created at $commit_time"

    cd - &>/dev/null

    # Record in history
    record_fake_commit "$message" "$commit_date"
}

create_til_entry() {
    local topic=$(printf '%s\n' "${TIL_TOPICS[@]}" | shuf -n 1)
    local category="bash"  # Default
    local filename="til/$category/$(echo "$topic" | tr ' ' '-').md"

    if [[ ! -f "$filename" ]]; then
        cat > "$filename" <<EOF
# $(echo "$topic" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')

Learned about $topic today.

## Key Points

- Important concept 1
- Important concept 2

## Resources

- [Resource](https://example.com)

---

_$(date +%Y-%m-%d)_
EOF
        git add "$filename"
    else
        # Update existing
        echo "" >> "$filename"
        echo "## Update $(date +%Y-%m-%d)" >> "$filename"
        echo "" >> "$filename"
        echo "Additional notes on $topic." >> "$filename"
        git add "$filename"
    fi
}

create_learning_entry() {
    local date=$(date +%Y-%m-%d)
    local filename="journal/$date.md"

    cat > "$filename" <<EOF
# $(date +%B %d, %Y)

## What I Learned

- Technical concept exploration
- Problem-solving approach
- Best practices discovered

## Progress

Continuing work on current projects and learning.

## Notes

[Personal notes and reflections]
EOF

    git add "$filename"
}

create_simple_update() {
    # Simple timestamp update
    local timestamp_file="UPDATES.md"

    if [[ ! -f "$timestamp_file" ]]; then
        echo "# Updates" > "$timestamp_file"
        echo "" >> "$timestamp_file"
    fi

    echo "- $(date '+%Y-%m-%d %H:%M'): General updates and maintenance" >> "$timestamp_file"

    git add "$timestamp_file"
}

#=============================================================================
# Fake Commit Logic
#=============================================================================

commit_if_needed() {
    if [[ $ENABLE_FAKER -eq 0 ]]; then
        log_warn "Faker is disabled. Use 'enable' command to activate"
        return 0
    fi

    if [[ -z "$TARGET_REPO" ]]; then
        load_config
    fi

    if [[ -z "$TARGET_REPO" ]] || [[ ! -d "$TARGET_REPO" ]]; then
        log_error "No target repository configured"
        echo "Run: $0 init"
        return 1
    fi

    # Check if we should commit today
    if ! should_commit_today; then
        log_debug "Skipping commit today (weekend/vacation mode)"
        return 0
    fi

    # Check if already committed today
    if has_committed_today; then
        log_debug "Already committed today"
        return 0
    fi

    # Determine number of commits
    local num_commits=$(get_num_commits_today)

    log_info "Creating $num_commits commit(s) today"

    for ((i=1; i<=num_commits; i++)); do
        # Select time window
        local window
        if [[ $MODE == "stealth" ]]; then
            window=$(get_preferred_time_window)
        else
            # Random window weighted by probability
            if [[ $((RANDOM % 100)) -lt $EVENING_PROBABILITY ]]; then
                window="$EVENING_WINDOW"
            elif [[ $((RANDOM % 2)) -eq 0 ]]; then
                window="$MORNING_WINDOW"
            else
                window="$AFTERNOON_WINDOW"
            fi
        fi

        local commit_time=$(get_random_commit_time "$window")
        local message=$(get_random_message "$MODE")

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would create commit at $commit_time: $message"
        else
            create_commit "$TARGET_REPO" "$message" "$commit_time"

            # Random delay between commits (if multiple)
            if [[ $i -lt $num_commits ]]; then
                sleep $((RANDOM % 300 + 60))  # 1-5 min delay
            fi
        fi
    done
}

has_committed_today() {
    if [[ ! -f "$FAKER_HISTORY" ]]; then
        return 1
    fi

    local today=$(date +%Y-%m-%d)

    jq -e --arg date "$today" '.commits[] | select(.date | startswith($date))' "$FAKER_HISTORY" &>/dev/null
}

#=============================================================================
# History Tracking
#=============================================================================

record_fake_commit() {
    local message=$1
    local date=$2

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$FAKER_HISTORY" ]]; then
        echo '{"commits": [], "stats": {"total": 0, "real": 0, "fake": 0}}' > "$FAKER_HISTORY"
    fi

    local tmp_file=$(mktemp)

    jq --arg msg "$message" \
       --arg date "$date" \
       '.commits += [{message: $msg, date: $date, fake: true}] | .stats.fake += 1 | .stats.total += 1' \
       "$FAKER_HISTORY" > "$tmp_file"

    mv "$tmp_file" "$FAKER_HISTORY"
}

show_status() {
    if [[ ! -f "$FAKER_HISTORY" ]]; then
        echo "No history found. Run 'commit-if-needed' first."
        return 0
    fi

    local total=$(jq -r '.stats.total' "$FAKER_HISTORY")
    local fake=$(jq -r '.stats.fake' "$FAKER_HISTORY")
    local real=$((total - fake))
    local fake_pct=0
    [[ $total -gt 0 ]] && fake_pct=$((fake * 100 / total))

    # Calculate streak
    local streak=0
    local today=$(date +%s)

    for ((i=0; i<365; i++)); do
        local check_date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)
        local has_commit=$(jq -e --arg date "$check_date" '.commits[] | select(.date | startswith($date))' "$FAKER_HISTORY" &>/dev/null && echo 1 || echo 0)

        if [[ $has_commit -eq 1 ]]; then
            ((streak++))
        else
            break
        fi
    done

    cat <<EOF

╔════════════════════════════════════════╗
║  GitHub Contribution Faker Status      ║
╚════════════════════════════════════════╝

Current Streak: ${GREEN}$streak days${NC}
Total Commits: $total
  Real: $real (${GREEN}$((100 - fake_pct))%${NC})
  Fake: $fake (${YELLOW}${fake_pct}%${NC})

Target Repo: ${TARGET_REPO:-"Not configured"}
Mode: $MODE
Faker: $(if [[ $ENABLE_FAKER -eq 1 ]]; then echo "${GREEN}ENABLED${NC}"; else echo "${RED}DISABLED${NC}"; fi)
Dry Run: $(if [[ $DRY_RUN -eq 1 ]]; then echo "${YELLOW}ON${NC}"; else echo "${RED}OFF${NC}"; fi)

Recent Commits:
EOF

    jq -r '.commits[-5:] | .[] | "  - \(.date | split("T")[0]) \(.date | split("T")[1] | split("+")[0]): \(.message)"' "$FAKER_HISTORY" 2>/dev/null || echo "  None"

    echo
}

#=============================================================================
# Configuration
#=============================================================================

save_config() {
    local config=$(jq -n \
        --arg repo "$TARGET_REPO" \
        --arg mode "$MODE" \
        --argjson enable "$ENABLE_FAKER" \
        --argjson dry_run "$DRY_RUN" \
        '{target_repo: $repo, mode: $mode, enable: $enable, dry_run: $dry_run}')

    echo "$config" > "$FAKER_CONFIG"
}

load_config() {
    if [[ ! -f "$FAKER_CONFIG" ]]; then
        return 1
    fi

    TARGET_REPO=$(jq -r '.target_repo' "$FAKER_CONFIG")
    MODE=$(jq -r '.mode // "normal"' "$FAKER_CONFIG")
    ENABLE_FAKER=$(jq -r '.enable // 0' "$FAKER_CONFIG")
    DRY_RUN=$(jq -r '.dry_run // 1' "$FAKER_CONFIG")
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Keep your GitHub contribution graph green (and expose its meaninglessness)

COMMANDS:
    init [notes|til]     Initialize repository
    start                Start faker (respects dry-run)
    commit-if-needed     Make commit if needed today
    status               Show statistics
    enable               Enable faker (disable dry-run)
    disable              Disable faker
    analyze [REPO]       Analyze your commit patterns

OPTIONS:
    --mode MODE          Set mode: normal, vacation, stealth, learning, til
    --dry-run            Show what would happen (default)
    --no-dry-run         Actually create commits (DANGEROUS)
    -h, --help           Show this help

MODES:
    normal      1-5 commits/day, weekdays, occasional weekends
    vacation    1-2 commits/week, looks like light maintenance
    stealth     Mimics your actual commit patterns
    learning    1 commit/day, learning journal entries
    til         Daily TIL entries, public repo

EXAMPLES:
    # Setup
    $0 init notes
    $0 analyze ~/code/my-project

    # Test (dry run)
    $0 commit-if-needed

    # Enable for real
    $0 enable
    $0 --no-dry-run commit-if-needed

    # Vacation mode
    $0 --mode vacation commit-if-needed

    # Status
    $0 status

    # Add to cron (runs at random time daily)
    0 */6 * * * $0 commit-if-needed

ETHICAL USE:
    ✅ Maintaining streaks during vacation
    ✅ Reflecting private repo work
    ✅ Making a statement about toxic metrics
    ❌ Lying to employers
    ❌ Faking experience for jobs
    ❌ Spamming public repos

WHY THIS EXISTS:
    GitHub contribution graphs are broken. They ignore:
    - Private repo work
    - Code review, mentoring, documentation
    - Planning, research, learning
    - Legitimate time off

    This script proves how meaningless they are.

EOF
}

show_disclaimer() {
    cat <<EOF

${YELLOW}═══════════════════════════════════════════════════════${NC}
${YELLOW}                   ⚠️  DISCLAIMER ⚠️                    ${NC}
${YELLOW}═══════════════════════════════════════════════════════${NC}

This script is a STATEMENT about toxic productivity metrics.

GitHub contribution graphs are BROKEN. They:
  ❌ Ignore private repository work
  ❌ Punish vacation time
  ❌ Ignore code review, mentoring, docs
  ❌ Create performative commit behavior

Use this to:
  ✅ Maintain streaks during legitimate time off
  ✅ Reflect work not captured by public commits
  ✅ Make a point about meaningless metrics

DO NOT use this to:
  ❌ Lie to employers about your work
  ❌ Fake experience for job applications
  ❌ Spam public repositories

By using this script, you acknowledge that contribution
graphs measure VISIBILITY, not VALUE.

${YELLOW}═══════════════════════════════════════════════════════${NC}

Press Enter to continue...
EOF

    read -r
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                MODE=$2
                shift 2
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --no-dry-run)
                DRY_RUN=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            init|start|commit-if-needed|status|enable|disable|analyze)
                command=$1
                shift
                break
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Load config
    load_config || true

    # Check dependencies
    check_commands jq git

    # Execute command
    case $command in
        init)
            show_disclaimer

            local repo_type=${1:-"notes"}

            case $repo_type in
                til)
                    init_til_repo
                    ;;
                *)
                    init_notes_repo
                    ;;
            esac

            save_config
            ;;
        start)
            if [[ $DRY_RUN -eq 1 ]]; then
                log_warn "DRY RUN MODE - use --no-dry-run to actually commit"
            fi

            commit_if_needed
            ;;
        commit-if-needed)
            commit_if_needed
            ;;
        status)
            show_status
            ;;
        enable)
            ENABLE_FAKER=1
            DRY_RUN=0
            log_success "Faker ENABLED - commits will be created"
            save_config
            ;;
        disable)
            ENABLE_FAKER=0
            log_success "Faker DISABLED"
            save_config
            ;;
        analyze)
            local repo=${1:-$(pwd)}
            analyze_commit_patterns "$repo"
            ;;
        "")
            show_help
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
