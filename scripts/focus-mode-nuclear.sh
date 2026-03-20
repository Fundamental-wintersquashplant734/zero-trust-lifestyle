#!/bin/bash
#=============================================================================
# focus-mode-nuclear.sh
# Extreme focus mode with aggressive distraction blocking
# "Nuclear option: block everything until work is done"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

FOCUS_DB="$DATA_DIR/focus_data.json"
FOCUS_SESSION="$DATA_DIR/current_focus.json"
BLOCKLIST="$CONFIG_DIR/focus_blocklist.txt"
HOSTS_BACKUP="/tmp/hosts.backup"

# Focus levels
FOCUS_GENTLE=1
FOCUS_SERIOUS=2
FOCUS_NUCLEAR=3
FOCUS_DOOMSDAY=4

# Default durations (minutes)
DEFAULT_POMODORO=25
DEFAULT_SHORT_BREAK=5
DEFAULT_LONG_BREAK=15

# Nuclear mode settings
ENABLE_NUCLEAR=${ENABLE_NUCLEAR:-0}
ENABLE_HOSTS_BLOCKING=${ENABLE_HOSTS_BLOCKING:-1}
ENABLE_APP_BLOCKING=${ENABLE_APP_BLOCKING:-1}
ENABLE_NOTIFICATION_BLOCKING=${ENABLE_NOTIFICATION_BLOCKING:-1}

# Penalty settings
BREAK_PENALTY_MULTIPLIER=2  # Break focus = 2x time added
SHAME_MODE=${SHAME_MODE:-1}

#=============================================================================
# Default Blocklists
#=============================================================================

DEFAULT_DISTRACTIONS=(
    # Social Media
    "facebook.com"
    "twitter.com"
    "x.com"
    "instagram.com"
    "tiktok.com"
    "reddit.com"
    "linkedin.com"
    "snapchat.com"
    "pinterest.com"

    # Entertainment
    "youtube.com"
    "netflix.com"
    "hulu.com"
    "twitch.tv"
    "disneyplus.com"
    "primevideo.com"

    # News
    "news.ycombinator.com"
    "cnn.com"
    "bbc.com"
    "nytimes.com"
    "theguardian.com"

    # Gaming
    "steampowered.com"
    "store.steampowered.com"
    "epicgames.com"
    "battle.net"

    # Shopping
    "amazon.com"
    "ebay.com"
    "aliexpress.com"
    "etsy.com"
)

NUCLEAR_ADDITIONS=(
    # Block everything extra
    "gmail.com"
    "mail.google.com"
    "outlook.com"
    "slack.com"
    "discord.com"
    "teams.microsoft.com"
    "zoom.us"
)

#=============================================================================
# Database Initialization
#=============================================================================

init_focus_db() {
    if [[ ! -f "$FOCUS_DB" ]]; then
        cat > "$FOCUS_DB" <<'EOF'
{
  "sessions": [],
  "stats": {
    "total_sessions": 0,
    "total_focus_minutes": 0,
    "total_breaks_taken": 0,
    "current_streak": 0,
    "longest_streak": 0,
    "nuclear_activations": 0,
    "distractions_blocked": 0
  },
  "violations": []
}
EOF
        log_info "Focus database initialized"
    fi
}

init_blocklist() {
    if [[ ! -f "$BLOCKLIST" ]]; then
        mkdir -p "$CONFIG_DIR"
        printf "%s\n" "${DEFAULT_DISTRACTIONS[@]}" > "$BLOCKLIST"
        log_info "Blocklist initialized with defaults"
    fi
}

#=============================================================================
# Focus Session Management
#=============================================================================

start_focus_session() {
    local duration=$1
    local level=${2:-$FOCUS_GENTLE}
    local task=${3:-"Focus work"}

    init_focus_db

    # Check if session already running
    if [[ -f "$FOCUS_SESSION" ]]; then
        log_error "Focus session already running. Use 'status' to check or 'stop' to end it."
        exit 1
    fi

    local start_time=$(date +%s)
    local end_time=$((start_time + duration * 60))

    cat > "$FOCUS_SESSION" <<EOF
{
  "start_time": $start_time,
  "end_time": $end_time,
  "duration_minutes": $duration,
  "level": $level,
  "task": "$task",
  "violations": 0,
  "distractions_blocked": 0
}
EOF

    # Apply blocking based on level
    apply_focus_mode "$level"

    log_success "Focus session started: $duration minutes at level $level"
    log_info "Task: $task"
    log_info "Session ends at: $(date -d @$end_time '+%H:%M:%S' 2>/dev/null || date -r $end_time '+%H:%M:%S')"

    # Show motivation
    show_focus_motivation "$level"

    # Start monitoring if nuclear
    if [[ $level -ge $FOCUS_NUCLEAR ]]; then
        monitor_focus_session &
        echo $! > /tmp/focus_monitor.pid
    fi
}

