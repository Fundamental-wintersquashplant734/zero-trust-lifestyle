#!/bin/bash
#=============================================================================
# birthday-reminder-pro.sh
# Never forget birthdays with auto gift suggestions
# "Because 'Happy Birthday' at 11:59 PM doesn't count"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

BIRTHDAY_DB_FILE="$DATA_DIR/birthdays.json"
GIFT_HISTORY_FILE="$DATA_DIR/gift_history.json"
REMINDER_HISTORY_FILE="$DATA_DIR/reminder_history.json"

# Reminder settings
ADVANCE_WARNING_DAYS=7   # Warn this many days before
CRITICAL_WARNING_DAYS=3  # Critical alert
PANIC_WARNING_DAYS=1     # PANIC MODE

# Gift suggestion settings
USE_SOCIAL_SCRAPING=1    # Scrape social media for interests
USE_AI_SUGGESTIONS=0     # Use AI for gift ideas (requires API key)
BUDGET_DEFAULT=50        # Default gift budget

# Alert settings
SEND_EMAIL_REMINDERS=0
SEND_PUSH_NOTIFICATIONS=1
CALENDAR_INTEGRATION=0

#=============================================================================
# Birthday Database Management
#=============================================================================

init_birthday_db() {
    if [[ ! -f "$BIRTHDAY_DB_FILE" ]]; then
        cat > "$BIRTHDAY_DB_FILE" <<'EOF'
{
  "people": []
}
EOF
        log_success "Initialized birthday database"
    fi
}

add_birthday() {
    local name=$1
    local date=$2  # Format: YYYY-MM-DD or MM-DD
    local relationship=${3:-"friend"}
    local importance=${4:-"normal"}  # critical, high, normal, low

    init_birthday_db

    # Validate date format
    if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ ! "$date" =~ ^[0-9]{2}-[0-9]{2}$ ]]; then
        log_error "Invalid date format. Use YYYY-MM-DD or MM-DD"
        return 1
    fi
    if ! date -d "$date" &>/dev/null 2>&1 && ! date -j -f "%Y-%m-%d" "$date" &>/dev/null 2>&1; then
        log_error "Invalid date format. Use YYYY-MM-DD or MM-DD"
        return 1
    fi

    local tmp_file=$(mktemp)

    # Add person to database
    jq --arg name "$name" \
       --arg date "$date" \
       --arg rel "$relationship" \
       --arg imp "$importance" \
       '.people += [{
           name: $name,
           birthday: $date,
           relationship: $rel,
           importance: $imp,
           added: (now | todate),
           social_profiles: {},
           interests: [],
           gift_preferences: []
       }]' \
       "$BIRTHDAY_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$BIRTHDAY_DB_FILE"

    log_success "Added birthday: $name on $date"
}

remove_birthday() {
    local name=$1

    init_birthday_db

    local tmp_file=$(mktemp)

    jq --arg name "$name" \
       '.people = [.people[] | select(.name != $name)]' \
       "$BIRTHDAY_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$BIRTHDAY_DB_FILE"

    log_success "Removed: $name"
}

list_birthdays() {
    init_birthday_db

    echo -e "\n${BOLD}📅 Birthday Database${NC}\n"

    jq -r '.people | sort_by(.birthday) | .[] |
        "\(.name) - \(.birthday) (\(.relationship), \(.importance))"' \
        "$BIRTHDAY_DB_FILE"

    echo
}

update_person_interests() {
    local name=$1
    shift
    local interests=("$@")

    init_birthday_db

    local interests_json=$(printf '%s\n' "${interests[@]}" | jq -R . | jq -s .)
    local tmp_file=$(mktemp)

    jq --arg name "$name" \
       --argjson interests "$interests_json" \
       '(.people[] | select(.name == $name)).interests = $interests' \
       "$BIRTHDAY_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$BIRTHDAY_DB_FILE"

    log_success "Updated interests for $name"
}

#=============================================================================
# Upcoming Birthday Detection
#=============================================================================

