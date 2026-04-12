#!/bin/bash
#=============================================================================
# slack-auto-responder.sh
# Auto-respond to Slack messages with random excuses and intelligent delays
# "I automated ignoring people professionally"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

# Auto-responder needs USER token (xoxp-...), not bot token
SLACK_USER_TOKEN=${SLACK_USER_TOKEN:-""}
SLACK_USER_ID=${SLACK_USER_ID:-""}

# Keep SLACK_TOKEN for backwards compatibility, but prefer SLACK_USER_TOKEN
if [[ -z "$SLACK_USER_TOKEN" && -n "${SLACK_TOKEN:-}" ]]; then
    # Check if SLACK_TOKEN is a user token (starts with xoxp-)
    if [[ "$SLACK_TOKEN" == xoxp-* ]]; then
        SLACK_USER_TOKEN="$SLACK_TOKEN"
    fi
fi

RESPONSE_DB="$DATA_DIR/slack_responses.json"
RESPONSE_CACHE="$DATA_DIR/slack_response_cache.json"
STATE_FILE="$DATA_DIR/slack_auto_responder_state.json"

# Delay range (in seconds)
MIN_DELAY=60        # 1 minute
MAX_DELAY=600       # 10 minutes

# Don't spam the same person
SPAM_PREVENTION_WINDOW=3600  # 1 hour

# Office hours (respond during work hours)
OFFICE_HOURS_START=9
OFFICE_HOURS_END=18

# Enable/disable features — defaults before we load state.
AUTO_RESPOND_ENABLED=${AUTO_RESPOND_ENABLED:-1}
OFFICE_HOURS_ONLY=${OFFICE_HOURS_ONLY:-0}
DETECT_URGENCY=${DETECT_URGENCY:-1}
DETECT_ACTIVITY=${DETECT_ACTIVITY:-1}
NO_DELAY=${NO_DELAY:-0}

# Migrate away from the legacy shell-sourced state file. Sourcing it was
# a shell-execution sink for anything that could write to $DATA_DIR.
_legacy_state="$DATA_DIR/slack_auto_responder_state"
if [[ -f "$_legacy_state" ]]; then
    rm -f "$_legacy_state"
fi
unset _legacy_state

# Load state as validated JSON — never source shell from disk.
load_state() {
    [[ -f "$STATE_FILE" ]] || return 0
    AUTO_RESPOND_ENABLED=$(jq -r '(.auto_respond_enabled // 1) | tonumber' "$STATE_FILE" 2>/dev/null || echo 1)
    OFFICE_HOURS_ONLY=$(jq -r '(.office_hours_only // 0) | tonumber' "$STATE_FILE" 2>/dev/null || echo 0)
    DETECT_URGENCY=$(jq -r '(.detect_urgency // 1) | tonumber' "$STATE_FILE" 2>/dev/null || echo 1)
    DETECT_ACTIVITY=$(jq -r '(.detect_activity // 1) | tonumber' "$STATE_FILE" 2>/dev/null || echo 1)
}

save_state() {
    local tmp
    tmp=$(mktemp "${STATE_FILE}.XXXXXX")
    jq -n \
        --argjson ar "$AUTO_RESPOND_ENABLED" \
        --argjson oh "$OFFICE_HOURS_ONLY" \
        --argjson du "$DETECT_URGENCY" \
        --argjson da "$DETECT_ACTIVITY" \
        '{auto_respond_enabled:$ar, office_hours_only:$oh, detect_urgency:$du, detect_activity:$da}' \
        > "$tmp"
    mv "$tmp" "$STATE_FILE"
    chmod 600 "$STATE_FILE"
}

load_state

#=============================================================================
# Response Templates
#=============================================================================

# Casual responses
CASUAL_RESPONSES=(
    "brb"
    "one sec"
    "give me a min"
    "hang on"
    "just a moment"
    "sec"
    "1 min"
)

# On a call/meeting
CALL_RESPONSES=(
    "on a call, will ping you after"
    "in a meeting, brb"
    "on a quick call"
    "jumping on a call, give me 10"
    "in a standup, will get back to you"
    "conference call running late, sorry"
)

# Grabbing something
GRABBING_RESPONSES=(
    "grabbing coffee, brb"
    "quick coffee break"
    "getting some water"
    "stepping away for coffee"
    "refilling coffee ☕"
    "quick break, back in 5"
)

