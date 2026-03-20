#!/bin/bash
#=============================================================================
# wife-happy-score.sh
# Relationship debt tracker and maintenance reminder system
# "I automated my relationship so I wouldn't forget anniversaries. Again."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

RELATIONSHIP_DB="$DATA_DIR/relationship.json"
PARTNER_NAME=${PARTNER_NAME:-"Partner"}  # Configurable in config.sh

# Thresholds (days)
DATE_NIGHT_THRESHOLD=14
FLOWERS_THRESHOLD=30
GIFT_THRESHOLD=60
COMPLIMENT_THRESHOLD=1

# Score weights
WEIGHT_DATE_NIGHT=25
WEIGHT_FLOWERS=20
WEIGHT_GIFT=15
WEIGHT_COMPLIMENT=10
WEIGHT_CHORES=20
WEIGHT_QUALITY_TIME=10

#=============================================================================
# Database Functions
#=============================================================================

init_db() {
    if [[ ! -f "$RELATIONSHIP_DB" ]]; then
        cat > "$RELATIONSHIP_DB" <<EOF
{
    "partner_name": "$PARTNER_NAME",
    "anniversary": "",
    "birthday": "",
    "last_date_night": "",
    "last_flowers": "",
    "last_gift": "",
    "last_compliment": "",
    "chores_this_week": 0,
    "quality_time_hours": 0,
    "important_dates": [],
    "preferences": {
        "favorite_flowers": "",
        "favorite_restaurant": "",
        "love_language": ""
    },
    "history": []
}
EOF
        log_info "Relationship database initialized"
    fi
}

get_db_value() {
    local key=$1
    jq -r ".$key // empty" "$RELATIONSHIP_DB"
}

update_db_value() {
    local key=$1
    local value=$2

    local tmp_file=$(mktemp)
    jq --arg k "$key" --arg v "$value" 'setpath($k | split("."); $v)' "$RELATIONSHIP_DB" > "$tmp_file"
    mv "$tmp_file" "$RELATIONSHIP_DB"

    log_debug "Updated $key = $value"
}

add_history_event() {
    local event_type=$1
    local description=$2

    local tmp_file=$(mktemp)
    jq --arg type "$event_type" \
       --arg desc "$description" \
       --arg date "$(date -Iseconds)" \
       '.history += [{type: $type, description: $desc, date: $date}]' \
       "$RELATIONSHIP_DB" > "$tmp_file"
    mv "$tmp_file" "$RELATIONSHIP_DB"
}

#=============================================================================
# Date Calculations
#=============================================================================

days_since() {
    local past_date=$1

    if [[ -z "$past_date" || "$past_date" == "null" ]]; then
        echo "999"  # Never happened
        return
    fi

    local past_epoch=$(date -d "$past_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$past_date" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)

    echo $(( (now_epoch - past_epoch) / 86400 ))
}

days_until() {
    local future_date=$1

    if [[ -z "$future_date" || "$future_date" == "null" ]]; then
        return 1
    fi

    local future_epoch=$(date -d "$future_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$future_date" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)

    echo $(( (future_epoch - now_epoch) / 86400 ))
}

get_next_occurrence() {
    local month_day=$1  # Format: MM-DD
    local this_year=$(date +%Y)

    local this_year_date="${this_year}-${month_day}"
    local days=$(days_until "$this_year_date")

    if [[ $days -lt 0 ]]; then
        # Already passed this year, return next year
        echo "$((this_year + 1))-${month_day}"
    else
        echo "$this_year_date"
    fi
}

#=============================================================================
# Score Calculation
#=============================================================================