stop_focus_session() {
    if [[ ! -f "$FOCUS_SESSION" ]]; then
        log_error "No active focus session"
        exit 1
    fi

    local session=$(cat "$FOCUS_SESSION")
    local start_time=$(echo "$session" | jq -r '.start_time')
    local level=$(echo "$session" | jq -r '.level')
    local task=$(echo "$session" | jq -r '.task')
    local violations=$(echo "$session" | jq -r '.violations')

    local now=$(date +%s)
    local actual_duration=$(( (now - start_time) / 60 ))

    # Remove blocking
    remove_focus_mode "$level"

    # Stop monitoring
    if [[ -f /tmp/focus_monitor.pid ]]; then
        local pid=$(cat /tmp/focus_monitor.pid)
        kill "$pid" 2>/dev/null || true
        rm /tmp/focus_monitor.pid
    fi

    # Record session
    record_session "$task" "$actual_duration" "$level" "$violations"

    # Clean up
    rm "$FOCUS_SESSION"

    log_success "Focus session completed: $actual_duration minutes"

    if [[ $violations -gt 0 ]]; then
        log_warn "Violations: $violations"
        if [[ $SHAME_MODE -eq 1 ]]; then
            shame_report "$violations"
        fi
    fi

    show_session_stats
}

get_session_status() {
    if [[ ! -f "$FOCUS_SESSION" ]]; then
        echo "No active focus session"
        return 1
    fi

    local session=$(cat "$FOCUS_SESSION")
    local start_time=$(echo "$session" | jq -r '.start_time')
    local end_time=$(echo "$session" | jq -r '.end_time')
    local duration=$(echo "$session" | jq -r '.duration_minutes')
    local level=$(echo "$session" | jq -r '.level')
    local task=$(echo "$session" | jq -r '.task')
    local violations=$(echo "$session" | jq -r '.violations')

    local now=$(date +%s)
    local elapsed=$(( (now - start_time) / 60 ))
    local remaining=$(( (end_time - now) / 60 ))

    if [[ $now -gt $end_time ]]; then
        local overtime=$(( (now - end_time) / 60 ))
        echo "⏰ SESSION COMPLETE ($overtime min ago)"
        echo "Run 'stop' to end the session"
    else
        local level_name=$(get_level_name "$level")

        cat <<EOF

╔════════════════════════════════════════╗
║      🎯 FOCUS SESSION ACTIVE 🎯        ║
╚════════════════════════════════════════╝

${BOLD}Task:${NC} $task
${BOLD}Level:${NC} $level_name
${BOLD}Progress:${NC} $elapsed/$duration minutes
${BOLD}Remaining:${NC} $remaining minutes
${BOLD}Violations:${NC} $violations

$(draw_progress_bar "$elapsed" "$duration")

EOF
    fi
}

draw_progress_bar() {
    local current=$1
    local total=$2
    local width=40

    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))

    local bar=""
    for ((i=0; i<width; i++)); do
        if [[ $i -lt $filled ]]; then
            bar+="█"
        else
            bar+="░"
        fi
    done

    echo "[$bar] $percent%"
}

#=============================================================================
# Focus Mode Application
#=============================================================================

apply_focus_mode() {
    local level=$1

    case $level in
        $FOCUS_GENTLE)
            log_info "Applying GENTLE focus mode..."
            block_websites "gentle"
            disable_notifications "gentle"
            ;;
        $FOCUS_SERIOUS)
            log_info "Applying SERIOUS focus mode..."
            block_websites "serious"
            block_applications "serious"
            disable_notifications "serious"
            ;;
        $FOCUS_NUCLEAR)
            log_warn "Applying NUCLEAR focus mode..."
            block_websites "nuclear"
            block_applications "nuclear"
            disable_notifications "nuclear"
            set_nuclear_wallpaper
            ;;
        $FOCUS_DOOMSDAY)
            log_error "Applying DOOMSDAY focus mode..."
            block_websites "doomsday"
            block_applications "doomsday"
            disable_notifications "doomsday"
            disable_internet
            set_nuclear_wallpaper
            lockdown_system
            ;;
    esac
}

