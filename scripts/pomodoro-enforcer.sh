#!/bin/bash
#=============================================================================
# pomodoro-enforcer.sh
# Nuclear Pomodoro timer that actually BLOCKS apps/sites
# "No mercy, no escape"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

POMODORO_STATE_FILE="$DATA_DIR/pomodoro_state.json"
POMODORO_HISTORY_FILE="$DATA_DIR/pomodoro_history.json"
BLOCKED_HOSTS_FILE="/etc/hosts.pomodoro.backup"

# Pomodoro timings (in seconds)
WORK_DURATION=1500      # 25 minutes
SHORT_BREAK=300         # 5 minutes
LONG_BREAK=900          # 15 minutes
POMODOROS_UNTIL_LONG=4  # Long break after this many pomodoros

# Blocking settings
BLOCK_WEBSITES=1
BLOCK_APPS=1
BLOCK_NOTIFICATIONS=1
NUCLEAR_MODE=0  # If 1, kill apps instead of just blocking

# Websites to block during work
BLOCKED_SITES=(
    "facebook.com"
    "twitter.com"
    "x.com"
    "reddit.com"
    "youtube.com"
    "instagram.com"
    "tiktok.com"
    "netflix.com"
    "twitch.tv"
    "9gag.com"
    "imgur.com"
    "linkedin.com"
    "news.ycombinator.com"
    "lobste.rs"
)

# Apps to block/kill during work (process names)
BLOCKED_APPS=(
    "slack"
    "discord"
    "telegram"
    "spotify"
    "steam"
    "chrome"  # Can be nuclear
    "firefox" # Can be nuclear
)

# Safe apps (never block these)
SAFE_APPS=(
    "vscode"
    "code"
    "vim"
    "emacs"
    "terminal"
    "iterm2"
    "alacritty"
    "kitty"
)

#=============================================================================
# State Management
#=============================================================================

init_state() {
    if [[ ! -f "$POMODORO_STATE_FILE" ]]; then
        cat > "$POMODORO_STATE_FILE" <<EOF
{
  "status": "idle",
  "current_pomodoro": 0,
  "total_pomodoros_today": 0,
  "start_time": 0,
  "end_time": 0,
  "type": "work"
}
EOF
        log_success "Initialized pomodoro state"
    fi
}

get_state() {
    init_state
    cat "$POMODORO_STATE_FILE"
}

update_state() {
    local key=$1
    local value=$2

    init_state

    local tmp_file=$(mktemp)
    if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        jq --arg key "$key" --argjson value "$value" \
           '.[$key] = $value' \
           "$POMODORO_STATE_FILE" > "$tmp_file"
    else
        jq --arg key "$key" --arg value "$value" \
           '.[$key] = $value' \
           "$POMODORO_STATE_FILE" > "$tmp_file"
    fi

    mv "$tmp_file" "$POMODORO_STATE_FILE"
}

get_status() {
    get_state | jq -r '.status'
}

is_work_time() {
    local status=$(get_status)
    [[ "$status" == "working" ]]
}

#=============================================================================
# Blocking - Websites
#=============================================================================

block_websites() {
    if [[ $BLOCK_WEBSITES -ne 1 ]]; then
        return 0
    fi

    if ! is_root; then
        log_warn "Need sudo to block websites. Run with sudo or skip website blocking."
        return 1
    fi

    log_info "Blocking distraction websites..."

    # Backup original hosts file if not already backed up
    if [[ ! -f "$BLOCKED_HOSTS_FILE" ]]; then
        cp /etc/hosts "$BLOCKED_HOSTS_FILE"
    fi

    # Add blocked sites to /etc/hosts
    for site in "${BLOCKED_SITES[@]}"; do
        if ! grep -q "$site" /etc/hosts; then
            echo "127.0.0.1 $site" >> /etc/hosts
            echo "127.0.0.1 www.$site" >> /etc/hosts
        fi
    done

    # Flush DNS cache
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        # macOS
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
    fi

    log_success "Websites blocked! Focus time."
}

