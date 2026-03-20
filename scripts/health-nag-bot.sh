#!/bin/bash
#=============================================================================
# health-nag-bot.sh
# Fitness/health nag bot with escalating guilt trips
# "No workout in 5 days = screen lockout"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

HEALTH_DB="$DATA_DIR/health_data.json"
NAG_HISTORY="$DATA_DIR/nag_history.json"

# Thresholds
MAX_SEDENTARY_HOURS=3
MIN_STEPS_DAILY=8000
MIN_WORKOUTS_PER_WEEK=3
MAX_DAYS_WITHOUT_WORKOUT=5
MIN_WATER_GLASSES=8
MIN_SLEEP_HOURS=7

# Nag levels
NAG_LEVEL_WARNING=1
NAG_LEVEL_SERIOUS=2
NAG_LEVEL_CRITICAL=3
NAG_LEVEL_LOCKOUT=4

# Enable features
ENABLE_SCREEN_LOCKOUT=${ENABLE_SCREEN_LOCKOUT:-0}
ENABLE_AUTO_NAG=${ENABLE_AUTO_NAG:-1}
SEDENTARY_CHECK_INTERVAL=3600  # 1 hour

# Activity tracker integration
FITBIT_TOKEN=${FITBIT_TOKEN:-""}
GARMIN_TOKEN=${GARMIN_TOKEN:-""}
APPLE_HEALTH_DB=${APPLE_HEALTH_DB:-""}

#=============================================================================
# Activity Data Collection
#=============================================================================

init_health_db() {
    if [[ ! -f "$HEALTH_DB" ]]; then
        cat > "$HEALTH_DB" <<'EOF'
{
  "workouts": [],
  "steps": {},
  "water": {},
  "sleep": {},
  "last_movement": null,
  "sedentary_time": 0,
  "stats": {
    "current_streak": 0,
    "longest_streak": 0,
    "total_workouts": 0
  }
}
EOF
        log_info "Health database initialized"
    fi
}

record_workout() {
    local workout_type=$1
    local duration=${2:-30}  # minutes

    init_health_db

    local today=$(date +%Y-%m-%d)
    local timestamp=$(date -Iseconds)

    local tmp_file=$(mktemp)

    jq --arg date "$today" \
       --arg type "$workout_type" \
       --arg duration "$duration" \
       --arg timestamp "$timestamp" \
       '.workouts += [{date: $date, type: $type, duration: ($duration | tonumber), timestamp: $timestamp}] |
        .stats.total_workouts += 1' \
       "$HEALTH_DB" > "$tmp_file"

    mv "$tmp_file" "$HEALTH_DB"

    # Update streak
    update_workout_streak

    log_success "Recorded $workout_type workout ($duration min)"
}

record_steps() {
    local steps=$1
    local date=${2:-$(date +%Y-%m-%d)}

    init_health_db

    local tmp_file=$(mktemp)

    jq --arg date "$date" \
       --arg steps "$steps" \
       '.steps[$date] = ($steps | tonumber)' \
       "$HEALTH_DB" > "$tmp_file"

    mv "$tmp_file" "$HEALTH_DB"

    log_debug "Recorded $steps steps for $date"
}

record_water() {
    local glasses=$1

    init_health_db

    local today=$(date +%Y-%m-%d)
    local current=$(jq -r --arg date "$today" '.water[$date] // 0' "$HEALTH_DB")
    local new_total=$((current + glasses))

    local tmp_file=$(mktemp)

    jq --arg date "$today" \
       --arg total "$new_total" \
       '.water[$date] = ($total | tonumber)' \
       "$HEALTH_DB" > "$tmp_file"

    mv "$tmp_file" "$HEALTH_DB"

    log_success "Recorded $glasses glass(es) of water (total today: $new_total)"
}

record_sleep() {
    local hours=$1
    local date=${2:-$(date -d yesterday +%Y-%m-%d)}

    init_health_db

    local tmp_file=$(mktemp)

    jq --arg date "$date" \
       --arg hours "$hours" \
       '.sleep[$date] = ($hours | tonumber)' \
       "$HEALTH_DB" > "$tmp_file"

    mv "$tmp_file" "$HEALTH_DB"

    log_debug "Recorded ${hours}h sleep for $date"
}