remove_focus_mode() {
    local level=$1

    log_info "Removing focus mode restrictions..."

    unblock_websites
    unblock_applications
    restore_notifications

    if [[ $level -ge $FOCUS_DOOMSDAY ]]; then
        restore_internet
        unlock_system
    fi

    if [[ $level -ge $FOCUS_NUCLEAR ]]; then
        restore_wallpaper
    fi
}

#=============================================================================
# Website Blocking
#=============================================================================

block_websites() {
    local level=$1

    if [[ $ENABLE_HOSTS_BLOCKING -eq 0 ]]; then
        return 0
    fi

    init_blocklist

    # Backup hosts file
    if [[ -f /etc/hosts ]] && [[ ! -f "$HOSTS_BACKUP" ]]; then
        sudo cp /etc/hosts "$HOSTS_BACKUP"
    fi

    log_info "Blocking distracting websites..."

    # Read blocklist
    local sites=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        sites+=("$line")
    done < "$BLOCKLIST"

    # Add nuclear sites if needed
    if [[ $level == "nuclear" || $level == "doomsday" ]]; then
        sites+=("${NUCLEAR_ADDITIONS[@]}")
    fi

    # Add to hosts file
    {
        echo ""
        echo "# FOCUS MODE BLOCKS - DO NOT EDIT"
        echo "# Started: $(date)"
        for site in "${sites[@]}"; do
            echo "127.0.0.1 $site"
            echo "127.0.0.1 www.$site"
            echo "::1 $site"
            echo "::1 www.$site"
        done
    } | sudo tee -a /etc/hosts > /dev/null

    # Flush DNS cache
    if command -v systemd-resolve &> /dev/null; then
        sudo systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        sudo dscacheutil -flushcache 2>/dev/null || true
    fi

    log_success "Blocked ${#sites[@]} websites"
}

unblock_websites() {
    if [[ ! -f "$HOSTS_BACKUP" ]]; then
        return 0
    fi

    log_info "Unblocking websites..."

    sudo cp "$HOSTS_BACKUP" /etc/hosts
    rm "$HOSTS_BACKUP"

    # Flush DNS cache
    if command -v systemd-resolve &> /dev/null; then
        sudo systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        sudo dscacheutil -flushcache 2>/dev/null || true
    fi

    log_success "Websites unblocked"
}

#=============================================================================
# Application Blocking
#=============================================================================

block_applications() {
    local level=$1

    if [[ $ENABLE_APP_BLOCKING -eq 0 ]]; then
        return 0
    fi

    log_info "Blocking distracting applications..."

    local apps=(
        "slack"
        "discord"
        "telegram"
        "signal"
        "chrome"
        "firefox"
    )

    # Kill running instances
    for app in "${apps[@]}"; do
        pkill -9 -i "$app" 2>/dev/null || true
    done

    # On Linux, use chmod to prevent execution (requires sudo)
    if [[ "$(uname)" == "Linux" ]]; then
        for app in "${apps[@]}"; do
            local app_path=$(which "$app" 2>/dev/null || true)
            if [[ -n "$app_path" ]]; then
                sudo chmod -x "$app_path" 2>/dev/null || true
            fi
        done
    fi

    # On macOS, can use chflags
    if [[ "$(uname)" == "Darwin" ]]; then
        for app in "${apps[@]}"; do
            local app_path="/Applications/${app^}.app"
            if [[ -d "$app_path" ]]; then
                sudo chflags hidden "$app_path" 2>/dev/null || true
            fi
        done
    fi

    log_success "Applications blocked"
}