unblock_websites() {
    if [[ $BLOCK_WEBSITES -ne 1 ]]; then
        return 0
    fi

    if ! is_root; then
        log_warn "Need sudo to unblock websites."
        return 1
    fi

    log_info "Unblocking websites..."

    # Restore original hosts file
    if [[ -f "$BLOCKED_HOSTS_FILE" ]]; then
        cp "$BLOCKED_HOSTS_FILE" /etc/hosts
        rm "$BLOCKED_HOSTS_FILE"
    fi

    # Flush DNS cache
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
    fi

    log_success "Websites unblocked. Enjoy your break!"
}

#=============================================================================
# Blocking - Applications
#=============================================================================

is_safe_app() {
    local app=$1

    for safe in "${SAFE_APPS[@]}"; do
        if [[ "$app" == *"$safe"* ]]; then
            return 0
        fi
    done

    return 1
}

block_apps() {
    if [[ $BLOCK_APPS -ne 1 ]]; then
        return 0
    fi

    log_info "Blocking distraction apps..."

    for app in "${BLOCKED_APPS[@]}"; do
        if is_safe_app "$app"; then
            continue
        fi

        # Check if app is running
        if pgrep -x "$app" &> /dev/null; then
            if [[ $NUCLEAR_MODE -eq 1 ]]; then
                log_warn "NUCLEAR MODE: Killing $app"
                pkill -9 -x "$app" 2>/dev/null || true
            else
                log_info "App running: $app (would kill in nuclear mode)"
            fi
        fi
    done

    # On macOS, we can use AppleScript to hide/minimize apps
    if [[ "$(get_os)" == "macos" ]]; then
        for app in "${BLOCKED_APPS[@]}"; do
            osascript -e "tell application \"$app\" to set visible to false" 2>/dev/null || true
        done
    fi

    log_success "Apps blocked!"
}

unblock_apps() {
    if [[ $BLOCK_APPS -ne 1 ]]; then
        return 0
    fi

    log_info "Unblocking apps..."

    # On macOS, restore visibility
    if [[ "$(get_os)" == "macos" ]]; then
        for app in "${BLOCKED_APPS[@]}"; do
            osascript -e "tell application \"$app\" to set visible to true" 2>/dev/null || true
        done
    fi

    log_success "Apps unblocked!"
}

#=============================================================================
# Blocking - Notifications
#=============================================================================

block_notifications() {
    if [[ $BLOCK_NOTIFICATIONS -ne 1 ]]; then
        return 0
    fi

    log_info "Blocking notifications..."

    # Linux (GNOME/Ubuntu)
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
    fi

    # macOS
    if [[ "$(get_os)" == "macos" ]]; then
        # Enable Do Not Disturb
        defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean true
        defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturbDate -date "$(date -u +"%Y-%m-%d %H:%M:%S +0000")"
        killall NotificationCenter 2>/dev/null || true
    fi

    log_success "Notifications blocked!"
}

unblock_notifications() {
    if [[ $BLOCK_NOTIFICATIONS -ne 1 ]]; then
        return 0
    fi

    log_info "Unblocking notifications..."

    # Linux
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
    fi

    # macOS
    if [[ "$(get_os)" == "macos" ]]; then
        defaults -currentHost write ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb -boolean false
        killall NotificationCenter 2>/dev/null || true
    fi

    log_success "Notifications unblocked!"
}

#=============================================================================
# Pomodoro Timer
#=============================================================================

start_work_session() {
    local duration=${1:-$WORK_DURATION}

    log_info "Starting work session ($(human_time_diff "$duration"))"

    # Update state
    update_state "status" "working"
    update_state "type" "work"
    update_state "start_time" "$(date +%s)"
    update_state "end_time" "$(($(date +%s) + duration))"

    # Enable blocking
    block_websites
    block_apps
    block_notifications

    # Notification
    notify "🍅 Pomodoro Started" "Focus time! $(human_time_diff "$duration")" "normal"

    # Run timer
    run_timer "$duration" "work"

    # Work session complete
    complete_work_session
}

start_break_session() {
    local duration=${1:-$SHORT_BREAK}
    local is_long=${2:-0}

    local break_type="short break"
    [[ $is_long -eq 1 ]] && break_type="long break"

    log_info "Starting $break_type ($(human_time_diff "$duration"))"

    # Update state
    update_state "status" "break"
    update_state "type" "$break_type"
    update_state "start_time" "$(date +%s)"
    update_state "end_time" "$(($(date +%s) + duration))"

    # Disable blocking
    unblock_websites
    unblock_apps
    unblock_notifications

    # Notification
    notify "🍃 Break Time" "Take a break! $(human_time_diff "$duration")" "normal"

    # Run timer
    run_timer "$duration" "break"

    # Break complete
    complete_break_session
}

