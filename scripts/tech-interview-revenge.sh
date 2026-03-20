#!/bin/bash
#=============================================================================
# tech-interview-revenge.sh
# Automation for the interview grind - flip the script on interviewers
# "They asked me to do a take-home. I automated their entire hiring process."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

COMPANY_DB_FILE="$DATA_DIR/companies_interviewed.json"
RED_FLAGS_FILE="$DATA_DIR/red_flags.json"
SALARY_DATA_FILE="$DATA_DIR/salary_data.json"
QUESTIONS_FILE="$DATA_DIR/reverse_questions.json"

# Salary negotiation
YOUR_CURRENT_SALARY=${YOUR_CURRENT_SALARY:-100000}
YOUR_YOE=${YOUR_YOE:-5}  # Years of experience
YOUR_LOCATION=${YOUR_LOCATION:-"San Francisco"}

# Red flag thresholds
MAX_INTERVIEW_ROUNDS=6
MAX_TAKEHOME_HOURS=4
MIN_ACCEPTABLE_SALARY=0  # Will calculate based on market

#=============================================================================
# Company Research & Red Flag Detection
#=============================================================================

init_databases() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$COMPANY_DB_FILE" ]]; then
        echo '{"companies": []}' > "$COMPANY_DB_FILE"
    fi

    if [[ ! -f "$RED_FLAGS_FILE" ]]; then
        cat > "$RED_FLAGS_FILE" <<'EOF'
{
  "red_flags": [
    {
      "category": "job_description",
      "patterns": [
        "rockstar", "ninja", "guru", "wizard",
        "wear many hats", "fast-paced environment",
        "unlimited PTO", "we're a family",
        "competitive salary", "salary commensurate with experience",
        "must be passionate", "no drama"
      ]
    },
    {
      "category": "interview_process",
      "issues": [
        "More than 6 rounds",
        "Take-home over 4 hours",
        "Unpaid work disguised as assessment",
        "No salary range provided",
        "Equity-heavy comp for early employees",
        "Asking for current salary",
        "Asking for references too early"
      ]
    },
    {
      "category": "company_culture",
      "red_flags": [
        "High turnover on LinkedIn",
        "Negative Glassdoor reviews",
        "Founders with ego problems",
        "No work-life balance",
        "Constant pivot/no clear product",
        "Micromanagement evident"
      ]
    }
  ]
}
EOF
    fi

    if [[ ! -f "$QUESTIONS_FILE" ]]; then
        init_reverse_questions
    fi
}