get_upcoming_birthdays() {
    local days_ahead=${1:-30}

    init_birthday_db

    local today=$(date +%s)
    local upcoming=()

    while IFS= read -r person; do
        local name=$(echo "$person" | jq -r '.name')
        local birthday=$(echo "$person" | jq -r '.birthday')
        local importance=$(echo "$person" | jq -r '.importance')

        # Calculate days until birthday
        local days_until=$(calculate_days_until_birthday "$birthday")

        if [[ $days_until -le $days_ahead ]] && [[ $days_until -ge 0 ]]; then
            upcoming+=("$days_until:$name:$birthday:$importance")
        fi
    done < <(jq -c '.people[]' "$BIRTHDAY_DB_FILE")

    # Sort by days until
    printf '%s\n' "${upcoming[@]}" | sort -n
}

calculate_days_until_birthday() {
    local birthday=$1

    # Extract month and day
    local month_day=$(echo "$birthday" | grep -oE '[0-9]{2}-[0-9]{2}$' || echo "$birthday")

    # Get current year
    local current_year=$(date +%Y)
    local next_year=$((current_year + 1))

    # Try this year
    local this_year_date="${current_year}-${month_day}"
    local this_year_epoch=$(date -d "$this_year_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$this_year_date" +%s 2>/dev/null)

    local today_epoch=$(date +%s)

    local days_until=$(( (this_year_epoch - today_epoch) / 86400 ))

    # If birthday already passed this year, use next year
    if [[ $days_until -lt 0 ]]; then
        local next_year_date="${next_year}-${month_day}"
        local next_year_epoch=$(date -d "$next_year_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$next_year_date" +%s 2>/dev/null)
        days_until=$(( (next_year_epoch - today_epoch) / 86400 ))
    fi

    echo "$days_until"
}

#=============================================================================
# Reminder System
#=============================================================================