run_timer() {
    local duration=$1
    local type=$2

    local end_time=$(($(date +%s) + duration))

    while true; do
        local now=$(date +%s)
        local remaining=$((end_time - now))

        if [[ $remaining -le 0 ]]; then
            break
        fi

        # Display countdown
        clear
        display_timer "$remaining" "$type"

        sleep 1
    done

    # Timer complete sound/notification
    if command -v paplay &> /dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true
    elif command -v afplay &> /dev/null; then
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
    fi
}

display_timer() {
    local remaining=$1
    local type=$2

    local minutes=$((remaining / 60))
    local seconds=$((remaining % 60))

    local color=$GREEN
    [[ "$type" == "break" ]] && color=$CYAN

    cat <<EOF

${BOLD}${color}╔════════════════════════════════════════════════════════════╗${NC}
${BOLD}${color}║                                                            ║${NC}
${BOLD}${color}║              🍅 POMODORO TIMER - ${type^^}                 ║${NC}
${BOLD}${color}║                                                            ║${NC}
${BOLD}${color}╚════════════════════════════════════════════════════════════╝${NC}

${BOLD}Time Remaining:${NC}

                    ${BOLD}${color}$(printf "%02d:%02d" "$minutes" "$seconds")${NC}

EOF

    if [[ "$type" == "work" ]]; then
        echo -e "${YELLOW}🚫 Distractions are blocked${NC}"
        echo -e "${YELLOW}📵 Notifications are off${NC}"
        echo
        echo -e "${GREEN}💪 Stay focused!${NC}"
    else
        echo -e "${CYAN}✅ Take a real break${NC}"
        echo -e "${CYAN}🚶 Stand up, stretch, move${NC}"
        echo
        echo -e "${BLUE}🔄 Next session starts automatically${NC}"
    fi

    echo
    echo -e "${YELLOW}Press Ctrl+C to cancel${NC}"
}

complete_work_session() {
    update_state "status" "idle"

    # Increment pomodoro count
    local current=$(get_state | jq -r '.current_pomodoro')
    local total=$(get_state | jq -r '.total_pomodoros_today')

    current=$((current + 1))
    total=$((total + 1))

    update_state "current_pomodoro" "$current"
    update_state "total_pomodoros_today" "$total"

    # Record in history
    record_pomodoro "work" "$WORK_DURATION"

    log_success "Work session complete! Pomodoro #$current"

    # Determine break type
    if [[ $((current % POMODOROS_UNTIL_LONG)) -eq 0 ]]; then
        notify "🎉 Long Break Time!" "You've completed $current pomodoros! Take a long break." "normal"

        if ask_yes_no "Start long break now?" "y"; then
            start_break_session "$LONG_BREAK" 1
        fi
    else
        notify "☕ Short Break Time!" "Take a quick 5-minute break" "normal"

        if ask_yes_no "Start short break now?" "y"; then
            start_break_session "$SHORT_BREAK" 0
        fi
    fi
}

complete_break_session() {
    update_state "status" "idle"

    log_success "Break complete! Ready for next session?"

    notify "🍅 Break Over" "Ready to start another pomodoro?" "normal"

    if ask_yes_no "Start work session now?" "y"; then
        start_work_session
    fi
}

#=============================================================================
# History & Statistics
#=============================================================================

record_pomodoro() {
    local type=$1
    local duration=$2

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$POMODORO_HISTORY_FILE" ]]; then
        echo '{"pomodoros": []}' > "$POMODORO_HISTORY_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --arg type "$type" \
       --arg duration "$duration" \
       --arg timestamp "$(date -Iseconds)" \
       '.pomodoros += [{timestamp: $timestamp, type: $type, duration: $duration}]' \
       "$POMODORO_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$POMODORO_HISTORY_FILE"
}