analyze_job_description() {
    local job_desc=$1

    echo -e "\n${BOLD}🚩 Red Flag Analysis${NC}\n"

    local flags_found=0

    # Check for red flag keywords
    local patterns=$(jq -r '.red_flags[] | select(.category == "job_description") | .patterns[]' "$RED_FLAGS_FILE")

    while IFS= read -r pattern; do
        if echo "$job_desc" | grep -qi "$pattern"; then
            ((flags_found++))
            echo -e "${RED}  🚩 Found: '$pattern'${NC}"
        fi
    done <<< "$patterns"

    # Additional checks
    if ! echo "$job_desc" | grep -qi "salary\|compensation\|pay"; then
        ((flags_found++))
        echo -e "${RED}  🚩 No salary information${NC}"
    fi

    if ! echo "$job_desc" | grep -qi "remote\|hybrid"; then
        echo -e "${YELLOW}  ⚠️  Remote policy unclear${NC}"
    fi

    if [[ $flags_found -gt 3 ]]; then
        echo -e "\n${RED}${BOLD}⛔ HIGH ALERT: $flags_found red flags found!${NC}"
        echo -e "${RED}Consider skipping this one.${NC}\n"
    elif [[ $flags_found -gt 0 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  Warning: $flags_found red flags${NC}\n"
    else
        echo -e "\n${GREEN}${BOLD}✅ Job description looks reasonable${NC}\n"
    fi
}

research_company() {
    local company_name=$1

    log_info "Researching company: $company_name"

    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          🔍 COMPANY RESEARCH: $company_name"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    # Check Glassdoor (would need scraping or API)
    echo -e "${BOLD}Quick Research Links:${NC}"
    echo "  • Glassdoor: https://www.glassdoor.com/Search/results.htm?keyword=$(echo "$company_name" | jq -sRr @uri)"
    echo "  • LinkedIn: https://www.linkedin.com/search/results/companies/?keywords=$(echo "$company_name" | jq -sRr @uri)"
    echo "  • Crunchbase: https://www.crunchbase.com/textsearch?q=$(echo "$company_name" | jq -sRr @uri)"
    echo "  • Layoffs.fyi: https://layoffs.fyi/"
    echo

    echo -e "${BOLD}What to check:${NC}"
    echo "  ✓ Glassdoor rating (look for < 3.5 stars)"
    echo "  ✓ Recent reviews mentioning layoffs/problems"
    echo "  ✓ LinkedIn: High employee turnover?"
    echo "  ✓ Funding status: Running out of money?"
    echo "  ✓ Layoffs in last 6 months?"
    echo "  ✓ Founder/exec LinkedIn: Red flag posts?"
    echo
}

#=============================================================================
# Reverse Interview Questions
#=============================================================================

init_reverse_questions() {
    cat > "$QUESTIONS_FILE" <<'EOF'
{
  "categories": {
    "technical_debt": [
      "What's your oldest production code? How old is your oldest dependency?",
      "How do you handle tech debt? Show me your tech debt backlog.",
      "What percentage of time do engineers spend on tech debt vs features?",
      "Tell me about your most embarrassing production incident.",
      "What's your test coverage? When was the last time you improved it?"
    ],
    "culture": [
      "What's your real turnover rate? Why did the last 3 engineers leave?",
      "How many hours per week do senior engineers actually work?",
      "When was the last time someone got promoted? How long did it take?",
      "Do people check Slack on weekends? Be honest.",
      "What happens when someone misses a deadline?",
      "How many all-hands meetings per week?"
    ],
    "process": [
      "How long does a PR sit before review? What's your record?",
      "How often do you deploy? What stops you from deploying more?",
      "Who has production access? Can engineers deploy without approval?",
      "What's your incident response process? Show me the runbook.",
      "How do you handle on-call? What's the page volume like?"
    ],
    "growth": [
      "What's the career ladder? Can you show me the documentation?",
      "How do performance reviews work? When was the last promotion?",
      "What's the raise/bonus structure? Show me numbers.",
      "What training budget do I get? Can I go to conferences?",
      "How do you handle engineers who want to switch teams?"
    ],
    "business": [
      "What's the runway? When do you need to raise again?",
      "What's the revenue? What's the burn rate?",
      "Who are your actual competitors? Why are you winning/losing?",
      "What happens if this funding round fails?",
      "Why did the CTO/VP Engineering leave? Don't give me the PR answer."
    ],
    "red_team": [
      "If you could change ONE thing about this company, what would it be?",
      "What's the biggest lie in our job description?",
      "Why is this position open? Did someone quit or get fired?",
      "What would make me want to quit in the first 6 months?",
      "Be honest: Is this a good place to work right now?"
    ]
  }
}
EOF
}

generate_reverse_questions() {
    local category=${1:-"all"}

    echo -e "\n${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║          💣 REVERSE INTERVIEW QUESTIONS 💣              ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}Use these to evaluate THEM:${NC}\n"

    if [[ "$category" == "all" ]]; then
        jq -r '.categories | to_entries[] |
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
            "\u001b[1m\(.key | ascii_upcase)\u001b[0m\n" +
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
            (.value[] | "  • \(.)\n")' "$QUESTIONS_FILE"
    else
        jq -r --arg cat "$category" '.categories[$cat][]? | "  • \(.)"' "$QUESTIONS_FILE"
    fi

    echo
    echo -e "${YELLOW}${BOLD}Pro tips:${NC}"
    echo "  • Ask these at the END of the interview"
    echo "  • Watch for hesitation and PR-speak"
    echo "  • Good companies will respect these questions"
    echo "  • Bad companies will get defensive"
    echo
}

#=============================================================================
# Salary Negotiation Calculator
#=============================================================================

calculate_market_rate() {
    local role=$1
    local yoe=${2:-$YOUR_YOE}
    local location=${3:-$YOUR_LOCATION}

    log_info "Calculating market rate for $role..."

    # Simplified market data (would normally query levels.fyi API)
    echo -e "\n${BOLD}💰 Salary Research${NC}\n"

    echo "Research sources:"
    echo "  • levels.fyi: https://www.levels.fyi/?search=$(echo "$role" | jq -sRr @uri)"
    echo "  • Glassdoor: https://www.glassdoor.com/Salaries/index.htm"
    echo "  • Payscale: https://www.payscale.com/research"
    echo "  • Blind: https://www.teamblind.com/salaries"
    echo

    # Rough estimates by YOE (for software engineer)
    local base_estimate
    if [[ $yoe -le 2 ]]; then
        base_estimate=120000
    elif [[ $yoe -le 5 ]]; then
        base_estimate=160000
    elif [[ $yoe -le 8 ]]; then
        base_estimate=200000
    else
        base_estimate=250000
    fi

    # Location multiplier
    local multiplier=1.0
    case $(echo "$location" | tr '[:upper:]' '[:lower:]') in
        *"san francisco"*|*"bay area"*|*"sf"*)
            multiplier=1.5
            ;;
        *"new york"*|*"nyc"*)
            multiplier=1.4
            ;;
        *"seattle"*)
            multiplier=1.3
            ;;
        *"austin"*|*"boston"*)
            multiplier=1.2
            ;;
    esac

    local adjusted_salary=$(echo "$base_estimate * $multiplier" | bc | cut -d. -f1)

    echo -e "${BOLD}Estimated Market Rate:${NC}"
    echo "  Base: \$${adjusted_salary}"
    echo "  + Bonus (15%): \$$(echo "$adjusted_salary * 0.15" | bc | cut -d. -f1)"
    echo "  + Equity: (varies widely)"
    echo
    echo -e "${GREEN}${BOLD}Total Comp Range: \$${adjusted_salary} - \$$(echo "$adjusted_salary * 1.3" | bc | cut -d. -f1)${NC}"
    echo
}

