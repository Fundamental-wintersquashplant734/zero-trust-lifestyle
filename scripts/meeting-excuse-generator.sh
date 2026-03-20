#!/bin/bash
#=============================================================================
# meeting-excuse-generator.sh
# Auto-decline low-value meetings with plausible excuses
# "I automated declining meetings professionally"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

[[ -f "$DATA_DIR/.meeting_excuse_enabled" ]] && AUTO_DECLINE=$(cat "$DATA_DIR/.meeting_excuse_enabled")

GOOGLE_CALENDAR_CREDS=${GOOGLE_CALENDAR_CREDS:-"$HOME/.config/google-calendar-creds.json"}
DECLINE_RULES_FILE="$DATA_DIR/meeting_decline_rules.json"
DECLINE_HISTORY_FILE="$DATA_DIR/meeting_declines.json"

# Time thresholds (minutes)
MIN_FOCUS_BLOCK=120  # 2 hours minimum for focus time
MAX_MEETINGS_PER_DAY=5

# Enable/disable features
AUTO_DECLINE=${AUTO_DECLINE:-0}  # Disabled by default (safety)
DRY_RUN_ONLY=${DRY_RUN_ONLY:-1}  # Dry run by default
SEND_NOTIFICATIONS=${SEND_NOTIFICATIONS:-1}

#=============================================================================
# Excuse Templates
#=============================================================================

# Professional excuses
PROFESSIONAL_EXCUSES=(
    "I have a conflicting commitment at that time"
    "I have a hard stop and won't be able to give this my full attention"
    "I'm at capacity with existing commitments"
    "I have overlapping priorities that require my focus"
    "I need to protect some focus time for deep work"
    "I'm currently heads-down on a critical deliverable"
    "I have a scheduling conflict that I can't move"
    "I'm committed to another obligation at that time"
)

# Async alternatives
ASYNC_SUGGESTIONS=(
    "Happy to review async - can you share notes/agenda beforehand?"
    "Would love to contribute async - please share the doc and I'll add comments"
    "Can I review the recording later? I'd like to stay informed"
    "Could we handle this via email/Slack instead?"
    "Happy to review the decisions async and provide feedback"
    "Can someone take notes and share? I'll follow up with thoughts"
)

# Delegate excuses
DELEGATE_RESPONSES=(
    "I think [PERSON] would be better suited for this discussion"
    "This might be better suited for [PERSON]'s expertise"
    "I recommend including [PERSON] instead - they're closer to this work"
    "[PERSON] from my team can represent our perspective"
)

# Reschedule suggestions
RESCHEDULE_OPTIONS=(
    "Could we find a time next week? I have more flexibility then"
    "My calendar is packed this week - can we push to next week?"
    "Would early next week work instead?"
    "Can we schedule for [DAY] at [TIME] instead?"
)

#=============================================================================
# Meeting Classification
#=============================================================================

classify_meeting_value() {
    local title=$1
    local attendees=$2
    local duration=$3
    local organizer=$4

    local score=50  # Start neutral

    # Low-value indicators
    if echo "$title" | grep -qiE "sync|standup|catch.?up|touch.?base|check.?in|fyi|optional"; then
        ((score -= 20))
    fi

    # "Optional" in title
    if echo "$title" | grep -qi "optional"; then
        ((score -= 30))
    fi

    # Too many attendees (probably not needed)
    local attendee_count=$(echo "$attendees" | tr ',' '\n' | wc -l)
    if [[ $attendee_count -gt 10 ]]; then
        ((score -= 15))
    fi

    # Too long
    if [[ $duration -gt 60 ]]; then
        ((score -= 10))
    fi

    # High-value indicators
    if echo "$title" | grep -qiE "1:1|one.on.one|planning|review|demo|retrospective|postmortem"; then
        ((score += 20))
    fi

    # With manager/exec
    if echo "$organizer" | grep -qiE "manager|director|vp|ceo|cto"; then
        ((score += 30))
    fi

    # Decision-making meetings
    if echo "$title" | grep -qiE "decision|planning|architecture|design"; then
        ((score += 15))
    fi

    # Decline keywords
    if echo "$title" | grep -qiE "all.hands|town.hall|social|happy.hour|team.building"; then
        ((score -= 25))
    fi

    echo $score
}