calculate_relationship_score() {
    local score=100

    # Date night debt
    local last_date=$(get_db_value "last_date_night")
    local days_since_date=$(days_since "$last_date")

    if [[ $days_since_date -gt $((DATE_NIGHT_THRESHOLD * 2)) ]]; then
        score=$((score - WEIGHT_DATE_NIGHT))
    elif [[ $days_since_date -gt $DATE_NIGHT_THRESHOLD ]]; then
        score=$((score - WEIGHT_DATE_NIGHT / 2))
    fi

    # Flowers debt
    local last_flowers=$(get_db_value "last_flowers")
    local days_since_flowers=$(days_since "$last_flowers")

    if [[ $days_since_flowers -gt $((FLOWERS_THRESHOLD * 2)) ]]; then
        score=$((score - WEIGHT_FLOWERS))
    elif [[ $days_since_flowers -gt $FLOWERS_THRESHOLD ]]; then
        score=$((score - WEIGHT_FLOWERS / 2))
    fi

    # Gift debt
    local last_gift=$(get_db_value "last_gift")
    local days_since_gift=$(days_since "$last_gift")

    if [[ $days_since_gift -gt $((GIFT_THRESHOLD * 2)) ]]; then
        score=$((score - WEIGHT_GIFT))
    elif [[ $days_since_gift -gt $GIFT_THRESHOLD ]]; then
        score=$((score - WEIGHT_GIFT / 2))
    fi

    # Daily compliments
    local last_compliment=$(get_db_value "last_compliment")
    local days_since_compliment=$(days_since "$last_compliment")

    if [[ $days_since_compliment -gt 3 ]]; then
        score=$((score - WEIGHT_COMPLIMENT))
    elif [[ $days_since_compliment -gt 1 ]]; then
        score=$((score - WEIGHT_COMPLIMENT / 2))
    fi

    # Chores (this week)
    local chores=$(get_db_value "chores_this_week")
    if [[ $chores -lt 3 ]]; then
        score=$((score - WEIGHT_CHORES))
    elif [[ $chores -lt 5 ]]; then
        score=$((score - WEIGHT_CHORES / 2))
    fi

    # Quality time (this week, in hours)
    local quality_time=$(get_db_value "quality_time_hours")
    if [[ $quality_time -lt 5 ]]; then
        score=$((score - WEIGHT_QUALITY_TIME))
    fi

    # Ensure score doesn't go below 0
    [[ $score -lt 0 ]] && score=0

    echo $score
}

get_urgency_level() {
    local score=$1

    if [[ $score -ge 80 ]]; then
        echo "EXCELLENT"
    elif [[ $score -ge 60 ]]; then
        echo "GOOD"
    elif [[ $score -ge 40 ]]; then
        echo "WARNING"
    elif [[ $score -ge 20 ]]; then
        echo "CRITICAL"
    else
        echo "DEFCON 1"
    fi
}

#=============================================================================
# Recommendations
#=============================================================================

generate_recommendations() {
    local score=$1
    local recommendations=()

    # Check each metric
    local last_date=$(get_db_value "last_date_night")
    local days_since_date=$(days_since "$last_date")

    if [[ $days_since_date -gt $DATE_NIGHT_THRESHOLD ]]; then
        local favorite_restaurant=$(get_db_value "preferences.favorite_restaurant")
        if [[ -n "$favorite_restaurant" ]]; then
            recommendations+=("📅 URGENT: Plan date night at $favorite_restaurant (${days_since_date} days overdue)")
        else
            recommendations+=("📅 URGENT: Plan date night (${days_since_date} days overdue)")
        fi
    fi

    local last_flowers=$(get_db_value "last_flowers")
    local days_since_flowers=$(days_since "$last_flowers")

    if [[ $days_since_flowers -gt $FLOWERS_THRESHOLD ]]; then
        local favorite_flowers=$(get_db_value "preferences.favorite_flowers")
        if [[ -n "$favorite_flowers" ]]; then
            recommendations+=("💐 Send $favorite_flowers (${days_since_flowers} days since last flowers)")
            recommendations+=("   → https://www.amazon.com/s?k=${favorite_flowers// /+}")
        else
            recommendations+=("💐 Send flowers (${days_since_flowers} days since last flowers)")
        fi
    fi

    local last_gift=$(get_db_value "last_gift")
    local days_since_gift=$(days_since "$last_gift")

    if [[ $days_since_gift -gt $GIFT_THRESHOLD ]]; then
        recommendations+=("🎁 Time for a thoughtful gift (${days_since_gift} days since last gift)")
    fi

    local last_compliment=$(get_db_value "last_compliment")
    local days_since_compliment=$(days_since "$last_compliment")

    if [[ $days_since_compliment -gt 0 ]]; then
        recommendations+=("💬 Give a genuine compliment TODAY")
    fi

    local chores=$(get_db_value "chores_this_week")
    if [[ $chores -lt 5 ]]; then
        recommendations+=("🧹 Do some chores without being asked (current: $chores this week)")
    fi

    local quality_time=$(get_db_value "quality_time_hours")
    if [[ $quality_time -lt 5 ]]; then
        recommendations+=("⏰ Spend quality time together (current: ${quality_time}h this week)")
    fi

    # Print recommendations
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        printf '%s\n' "${recommendations[@]}"
    else
        echo "✨ You're doing great! Keep it up!"
    fi
}