negotiate_offer() {
    local offered_salary=$1

    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          🎯 SALARY NEGOTIATION ASSISTANT 🎯             ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    read -p "Your current salary: \$" current_salary
    read -p "Offered salary: \$" offered_salary
    read -p "Market rate (from research): \$" market_rate

    local min_acceptable=$(echo "$current_salary * 1.15" | bc | cut -d. -f1)
    local target=$(echo "$market_rate" | bc | cut -d. -f1)
    local ask=$(echo "$target * 1.1" | bc | cut -d. -f1)

    echo
    echo -e "${BOLD}Negotiation Strategy:${NC}\n"

    if [[ $offered_salary -lt $min_acceptable ]]; then
        echo -e "${RED}❌ REJECT: Offer is below minimum acceptable${NC}"
        echo "  Minimum acceptable: \$$min_acceptable (15% raise)"
        echo "  Offered: \$$offered_salary"
        echo
        echo -e "${BOLD}Response template:${NC}"
        cat <<EOF

"Thank you for the offer. I'm excited about the role, but the
compensation is below my target range. Based on my research and
experience, I'm looking for \$$target base salary.

Could we discuss increasing the base salary closer to market rate?"

EOF
    elif [[ $offered_salary -lt $target ]]; then
        echo -e "${YELLOW}⚠️  NEGOTIATE: Below market rate${NC}"
        echo "  Target: \$$target"
        echo "  Offered: \$$offered_salary"
        echo "  Gap: \$$(echo "$target - $offered_salary" | bc)"
        echo
        echo -e "${BOLD}Counter-offer: \$$ask${NC}"
        echo
        cat <<EOF
Response template:

"Thank you for the offer. I'm very interested in the position.

Based on my research of market rates for similar roles and my X years
of experience, I was expecting closer to \$$ask base salary.

Is there flexibility in the compensation package?"

EOF
    else
        echo -e "${GREEN}✅ GOOD OFFER: At or above market${NC}"
        echo "  Still try to negotiate 5-10% higher!"
        echo
        cat <<EOF
Response template:

"Thank you for the offer! I'm excited about joining.

I was hoping for \$$ask to make this an easy yes. Is there any
flexibility in the base salary or signing bonus?"

EOF
    fi

    echo
    echo -e "${BOLD}${YELLOW}Negotiation Tips:${NC}"
    echo "  • NEVER give your current salary"
    echo "  • Always counter - they expect it"
    echo "  • Ask for signing bonus if base won't budge"
    echo "  • Get competing offers to use as leverage"
    echo "  • Don't accept immediately - sleep on it"
    echo "  • Everything is negotiable: salary, equity, bonus, PTO, start date"
    echo
}

#=============================================================================
# Take-Home Assignment Analyzer
#=============================================================================