check_and_send_reminders() {
    log_info "Checking for upcoming birthdays..."

    local critical_alerts=()
    local warning_alerts=()
    local info_alerts=()

    while IFS=: read -r days_until name birthday importance; do
        if [[ -z "$days_until" ]]; then
            continue
        fi

        # Determine alert level
        if [[ $days_until -eq 0 ]]; then
            critical_alerts+=("🎂 TODAY: $name's birthday!")
            send_birthday_alert "$name" "$days_until" "critical"
        elif [[ $days_until -le $PANIC_WARNING_DAYS ]]; then
            critical_alerts+=("🚨 URGENT: $name's birthday in $days_until day(s)!")
            send_birthday_alert "$name" "$days_until" "critical"
        elif [[ $days_until -le $CRITICAL_WARNING_DAYS ]]; then
            warning_alerts+=("⚠️  Soon: $name's birthday in $days_until days")
            send_birthday_alert "$name" "$days_until" "high"
        elif [[ $days_until -le $ADVANCE_WARNING_DAYS ]]; then
            info_alerts+=("📅 Upcoming: $name's birthday in $days_until days")
            send_birthday_alert "$name" "$days_until" "normal"
        fi
    done < <(get_upcoming_birthdays 7)

    # Display alerts
    if [[ ${#critical_alerts[@]} -gt 0 ]]; then
        echo -e "\n${RED}${BOLD}CRITICAL REMINDERS:${NC}"
        printf '%s\n' "${critical_alerts[@]}"
        echo
    fi

    if [[ ${#warning_alerts[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}${BOLD}WARNINGS:${NC}"
        printf '%s\n' "${warning_alerts[@]}"
        echo
    fi

    if [[ ${#info_alerts[@]} -gt 0 ]]; then
        echo -e "\n${BLUE}${BOLD}UPCOMING:${NC}"
        printf '%s\n' "${info_alerts[@]}"
        echo
    fi

    if [[ ${#critical_alerts[@]} -eq 0 ]] && [[ ${#warning_alerts[@]} -eq 0 ]] && [[ ${#info_alerts[@]} -eq 0 ]]; then
        log_success "No urgent birthdays. You're safe... for now."
    fi
}

send_birthday_alert() {
    local name=$1
    local days_until=$2
    local urgency=$3

    local message="$name's birthday is "
    [[ $days_until -eq 0 ]] && message="$name's birthday is TODAY!" || message+="in $days_until day(s)!"

    # Desktop notification
    if [[ $SEND_PUSH_NOTIFICATIONS -eq 1 ]]; then
        notify "🎂 Birthday Alert" "$message" "$urgency"
    fi

    # Email reminder
    if [[ $SEND_EMAIL_REMINDERS -eq 1 ]] && [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "$message" | mail -s "Birthday Reminder: $name" "$ALERT_EMAIL" 2>/dev/null || true
    fi

    # Record reminder
    record_reminder "$name" "$days_until"
}

record_reminder() {
    local name=$1
    local days_until=$2

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$REMINDER_HISTORY_FILE" ]]; then
        echo '{"reminders": []}' > "$REMINDER_HISTORY_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --arg name "$name" \
       --arg days "$days_until" \
       --arg timestamp "$(date -Iseconds)" \
       '.reminders += [{timestamp: $timestamp, name: $name, days_until: $days}]' \
       "$REMINDER_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$REMINDER_HISTORY_FILE"
}

#=============================================================================
# Gift Suggestion Engine
#=============================================================================

suggest_gifts() {
    local name=$1

    init_birthday_db

    echo -e "\n${BOLD}🎁 Gift Suggestions for $name${NC}\n"

    # Get person data
    local person=$(jq --arg name "$name" '.people[] | select(.name == $name)' "$BIRTHDAY_DB_FILE")

    if [[ -z "$person" ]]; then
        log_error "Person not found: $name"
        return 1
    fi

    local relationship=$(echo "$person" | jq -r '.relationship')
    local interests=$(echo "$person" | jq -r '.interests[]' 2>/dev/null || echo "")

    # Get budget based on relationship
    local budget=$(get_gift_budget "$relationship")

    echo -e "${BOLD}Budget:${NC} \$$budget"
    echo -e "${BOLD}Relationship:${NC} $relationship"
    echo

    # Generate suggestions based on interests
    if [[ -n "$interests" ]]; then
        echo -e "${BOLD}Based on their interests:${NC}"
        while IFS= read -r interest; do
            [[ -z "$interest" ]] && continue
            generate_gift_ideas "$interest" "$budget"
        done <<< "$interests"
        echo
    fi

    # Generic suggestions by relationship
    echo -e "${BOLD}Generic suggestions:${NC}"
    generate_generic_gifts "$relationship" "$budget"
    echo

    # Show Amazon/shopping links
    generate_shopping_links "$interests" "$budget"
}

get_gift_budget() {
    local relationship=$1

    case $relationship in
        spouse|partner)
            echo "200"
            ;;
        parent|sibling)
            echo "100"
            ;;
        close_friend)
            echo "75"
            ;;
        friend)
            echo "50"
            ;;
        coworker)
            echo "25"
            ;;
        acquaintance)
            echo "15"
            ;;
        *)
            echo "$BUDGET_DEFAULT"
            ;;
    esac
}

generate_gift_ideas() {
    local interest=$1
    local budget=$2

    case $(echo "$interest" | tr '[:upper:]' '[:lower:]') in
        *coffee*)
            echo "  • Premium coffee beans subscription (\$20-60/month)"
            echo "  • Specialty coffee maker (\$50-200)"
            ;;
        *tech*|*gaming*)
            echo "  • Mechanical keyboard (\$80-150)"
            echo "  • High-quality mouse (\$50-100)"
            echo "  • Steam gift card (\$25-100)"
            ;;
        *book*|*reading*)
            echo "  • Kindle/e-reader (\$80-150)"
            echo "  • Bookstore gift card (\$25-100)"
            echo "  • Book subscription box (\$30-50/month)"
            ;;
        *fitness*|*gym*)
            echo "  • Fitness tracker (\$50-150)"
            echo "  • Gym bag (\$30-80)"
            echo "  • Workout gear (\$30-100)"
            ;;
        *music*)
            echo "  • Quality headphones (\$50-200)"
            echo "  • Spotify/Apple Music gift card (\$25-100)"
            echo "  • Vinyl record (\$20-50)"
            ;;
        *cooking*|*food*)
            echo "  • Cookbook (\$20-40)"
            echo "  • Kitchen gadget (\$30-100)"
            echo "  • Cooking class voucher (\$50-150)"
            ;;
        *travel*)
            echo "  • Travel accessories (\$20-80)"
            echo "  • Luggage tags (\$15-30)"
            echo "  • Travel guide book (\$20-40)"
            ;;
        *)
            echo "  • Gift card to favorite store (\$$((budget / 2))-\$${budget})"
            ;;
    esac
}