update_sedentary_time() {
    init_health_db

    local last_movement=$(jq -r '.last_movement // ""' "$HEALTH_DB")
    local now=$(date +%s)

    if [[ -z "$last_movement" ]]; then
        # First time
        jq --arg time "$now" '.last_movement = $time' "$HEALTH_DB" > "$HEALTH_DB.tmp"
        mv "$HEALTH_DB.tmp" "$HEALTH_DB"
        return 0
    fi

    local sedentary_seconds=$((now - last_movement))
    local sedentary_hours=$((sedentary_seconds / 3600))

    jq --arg time "$sedentary_seconds" \
       '.sedentary_time = ($time | tonumber)' \
       "$HEALTH_DB" > "$HEALTH_DB.tmp"
    mv "$HEALTH_DB.tmp" "$HEALTH_DB"

    echo $sedentary_hours
}

reset_sedentary_time() {
    init_health_db

    local now=$(date +%s)

    jq --arg time "$now" \
       '.last_movement = $time | .sedentary_time = 0' \
       "$HEALTH_DB" > "$HEALTH_DB.tmp"
    mv "$HEALTH_DB.tmp" "$HEALTH_DB"

    log_success "Movement detected! Sedentary timer reset."
}

#=============================================================================
# Streak Calculation
#=============================================================================

update_workout_streak() {
    init_health_db

    local streak=0
    local today_epoch=$(date +%s)

    # Check backwards day by day
    for ((i=0; i<365; i++)); do
        local check_date=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)

        local has_workout=$(jq -e --arg date "$check_date" \
            '.workouts[] | select(.date == $date)' \
            "$HEALTH_DB" &>/dev/null && echo 1 || echo 0)

        if [[ $has_workout -eq 1 ]]; then
            ((streak++))
        else
            break
        fi
    done

    # Update stats
    local longest=$(jq -r '.stats.longest_streak' "$HEALTH_DB")
    [[ $streak -gt $longest ]] && longest=$streak

    local tmp_file=$(mktemp)

    jq --arg streak "$streak" \
       --arg longest "$longest" \
       '.stats.current_streak = ($streak | tonumber) |
        .stats.longest_streak = ($longest | tonumber)' \
       "$HEALTH_DB" > "$tmp_file"

    mv "$tmp_file" "$HEALTH_DB"
}