analyze_takehome() {
    local assignment_desc=$1

    echo -e "\n${BOLD}${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║          ⚠️  TAKE-HOME ASSIGNMENT ANALYSIS ⚠️           ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"

    read -p "Estimated hours to complete: " hours
    read -p "Is this similar to their actual product? (yes/no): " is_product_work
    read -p "Will this code be used in production? (yes/no): " is_production

    local red_flags=0

    echo
    echo -e "${BOLD}Analysis:${NC}\n"

    if [[ $hours -gt 4 ]]; then
        ((red_flags++))
        echo -e "${RED}  🚩 Too long: ${hours}h (max should be 4h)${NC}"
    else
        echo -e "${GREEN}  ✓ Reasonable time: ${hours}h${NC}"
    fi

    if [[ "$is_product_work" == "yes" ]]; then
        ((red_flags++))
        echo -e "${RED}  🚩 Suspiciously similar to their product${NC}"
    fi

    if [[ "$is_production" == "yes" ]]; then
        ((red_flags++))
        echo -e "${RED}  🚩 Free labor: They'll use your code${NC}"
    fi

    # Check for specific red flag patterns
    if echo "$assignment_desc" | grep -qi "full.*stack\|frontend.*backend"; then
        ((red_flags++))
        echo -e "${RED}  🚩 Full-stack requirement (scope creep)${NC}"
    fi

    if echo "$assignment_desc" | grep -qi "deploy\|production\|aws\|kubernetes"; then
        ((red_flags++))
        echo -e "${RED}  🚩 Requires infrastructure setup${NC}"
    fi

    if echo "$assignment_desc" | grep -qi "design.*system\|architecture"; then
        ((red_flags++))
        echo -e "${RED}  🚩 Architecture work (too senior for take-home)${NC}"
    fi

    echo
    if [[ $red_flags -ge 3 ]]; then
        echo -e "${RED}${BOLD}⛔ REJECT THIS ASSIGNMENT${NC}"
        echo
        echo -e "${BOLD}Suggested response:${NC}"
        cat <<EOF

"Thank you for the assignment. After reviewing it, I believe this scope
exceeds what's reasonable for an interview process.

I'm happy to do a shorter take-home (2-4 hours) or a live coding session
instead. Could we discuss alternatives?"

EOF
    elif [[ $red_flags -ge 1 ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  PROCEED WITH CAUTION${NC}"
        echo "  Consider negotiating the scope or timeline"
    else
        echo -e "${GREEN}${BOLD}✅ Seems reasonable${NC}"
        echo "  But still track your time!"
    fi

    echo
    echo -e "${BOLD}Pro tips:${NC}"
    echo "  • Track your time precisely"
    echo "  • Stop at 4 hours regardless of completion"
    echo "  • If you exceed 4h, mention it in your submission"
    echo "  • Your hourly rate: \$$(echo "$YOUR_CURRENT_SALARY / 2080" | bc)"
    echo
}

#=============================================================================
# Auto-Decline Template Generator
#=============================================================================

generate_decline_template() {
    local reason=$1

    echo -e "\n${BOLD}📧 Decline Email Template${NC}\n"

    case $reason in
        lowball)
            cat <<EOF
Subject: Re: Offer - [Company Name]

Hi [Recruiter Name],

Thank you for the offer. After careful consideration, I've decided to
pursue other opportunities that better align with my compensation expectations.

I appreciate the time your team spent with me.

Best regards,
[Your Name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BOLD}Why this works:${NC}
• Professional and brief
• No need to explain further
• Leaves door open (if you want)
• Signals the offer was too low
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
            ;;
        process)
            cat <<EOF
Subject: Interview Process - Moving Forward

Hi [Recruiter Name],

Thank you for your interest. After [X rounds/Y weeks], I've decided to
focus on opportunities with more streamlined interview processes.

I appreciate your time.

Best,
[Your Name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BOLD}When to use:${NC}
• After 6+ rounds
• After 2+ months of interviewing
• After ridiculous take-home assignments
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
            ;;
        redflags)
            cat <<EOF
Subject: Position at [Company Name]

Hi [Recruiter Name],

Thank you for the opportunity to interview. After learning more about
the role and company, I don't think this is the right fit for me at
this time.

Best wishes,
[Your Name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BOLD}When to use:${NC}
• Too many red flags discovered
• Toxic culture detected
• Better offer received
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
            ;;
        *)
            cat <<EOF
Subject: Re: [Position] at [Company]

