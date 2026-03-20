#!/bin/bash
#=============================================================================
# expense-shame-dashboard.sh
# Financial shame dashboard: "Coffee this month = $347"
# "Because you need to see how much you waste on stupid stuff"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

EXPENSE_DB="$DATA_DIR/expenses.json"
CATEGORIES_FILE="$DATA_DIR/expense_categories.json"
GOALS_FILE="$DATA_DIR/financial_goals.json"

# Shame thresholds
COFFEE_SHAME_THRESHOLD=100
FOOD_DELIVERY_SHAME_THRESHOLD=200
SUBSCRIPTION_SHAME_THRESHOLD=50

# Your hourly rate (for conversion)
HOURLY_RATE=${HOURLY_RATE:-50}  # Default $50/hour

#=============================================================================
# Category Detection Rules
#=============================================================================

init_categories() {
    if [[ ! -f "$CATEGORIES_FILE" ]]; then
        cat > "$CATEGORIES_FILE" <<'EOF'
{
  "coffee": {
    "keywords": ["starbucks", "coffee", "cafe", "espresso", "dunkin", "peets", "blue bottle"],
    "shame_level": "high",
    "emoji": "☕"
  },
  "food_delivery": {
    "keywords": ["uber eats", "doordash", "grubhub", "postmates", "deliveroo", "seamless"],
    "shame_level": "critical",
    "emoji": "🍔"
  },
  "subscriptions": {
    "keywords": ["netflix", "spotify", "hulu", "disney", "amazon prime", "apple music", "youtube premium", "github copilot", "chatgpt"],
    "shame_level": "medium",
    "emoji": "📱"
  },
  "alcohol": {
    "keywords": ["bar", "liquor", "beer", "wine", "brewery", "pub", "tavern"],
    "shame_level": "high",
    "emoji": "🍺"
  },
  "impulse_shopping": {
    "keywords": ["amazon", "ebay", "etsy", "target", "walmart"],
    "shame_level": "high",
    "emoji": "🛒"
  },
  "entertainment": {
    "keywords": ["cinema", "movie", "theater", "concert", "gaming", "steam", "playstation", "xbox"],
    "shame_level": "medium",
    "emoji": "🎮"
  },
  "transportation": {
    "keywords": ["uber", "lyft", "taxi", "parking", "gas", "fuel"],
    "shame_level": "low",
    "emoji": "🚗"
  },
  "groceries": {
    "keywords": ["whole foods", "trader joe", "safeway", "kroger", "grocery"],
    "shame_level": "low",
    "emoji": "🛒"
  },
  "fitness": {
    "keywords": ["gym", "fitness", "yoga", "peloton", "training"],
    "shame_level": "low",
    "emoji": "💪"
  },
  "other": {
    "keywords": [],
    "shame_level": "low",
    "emoji": "❓"
  }
}
EOF
        log_success "Initialized expense categories"
    fi
}

categorize_expense() {
    local description=$1

    init_categories

    # Check each category
    while IFS= read -r category; do
        local keywords=$(jq -r ".${category}.keywords[]" "$CATEGORIES_FILE" 2>/dev/null || echo "")

        while IFS= read -r keyword; do
            [[ -z "$keyword" ]] && continue

            if echo "$description" | grep -qi "$keyword"; then
                echo "$category"
                return 0
            fi
        done <<< "$keywords"
    done < <(jq -r 'keys[]' "$CATEGORIES_FILE")

    echo "other"
}

get_category_emoji() {
    local category=$1
    jq -r ".${category}.emoji // \"❓\"" "$CATEGORIES_FILE" 2>/dev/null || echo "❓"
}

#=============================================================================
# CSV Parsing
#=============================================================================