show_stats() {
    if [[ ! -f "$POMODORO_HISTORY_FILE" ]]; then
        log_info "No pomodoro history available"
        return 0
    fi

    echo -e "\n${BOLD}🍅 Pomodoro Statistics${NC}\n"

    local today=$(date +%Y-%m-%d)
    local this_week_start=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null)

    local total=$(jq '.pomodoros | length' "$POMODORO_HISTORY_FILE")
    local today_count=$(jq --arg date "$today" '[.pomodoros[] | select(.timestamp | startswith($date))] | length' "$POMODORO_HISTORY_FILE")
    local week_count=$(jq --arg date "$this_week_start" '[.pomodoros[] | select(.timestamp >= $date)] | length' "$POMODORO_HISTORY_FILE")

    echo "Total pomodoros: $total"
    echo "Today: $today_count"
    echo "This week: $week_count"
    echo

    local total_minutes=$(jq '[.pomodoros[].duration | tonumber] | add / 60' "$POMODORO_HISTORY_FILE" 2>/dev/null || echo "0")
    echo "Total focus time: $(printf "%.0f" "$total_minutes") minutes ($(printf "%.1f" "$(echo "$total_minutes / 60" | bc -l)") hours)"
    echo

    echo -e "${BOLD}Recent sessions:${NC}"
    jq -r '.pomodoros[-10:] | .[] | "\(.timestamp) - \(.type) (\(.duration | tonumber / 60) minutes)"' "$POMODORO_HISTORY_FILE"
}

#=============================================================================
# Emergency Functions
#=============================================================================

emergency_unblock() {
    log_warn "EMERGENCY UNBLOCK!"

    unblock_websites
    unblock_apps
    unblock_notifications

    update_state "status" "idle"

    log_success "All blocks removed"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Nuclear Pomodoro timer with actual blocking

COMMANDS:
    start                    Start a work session
    break [SHORT|LONG]       Start a break
    stop                     Stop current session
    stats                    Show statistics
    emergency-unblock        Remove all blocks immediately

OPTIONS:
    --work-duration SECS     Work session duration (default: 1500 = 25min)
    --short-break SECS       Short break duration (default: 300 = 5min)
    --long-break SECS        Long break duration (default: 900 = 15min)
    --nuclear                Enable nuclear mode (kill apps instead of hide)
    --no-websites            Don't block websites
    --no-apps                Don't block apps
    --no-notifications       Don't block notifications
    -h, --help               Show this help

EXAMPLES:
    # Start a standard 25-minute pomodoro
    $0 start

    # Start with custom duration (20 minutes)
    $0 start --work-duration 1200

    # Nuclear mode (actually kills apps)
    sudo $0 start --nuclear

    # Emergency unblock (if you need to escape)
    sudo $0 emergency-unblock

    # View your productivity stats
    $0 stats

BLOCKING:
    Websites: ${#BLOCKED_SITES[@]} sites (Facebook, Twitter, Reddit, YouTube, etc.)
    Apps: ${#BLOCKED_APPS[@]} apps (Slack, Discord, Spotify, etc.)
    Notifications: System-wide Do Not Disturb

TIPS:
    • Run with sudo for full blocking power
    • Use --nuclear mode if you lack self-control
    • The timer won't let you quit (Ctrl+C works but unblocks everything)
    • Customize blocked sites/apps in the script configuration

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --work-duration)
                WORK_DURATION=$2
                shift 2
                ;;
            --short-break)
                SHORT_BREAK=$2
                shift 2
                ;;
            --long-break)
                LONG_BREAK=$2
                shift 2
                ;;
            --nuclear)
                NUCLEAR_MODE=1
                shift
                ;;
            --no-websites)
                BLOCK_WEBSITES=0
                shift
                ;;
            --no-apps)
                BLOCK_APPS=0
                shift
                ;;
            --no-notifications)
                BLOCK_NOTIFICATIONS=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            start|break|stop|stats|emergency-unblock)
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

    # Initialize state
    init_state

    # Execute command
    case $command in
        start)
            trap emergency_unblock EXIT INT TERM
            start_work_session
            ;;
        break)
            local break_type=${1:-SHORT}
            if [[ "$break_type" == "LONG" ]]; then
                start_break_session "$LONG_BREAK" 1
            else
                start_break_session "$SHORT_BREAK" 0
            fi
            ;;
        stop)
            emergency_unblock
            log_info "Pomodoro stopped"
            ;;
        stats)
            show_stats
            ;;
        emergency-unblock)
            emergency_unblock
            ;;
        "")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