check_important_dates() {
    local alerts=()

    # Check anniversary
    local anniversary=$(get_db_value "anniversary")
    if [[ -n "$anniversary" && "$anniversary" != "null" ]]; then
        local next_anniversary=$(get_next_occurrence "${anniversary:5:5}")  # Extract MM-DD
        local days=$(days_until "$next_anniversary")

        if [[ $days -le 7 && $days -ge 0 ]]; then
            alerts+=("🚨 ANNIVERSARY IN $days DAYS! ($next_anniversary)")
        elif [[ $days -le 30 && $days -ge 0 ]]; then
            alerts+=("⚠️  Anniversary coming up in $days days ($next_anniversary)")
        fi
    fi

    # Check birthday
    local birthday=$(get_db_value "birthday")
    if [[ -n "$birthday" && "$birthday" != "null" ]]; then
        local next_birthday=$(get_next_occurrence "${birthday:5:5}")
        local days=$(days_until "$next_birthday")

        if [[ $days -le 7 && $days -ge 0 ]]; then
            alerts+=("🎂 BIRTHDAY IN $days DAYS! ($next_birthday)")
        elif [[ $days -le 30 && $days -ge 0 ]]; then
            alerts+=("⚠️  Birthday coming up in $days days ($next_birthday)")
        fi
    fi

    # Print alerts
    if [[ ${#alerts[@]} -gt 0 ]]; then
        printf '%s\n' "${alerts[@]}"
    fi
}

#=============================================================================
# Actions
#=============================================================================

record_action() {
    local action=$1
    local today=$(date +%Y-%m-%d)

    case $action in
        date)
            update_db_value "last_date_night" "$today"
            add_history_event "date_night" "Date night"
            log_success "Recorded date night for today"
            ;;
        flowers)
            update_db_value "last_flowers" "$today"
            add_history_event "flowers" "Sent flowers"
            log_success "Recorded flowers for today"
            ;;
        gift)
            update_db_value "last_gift" "$today"
            read -p "What gift? " gift_desc
            add_history_event "gift" "$gift_desc"
            log_success "Recorded gift: $gift_desc"
            ;;
        compliment)
            update_db_value "last_compliment" "$today"
            add_history_event "compliment" "Gave compliment"
            log_success "Recorded compliment for today"
            ;;
        chore)
            local current_chores=$(get_db_value "chores_this_week")
            update_db_value "chores_this_week" "$((current_chores + 1))"
            read -p "What chore? " chore_desc
            add_history_event "chore" "$chore_desc"
            log_success "Recorded chore: $chore_desc (total this week: $((current_chores + 1)))"
            ;;
        quality-time)
            read -p "How many hours? " hours
            local current_time=$(get_db_value "quality_time_hours")
            update_db_value "quality_time_hours" "$((current_time + hours))"
            add_history_event "quality_time" "${hours}h together"
            log_success "Recorded ${hours}h quality time (total this week: $((current_time + hours))h)"
            ;;
        *)
            log_error "Unknown action: $action"
            return 1
            ;;
    esac
}