get_days_since_last_workout() {
    init_health_db

    local last_workout=$(jq -r '.workouts[-1].date // ""' "$HEALTH_DB")

    if [[ -z "$last_workout" ]]; then
        echo 999
        return
    fi

    local last_epoch=$(date -d "$last_workout" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_workout" +%s)
    local now_epoch=$(date +%s)

    echo $(( (now_epoch - last_epoch) / 86400 ))
}

#=============================================================================
# Fitness Tracker Integration
#=============================================================================

sync_fitbit() {
    if [[ -z "$FITBIT_TOKEN" ]]; then
        log_debug "Fitbit token not configured"
        return 1
    fi

    log_info "Syncing with Fitbit..."

    local today=$(date +%Y-%m-%d)

    # Get steps
    local steps=$(curl -s -H "Authorization: Bearer $FITBIT_TOKEN" \
        "https://api.fitbit.com/1/user/-/activities/date/$today.json" | \
        jq -r '.summary.steps' 2>/dev/null || echo 0)

    if [[ $steps -gt 0 ]]; then
        record_steps "$steps" "$today"
    fi

    # Get sleep (from last night)
    local yesterday=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
    local sleep=$(curl -s -H "Authorization: Bearer $FITBIT_TOKEN" \
        "https://api.fitbit.com/1.2/user/-/sleep/date/$yesterday.json" | \
        jq -r '.summary.totalMinutesAsleep' 2>/dev/null || echo 0)

    if [[ $sleep -gt 0 ]]; then
        local sleep_hours=$(echo "scale=1; $sleep / 60" | bc)
        record_sleep "$sleep_hours" "$yesterday"
    fi

    log_success "Fitbit sync complete"
}

sync_garmin() {
    if [[ -z "$GARMIN_TOKEN" ]]; then
        log_debug "Garmin token not configured"
        return 1
    fi

    log_info "Syncing with Garmin..."

    local today=$(date +%Y-%m-%d)

    # Get steps and activities for today
    local activities=$(curl -s -H "Authorization: Bearer $GARMIN_TOKEN" \
        "https://apis.garmin.com/wellness-api/rest/dailies?uploadStartTimeInSeconds=$(date -d "$today 00:00:00" +%s)&uploadEndTimeInSeconds=$(date -d "$today 23:59:59" +%s)" \
        2>/dev/null)

    if [[ -n "$activities" ]]; then
        # Extract steps
        local steps=$(echo "$activities" | jq -r '.[0].totalSteps // 0' 2>/dev/null)
        if [[ $steps -gt 0 ]]; then
            record_steps "$steps" "$today"
        fi

        # Extract activities (workouts)
        local activity_duration=$(echo "$activities" | jq -r '.[0].moderateIntensityDurationInSeconds // 0' 2>/dev/null)
        if [[ $activity_duration -gt 0 ]]; then
            local duration_minutes=$((activity_duration / 60))
            if [[ $duration_minutes -ge 10 ]]; then
                # Only record if at least 10 minutes of activity
                record_workout "garmin_activity" "$duration_minutes"
            fi
        fi
    fi

    # Get sleep data (from last night)
    local yesterday=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
    local sleep_data=$(curl -s -H "Authorization: Bearer $GARMIN_TOKEN" \
        "https://apis.garmin.com/wellness-api/rest/sleeps?uploadStartTimeInSeconds=$(date -d "$yesterday 00:00:00" +%s)&uploadEndTimeInSeconds=$(date -d "$today 00:00:00" +%s)" \
        2>/dev/null)

    if [[ -n "$sleep_data" ]]; then
        local sleep_seconds=$(echo "$sleep_data" | jq -r '.[0].sleepTimeSeconds // 0' 2>/dev/null)
        if [[ $sleep_seconds -gt 0 ]]; then
            local sleep_hours=$(echo "scale=1; $sleep_seconds / 3600" | bc)
            record_sleep "$sleep_hours" "$yesterday"
        fi
    fi

    log_success "Garmin sync complete"
}

detect_movement() {
    # Detect if user is active by checking:
    # - Mouse/keyboard activity
    # - CPU usage (active window)
    # - Network activity

    # Check last input time (Linux)
    if command -v xprintidle &> /dev/null; then
        local idle_ms=$(xprintidle)
        local idle_sec=$((idle_ms / 1000))

        # If idle less than 60 seconds, consider active
        [[ $idle_sec -lt 60 ]]
        return $?
    fi

    # macOS
    if command -v ioreg &> /dev/null; then
        local idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
        [[ $idle -lt 60 ]]
        return $?
    fi

    # Fallback - assume active
    return 0
}

#=============================================================================
# Nag Level Calculation
#=============================================================================

calculate_nag_level() {
    init_health_db

    local nag_level=0
    local reasons=()

    # Check days since last workout
    local days_since=$(get_days_since_last_workout)

    if [[ $days_since -ge $MAX_DAYS_WITHOUT_WORKOUT ]]; then
        nag_level=$NAG_LEVEL_LOCKOUT
        reasons+=("NO WORKOUT IN $days_since DAYS")
    elif [[ $days_since -ge 3 ]]; then
        nag_level=$((nag_level > NAG_LEVEL_CRITICAL ? nag_level : NAG_LEVEL_CRITICAL))
        reasons+=("No workout in $days_since days")
    fi

    # Check sedentary time
    local sedentary_hours=$(update_sedentary_time)

    if [[ $sedentary_hours -ge $MAX_SEDENTARY_HOURS ]]; then
        nag_level=$((nag_level > NAG_LEVEL_SERIOUS ? nag_level : NAG_LEVEL_SERIOUS))
        reasons+=("Sitting for $sedentary_hours hours")
    fi

    # Check today's steps
    local today=$(date +%Y-%m-%d)
    local steps=$(jq -r --arg date "$today" '.steps[$date] // 0' "$HEALTH_DB")

    if [[ $steps -lt $((MIN_STEPS_DAILY / 2)) ]]; then
        nag_level=$((nag_level > NAG_LEVEL_WARNING ? nag_level : NAG_LEVEL_WARNING))
        reasons+=("Only $steps steps today")
    fi

    # Check water intake
    local water=$(jq -r --arg date "$today" '.water[$date] // 0' "$HEALTH_DB")

    if [[ $water -lt $((MIN_WATER_GLASSES / 2)) ]]; then
        nag_level=$((nag_level > NAG_LEVEL_WARNING ? nag_level : NAG_LEVEL_WARNING))
        reasons+=("Only $water glasses of water")
    fi

    # Check sleep (yesterday)
    local yesterday=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
    local sleep=$(jq -r --arg date "$yesterday" '.sleep[$date] // 0' "$HEALTH_DB")

    if [[ $sleep -gt 0 ]] && (( $(echo "$sleep < $MIN_SLEEP_HOURS" | bc -l) )); then
        nag_level=$((nag_level > NAG_LEVEL_WARNING ? nag_level : NAG_LEVEL_WARNING))
        reasons+=("Only ${sleep}h sleep last night")
    fi

    echo "$nag_level|${reasons[*]}"
}

#=============================================================================
# Nag Messages
#=============================================================================

get_nag_message() {
    local level=$1
    local reason=$2

    case $level in
        $NAG_LEVEL_WARNING)
            cat <<EOF
⚠️  Health Check-In

$reason

Reminder:
- Take a 5-minute walk
- Drink some water
- Stretch a bit

Your body will thank you later.
EOF
            ;;
        $NAG_LEVEL_SERIOUS)
            cat <<EOF
