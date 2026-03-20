#!/bin/bash
#=============================================================================
# meeting-cost-calculator.sh
# Real-time meeting cost tracker - "This meeting has cost $847 so far"
# Show $ spent per minute based on attendee salaries
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

SALARY_DB_FILE="$DATA_DIR/salary_database.json"
MEETING_HISTORY_FILE="$DATA_DIR/meeting_history.json"
CALENDAR_CACHE="$DATA_DIR/calendar_cache.json"

# Default salary estimates (annual USD)
DEFAULT_JUNIOR_DEV=70000
DEFAULT_MID_DEV=100000
DEFAULT_SENIOR_DEV=140000
DEFAULT_STAFF_DEV=180000
DEFAULT_PRINCIPAL_DEV=220000
DEFAULT_MANAGER=150000
DEFAULT_DIRECTOR=200000
DEFAULT_VP=300000
DEFAULT_CEO=500000

# Cost calculation
OVERHEAD_MULTIPLIER=1.4  # Benefits, office space, etc.
WORKING_HOURS_PER_YEAR=2080  # 52 weeks * 40 hours

# Display settings
UPDATE_INTERVAL=60  # Seconds between display updates
SHOW_BREAKDOWN=1
ALERT_EXPENSIVE_THRESHOLD=1000  # Alert if meeting costs exceed this

#=============================================================================
# Salary Database Management
#=============================================================================

init_salary_db() {
    if [[ ! -f "$SALARY_DB_FILE" ]]; then
        cat > "$SALARY_DB_FILE" <<'EOF'
{
  "roles": {
    "junior_dev": 70000,
    "mid_dev": 100000,
    "senior_dev": 140000,
    "staff_dev": 180000,
    "principal_dev": 220000,
    "tech_lead": 160000,
    "manager": 150000,
    "senior_manager": 180000,
    "director": 200000,
    "senior_director": 250000,
    "vp": 300000,
    "svp": 400000,
    "ceo": 500000,
    "unknown": 100000
  },
  "people": {}
}
EOF
        log_success "Initialized salary database"
    fi
}

get_salary() {
    local name=$1
    init_salary_db

    # Check if person exists in database
    local salary=$(jq -r --arg name "$name" '.people[$name] // empty' "$SALARY_DB_FILE")

    if [[ -n "$salary" ]]; then
        echo "$salary"
        return 0
    fi

    # Try to guess from common role keywords in name/title
    local role=$(guess_role "$name")
    local role_salary=$(jq -r --arg role "$role" '.roles[$role] // .roles.unknown' "$SALARY_DB_FILE")

    echo "$role_salary"
}

guess_role() {
    local name=$1
    local lower_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # Try to extract role from common patterns
    if [[ "$lower_name" == *"ceo"* ]] || [[ "$lower_name" == *"chief executive"* ]]; then
        echo "ceo"
    elif [[ "$lower_name" == *"vp"* ]] || [[ "$lower_name" == *"vice president"* ]]; then
        echo "vp"
    elif [[ "$lower_name" == *"director"* ]]; then
        echo "director"
    elif [[ "$lower_name" == *"manager"* ]]; then
        echo "manager"
    elif [[ "$lower_name" == *"principal"* ]]; then
        echo "principal_dev"
    elif [[ "$lower_name" == *"staff"* ]]; then
        echo "staff_dev"
    elif [[ "$lower_name" == *"senior"* ]]; then
        echo "senior_dev"
    elif [[ "$lower_name" == *"junior"* ]]; then
        echo "junior_dev"
    else
        echo "mid_dev"
    fi
}

set_salary() {
    local name=$1
    local salary=$2

    init_salary_db

    local tmp_file=$(mktemp)
    jq --arg name "$name" --argjson salary "$salary" \
       '.people[$name] = $salary' \
       "$SALARY_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$SALARY_DB_FILE"
    log_success "Set salary for $name: \$$salary"
}

#=============================================================================
# Cost Calculation
#=============================================================================

calculate_hourly_rate() {
    local annual_salary=$1
    local true_cost=$(echo "$annual_salary * $OVERHEAD_MULTIPLIER" | bc)
    local hourly_rate=$(echo "scale=2; $true_cost / $WORKING_HOURS_PER_YEAR" | bc)
    echo "$hourly_rate"
}

calculate_minute_rate() {
    local hourly_rate=$1
    local minute_rate=$(echo "scale=2; $hourly_rate / 60" | bc)
    echo "$minute_rate"
}

calculate_meeting_cost() {
    local attendees=("$@")
    local duration_minutes=${duration_minutes:-30}

    local total_cost=0

    for attendee in "${attendees[@]}"; do
        local salary=$(get_salary "$attendee")
        local hourly=$(calculate_hourly_rate "$salary")
        local minute=$(calculate_minute_rate "$hourly")
        local cost=$(echo "$minute * $duration_minutes" | bc)
        total_cost=$(echo "$total_cost + $cost" | bc)
    done

    printf "%.2f" "$total_cost"
}

#=============================================================================
# Meeting Monitoring
#=============================================================================