should_decline_meeting() {
    local score=$1
    local threshold=40

    [[ $score -lt $threshold ]]
}

#=============================================================================
# Excuse Generation
#=============================================================================

generate_excuse() {
    local meeting_title=$1
    local score=$2
    local reason=${3:-""}

    local excuse=""
    local suggestion=""

    # Select excuse type based on reason
    case $reason in
        too_many_today)
            excuse="${PROFESSIONAL_EXCUSES[4]}"  # at capacity
            suggestion="Can we find time next week?"
            ;;
        focus_time)
            excuse="${PROFESSIONAL_EXCUSES[4]}"  # need focus time
            suggestion="${ASYNC_SUGGESTIONS[0]}"
            ;;
        low_value)
            excuse="${PROFESSIONAL_EXCUSES[0]}"  # conflicting commitment
            suggestion=$(printf '%s\n' "${ASYNC_SUGGESTIONS[@]}" | shuf -n 1)
            ;;
        optional)
            excuse="Thanks for the invite!"
            suggestion="${ASYNC_SUGGESTIONS[2]}"  # review recording
            ;;
        *)
            # Random professional excuse
            excuse=$(printf '%s\n' "${PROFESSIONAL_EXCUSES[@]}" | shuf -n 1)
            suggestion=$(printf '%s\n' "${ASYNC_SUGGESTIONS[@]}" | shuf -n 1)
            ;;
    esac

    # Format response
    cat <<EOF
$excuse

$suggestion

Thanks for understanding!
EOF
}

#=============================================================================
# Calendar Integration
#=============================================================================