import_csv() {
    local csv_file=$1

    if [[ ! -f "$csv_file" ]]; then
        log_error "File not found: $csv_file"
        return 1
    fi

    log_info "Importing expenses from $csv_file"

    local count=0

    # Skip header, parse CSV
    tail -n +2 "$csv_file" | while IFS=, read -r date description amount; do
        # Clean fields
        date=$(echo "$date" | tr -d '"' | xargs)
        description=$(echo "$description" | tr -d '"' | xargs)
        amount=$(echo "$amount" | tr -d '"$' | xargs)

        # Skip empty lines
        [[ -z "$date" ]] && continue

        # Only process expenses (negative amounts or explicit expenses)
        if [[ "$amount" =~ ^- ]] || [[ "$amount" =~ ^[0-9]+\.[0-9]{2}$ ]]; then
            # Remove negative sign
            amount=${amount#-}

            # Categorize
            local category=$(categorize_expense "$description")

            # Add expense
            add_expense "$date" "$description" "$amount" "$category"

            ((count++))
        fi
    done

    log_success "Imported $count expenses"
}

#=============================================================================
# Expense Management
#=============================================================================

init_expense_db() {
    if [[ ! -f "$EXPENSE_DB" ]]; then
        echo '{"expenses": []}' > "$EXPENSE_DB"
    fi
}

add_expense() {
    local date=$1
    local description=$2
    local amount=$3
    local category=${4:-"other"}

    init_expense_db

    local tmp_file=$(mktemp)

    jq --arg date "$date" \
       --arg desc "$description" \
       --arg amt "$amount" \
       --arg cat "$category" \
       '.expenses += [{date: $date, description: $desc, amount: ($amt | tonumber), category: $cat}]' \
       "$EXPENSE_DB" > "$tmp_file"

    mv "$tmp_file" "$EXPENSE_DB"

    log_debug "Added expense: $description - \$$amount ($category)"
}

#=============================================================================
# Shame Calculations
#=============================================================================

calculate_monthly_spending() {
    local month=${1:-$(date +%Y-%m)}

    init_expense_db

    jq --arg month "$month" \
       '[.expenses[] | select(.date | startswith($month)) | .amount] | add // 0' \
       "$EXPENSE_DB"
}

calculate_category_spending() {
    local category=$1
    local month=${2:-$(date +%Y-%m)}

    init_expense_db

    jq --arg cat "$category" \
       --arg month "$month" \
       '[.expenses[] | select(.category == $cat and (.date | startswith($month))) | .amount] | add // 0' \
       "$EXPENSE_DB"
}

get_top_expenses() {
    local month=${1:-$(date +%Y-%m)}
    local limit=${2:-10}

    init_expense_db

    jq --arg month "$month" \
       --argjson limit "$limit" \
       '[.expenses[] | select(.date | startswith($month))] | sort_by(-.amount) | .[:$limit]' \
       "$EXPENSE_DB"
}

calculate_hours_worked() {
    local amount=$1
    echo "scale=1; $amount / $HOURLY_RATE" | bc
}

#=============================================================================
# Shame Report Generation
#=============================================================================

generate_shame_report() {
    local month=${1:-$(date +%Y-%m)}
    local month_name=$(date -d "${month}-01" '+%B %Y' 2>/dev/null || date -j -f "%Y-%m" "$month" '+%B %Y')

    log_info "Generating shame report for $month_name..."

    # Total spending
    local total=$(calculate_monthly_spending "$month")

    # Category breakdown
    local coffee=$(calculate_category_spending "coffee" "$month")
    local food_delivery=$(calculate_category_spending "food_delivery" "$month")
    local subscriptions=$(calculate_category_spending "subscriptions" "$month")
    local alcohol=$(calculate_category_spending "alcohol" "$month")
    local impulse=$(calculate_category_spending "impulse_shopping" "$month")

    # Calculate hours worked equivalent
    local total_hours=$(calculate_hours_worked "$total")
    local coffee_hours=$(calculate_hours_worked "$coffee")
    local delivery_hours=$(calculate_hours_worked "$food_delivery")

    # Shame levels
    local shame_items=()

    cat <<EOF

${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              💸 FINANCIAL SHAME REPORT 💸                 ║
║                    $month_name
║                                                           ║
╚═══════════════════════════════════════════════════════════╝${NC}

${BOLD}Total Spent: ${RED}\$${total}${NC} ${YELLOW}(${total_hours} hours of work)${NC}

${BOLD}═══════════════════════════════════════════════════════════${NC}

EOF

    # Coffee shame
    if (( $(echo "$coffee > $COFFEE_SHAME_THRESHOLD" | bc -l) )); then
        echo -e "${RED}${BOLD}☕ COFFEE: \$${coffee}${NC} ${YELLOW}(${coffee_hours}h of work)${NC}"
        echo -e "   ${YELLOW}⚠️  You spent more on coffee than on:${NC}"

        # Compare to useful things
        local github_copilot=10
        local netflix=15
        echo -e "   - GitHub Copilot (\$${github_copilot}/mo) × $((${coffee%.*} / github_copilot)) months"
        echo -e "   - Netflix (\$${netflix}/mo) × $((${coffee%.*} / netflix)) months"
        echo
        shame_items+=("coffee")
    else
        echo -e "${GREEN}☕ Coffee: \$${coffee}${NC} (reasonable)"
        echo
    fi

    # Food delivery shame
    if (( $(echo "$food_delivery > $FOOD_DELIVERY_SHAME_THRESHOLD" | bc -l) )); then
        echo -e "${RED}${BOLD}🍔 FOOD DELIVERY: \$${food_delivery}${NC} ${YELLOW}(${delivery_hours}h of work)${NC}"
        echo -e "   ${RED}🚨 CRITICAL SHAME LEVEL${NC}"
        echo -e "   If you cooked instead:"
        local savings=$((${food_delivery%.*} * 70 / 100))
        echo -e "   - Could have saved ~\$${savings} (70% of delivery cost)"
        echo -e "   - That's $(calculate_hours_worked $savings)h of freedom"
        echo
        shame_items+=("delivery")
    else
        echo -e "${GREEN}🍔 Food Delivery: \$${food_delivery}${NC}"
        echo
    fi

    # Subscriptions
    if (( $(echo "$subscriptions > 0" | bc -l) )); then
        echo -e "${YELLOW}📱 Subscriptions: \$${subscriptions}${NC}"
        echo -e "   Recurring monthly drain: \$${subscriptions}"
        echo -e "   Annual cost: \$$((${subscriptions%.*} * 12))"

        # List subscriptions
        local sub_list=$(jq -r --arg month "$month" \
            '[.expenses[] | select(.category == "subscriptions" and (.date | startswith($month)))] |
            group_by(.description) |
            map({desc: .[0].description, total: (map(.amount) | add)}) |
            .[] | "   - \(.desc): $\(.total)"' \
            "$EXPENSE_DB" 2>/dev/null || echo "")

        if [[ -n "$sub_list" ]]; then
            echo "$sub_list"
        fi
        echo
    fi

    # Alcohol
    if (( $(echo "$alcohol > 0" | bc -l) )); then
        local alcohol_hours=$(calculate_hours_worked "$alcohol")
        echo -e "${YELLOW}🍺 Alcohol: \$${alcohol}${NC} (${alcohol_hours}h of work)"
        echo
    fi

    # Impulse shopping
    if (( $(echo "$impulse > 100" | bc -l) )); then
        local impulse_hours=$(calculate_hours_worked "$impulse")
        echo -e "${YELLOW}🛒 Impulse Shopping: \$${impulse}${NC} (${impulse_hours}h of work)"
        echo -e "   ${YELLOW}Stuff you probably don't need${NC}"
        echo
        shame_items+=("impulse")
    fi

    # Top 5 individual expenses
    echo -e "${BOLD}🏆 Top 5 Individual Expenses:${NC}"
    local top_expenses=$(get_top_expenses "$month" 5)

    echo "$top_expenses" | jq -r '.[] | "   \(.category): \(.description) - $\(.amount)"' 2>/dev/null || echo "   No data"

    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"

    # Shame summary
    if [[ ${#shame_items[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}SHAME SUMMARY:${NC}"
        echo -e "${RED}You have ${#shame_items[@]} category(ies) in the danger zone!${NC}"
        echo
        echo -e "${YELLOW}What you could have done with that money:${NC}"

        local wasted=$((${coffee%.*} + ${food_delivery%.*}))
        echo -e "  - Saved \$${wasted} (coffee + delivery)"
        echo -e "  - Bought $(( wasted / 50 )) nice dinners"
        echo -e "  - Invested it (7% return) = \$$((wasted * 107 / 100)) next year"
        echo -e "  - $(calculate_hours_worked $wasted) hours of freedom"
    else
        echo -e "${GREEN}${BOLD}✅ No major shame this month!${NC}"
        echo -e "${GREEN}Your spending is reasonable.${NC}"
    fi

    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
}

#=============================================================================
# Trends & Comparisons
#=============================================================================

show_trend() {
    local category=${1:-"total"}
    local months=6

    echo -e "\n${BOLD}📈 Spending Trend (Last $months months):${NC}\n"

    for ((i=months-1; i>=0; i--)); do
        local month=$(date -d "$i months ago" '+%Y-%m' 2>/dev/null || date -v-${i}m '+%Y-%m')
        local month_name=$(date -d "${month}-01" '+%b %Y' 2>/dev/null || date -j -f "%Y-%m" "$month" '+%b %Y')

        local amount
        if [[ "$category" == "total" ]]; then
            amount=$(calculate_monthly_spending "$month")
        else
            amount=$(calculate_category_spending "$category" "$month")
        fi

        # Create bar graph
        local bar_length=$((${amount%.*} / 10))
        local bar=$(printf '█%.0s' $(seq 1 $bar_length))

        echo -e "$month_name: \$${amount} ${bar}"
    done

    echo
}

compare_to_goals() {
    if [[ ! -f "$GOALS_FILE" ]]; then
        log_info "No financial goals set. Use 'set-goal' command."
        return 0
    fi

    local month=$(date +%Y-%m)
    local total=$(calculate_monthly_spending "$month")

    echo -e "\n${BOLD}🎯 Goal Progress:${NC}\n"

    # Monthly budget
    local budget=$(jq -r '.monthly_budget // 0' "$GOALS_FILE")
    if [[ $budget -gt 0 ]]; then
        local remaining=$((budget - ${total%.*}))
        local pct=$((${total%.*} * 100 / budget))

        if [[ $pct -gt 100 ]]; then
            echo -e "${RED}Monthly Budget: \$${total} / \$${budget} (${pct}% - OVER BUDGET!)${NC}"
        elif [[ $pct -gt 80 ]]; then
            echo -e "${YELLOW}Monthly Budget: \$${total} / \$${budget} (${pct}%)${NC}"
        else
            echo -e "${GREEN}Monthly Budget: \$${total} / \$${budget} (${pct}%)${NC}"
        fi

        echo -e "  Remaining: \$${remaining}"
    fi

    # Category goals
    jq -r '.category_limits // {} | to_entries[] | "\(.key):\(.value)"' "$GOALS_FILE" 2>/dev/null | while IFS=: read -r category limit; do
        local spent=$(calculate_category_spending "$category" "$month")
        local pct=$((${spent%.*} * 100 / limit))

        if [[ $pct -gt 100 ]]; then
            echo -e "${RED}$category: \$${spent} / \$${limit} (${pct}% - OVER!)${NC}"
        elif [[ $pct -gt 80 ]]; then
            echo -e "${YELLOW}$category: \$${spent} / \$${limit} (${pct}%)${NC}"
        else
            echo -e "${GREEN}$category: \$${spent} / \$${limit} (${pct}%)${NC}"
        fi
    done

    echo
}

#=============================================================================
# Goals Management
#=============================================================================

set_goal() {
    local goal_type=$1
    local amount=$2

    if [[ ! -f "$GOALS_FILE" ]]; then
        echo '{}' > "$GOALS_FILE"
    fi

    local tmp_file=$(mktemp)

    case $goal_type in
        budget)
            jq --arg amt "$amount" '.monthly_budget = ($amt | tonumber)' "$GOALS_FILE" > "$tmp_file"
            mv "$tmp_file" "$GOALS_FILE"
            log_success "Set monthly budget to \$${amount}"
            ;;
        *)
            # Category limit
            jq --arg cat "$goal_type" \
               --arg amt "$amount" \
               '.category_limits[$cat] = ($amt | tonumber)' \
               "$GOALS_FILE" > "$tmp_file"
            mv "$tmp_file" "$GOALS_FILE"
            log_success "Set $goal_type limit to \$${amount}"
            ;;
    esac
}

#=============================================================================
# Email Reports
#=============================================================================

send_shame_email() {
    local month=${1:-$(date +%Y-%m)}

    if [[ -z "${ALERT_EMAIL:-}" ]]; then
        log_warn "ALERT_EMAIL not configured in config.sh"
        return 1
    fi

    local report=$(generate_shame_report "$month")

    echo "$report" | mail -s "💸 Monthly Shame Report - $month" "$ALERT_EMAIL"

    log_success "Shame report emailed to $ALERT_EMAIL"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Financial shame dashboard - see how much you waste

COMMANDS:
    import CSV           Import expenses from CSV
    report [MONTH]       Generate shame report
    trend [CATEGORY]     Show spending trend
    goals                Compare to goals
    set-goal TYPE AMT    Set financial goal
    email [MONTH]        Email shame report

OPTIONS:
    --rate RATE          Set hourly rate (default: \$50)
    -h, --help           Show this help

EXAMPLES:
    # Import bank statement
    $0 import ~/Downloads/transactions.csv

    # View this month's shame
    $0 report

    # View last month
    $0 report 2024-11

    # Coffee trend
    $0 trend coffee

    # Set monthly budget
    $0 set-goal budget 3000

    # Set category limit
    $0 set-goal coffee 100

    # Email monthly report
    $0 email

CSV FORMAT:
    date,description,amount
    2024-11-15,"Starbucks",5.50
    2024-11-16,"Uber Eats",-25.00

SHAME CATEGORIES:
    ☕ Coffee - Starbucks, Dunkin, etc.
    🍔 Food Delivery - Uber Eats, DoorDash
    📱 Subscriptions - Netflix, Spotify
    🍺 Alcohol - Bars, liquor stores
    🛒 Impulse Shopping - Amazon, Target

AUTOMATION:
    # Monthly email report (1st of month)
    0 9 1 * * $0 email

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rate)
                HOURLY_RATE=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            import|report|trend|goals|set-goal|email)
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
    init_categories
    init_expense_db

    # Execute command
    case $command in
        import)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: import CSV_FILE"
                exit 1
            fi
            import_csv "$1"
            ;;
        report)
            local month=${1:-$(date +%Y-%m)}
            generate_shame_report "$month"
            ;;
        trend)
            local category=${1:-"total"}
            show_trend "$category"
            ;;
        goals)
            compare_to_goals
            ;;
        set-goal)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: set-goal TYPE AMOUNT"
                exit 1
            fi
            set_goal "$1" "$2"
            ;;
        email)
            local month=${1:-$(date +%Y-%m)}
            send_shame_email "$month"
            ;;
        "")
            # Default: show this month's report
            generate_shame_report
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