🚨 HEALTH ALERT

$reason

This is getting serious. You need to:
- Stand up RIGHT NOW
- Walk around for 10 minutes
- Do some stretches
- Get some water

Your back/neck/health is suffering.
EOF
            ;;
        $NAG_LEVEL_CRITICAL)
            cat <<EOF
🔴 CRITICAL HEALTH WARNING

$reason

This is UNACCEPTABLE.

Your workout streak is dead.
Your body is deteriorating.
Your fitness goals are a joke.

DO SOMETHING. NOW.

Suggested:
- 30-minute workout
- Long walk
- Gym session

No excuses.
EOF
            ;;
        $NAG_LEVEL_LOCKOUT)
            cat <<EOF
🔒 SCREEN LOCKOUT IMMINENT

$reason

You've crossed the line.

${MAX_DAYS_WITHOUT_WORKOUT} days without exercise is inexcusable.

MANDATORY ACTIONS:
1. Close this window
2. Go work out (minimum 30 min)
3. Record workout to unlock
4. Come back when you've earned it

Your screen will lock in 5 minutes if you don't move.

This is for your own good.
EOF
            ;;
    esac
}

#=============================================================================
# Nag Delivery
#=============================================================================

send_nag() {
    local level=$1
    local reasons=$2

    local message=$(get_nag_message "$level" "$reasons")

    # Desktop notification
    local urgency="normal"
    [[ $level -ge $NAG_LEVEL_CRITICAL ]] && urgency="critical"

    notify "Health Nag Bot" "$message" "$urgency"

    # Terminal warning
    echo -e "${RED}$message${NC}" >&2

    # Log nag
    record_nag "$level" "$reasons"

    # Extreme measures
    if [[ $level -eq $NAG_LEVEL_LOCKOUT ]] && [[ $ENABLE_SCREEN_LOCKOUT -eq 1 ]]; then
        log_warn "Initiating lockout countdown..."
        initiate_lockout
    fi
}

record_nag() {
    local level=$1
    local reasons=$2

    if [[ ! -f "$NAG_HISTORY" ]]; then
        echo '{"nags": []}' > "$NAG_HISTORY"
    fi

    local tmp_file=$(mktemp)

    jq --arg level "$level" \
       --arg reasons "$reasons" \
       --arg timestamp "$(date -Iseconds)" \
       '.nags += [{level: ($level | tonumber), reasons: $reasons, timestamp: $timestamp}]' \
       "$NAG_HISTORY" > "$tmp_file"

    mv "$tmp_file" "$NAG_HISTORY"
}

#=============================================================================
# Screen Lockout
#=============================================================================