#=============================================================================
# Display
#=============================================================================

show_dashboard() {
    local score=$(calculate_relationship_score)
    local urgency=$(get_urgency_level "$score")

    # Color based on score
    local color=$GREEN
    [[ $score -lt 60 ]] && color=$YELLOW
    [[ $score -lt 40 ]] && color=$RED

    echo -e "\n${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     RELATIONSHIP HAPPINESS SCORE      ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}Partner:${NC} $(get_db_value 'partner_name')"
    echo -e "${color}${BOLD}Score: $score/100${NC} ($urgency)"
    echo

    # Important date alerts
    local alerts=$(check_important_dates)
    if [[ -n "$alerts" ]]; then
        echo -e "${RED}${BOLD}📌 IMPORTANT DATES:${NC}"
        echo "$alerts"
        echo
    fi

    # Metrics
    echo -e "${BOLD}📊 Metrics:${NC}"
    echo "  📅 Last date night: $(human_time_diff $(($(days_since "$(get_db_value 'last_date_night')") * 86400))) ago"
    echo "  💐 Last flowers: $(human_time_diff $(($(days_since "$(get_db_value 'last_flowers')") * 86400))) ago"
    echo "  🎁 Last gift: $(human_time_diff $(($(days_since "$(get_db_value 'last_gift')") * 86400))) ago"
    echo "  💬 Last compliment: $(human_time_diff $(($(days_since "$(get_db_value 'last_compliment')") * 86400))) ago"
    echo "  🧹 Chores this week: $(get_db_value 'chores_this_week')"
    echo "  ⏰ Quality time this week: $(get_db_value 'quality_time_hours')h"
    echo

    # Recommendations
    echo -e "${BOLD}💡 Recommendations:${NC}"
    generate_recommendations "$score"
    echo
}

#=============================================================================
# Setup
#=============================================================================

run_setup() {
    echo -e "${BOLD}Relationship Tracker Setup${NC}\n"

    read -p "Partner's name: " partner_name
    update_db_value "partner_name" "$partner_name"

    read -p "Anniversary (YYYY-MM-DD): " anniversary
    update_db_value "anniversary" "$anniversary"

    read -p "Partner's birthday (YYYY-MM-DD): " birthday
    update_db_value "birthday" "$birthday"

    read -p "Favorite flowers (optional): " flowers
    update_db_value "preferences.favorite_flowers" "$flowers"

    read -p "Favorite restaurant (optional): " restaurant
    update_db_value "preferences.favorite_restaurant" "$restaurant"

    log_success "Setup complete!"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [ACTION]

Relationship happiness tracker and maintenance reminder

OPTIONS:
    -s, --setup          Run initial setup
    -d, --dashboard      Show dashboard (default)
    -r, --record ACTION  Record an action (date, flowers, gift, compliment, chore, quality-time)
    -h, --help           Show this help

EXAMPLES:
    # Show dashboard
    $0

    # Record date night
    $0 --record date

    # Record chore
    $0 --record chore

    # Setup
    $0 --setup

DAILY REMINDER:
    Add to crontab for daily morning reminder:
    0 9 * * * $0 --dashboard | notify-send "Relationship Status"

EOF
}

main() {
    local action=""
    local show_dashboard_flag=1

    # Initialize database
    init_db

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--setup)
                run_setup
                exit 0
                ;;
            -d|--dashboard)
                show_dashboard_flag=1
                shift
                ;;
            -r|--record)
                action=$2
                show_dashboard_flag=0
                shift 2
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

    # Record action
    if [[ -n "$action" ]]; then
        record_action "$action"
        echo
        # Show updated dashboard
        show_dashboard
        exit 0
    fi

    # Show dashboard
    if [[ $show_dashboard_flag -eq 1 ]]; then
        show_dashboard

        # Send notification if score is low
        local score=$(calculate_relationship_score)
        if [[ $score -lt 40 ]]; then
            send_alert "⚠️  Relationship score is LOW: $score/100"
        fi
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