parse_calendar() {
    # Try to get calendar events from various sources
    local events="[]"

    # Try ical if available
    if command -v icalBuddy &> /dev/null; then
        # macOS calendar
        events=$(icalBuddy -n -ea -iep "title,attendees" eventsToday 2>/dev/null || echo "[]")
    fi

    # Try Google Calendar API (if configured)
    if [[ -n "${GOOGLE_CALENDAR_API_KEY:-}" ]]; then
        # Would fetch from Google Calendar API
        :
    fi

    echo "$events"
}

get_current_meeting() {
    # Check if we're in a Zoom/Meet/Teams call
    local zoom_running=0
    local meet_running=0
    local teams_running=0

    if pgrep -x "zoom" &> /dev/null; then
        zoom_running=1
    fi

    if pgrep -x "chrome" &> /dev/null && lsof -c chrome 2>/dev/null | grep -q "meet.google.com"; then
        meet_running=1
    fi

    if pgrep -x "teams" &> /dev/null; then
        teams_running=1
    fi

    if [[ $zoom_running -eq 1 ]] || [[ $meet_running -eq 1 ]] || [[ $teams_running -eq 1 ]]; then
        echo "1"
    else
        echo "0"
    fi
}

#=============================================================================
# Real-time Display
#=============================================================================