unblock_applications() {
    if [[ $ENABLE_APP_BLOCKING -eq 0 ]]; then
        return 0
    fi

    log_info "Unblocking applications..."

    local apps=(
        "slack"
        "discord"
        "telegram"
        "signal"
        "chrome"
        "firefox"
    )

    # Restore permissions on Linux
    if [[ "$(uname)" == "Linux" ]]; then
        for app in "${apps[@]}"; do
            local app_path=$(which "$app" 2>/dev/null || true)
            if [[ -n "$app_path" ]]; then
                sudo chmod +x "$app_path" 2>/dev/null || true
            fi
        done
    fi

    # Restore on macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        for app in "${apps[@]}"; do
            local app_path="/Applications/${app^}.app"
            if [[ -d "$app_path" ]]; then
                sudo chflags nohidden "$app_path" 2>/dev/null || true
            fi
        done
    fi

    log_success "Applications unblocked"
}

#=============================================================================
# Notification Management
#=============================================================================

disable_notifications() {
    local level=$1

    if [[ $ENABLE_NOTIFICATION_BLOCKING -eq 0 ]]; then
        return 0
    fi

    log_info "Disabling notifications..."

    # Linux (GNOME)
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
    fi

    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean true
        defaults -currentHost write com.apple.notificationcenterui doNotDisturbDate -date "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        killall NotificationCenter 2>/dev/null || true
    fi

    log_success "Notifications disabled"
}

restore_notifications() {
    if [[ $ENABLE_NOTIFICATION_BLOCKING -eq 0 ]]; then
        return 0
    fi

    log_info "Restoring notifications..."

    # Linux (GNOME)
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.notifications show-banners true 2>/dev/null || true
    fi

    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean false
        killall NotificationCenter 2>/dev/null || true
    fi

    log_success "Notifications restored"
}

#=============================================================================
# Nuclear Mode Features
#=============================================================================

set_nuclear_wallpaper() {
    log_info "Setting FOCUS MODE wallpaper..."

    local wallpaper_text="FOCUS MODE ACTIVE\n\nNO DISTRACTIONS\nGET WORK DONE"
    local wallpaper="/tmp/focus_wallpaper.png"

    # Create simple wallpaper with ImageMagick if available
    if command -v convert &> /dev/null; then
        convert -size 1920x1080 xc:black \
            -font DejaVu-Sans-Bold -pointsize 72 -fill red \
            -gravity center -annotate +0+0 "$wallpaper_text" \
            "$wallpaper" 2>/dev/null || true

        # Set wallpaper (Linux)
        if command -v gsettings &> /dev/null; then
            gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper"
        fi

        # macOS
        if [[ "$(uname)" == "Darwin" ]]; then
            osascript -e "tell application \"System Events\" to set picture of every desktop to \"$wallpaper\"" 2>/dev/null || true
        fi
    fi
}

restore_wallpaper() {
    # Just reset to default or previous
    log_info "Restoring wallpaper..."
}

disable_internet() {
    log_warn "DISABLING INTERNET CONNECTION..."

    # This is extreme - only for doomsday mode
    if command -v nmcli &> /dev/null; then
        nmcli networking off
    fi

    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        networksetup -setairportpower en0 off 2>/dev/null || true
    fi
}

restore_internet() {
    log_info "Restoring internet connection..."

    if command -v nmcli &> /dev/null; then
        nmcli networking on
    fi

    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        networksetup -setairportpower en0 on 2>/dev/null || true
    fi
}

lockdown_system() {
    log_error "SYSTEM LOCKDOWN ACTIVE"

    # Prevent system sleep
    if command -v systemd-inhibit &> /dev/null; then
        systemd-inhibit --what=sleep --who="focus-mode" --why="Focus session active" &
        echo $! > /tmp/focus_inhibit.pid
    fi

    # macOS
    if command -v caffeinate &> /dev/null; then
        caffeinate -d &
        echo $! > /tmp/focus_caffeinate.pid
    fi
}

unlock_system() {
    log_info "Unlocking system..."

    if [[ -f /tmp/focus_inhibit.pid ]]; then
        kill "$(cat /tmp/focus_inhibit.pid)" 2>/dev/null || true
        rm /tmp/focus_inhibit.pid
    fi

    if [[ -f /tmp/focus_caffeinate.pid ]]; then
        kill "$(cat /tmp/focus_caffeinate.pid)" 2>/dev/null || true
        rm /tmp/focus_caffeinate.pid
    fi
}

#=============================================================================
# Session Monitoring
#=============================================================================