generate_generic_gifts() {
    local relationship=$1
    local budget=$2

    case $relationship in
        spouse|partner)
            echo "  • Jewelry (\$100-300)"
            echo "  • Spa day voucher (\$100-200)"
            echo "  • Weekend getaway (\$200-500)"
            echo "  • Personalized photo album (\$50-100)"
            ;;
        parent)
            echo "  • Nice wine/whiskey (\$50-150)"
            echo "  • Photo frame with family picture (\$30-80)"
            echo "  • Dinner at nice restaurant (\$100-200)"
            ;;
        friend|close_friend)
            echo "  • Experience gift (concert, show, etc.) (\$50-150)"
            echo "  • Board game (\$30-60)"
            echo "  • Subscription box (\$30-50/month)"
            ;;
        coworker)
            echo "  • Coffee shop gift card (\$15-25)"
            echo "  • Desk plant (\$10-30)"
            echo "  • Nice pen (\$20-50)"
            ;;
        *)
            echo "  • Gift card (\$25-50)"
            echo "  • Bottle of wine (\$20-40)"
            echo "  • Book (\$15-30)"
            ;;
    esac
}

generate_shopping_links() {
    local interests=$1
    local budget=$2

    echo -e "${BOLD}🛒 Quick Shopping Links:${NC}"
    echo "  • Amazon: https://amazon.com/gp/gift-central"
    echo "  • Etsy (personalized): https://etsy.com/gift-mode"
    echo "  • Uncommon Goods: https://uncommongoods.com"
    echo "  • Giftcards: https://giftcards.amazon.com"
}

#=============================================================================
# Social Media Scraping (for interests)
#=============================================================================

scrape_social_interests() {
    local name=$1

    if [[ $USE_SOCIAL_SCRAPING -ne 1 ]]; then
        log_info "Social scraping disabled"
        return 0
    fi

    log_info "Analyzing social media profiles for $name..."

    # This would integrate with social media APIs
    # For now, manual process

    echo -e "\n${YELLOW}Manual OSINT checklist:${NC}"
    echo "  1. Check recent Instagram/Facebook posts"
    echo "  2. Look at liked/saved content"
    echo "  3. Review Amazon wishlist if available"
    echo "  4. Check recent tweets/posts for hints"
    echo "  5. Ask mutual friends subtly"
    echo

    log_info "Add interests manually with: $0 add-interest \"$name\" \"interest1\" \"interest2\""
}

#=============================================================================
# Gift History Tracking
#=============================================================================

record_gift() {
    local name=$1
    local gift=$2
    local cost=${3:-0}
    local year=${4:-$(date +%Y)}

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$GIFT_HISTORY_FILE" ]]; then
        echo '{"gifts": []}' > "$GIFT_HISTORY_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --arg name "$name" \
       --arg gift "$gift" \
       --arg cost "$cost" \
       --arg year "$year" \
       --arg timestamp "$(date -Iseconds)" \
       '.gifts += [{timestamp: $timestamp, name: $name, gift: $gift, cost: $cost, year: $year}]' \
       "$GIFT_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$GIFT_HISTORY_FILE"

    log_success "Recorded gift: $gift for $name (\$$cost)"
}

show_gift_history() {
    local name=${1:-""}

    if [[ ! -f "$GIFT_HISTORY_FILE" ]]; then
        log_info "No gift history available"
        return 0
    fi

    echo -e "\n${BOLD}🎁 Gift History${NC}\n"

    if [[ -n "$name" ]]; then
        jq -r --arg name "$name" \
            '.gifts[] | select(.name == $name) |
            "\(.year): \(.gift) (\$\(.cost))"' \
            "$GIFT_HISTORY_FILE"
    else
        jq -r '.gifts[] | "\(.name) (\(.year)): \(.gift) (\$\(.cost))"' \
            "$GIFT_HISTORY_FILE"
    fi

    echo
}