Hi [Name],

Thank you for your time. I've decided to pursue other opportunities.

Best,
[Your Name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BOLD}The nuclear option:${NC}
• Shortest possible decline
• Maximum sass
• Use when they wasted your time
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
            ;;
    esac
}

#=============================================================================
# Interview Stats & Tracking
#=============================================================================

track_company() {
    local company=$1
    local status=$2  # applied, interviewing, offered, rejected, declined

    init_databases

    local tmp_file=$(mktemp)

    jq --arg company "$company" \
       --arg status "$status" \
       --arg timestamp "$(date -Iseconds)" \
       '.companies += [{
           name: $company,
           status: $status,
           timestamp: $timestamp,
           rounds: 0,
           takehome_hours: 0
       }]' \
       "$COMPANY_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$COMPANY_DB_FILE"
}

show_stats() {
    if [[ ! -f "$COMPANY_DB_FILE" ]]; then
        log_info "No interview data yet"
        return 0
    fi

    echo -e "\n${BOLD}📊 Interview Stats${NC}\n"

    local total=$(jq '.companies | length' "$COMPANY_DB_FILE")
    local offered=$(jq '[.companies[] | select(.status == "offered")] | length' "$COMPANY_DB_FILE")
    local rejected=$(jq '[.companies[] | select(.status == "rejected")] | length' "$COMPANY_DB_FILE")

    echo "Total applications: $total"
    echo "Offers received: $offered"
    echo "Rejected: $rejected"
    echo

    if [[ $total -gt 0 ]]; then
        local offer_rate=$(echo "scale=1; $offered * 100 / $total" | bc)
        echo "Offer rate: ${offer_rate}%"
    fi

    echo
    echo -e "${BOLD}Recent activity:${NC}"
    jq -r '.companies[-10:] | .[] |
        "  [\(.status)] \(.name) - \(.timestamp)"' \
        "$COMPANY_DB_FILE"

    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Flip the script on technical interviews

COMMANDS:
    research COMPANY             Research company (red flags, etc.)
    analyze-job FILE             Analyze job description for red flags
    questions [CATEGORY]         Generate reverse interview questions
    salary ROLE [YOE] [LOCATION] Calculate market salary
    negotiate                    Salary negotiation assistant
    takehome                     Analyze take-home assignment
    decline REASON               Generate decline email
    stats                        Show interview statistics

CATEGORIES (for questions):
    technical_debt, culture, process, growth, business, red_team, all

REASONS (for decline):
    lowball, process, redflags, generic

EXAMPLES:
    # Research a company
    $0 research "SomeStartup"

    # Analyze job description
    $0 analyze-job job_description.txt

    # Get reverse interview questions
    $0 questions red_team

    # Calculate market rate
    $0 salary "Senior Engineer" 8 "SF"

    # Salary negotiation help
    $0 negotiate

    # Analyze take-home assignment
    $0 takehome

    # Generate decline email
    $0 decline lowball

WORKFLOW:
    1. Research company: $0 research "Company"
    2. Analyze job desc: $0 analyze-job job.txt
    3. Prepare questions: $0 questions all
    4. After offer: $0 negotiate
    5. If bad offer: $0 decline lowball

PHILOSOPHY:
    • Your time is valuable
    • They need you more than you need them
    • Every interview is a two-way evaluation
    • Bad companies show red flags early
    • Always negotiate
    • Walk away from bullshit

EOF
}

main() {
    local command=""

    # Initialize
    init_databases

    # Parse command
    case ${1:-help} in
        research)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: research COMPANY"
                exit 1
            fi
            research_company "$2"
            ;;
        analyze-job)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: analyze-job FILE"
                exit 1
            fi
            if [[ ! -f "$2" ]]; then
                log_error "File not found: $2"
                exit 1
            fi
            analyze_job_description "$(cat "$2")"
            ;;
        questions)
            generate_reverse_questions "${2:-all}"
            ;;
        salary)
            calculate_market_rate "${2:-Software Engineer}" "${3:-$YOUR_YOE}" "${4:-$YOUR_LOCATION}"
            ;;
        negotiate)
            negotiate_offer
            ;;
        takehome)
            echo "Paste the take-home assignment description (Ctrl+D when done):"
            local desc=$(cat)
            analyze_takehome "$desc"
            ;;
        decline)
            generate_decline_template "${2:-generic}"
            ;;
        stats)
            show_stats
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