initiate_lockout() {
    log_warn "LOCKOUT IN 5 MINUTES - GO WORK OUT!"

    # Countdown notification
    for ((i=5; i>0; i--)); do
        notify "Lockout Warning" "$i minutes until screen lock" "critical"
        sleep 60
    done

    # Check if workout was recorded
    local last_check=$(date +%s)
    local last_workout_time=$(jq -r '.workouts[-1].timestamp // ""' "$HEALTH_DB")

    if [[ -n "$last_workout_time" ]]; then
        local workout_epoch=$(date -d "$last_workout_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$last_workout_time" +%s)

        if [[ $workout_epoch -gt $((last_check - 300)) ]]; then
            notify "Lockout Cancelled" "Workout detected. Well done!" "normal"
            return 0
        fi
    fi

    # Execute lockout
    log_error "TIME'S UP - LOCKING SCREEN"

    if command -v gnome-screensaver-command &> /dev/null; then
        gnome-screensaver-command -l
    elif command -v xdg-screensaver &> /dev/null; then
        xdg-screensaver lock
    elif command -v loginctl &> /dev/null; then
        loginctl lock-session
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
    fi

    notify "Screen Locked" "Go work out. Record workout to continue." "critical"
}

#=============================================================================
# Monitoring Daemon
#=============================================================================

run_monitor() {
    log_info "Starting health nag monitoring..."

    while true; do
        # Check if user moved
        if detect_movement; then
            reset_sedentary_time
        fi

        # Calculate nag level
        local result=$(calculate_nag_level)
        local level=$(echo "$result" | cut -d'|' -f1)
        local reasons=$(echo "$result" | cut -d'|' -f2-)

        # Send nag if needed
        if [[ $level -gt 0 ]] && [[ $ENABLE_AUTO_NAG -eq 1 ]]; then
            send_nag "$level" "$reasons"
        fi

        # Sync fitness trackers
        if [[ -n "$FITBIT_TOKEN" ]]; then
            sync_fitbit
        fi

        if [[ -n "$GARMIN_TOKEN" ]]; then
            sync_garmin
        fi

        # Wait before next check
        sleep "$SEDENTARY_CHECK_INTERVAL"
    done
}

#=============================================================================
# Dashboard
#=============================================================================

show_dashboard() {
    init_health_db

    local today=$(date +%Y-%m-%d)

    # Get stats
    local current_streak=$(jq -r '.stats.current_streak' "$HEALTH_DB")
    local longest_streak=$(jq -r '.stats.longest_streak' "$HEALTH_DB")
    local total_workouts=$(jq -r '.stats.total_workouts' "$HEALTH_DB")
    local days_since=$(get_days_since_last_workout)

    local steps=$(jq -r --arg date "$today" '.steps[$date] // 0' "$HEALTH_DB")
    local water=$(jq -r --arg date "$today" '.water[$date] // 0' "$HEALTH_DB")

    local yesterday=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
    local sleep=$(jq -r --arg date "$yesterday" '.sleep[$date] // 0' "$HEALTH_DB")

    # Calculate nag level
    local result=$(calculate_nag_level)
    local nag_level=$(echo "$result" | cut -d'|' -f1)

    # Health score
    local health_score=100

    [[ $days_since -gt 3 ]] && health_score=$((health_score - 30))
    [[ $steps -lt $MIN_STEPS_DAILY ]] && health_score=$((health_score - 20))
    [[ $water -lt $MIN_WATER_GLASSES ]] && health_score=$((health_score - 10))
    [[ $sleep -gt 0 && $(echo "$sleep < $MIN_SLEEP_HOURS" | bc -l) -eq 1 ]] && health_score=$((health_score - 20))

    [[ $health_score -lt 0 ]] && health_score=0

    local health_color=$GREEN
    [[ $health_score -lt 70 ]] && health_color=$YELLOW
    [[ $health_score -lt 40 ]] && health_color=$RED

    cat <<EOF

╔════════════════════════════════════════╗
║      💪 HEALTH NAG DASHBOARD 💪        ║
╚════════════════════════════════════════╝

${BOLD}Health Score: ${health_color}${health_score}/100${NC}

${BOLD}Workout Stats:${NC}
  Current Streak: ${current_streak} days
  Longest Streak: ${longest_streak} days
  Total Workouts: ${total_workouts}
  Days Since Last: ${days_since} days

${BOLD}Today's Progress:${NC}
  Steps: ${steps}/${MIN_STEPS_DAILY} $(if [[ $steps -ge $MIN_STEPS_DAILY ]]; then echo "✅"; else echo "❌"; fi)
  Water: ${water}/${MIN_WATER_GLASSES} glasses $(if [[ $water -ge $MIN_WATER_GLASSES ]]; then echo "✅"; else echo "❌"; fi)

${BOLD}Last Night:${NC}
  Sleep: ${sleep}h $(if [[ $sleep -ge $MIN_SLEEP_HOURS ]]; then echo "✅"; elif [[ $sleep -eq 0 ]]; then echo "⚪"; else echo "❌"; fi)

${BOLD}Current Status:${NC}
EOF

    case $nag_level in
        0)
            echo -e "  ${GREEN}✅ Looking good! Keep it up!${NC}"
            ;;
        $NAG_LEVEL_WARNING)
            echo -e "  ${YELLOW}⚠️  Minor issues - easy fixes${NC}"
            ;;
        $NAG_LEVEL_SERIOUS)
            echo -e "  ${YELLOW}🚨 Needs attention - move now${NC}"
            ;;
        $NAG_LEVEL_CRITICAL)
            echo -e "  ${RED}🔴 CRITICAL - workout required${NC}"
            ;;
        $NAG_LEVEL_LOCKOUT)
            echo -e "  ${RED}🔒 LOCKOUT LEVEL - immediate action${NC}"
            ;;
    esac

    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Health nag bot with escalating guilt trips