display_meeting_cost() {
    local attendees=("$@")
    local start_time=$(date +%s)

    clear
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║         💰 MEETING COST CALCULATOR - LIVE 💰              ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo

    while true; do
        local now=$(date +%s)
        local elapsed_seconds=$((now - start_time))
        local elapsed_minutes=$(echo "scale=2; $elapsed_seconds / 60" | bc)

        # Calculate current cost
        local total_cost=0
        local breakdown=""

        for attendee in "${attendees[@]}"; do
            local salary=$(get_salary "$attendee")
            local hourly=$(calculate_hourly_rate "$salary")
            local minute=$(calculate_minute_rate "$hourly")
            local attendee_cost=$(echo "$minute * $elapsed_minutes" | bc)
            total_cost=$(echo "$total_cost + $attendee_cost" | bc)

            if [[ $SHOW_BREAKDOWN -eq 1 ]]; then
                breakdown+=$(printf "  %-30s \$%-8.2f (\$%.2f/min)\n" "$attendee" "$attendee_cost" "$minute")
            fi
        done

        # Clear previous output (move cursor up)
        tput cup 5 0

        echo -e "${BOLD}Duration:${NC} $(human_time_diff "$elapsed_seconds") ($(printf "%.1f" "$elapsed_minutes") minutes)"
        echo
        echo -e "${BOLD}${GREEN}💵 TOTAL COST: \$$(printf "%.2f" "$total_cost")${NC}"
        echo
        echo -e "${BOLD}Cost per minute: \$$(echo "scale=2; $total_cost / $elapsed_minutes" | bc 2>/dev/null || echo "0.00")${NC}"
        echo

        if [[ $SHOW_BREAKDOWN -eq 1 ]]; then
            echo -e "${BOLD}Breakdown by attendee:${NC}"
            echo "$breakdown"
            echo
        fi

        # Alert if expensive
        local total_int=$(printf "%.0f" "$total_cost")
        if [[ $total_int -gt $ALERT_EXPENSIVE_THRESHOLD ]] && [[ $(($elapsed_seconds % 300)) -eq 0 ]]; then
            notify "💰 Expensive Meeting Alert" "This meeting has cost \$$total_int so far!" "critical"
        fi

        # Show stats
        echo -e "${CYAN}Stats:${NC}"
        echo "  • Attendees: ${#attendees[@]}"
        echo "  • Average salary: \$$(echo "scale=0; ($total_cost / $elapsed_minutes) * 60 / ${#attendees[@]} / $OVERHEAD_MULTIPLIER" | bc)"
        echo
        echo -e "${YELLOW}Press Ctrl+C to end meeting${NC}"

        sleep "$UPDATE_INTERVAL"
    done
}

quick_estimate() {
    local num_attendees=$1
    local duration_minutes=$2
    local avg_role=${3:-"mid_dev"}

    init_salary_db

    local role_salary=$(jq -r --arg role "$avg_role" '.roles[$role] // .roles.unknown' "$SALARY_DB_FILE")
    local hourly=$(calculate_hourly_rate "$role_salary")
    local minute=$(calculate_minute_rate "$hourly")
    local cost=$(echo "$minute * $duration_minutes * $num_attendees" | bc)

    echo -e "${BOLD}Quick Estimate:${NC}"
    echo "  • Attendees: $num_attendees ($avg_role)"
    echo "  • Duration: $duration_minutes minutes"
    echo "  • Cost per person: \$$(printf "%.2f" "$(echo "$minute * $duration_minutes" | bc)")"
    echo
    echo -e "${BOLD}${GREEN}💵 TOTAL COST: \$$(printf "%.2f" "$cost")${NC}"
    echo
    echo -e "${YELLOW}Tip: That money could buy:${NC}"

    local coffees=$(echo "$cost / 5" | bc)
    local pizzas=$(echo "$cost / 15" | bc)
    local aws_instances=$(echo "$cost / 0.10" | bc)

    echo "  • $coffees Starbucks coffees"
    echo "  • $pizzas pizzas"
    echo "  • $(printf "%.0f" "$aws_instances") hours of t3.medium AWS instance"
}

#=============================================================================
# History Tracking
#=============================================================================

save_meeting_record() {
    local duration_minutes=$1; shift
    local cost=$1; shift
    local attendees=("$@")

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$MEETING_HISTORY_FILE" ]]; then
        echo '{"meetings": []}' > "$MEETING_HISTORY_FILE"
    fi

    local attendees_json=$(printf '%s\n' "${attendees[@]}" | jq -R . | jq -s .)
    local tmp_file=$(mktemp)

    jq --argjson attendees "$attendees_json" \
       --arg duration "$duration_minutes" \
       --arg cost "$cost" \
       --arg timestamp "$(date -Iseconds)" \
       '.meetings += [{timestamp: $timestamp, duration: $duration, cost: $cost, attendees: $attendees}]' \
       "$MEETING_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$MEETING_HISTORY_FILE"
}

show_meeting_stats() {
    if [[ ! -f "$MEETING_HISTORY_FILE" ]]; then
        log_info "No meeting history available"
        return 0
    fi

    echo -e "\n${BOLD}📊 Meeting Statistics${NC}\n"

    local total_meetings=$(jq '.meetings | length' "$MEETING_HISTORY_FILE")
    local total_cost=$(jq '[.meetings[].cost | tonumber] | add' "$MEETING_HISTORY_FILE" 2>/dev/null || echo "0")
    local total_time=$(jq '[.meetings[].duration | tonumber] | add' "$MEETING_HISTORY_FILE" 2>/dev/null || echo "0")

    echo "Total meetings tracked: $total_meetings"
    echo "Total cost: \$$(printf "%.2f" "$total_cost")"
    echo "Total time: $(human_time_diff "$((total_time * 60))")"
    echo
    echo "Average meeting cost: \$$(echo "scale=2; $total_cost / $total_meetings" | bc 2>/dev/null || echo "0.00")"
    echo "Average meeting duration: $(echo "scale=0; $total_time / $total_meetings" | bc 2>/dev/null || echo "0") minutes"
    echo

    echo -e "${BOLD}Most expensive meetings:${NC}"
    jq -r '.meetings | sort_by(-.cost | tonumber) | .[0:5] | .[] | "\(.timestamp) - $\(.cost) (\(.duration) min, \(.attendees | length) attendees)"' "$MEETING_HISTORY_FILE"
    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Real-time meeting cost calculator

COMMANDS:
    live ATTENDEES...        Start live cost tracking
    estimate N MINS [ROLE]   Quick cost estimate
    stats                    Show meeting statistics
    set NAME SALARY          Set salary for person
    list                     List salary database

OPTIONS:
    --no-breakdown           Hide per-attendee breakdown
    --alert-threshold N      Alert when cost exceeds N dollars
    -h, --help              Show this help

EXAMPLES:
    # Track live meeting cost
    $0 live "Alice (Senior Dev)" "Bob (Manager)" "Carol (Junior Dev)"

    # Quick estimate
    $0 estimate 5 30 mid_dev
    # 5 people, 30 minutes, mid-level developers

    # Set custom salary
    $0 set "Alice" 150000

    # View stats
    $0 stats

ROLES:
    junior_dev, mid_dev, senior_dev, staff_dev, principal_dev
    tech_lead, manager, senior_manager, director, vp, ceo

TIPS:
    • Use this during Zoom/Meet to show real-time costs
    • Display on second monitor to guilt-trip meeting organizers
    • Export stats for expense justification
    • Set accurate salaries for better estimates

EOF
}

main() {
    local command=""
    local no_breakdown=0

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-breakdown)
                SHOW_BREAKDOWN=0
                shift
                ;;
            --alert-threshold)
                ALERT_EXPENSIVE_THRESHOLD=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            live|estimate|stats|set|list)
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

    # Initialize database
    init_salary_db

    # Execute command
    case $command in
        live)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: live ATTENDEES..."
                exit 1
            fi
            display_meeting_cost "$@"
            ;;
        estimate)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: estimate N MINUTES [ROLE]"
                exit 1
            fi
            quick_estimate "$@"
            ;;
        stats)
            show_meeting_stats
            ;;
        set)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: set NAME SALARY"
                exit 1
            fi
            set_salary "$1" "$2"
            ;;
        list)
            init_salary_db
            echo -e "${BOLD}Salary Database:${NC}\n"
            jq -r '.roles | to_entries[] | "\(.key): $\(.value)"' "$SALARY_DB_FILE" | column -t
            echo
            if [[ $(jq '.people | length' "$SALARY_DB_FILE") -gt 0 ]]; then
                echo -e "${BOLD}Custom Salaries:${NC}\n"
                jq -r '.people | to_entries[] | "\(.key): $\(.value)"' "$SALARY_DB_FILE" | column -t
            fi
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