monitor_focus_session() {
    log_info "Focus monitor started (PID: $$)"

    while [[ -f "$FOCUS_SESSION" ]]; do
        # Check for violations
        check_violations

        # Auto-end if time expired
        local session=$(cat "$FOCUS_SESSION")
        local end_time=$(echo "$session" | jq -r '.end_time')
        local now=$(date +%s)

        if [[ $now -ge $end_time ]]; then
            notify "Focus Session" "Time's up! Session complete." "normal"
            break
        fi

        sleep 30
    done
}

check_violations() {
    # Check if blocked sites are being accessed
    # This is a simplified version - real implementation would need packet inspection

    init_blocklist

    while IFS= read -r site; do
        [[ -z "$site" || "$site" =~ ^# ]] && continue

        # Check browser history/active connections
        if netstat -an 2>/dev/null | grep -q "$site"; then
            record_violation "$site"
        fi
    done < "$BLOCKLIST"
}

record_violation() {
    local site=$1

    if [[ ! -f "$FOCUS_SESSION" ]]; then
        return
    fi

    log_warn "VIOLATION DETECTED: Attempted to access $site"

    # Update session
    local tmp=$(mktemp)
    jq '.violations += 1 | .distractions_blocked += 1' "$FOCUS_SESSION" > "$tmp"
    mv "$tmp" "$FOCUS_SESSION"

    # Add penalty time
    local penalty=$((DEFAULT_POMODORO * BREAK_PENALTY_MULTIPLIER))
    jq --arg penalty "$penalty" '.end_time += ($penalty | tonumber * 60)' "$FOCUS_SESSION" > "$tmp"
    mv "$tmp" "$FOCUS_SESSION"

    notify "FOCUS VIOLATION" "Attempted to access $site\nAdded $penalty min penalty!" "critical"

    # Update global stats
    local tmp_db=$(mktemp)
    jq '.stats.distractions_blocked += 1' "$FOCUS_DB" > "$tmp_db"
    mv "$tmp_db" "$FOCUS_DB"
}

#=============================================================================
# Session Recording
#=============================================================================

record_session() {
    local task=$1
    local duration=$2
    local level=$3
    local violations=$4

    init_focus_db

    local tmp=$(mktemp)

    jq --arg task "$task" \
       --arg duration "$duration" \
       --arg level "$level" \
       --arg violations "$violations" \
       --arg timestamp "$(date -Iseconds)" \
       '.sessions += [{
           task: $task,
           duration: ($duration | tonumber),
           level: ($level | tonumber),
           violations: ($violations | tonumber),
           timestamp: $timestamp
       }] |
       .stats.total_sessions += 1 |
       .stats.total_focus_minutes += ($duration | tonumber)' \
       "$FOCUS_DB" > "$tmp"

    mv "$tmp" "$FOCUS_DB"

    # Update streak
    update_streak

    log_success "Session recorded"
}

update_streak() {
    init_focus_db

    local today=$(date +%Y-%m-%d)
    local streak=0

    # Check backwards day by day
    for ((i=0; i<365; i++)); do
        local check_date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)

        local has_session=$(jq -e --arg date "$check_date" \
            '.sessions[] | select(.timestamp | startswith($date))' \
            "$FOCUS_DB" &>/dev/null && echo 1 || echo 0)

        if [[ $has_session -eq 1 ]]; then
            ((streak++))
        else
            break
        fi
    done

    local longest=$(jq -r '.stats.longest_streak' "$FOCUS_DB")
    [[ $streak -gt $longest ]] && longest=$streak

    local tmp=$(mktemp)
    jq --arg streak "$streak" \
       --arg longest "$longest" \
       '.stats.current_streak = ($streak | tonumber) |
        .stats.longest_streak = ($longest | tonumber)' \
       "$FOCUS_DB" > "$tmp"

    mv "$tmp" "$FOCUS_DB"
}

#=============================================================================
# Pomodoro Timer
#=============================================================================