#=============================================================================
# Dashboard
#=============================================================================

show_dashboard() {
    clear

    cat <<EOF
${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}║              🎂 BIRTHDAY DASHBOARD 🎁                      ║${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

EOF

    # Show critical alerts first
    check_and_send_reminders

    # Show next 30 days
    echo -e "\n${BOLD}📅 Next 30 Days:${NC}\n"

    while IFS=: read -r days_until name birthday importance; do
        [[ -z "$days_until" ]] && continue

        local urgency_emoji="📅"
        [[ $days_until -eq 0 ]] && urgency_emoji="🎂"
        [[ $days_until -le $PANIC_WARNING_DAYS ]] && urgency_emoji="🚨"
        [[ $days_until -le $CRITICAL_WARNING_DAYS ]] && urgency_emoji="⚠️ "

        echo "$urgency_emoji  $name - in $days_until days ($birthday)"
    done < <(get_upcoming_birthdays 30)

    echo

    # Stats
    local total_people=$(jq '.people | length' "$BIRTHDAY_DB_FILE" 2>/dev/null || echo "0")
    echo -e "${BOLD}Total people tracked:${NC} $total_people"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Never forget a birthday again

COMMANDS:
    add NAME DATE [REL] [IMP]    Add birthday (DATE: YYYY-MM-DD or MM-DD)
    remove NAME                   Remove birthday
    list                          List all birthdays
    check                         Check upcoming birthdays
    dashboard                     Show dashboard
    suggest NAME                  Get gift suggestions
    record-gift NAME GIFT [COST]  Record a gift given
    add-interest NAME INTERESTS... Add interests for person
    history [NAME]                Show gift history
    scrape NAME                   Scrape social media for interests

RELATIONSHIPS:
    spouse, partner, parent, sibling, close_friend, friend, coworker, acquaintance

IMPORTANCE:
    critical, high, normal, low

OPTIONS:
    -h, --help                    Show this help

EXAMPLES:
    # Add birthdays
    $0 add "Alice" "1990-05-15" "spouse" "critical"
    $0 add "Bob" "07-22" "friend" "normal"

    # Check upcoming
    $0 check

    # Get gift suggestions
    $0 suggest "Alice"

    # Add interests (helps with gift suggestions)
    $0 add-interest "Alice" "coffee" "books" "yoga"

    # Record gift
    $0 record-gift "Alice" "Coffee maker" 89

    # Show dashboard
    $0 dashboard

AUTOMATION:
    # Daily check (add to crontab)
    0 9 * * * $SCRIPT_DIR/birthday-reminder-pro.sh check

    # Weekly dashboard email
    0 9 * * 0 $SCRIPT_DIR/birthday-reminder-pro.sh dashboard | mail -s "Birthday Report" you@email.com

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            add|remove|list|check|dashboard|suggest|record-gift|add-interest|history|scrape)
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
    check_commands jq

    # Initialize database
    init_birthday_db

    # Execute command
    case $command in
        add)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: add NAME DATE [RELATIONSHIP] [IMPORTANCE]"
                exit 1
            fi
            add_birthday "$@"
            ;;
        remove)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: remove NAME"
                exit 1
            fi
            remove_birthday "$1"
            ;;
        list)
            list_birthdays
            ;;
        check)
            check_and_send_reminders
            ;;
        dashboard)
            show_dashboard
            ;;
        suggest)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: suggest NAME"
                exit 1
            fi
            suggest_gifts "$1"
            ;;
        record-gift)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: record-gift NAME GIFT [COST]"
                exit 1
            fi
            record_gift "$@"
            ;;
        add-interest)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: add-interest NAME INTERESTS..."
                exit 1
            fi
            local name=$1
            shift
            update_person_interests "$name" "$@"
            ;;
        history)
            show_gift_history "$@"
            ;;
        scrape)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: scrape NAME"
                exit 1
            fi
            scrape_social_interests "$1"
            ;;
        "")
            show_dashboard
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