# Working on something
WORKING_RESPONSES=(
    "heads down on something, will check in a bit"
    "in the zone, give me a few"
    "debugging something, brb"
    "finishing up a task"
    "wrapping something up"
    "just need to finish this thought"
    "in the middle of something, 5 min"
)

# Later responses (for after hours)
LATER_RESPONSES=(
    "saw this late, will check tomorrow"
    "just seeing this, will respond in the morning"
    "catching up on messages, will get back to you"
    "missed this earlier, will respond soon"
)

# Urgent acknowledgment
URGENT_RESPONSES=(
    "saw this, give me 2 min"
    "on it"
    "checking now"
    "one sec"
    "looking"
)

#=============================================================================
# Slack API Functions
#=============================================================================

slack_api_call() {
    local method=$1
    shift
    local params="$*"

    if [[ -z "$SLACK_USER_TOKEN" ]]; then
        log_error "SLACK_USER_TOKEN not set in config"
        log_error "This script requires a USER token (xoxp-...), not a bot token (xoxb-...)"
        return 1
    fi

    local url="https://slack.com/api/${method}"

    curl -s -X POST "$url" \
        -H "Authorization: Bearer $SLACK_USER_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$params" 2>/dev/null
}

get_unread_messages() {
    local oldest_ts=${1:-0}
    log_debug "Fetching unread messages since timestamp: $oldest_ts"

    # Get conversations list
    local convos=$(slack_api_call "conversations.list" '{"types": "im,mpim"}')

    # Check if API call was successful
    if ! echo "$convos" | jq -e '.ok == true' >/dev/null 2>&1; then
        local error=$(echo "$convos" | jq -r '.error // "unknown"' 2>/dev/null || echo "api_error")
        log_error "Failed to fetch conversations: $error"
        if [[ "$error" == "not_authed" || "$error" == "invalid_auth" ]]; then
            log_error "Token authentication failed. Check SLACK_USER_TOKEN is valid."
        elif [[ "$error" == "missing_scope" ]]; then
            log_error "Token missing required scopes. Need: channels:read, im:read, channels:history, im:history"
        fi
        return 1
    fi

    # Get unread DMs
    local unread=()

    while IFS= read -r convo_id; do
        [[ -z "$convo_id" ]] && continue

        # Use oldest parameter to only fetch messages after last check
        local history=$(slack_api_call "conversations.history" "{\"channel\": \"$convo_id\", \"oldest\": \"$oldest_ts\", \"limit\": 100}")

        # Check if API call was successful
        if ! echo "$history" | jq -e '.ok == true' >/dev/null 2>&1; then
            continue
        fi

        # Check for messages not from us
        local messages=$(echo "$history" | jq -r --arg user "$SLACK_USER_ID" \
            '.messages[] | select(.user != $user and .user != null) | {user: .user, text: .text, ts: .ts, channel: "'$convo_id'"}' 2>/dev/null || echo "")

        if [[ -n "$messages" ]]; then
            echo "$messages"
        fi
    done < <(echo "$convos" | jq -r '.channels[]?.id // empty' 2>/dev/null || echo "")
}

get_mentions() {
    log_debug "Checking for mentions..."

    # Search for mentions
    local mentions=$(slack_api_call "search.messages" "{\"query\": \"<@$SLACK_USER_ID>\", \"count\": 20}")

    # Check if API call was successful
    if ! echo "$mentions" | jq -e '.ok == true' >/dev/null 2>&1; then
        local error=$(echo "$mentions" | jq -r '.error // "unknown"' 2>/dev/null || echo "api_error")
        log_debug "Failed to fetch mentions: $error"
        return 1
    fi

    echo "$mentions" | jq -r '.messages.matches[]? | select(.user != "'$SLACK_USER_ID'") | {user: .username, text: .text, ts: .ts, channel: .channel.id}' 2>/dev/null || echo ""
}

send_slack_message() {
    local channel=$1
    local text=$2
    local thread_ts=${3:-}

    log_info "Sending to $channel: $text"

    local payload="{\"channel\": \"$channel\", \"text\": \"$text\""

    if [[ -n "$thread_ts" ]]; then
        payload+=", \"thread_ts\": \"$thread_ts\""
    fi

    payload+="}"

    local response=$(slack_api_call "chat.postMessage" "$payload")

    if echo "$response" | jq -e '.ok' &>/dev/null; then
        log_success "Message sent successfully"
        return 0
    else
        local error=$(echo "$response" | jq -r '.error // "unknown"')
        log_error "Failed to send message: $error"
        return 1
    fi
}