pomodoro() {
    local cycles=${1:-4}
    local work_min=${2:-$DEFAULT_POMODORO}
    local short_break=${3:-$DEFAULT_SHORT_BREAK}
    local long_break=${4:-$DEFAULT_LONG_BREAK}

    log_info "Starting Pomodoro: $cycles cycles of ${work_min}min work"

    for ((i=1; i<=cycles; i++)); do
        log_info "Cycle $i/$cycles - WORK TIME ($work_min min)"
        start_focus_session "$work_min" "$FOCUS_SERIOUS" "Pomodoro cycle $i"

        # Wait for session to complete
        sleep $((work_min * 60))
        stop_focus_session

        if [[ $i -lt $cycles ]]; then
            log_success "Break time! ($short_break min)"
            notify "Pomodoro" "Take a ${short_break}min break!" "normal"
            sleep $((short_break * 60))
        else
            log_success "All cycles complete! Long break ($long_break min)"
            notify "Pomodoro Complete" "Take a ${long_break}min break!" "normal"
        fi
    done

    log_success "Pomodoro session complete!"
}

#=============================================================================
# Dashboard & Stats
#=============================================================================

show_dashboard() {
    init_focus_db

    local total_sessions=$(jq -r '.stats.total_sessions' "$FOCUS_DB")
    local total_minutes=$(jq -r '.stats.total_focus_minutes' "$FOCUS_DB")
    local total_hours=$(echo "scale=1; $total_minutes / 60" | bc)
    local current_streak=$(jq -r '.stats.current_streak' "$FOCUS_DB")
    local longest_streak=$(jq -r '.stats.longest_streak' "$FOCUS_DB")
    local distractions=$(jq -r '.stats.distractions_blocked' "$FOCUS_DB")

    # Today's stats
    local today=$(date +%Y-%m-%d)
    local today_sessions=$(jq --arg date "$today" '[.sessions[] | select(.timestamp | startswith($date))] | length' "$FOCUS_DB")
    local today_minutes=$(jq --arg date "$today" '[.sessions[] | select(.timestamp | startswith($date)) | .duration] | add // 0' "$FOCUS_DB")

    # This week
    local week_start=$(date -d "monday" +%Y-%m-%d 2>/dev/null || date -v-mon +%Y-%m-%d)
    local week_sessions=$(jq --arg date "$week_start" '[.sessions[] | select(.timestamp >= $date)] | length' "$FOCUS_DB")
    local week_minutes=$(jq --arg date "$week_start" '[.sessions[] | select(.timestamp >= $date) | .duration] | add // 0' "$FOCUS_DB")

    cat <<EOF

╔════════════════════════════════════════╗
║      🎯 FOCUS MODE DASHBOARD 🎯        ║
╚════════════════════════════════════════╝

${BOLD}Overall Stats:${NC}
  Total Sessions: $total_sessions
  Total Focus Time: ${total_hours}h ($total_minutes min)
  Current Streak: $current_streak days
  Longest Streak: $longest_streak days
  Distractions Blocked: $distractions

${BOLD}Today:${NC}
  Sessions: $today_sessions
  Focus Time: $today_minutes min

${BOLD}This Week:${NC}
  Sessions: $week_sessions
  Focus Time: $week_minutes min

EOF

    # Show active session if any
    if [[ -f "$FOCUS_SESSION" ]]; then
        echo "${BOLD}Active Session:${NC}"
        get_session_status
    fi
}

show_session_stats() {
    init_focus_db

    local last_5=$(jq -r '.sessions[-5:] | reverse | .[] |
        "\(.timestamp | split("T")[0]) \(.timestamp | split("T")[1] | split("+")[0]) - \(.task) (\(.duration)min, Level \(.level), \(.violations) violations)"' \
        "$FOCUS_DB")

    cat <<EOF

${BOLD}Recent Sessions:${NC}
$last_5

EOF
}

#=============================================================================
# Motivational Messages
#=============================================================================

show_focus_motivation() {
    local level=$1

    case $level in
        $FOCUS_GENTLE)
            cat <<EOF

💡 Focus Mode Active

You can do this. Minimize distractions and focus on what matters.

EOF
            ;;
        $FOCUS_SERIOUS)
            cat <<EOF

⚡ Serious Focus Mode

No excuses. This is work time. Everything else can wait.

EOF
            ;;
        $FOCUS_NUCLEAR)
            cat <<EOF

☢️  NUCLEAR FOCUS MODE

This is war against distraction.

Your distractions are blocked.
Your notifications are off.
Your excuses are irrelevant.

WORK. NOW.

EOF
            ;;
        $FOCUS_DOOMSDAY)
            cat <<EOF

💀 DOOMSDAY MODE ACTIVATED