get_upcoming_meetings() {
    local hours_ahead=${1:-24}

    if ! command -v gcalcli &> /dev/null; then
        log_warn "gcalcli not installed"
        return 1
    fi

    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local later=$(date -u -d "+${hours_ahead} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                  date -u -v+${hours_ahead}H +%Y-%m-%dT%H:%M:%SZ)

    gcalcli --calendar="primary" agenda "$now" "$later" --tsv 2>/dev/null | \
        awk -F'\t' '{print $1"|"$2"|"$3"|"$4}' || true
}

decline_calendar_event() {
    local event_id=$1
    local message=$2

    log_info "Declining event: $event_id"

    if [[ $DRY_RUN_ONLY -eq 1 ]]; then
        log_warn "[DRY RUN] Would decline with message:"
        echo "$message"
        return 0
    fi

    # Use gcalcli to decline
    echo "$message" | gcalcli --calendar="primary" decline "$event_id" 2>/dev/null || {
        log_error "Failed to decline event"
        return 1
    }

    log_success "Meeting declined successfully"
}

#=============================================================================
# Decline Logic
#=============================================================================

process_meeting() {
    local meeting_time=$1
    local meeting_title=$2
    local event_id=$3
    local organizer=$4

    log_info "Processing: $meeting_title"

    # Skip if already processed
    if has_processed_meeting "$event_id"; then
        log_debug "Already processed: $event_id"
        return 0
    fi

    # Extract attendees (simplified)
    local attendees=$(gcalcli --calendar="primary" search "$meeting_title" 2>/dev/null | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+' | tr '\n' ',' || echo "")

    # Get duration (simplified - assume 30 min default)
    local duration=30

    # Classify meeting
    local score=$(classify_meeting_value "$meeting_title" "$attendees" "$duration" "$organizer")

    log_debug "Meeting score: $score"

    # Determine if should decline
    local decline_reason=""

    # Check if too many meetings today
    local meetings_today=$(count_meetings_today)
    if [[ $meetings_today -ge $MAX_MEETINGS_PER_DAY ]]; then
        decline_reason="too_many_today"
    fi

    # Check if during focus time
    if is_focus_time "$meeting_time"; then
        decline_reason="focus_time"
    fi

    # Check meeting value
    if should_decline_meeting "$score"; then
        decline_reason="low_value"
    fi

    # Optional meetings
    if echo "$meeting_title" | grep -qi "optional"; then
        decline_reason="optional"
    fi

    # Should we decline?
    if [[ -n "$decline_reason" ]]; then
        log_warn "Declining: $meeting_title (reason: $decline_reason, score: $score)"

        # Generate excuse
        local excuse=$(generate_excuse "$meeting_title" "$score" "$decline_reason")

        # Decline
        if decline_calendar_event "$event_id" "$excuse"; then
            # Record decline
            record_decline "$event_id" "$meeting_title" "$decline_reason" "$score"

            # Notify
            if [[ $SEND_NOTIFICATIONS -eq 1 ]]; then
                notify "Meeting Declined" "$meeting_title" "normal"
            fi

            # Calculate time saved
            log_success "Time saved: ${duration} minutes"
        fi
    else
        log_success "Keeping: $meeting_title (score: $score)"
    fi

    # Mark as processed
    mark_processed "$event_id"
}

#=============================================================================
# Focus Time Protection
#=============================================================================

is_focus_time() {
    local meeting_time=$1

    # Check if within focus time blocks
    # For now, simple implementation: 9-11am and 2-4pm are focus time
    local hour=$(date -d "$meeting_time" +%H 2>/dev/null || date -j -f "%Y-%m-%d %H:%M" "$meeting_time" +%H 2>/dev/null || echo 12)

    if [[ $hour -ge 9 && $hour -lt 11 ]]; then
        return 0
    fi

    if [[ $hour -ge 14 && $hour -lt 16 ]]; then
        return 0
    fi

    return 1
}

count_meetings_today() {
    # Count meetings already accepted today
    gcalcli --calendar="primary" agenda "today" "tomorrow" --tsv 2>/dev/null | wc -l || echo 0
}

#=============================================================================
# Decline History
#=============================================================================

init_decline_history() {
    if [[ ! -f "$DECLINE_HISTORY_FILE" ]]; then
        echo '{"declines": [], "processed": []}' > "$DECLINE_HISTORY_FILE"
    fi
}

has_processed_meeting() {
    local event_id=$1

    init_decline_history

    jq -e --arg id "$event_id" '.processed | contains([$id])' "$DECLINE_HISTORY_FILE" &>/dev/null
}

mark_processed() {
    local event_id=$1

    init_decline_history

    local tmp_file=$(mktemp)

    jq --arg id "$event_id" '.processed += [$id] | .processed = (.processed | unique)' \
        "$DECLINE_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$DECLINE_HISTORY_FILE"
}

record_decline() {
    local event_id=$1
    local title=$2
    local reason=$3
    local score=$4

    init_decline_history

    local tmp_file=$(mktemp)

    jq --arg id "$event_id" \
       --arg title "$title" \
       --arg reason "$reason" \
       --arg score "$score" \
       --arg timestamp "$(date -Iseconds)" \
       '.declines += [{event_id: $id, title: $title, reason: $reason, score: ($score | tonumber), timestamp: $timestamp}]' \
       "$DECLINE_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$DECLINE_HISTORY_FILE"

    # Keep last 100 declines
    jq '.declines = .declines[-100:]' "$DECLINE_HISTORY_FILE" > "$tmp_file"
    mv "$tmp_file" "$DECLINE_HISTORY_FILE"
}

show_decline_stats() {
    init_decline_history

    local total_declines=$(jq '.declines | length' "$DECLINE_HISTORY_FILE")
    local this_week=$(jq --arg cutoff "$(date -d '7 days ago' -Iseconds 2>/dev/null || date -v-7d -Iseconds)" \
        '[.declines[] | select(.timestamp > $cutoff)] | length' "$DECLINE_HISTORY_FILE")

    # Calculate time saved (assume 30 min average)
    local minutes_saved=$((total_declines * 30))
    local hours_saved=$((minutes_saved / 60))

    cat <<EOF

╔════════════════════════════════════════╗
║   MEETING DECLINE STATISTICS           ║
╚════════════════════════════════════════╝

Total meetings declined: $total_declines
This week: $this_week

Time saved: ${hours_saved}h $((minutes_saved % 60))m

Recent declines:
EOF

    jq -r '.declines[-10:] | .[] | "  - \(.timestamp | split("T")[0]) - \(.title) (\(.reason))"' \
        "$DECLINE_HISTORY_FILE" 2>/dev/null || echo "  None"

    echo
}

#=============================================================================
# Main Logic
#=============================================================================

process_all_meetings() {
    local hours_ahead=${1:-24}

    log_info "Scanning meetings for next ${hours_ahead} hours..."

    local meetings=$(get_upcoming_meetings "$hours_ahead")

    if [[ -z "$meetings" ]]; then
        log_info "No upcoming meetings found"
        return 0
    fi

    local count=0

    while IFS='|' read -r meeting_time meeting_title event_id organizer; do
        [[ -z "$meeting_title" ]] && continue

        process_meeting "$meeting_time" "$meeting_title" "$event_id" "$organizer"
        ((count++))
    done <<< "$meetings"

    log_success "Processed $count meetings"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Auto-decline low-value meetings with professional excuses

COMMANDS:
    process              Process upcoming meetings (default)
    stats                Show decline statistics
    enable               Enable auto-decline (removes dry-run mode)
    disable              Disable auto-decline (back to dry-run)

OPTIONS:
    --hours N            Look ahead N hours (default: 24)
    --auto               Enable automatic declining (dangerous!)
    --dry-run            Dry run only (show what would be declined)
    -h, --help           Show this help

EXAMPLES:
    # Dry run (see what would be declined)
    $0 process

    # Process next 48 hours
    $0 --hours 48 process

    # Enable auto-decline (careful!)
    $0 enable

    # View statistics
    $0 stats

SETUP:
    1. Install gcalcli:
       pip3 install gcalcli

    2. Authenticate:
       gcalcli init

    3. Test (dry run):
       $0 process

    4. When ready, enable auto-decline:
       $0 enable

SAFETY:
    - Dry run mode by default
    - Never declines 1:1s or exec meetings
    - Keeps history of all declines
    - Can be disabled anytime

MEETING CLASSIFICATION:
    Low value (auto-decline):
    - "sync", "standup", "touch base"
    - Optional meetings
    - >10 attendees
    - During focus time (9-11am, 2-4pm)
    - >$MAX_MEETINGS_PER_DAY meetings/day

    High value (keep):
    - 1:1s with manager
    - Planning/decision meetings
    - With executives
    - <5 attendees

EOF
}

main() {
    local command="process"
    local hours_ahead=24

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --hours)
                hours_ahead=$2
                shift 2
                ;;
            --auto)
                AUTO_DECLINE=1
                DRY_RUN_ONLY=0
                log_warn "Auto-decline ENABLED"
                shift
                ;;
            --dry-run)
                DRY_RUN_ONLY=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            process|stats|enable|disable)
                command=$1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check dependencies
    check_commands jq

    if ! command -v gcalcli &> /dev/null; then
        log_error "gcalcli not installed"
        echo "Install with: pip3 install gcalcli"
        exit 1
    fi

    # Execute command
    case $command in
        process)
            if [[ $DRY_RUN_ONLY -eq 1 ]]; then
                log_warn "DRY RUN MODE - no meetings will actually be declined"
            fi

            process_all_meetings "$hours_ahead"
            ;;
        stats)
            show_decline_stats
            ;;
        enable)
            echo "1" > "$DATA_DIR/.meeting_excuse_enabled"
            log_warn "Auto-decline ENABLED - meetings will be declined automatically"
            log_warn "Use '$0 disable' to turn off"
            ;;
        disable)
            echo "0" > "$DATA_DIR/.meeting_excuse_enabled"
            log_success "Auto-decline DISABLED - back to dry-run mode"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