set_slack_status() {
    local emoji=$1
    local text=$2
    local expiration=${3:-0}

    local payload="{\"status_text\": \"$text\", \"status_emoji\": \"$emoji\""

    if [[ $expiration -gt 0 ]]; then
        payload+=", \"status_expiration\": $expiration"
    fi

    payload+="}"

    slack_api_call "users.profile.set" "{\"profile\": $payload}"
}

check_user_activity() {
    # Check if user is actually active (typing, online, etc.)
    local presence=$(slack_api_call "users.getPresence" "{\"user\": \"$SLACK_USER_ID\"}")

    local is_active=$(echo "$presence" | jq -r '.presence' 2>/dev/null || echo "away")

    if [[ "$is_active" == "active" ]]; then
        log_debug "User is currently active"
        return 0
    else
        log_debug "User appears away"
        return 1
    fi
}

#=============================================================================
# Response Logic
#=============================================================================

get_random_response() {
    local urgency=${1:-normal}
    local time_of_day=${2:-day}

    local responses=()

    # Select response pool based on urgency and time
    if [[ "$urgency" == "urgent" ]]; then
        responses=("${URGENT_RESPONSES[@]}")
    elif [[ "$time_of_day" == "night" ]]; then
        responses=("${LATER_RESPONSES[@]}")
    else
        # Mix different types for variety
        local response_type=$((RANDOM % 4))
        case $response_type in
            0) responses=("${CASUAL_RESPONSES[@]}") ;;
            1) responses=("${CALL_RESPONSES[@]}") ;;
            2) responses=("${GRABBING_RESPONSES[@]}") ;;
            3) responses=("${WORKING_RESPONSES[@]}") ;;
        esac
    fi

    # Random selection
    local random_index=$((RANDOM % ${#responses[@]}))
    echo "${responses[$random_index]}"
}

calculate_response_delay() {
    local urgency=${1:-normal}
    local time_of_day=${2:-day}

    local delay

    # No delay mode (for testing)
    if [[ $NO_DELAY -eq 1 ]]; then
        echo 0
        return
    fi

    if [[ "$urgency" == "urgent" ]]; then
        # Urgent: 30 seconds to 2 minutes
        delay=$((30 + RANDOM % 90))
    elif [[ "$urgency" == "high" ]]; then
        # High priority: 1-3 minutes
        delay=$((60 + RANDOM % 120))
    elif [[ "$time_of_day" == "night" ]]; then
        # Night time: longer delays (5-10 minutes)
        delay=$((300 + RANDOM % 300))
    else
        # Normal: 1-10 minutes as configured
        delay=$(generate_random_delay "$MIN_DELAY" "$MAX_DELAY")
    fi

    echo $delay
}

detect_message_urgency() {
    local text=$1
    local user=$2

    # Urgent keywords
    local urgent_keywords=(
        "urgent"
        "asap"
        "emergency"
        "critical"
        "now"
        "immediately"
        "911"
        "p0"
        "production"
        "down"
        "broken"
        "fire"
        "🔥"
        "🚨"
    )

    # High priority keywords
    local high_keywords=(
        "important"
        "quick question"
        "need help"
        "blocked"
        "issue"
        "problem"
        "can you"
        "could you"
    )

    # Check for urgent
    for keyword in "${urgent_keywords[@]}"; do
        if echo "$text" | grep -qi "$keyword"; then
            echo "urgent"
            return
        fi
    done

    # Check for high
    for keyword in "${high_keywords[@]}"; do
        if echo "$text" | grep -qi "$keyword"; then
            echo "high"
            return
        fi
    done

    # Check for multiple exclamation marks
    local exclamations=$(echo "$text" | grep -o '!' | wc -l)
    if [[ $exclamations -ge 3 ]]; then
        echo "high"
        return
    fi

    # Check for ALL CAPS (more than 50% caps)
    local total_chars=$(echo "$text" | tr -d ' \n' | wc -c)
    local caps_chars=$(echo "$text" | grep -o '[A-Z]' | wc -l)

    if [[ $total_chars -gt 10 ]] && [[ $((caps_chars * 100 / total_chars)) -gt 50 ]]; then
        echo "high"
        return
    fi

    echo "normal"
}

is_office_hours() {
    local hour=$(date +%H)
    local day=$(date +%u)  # 1-7 (Monday-Sunday)

    # Weekend
    if [[ $day -ge 6 ]]; then
        return 1
    fi

    # Check office hours
    if [[ $hour -ge $OFFICE_HOURS_START && $hour -lt $OFFICE_HOURS_END ]]; then
        return 0
    fi

    return 1
}

get_time_of_day() {
    local hour=$(date +%H)

    if [[ $hour -ge 22 || $hour -lt 6 ]]; then
        echo "night"
    elif [[ $hour -ge 6 && $hour -lt 12 ]]; then
        echo "morning"
    elif [[ $hour -ge 12 && $hour -lt 18 ]]; then
        echo "afternoon"
    else
        echo "evening"
    fi
}

#=============================================================================
# Response Tracking
#=============================================================================

init_response_cache() {
    if [[ ! -f "$RESPONSE_CACHE" ]]; then
        echo '{"responses": []}' > "$RESPONSE_CACHE"
    fi
}

has_responded_recently() {
    local user=$1
    local channel=$2
    local window=$SPAM_PREVENTION_WINDOW

    init_response_cache

    local now=$(date +%s)
    local cutoff=$((now - window))

    # Check if we responded to this user/channel recently
    local recent=$(jq --arg user "$user" \
                      --arg channel "$channel" \
                      --arg cutoff "$cutoff" \
                      '.responses[] | select(.user == $user and .channel == $channel and (.timestamp | tonumber) > ($cutoff | tonumber))' \
                      "$RESPONSE_CACHE" 2>/dev/null || echo "")

    if [[ -n "$recent" ]]; then
        log_debug "Already responded to $user in $channel recently"
        return 0
    fi

    return 1
}

record_response() {
    local user=$1
    local channel=$2
    local message=$3

    init_response_cache

    local tmp_file=$(mktemp)

    jq --arg user "$user" \
       --arg channel "$channel" \
       --arg message "$message" \
       --arg timestamp "$(date +%s)" \
       '.responses += [{user: $user, channel: $channel, message: $message, timestamp: $timestamp}]' \
       "$RESPONSE_CACHE" > "$tmp_file"

    mv "$tmp_file" "$RESPONSE_CACHE"

    # Clean old entries (keep last 24 hours)
    local yesterday=$(($(date +%s) - 86400))
    jq --arg cutoff "$yesterday" \
       '.responses = [.responses[] | select((.timestamp | tonumber) > ($cutoff | tonumber))]' \
       "$RESPONSE_CACHE" > "$tmp_file"

    mv "$tmp_file" "$RESPONSE_CACHE"
}

#=============================================================================
# Main Response Handler
#=============================================================================

process_message() {
    local user=$1
    local channel=$2
    local text=$3
    local ts=$4

    log_info "Processing message from $user in $channel"

    # Check if we should respond
    if [[ $AUTO_RESPOND_ENABLED -eq 0 ]]; then
        log_debug "Auto-respond disabled"
        return 0
    fi

    # Check office hours
    if [[ $OFFICE_HOURS_ONLY -eq 1 ]] && ! is_office_hours; then
        log_debug "Outside office hours, skipping"
        return 0
    fi

    # Check if already responded recently
    if has_responded_recently "$user" "$channel"; then
        log_debug "Already responded recently, skipping to prevent spam"
        return 0
    fi

    # Check if user is actually active (don't auto-respond if you're typing)
    if [[ $DETECT_ACTIVITY -eq 1 ]] && check_user_activity; then
        log_debug "User is active, skipping auto-response"
        return 0
    fi

    # Detect urgency
    local urgency="normal"
    if [[ $DETECT_URGENCY -eq 1 ]]; then
        urgency=$(detect_message_urgency "$text" "$user")
        log_debug "Message urgency: $urgency"
    fi

    # Get time context
    local time_of_day=$(get_time_of_day)

    # Calculate delay
    local delay=$(calculate_response_delay "$urgency" "$time_of_day")
    log_info "Will respond in ${delay}s ($(human_time_diff $delay))"

    # Get response
    local response=$(get_random_response "$urgency" "$time_of_day")

    # Show notification
    notify "Slack Auto-Response Queued" "Will respond in $(human_time_diff $delay): '$response'" "normal"

    # Wait for delay
    sleep "$delay"

    # Send response
    if send_slack_message "$channel" "$response" "$ts"; then
        record_response "$user" "$channel" "$response"

        # Optional: Set Slack status
        if [[ "$urgency" != "urgent" ]]; then
            local status_emoji=":coffee:"
            [[ "$time_of_day" == "night" ]] && status_emoji=":zzz:"

            set_slack_status "$status_emoji" "Back in a few" "$(($(date +%s) + 300))"
        fi
    fi
}

#=============================================================================
# Monitoring Daemon
#=============================================================================

monitor_slack() {
    log_info "Starting Slack auto-responder daemon"

    # Test API connection first
    log_info "Testing Slack API connection..."
    local test_response=$(slack_api_call "auth.test" "{}")

    if ! echo "$test_response" | jq -e '.ok == true' >/dev/null 2>&1; then
        local error=$(echo "$test_response" | jq -r '.error // "unknown"' 2>/dev/null || echo "invalid_response")
        log_error "Slack API connection failed: $error"
        log_error "Please check your SLACK_USER_TOKEN is valid"
        exit 1
    fi

    local user_name=$(echo "$test_response" | jq -r '.user // "unknown"')
    log_success "Connected to Slack as: $user_name"

    # Track last check time to only process new messages
    # Start by checking messages from the last hour (not just future messages)
    # Use Slack timestamp format (seconds with decimal for microseconds)
    local last_check_ts=$(echo "$(date +%s) - 3600" | bc)
    log_info "Monitoring for messages (will respond to unread messages from last hour)..."
    log_debug "Starting timestamp: $last_check_ts"

    while true; do
        # Wait before checking (30 seconds)
        sleep 30

        # Get unread DMs - pass last_check_ts as oldest timestamp for API filtering
        local messages
        messages=$(get_unread_messages "$last_check_ts") || true

        if [[ -n "$messages" ]]; then
            while IFS= read -r message; do
                [[ -z "$message" ]] && continue

                # Validate JSON before parsing
                if ! echo "$message" | jq -e '.' >/dev/null 2>&1; then
                    continue
                fi

                local user=$(echo "$message" | jq -r '.user // empty')
                local channel=$(echo "$message" | jq -r '.channel // empty')
                local text=$(echo "$message" | jq -r '.text // empty')
                local ts=$(echo "$message" | jq -r '.ts // empty')

                # Skip if missing required fields
                [[ -z "$user" || -z "$channel" || -z "$ts" ]] && continue

                # Additional timestamp check (should be redundant now but kept for safety)
                # Use < instead of <= to avoid skipping messages at exact timestamp
                local msg_ts_float=$ts
                if ! ([[ "${msg_ts_float%%.*}" -gt "${last_check_ts%%.*}" ]] || [[ "$msg_ts_float" > "$last_check_ts" ]]); then
                    log_debug "Skipping old message (ts=$msg_ts_float <= last=$last_check_ts)"
                    continue
                fi

                log_info "New message detected: user=$user, ts=$ts"

                # Process synchronously to avoid race conditions
                process_message "$user" "$channel" "$text" "$ts"
            done <<< "$messages"
        fi

        # Get mentions (in channels)
        local mentions
        mentions=$(get_mentions) || true

        if [[ -n "$mentions" ]]; then
            while IFS= read -r mention; do
                [[ -z "$mention" ]] && continue

                # Validate JSON before parsing
                if ! echo "$mention" | jq -e '.' >/dev/null 2>&1; then
                    continue
                fi

                local user=$(echo "$mention" | jq -r '.user // empty')
                local channel=$(echo "$mention" | jq -r '.channel // empty')
                local text=$(echo "$mention" | jq -r '.text // empty')
                local ts=$(echo "$mention" | jq -r '.ts // empty')

                # Skip if missing required fields
                [[ -z "$user" || -z "$channel" || -z "$ts" ]] && continue

                # Additional timestamp check with proper float comparison
                local msg_ts_float=$ts
                if ! ([[ "${msg_ts_float%%.*}" -gt "${last_check_ts%%.*}" ]] || [[ "$msg_ts_float" > "$last_check_ts" ]]); then
                    continue
                fi

                log_info "New mention detected: user=$user, ts=$ts"

                process_message "$user" "$channel" "$text" "$ts"
            done <<< "$mentions"
        fi

        # Update last check timestamp to current time
        # Use the current timestamp to ensure we don't miss messages
        last_check_ts=$(date +%s)
    done
}

#=============================================================================
# Manual Controls
#=============================================================================

enable_auto_respond() {
    AUTO_RESPOND_ENABLED=1
    save_state
    log_success "Auto-respond ENABLED"
    notify "Slack Auto-Responder" "Auto-respond is now ENABLED" "normal"
}

disable_auto_respond() {
    AUTO_RESPOND_ENABLED=0
    save_state
    log_warn "Auto-respond DISABLED"
    notify "Slack Auto-Responder" "Auto-respond is now DISABLED" "normal"
}

toggle_auto_respond() {
    if [[ $AUTO_RESPOND_ENABLED -eq 1 ]]; then
        disable_auto_respond
    else
        enable_auto_respond
    fi
}

show_status() {
    cat <<EOF

╔════════════════════════════════════════╗
║   SLACK AUTO-RESPONDER STATUS          ║
╚════════════════════════════════════════╝

Auto-respond: $(if [[ $AUTO_RESPOND_ENABLED -eq 1 ]]; then echo -e "${GREEN}ENABLED${NC}"; else echo -e "${RED}DISABLED${NC}"; fi)
Office hours only: $OFFICE_HOURS_ONLY
Detect urgency: $DETECT_URGENCY
Detect activity: $DETECT_ACTIVITY

Response delay: $(human_time_diff $MIN_DELAY) - $(human_time_diff $MAX_DELAY)
Spam prevention: $(human_time_diff $SPAM_PREVENTION_WINDOW)

Current time: $(date)
Office hours: $OFFICE_HOURS_START:00 - $OFFICE_HOURS_END:00
In office hours: $(if is_office_hours; then echo "YES"; else echo "NO"; fi)

Recent responses (last hour):
EOF

    if [[ -f "$RESPONSE_CACHE" ]]; then
        jq -r '.responses[-5:] | .[] | "  - \(.timestamp | tonumber | strftime("%H:%M")) → \(.user): \(.message)"' "$RESPONSE_CACHE" 2>/dev/null || echo "  None"
    fi

    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Auto-respond to Slack messages with random excuses

COMMANDS:
    monitor              Start monitoring daemon (default)
    enable               Enable auto-respond
    disable              Disable auto-respond
    toggle               Toggle auto-respond on/off
    status               Show current status
    test USER CHANNEL    Test auto-respond for user

OPTIONS:
    --min-delay SECS    Minimum delay in seconds (default: 60)
    --max-delay SECS    Maximum delay in seconds (default: 600)
    --office-hours      Only respond during office hours
    --no-delay          Respond immediately (for testing)
    -h, --help          Show this help

EXAMPLES:
    # Start monitoring daemon
    $0 monitor &

    # Check status
    $0 status

    # Disable for deep work session
    $0 disable

    # Re-enable later
    $0 enable

    # Test with instant response (no delay)
    $0 --no-delay test U12345 C67890

SETUP:
    1. Get Slack USER token (xoxp-...): https://api.slack.com/tokens
       NOTE: This script needs a USER token, not a bot token!

    2. Add to config/config.sh:
       export SLACK_USER_TOKEN="xoxp-your-user-token-here"
       export SLACK_USER_ID="U01234567"

    3. Run daemon:
       $0 monitor &

SMART FEATURES:
    ✓ Random delays (1-10 minutes)
    ✓ Different responses based on time of day
    ✓ Urgency detection (faster response for urgent messages)
    ✓ Spam prevention (won't respond to same person repeatedly)
    ✓ Activity detection (won't respond if you're active)
    ✓ Office hours awareness

EOF
}

main() {
    local command="monitor"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --min-delay)
                MIN_DELAY=$2
                shift 2
                ;;
            --max-delay)
                MAX_DELAY=$2
                shift 2
                ;;
            --office-hours)
                OFFICE_HOURS_ONLY=1
                shift
                ;;
            --no-delay)
                NO_DELAY=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            monitor|enable|disable|toggle|status|test)
                command=$1
                shift
                break  # Stop parsing, let command handle remaining args
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check dependencies
    check_commands jq curl bc

    # Check Slack user token
    if [[ -z "$SLACK_USER_TOKEN" ]]; then
        log_error "SLACK_USER_TOKEN not set in config.sh"
        echo ""
        echo "This script requires a USER token (xoxp-...), not a bot token (xoxb-...)"
        echo ""
        echo "Get your user token from: https://api.slack.com/tokens"
        echo "Add to config/config.sh:"
        echo "  export SLACK_USER_TOKEN=\"xoxp-your-token-here\""
        echo "  export SLACK_USER_ID=\"U01234567\""
        exit 1
    fi

    # Execute command
    case $command in
        monitor)
            monitor_slack
            ;;
        enable)
            enable_auto_respond
            ;;
        disable)
            disable_auto_respond
            ;;
        toggle)
            toggle_auto_respond
            ;;
        status)
            show_status
            ;;
        test)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: test USER CHANNEL"
                exit 1
            fi
            process_message "$1" "$2" "test message" "$(date +%s).000000"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