Everything is locked down.
Internet is disabled.
No escape.

This is you vs. the task.

There is no alternative but to finish.

DO. THE. WORK.

EOF
            ;;
    esac
}

shame_report() {
    local violations=$1

    cat <<EOF

╔════════════════════════════════════════╗
║         SHAME REPORT                   ║
╚════════════════════════════════════════╝

You broke focus $violations time(s).

Each violation shows weakness.
Each distraction is a failure.

Do better next time.

EOF
}

get_level_name() {
    local level=$1

    case $level in
        $FOCUS_GENTLE) echo "Gentle" ;;
        $FOCUS_SERIOUS) echo "Serious" ;;
        $FOCUS_NUCLEAR) echo "☢️  NUCLEAR" ;;
        $FOCUS_DOOMSDAY) echo "💀 DOOMSDAY" ;;
        *) echo "Unknown" ;;
    esac
}

#=============================================================================
# Emergency Override
#=============================================================================

emergency_override() {
    log_error "EMERGENCY OVERRIDE ACTIVATED"

    # Stop everything
    if [[ -f "$FOCUS_SESSION" ]]; then
        local level=$(jq -r '.level' "$FOCUS_SESSION")
        remove_focus_mode "$level"
        rm "$FOCUS_SESSION"
    fi

    # Kill monitor
    if [[ -f /tmp/focus_monitor.pid ]]; then
        kill "$(cat /tmp/focus_monitor.pid)" 2>/dev/null || true
        rm /tmp/focus_monitor.pid
    fi

    # Restore everything
    unblock_websites
    unblock_applications
    restore_notifications
    restore_internet
    unlock_system

    log_success "All restrictions removed"
}

#=============================================================================
# Help
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Extreme focus mode with aggressive distraction blocking

COMMANDS:
    start MINUTES [LEVEL] [TASK]  Start focus session
    stop                          Stop current session
    status                        Show current session status
    dashboard                     Show statistics dashboard
    pomodoro [CYCLES]             Run Pomodoro timer (default: 4 cycles)
    emergency                     Emergency override - remove all blocks

FOCUS LEVELS:
    1 - Gentle      Block websites only
    2 - Serious     Block websites + apps + notifications (default)
    3 - Nuclear     Everything + wallpaper + monitoring
    4 - Doomsday    Nuclear + internet disabled + system lockdown

EXAMPLES:
    # Start 25min focus session
    $0 start 25

    # Start 90min NUCLEAR session
    $0 start 90 3 "Write thesis chapter"

    # Start Pomodoro (4x25min cycles)
    $0 pomodoro

    # Check status
    $0 status

    # Emergency stop everything
    $0 emergency

BLOCKLIST:
    Edit blocklist: $BLOCKLIST
    Add custom sites, one per line

CONFIGURATION:
    Enable nuclear mode: ENABLE_NUCLEAR=1
    Disable shame mode: SHAME_MODE=0

    Set in config/config.sh or export as environment variables

WARNING:
    - Nuclear mode is AGGRESSIVE
    - Doomsday mode disables internet
    - Violations add penalty time (${BREAK_PENALTY_MULTIPLIER}x)
    - Use 'emergency' command if stuck

EOF
}

#=============================================================================
# Main
#=============================================================================

main() {
    local command=${1:-"dashboard"}
    shift || true

    # Check dependencies
    check_commands jq bc

    # Initialize
    init_focus_db
    init_blocklist

    case $command in
        start)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: start MINUTES [LEVEL] [TASK]"
                exit 1
            fi
            local duration=$1
            local level=${2:-$FOCUS_SERIOUS}
            local task=${3:-"Focus work"}

            # Check if nuclear mode is allowed
            if [[ $level -ge $FOCUS_NUCLEAR ]] && [[ $ENABLE_NUCLEAR -eq 0 ]]; then
                log_error "Nuclear mode disabled. Set ENABLE_NUCLEAR=1 to enable."
                exit 1
            fi

            start_focus_session "$duration" "$level" "$task"
            ;;
        stop)
            stop_focus_session
            ;;
        status)
            get_session_status
            ;;
        dashboard)
            show_dashboard
            ;;
        pomodoro)
            local cycles=${1:-4}
            pomodoro "$cycles"
            ;;
        emergency)
            emergency_override
            ;;
        -h|--help)
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