COMMANDS:
    monitor              Start monitoring daemon
    dashboard            Show health dashboard
    workout TYPE [MIN]   Record workout
    steps COUNT          Record steps
    water [GLASSES]      Record water intake (default: 1)
    sleep HOURS          Record sleep
    sync [fitbit|garmin] Sync with fitness tracker (default: all)
    moved                Reset sedentary timer

WORKOUT TYPES:
    gym, run, walk, bike, yoga, swim, hiit, sports

OPTIONS:
    --enable-lockout     Enable screen lockout (DANGEROUS)
    --no-nag             Disable auto-nagging
    -h, --help           Show this help

EXAMPLES:
    # Record workout
    $0 workout gym 45

    # Record steps
    $0 steps 10000

    # Drink water
    $0 water 2

    # Record sleep
    $0 sleep 7.5

    # Start monitoring
    $0 monitor &

    # Check status
    $0 dashboard

    # I moved (reset sedentary timer)
    $0 moved

SETUP:
    1. Configure in config/config.sh:
       FITBIT_TOKEN="your_token"        # Optional
       GARMIN_TOKEN="your_token"        # Optional
       ENABLE_SCREEN_LOCKOUT=0  # Set to 1 for hardcore mode

    2. Start daemon:
       $0 monitor &

    3. Add to startup

NAG LEVELS:
    ⚠️  Warning     - Minor issues
    🚨 Serious     - 3+ hours sitting
    🔴 Critical    - 3+ days no workout
    🔒 Lockout     - ${MAX_DAYS_WITHOUT_WORKOUT}+ days = screen lock

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --enable-lockout)
                ENABLE_SCREEN_LOCKOUT=1
                log_warn "Screen lockout ENABLED"
                shift
                ;;
            --no-nag)
                ENABLE_AUTO_NAG=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            monitor|dashboard|workout|steps|water|sleep|sync|moved)
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

    # Check dependencies
    check_commands jq bc

    # Initialize
    init_health_db

    # Execute command
    case $command in
        monitor)
            run_monitor
            ;;
        dashboard)
            show_dashboard
            ;;
        workout)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: workout TYPE [DURATION]"
                exit 1
            fi
            record_workout "$1" "${2:-30}"
            show_dashboard
            ;;
        steps)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: steps COUNT"
                exit 1
            fi
            record_steps "$1"
            ;;
        water)
            local glasses=${1:-1}
            record_water "$glasses"
            ;;
        sleep)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: sleep HOURS"
                exit 1
            fi
            record_sleep "$1"
            ;;
        sync)
            local tracker=${1:-"all"}
            case $tracker in
                fitbit)
                    sync_fitbit
                    ;;
                garmin)
                    sync_garmin
                    ;;
                all)
                    [[ -n "$FITBIT_TOKEN" ]] && sync_fitbit
                    [[ -n "$GARMIN_TOKEN" ]] && sync_garmin
                    ;;
                *)
                    log_error "Unknown tracker: $tracker. Use 'fitbit', 'garmin', or 'all'"
                    exit 1
                    ;;
            esac
            ;;
        moved)
            reset_sedentary_time
            ;;
        "")
            show_dashboard
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
