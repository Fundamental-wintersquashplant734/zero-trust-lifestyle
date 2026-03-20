#!/bin/bash
#=============================================================================
# fear-challenge.sh
# Picks something you're afraid of, schedules you to face it
# "The algorithm decided. You're doing it. No excuses."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

FEARS_DB_FILE="$DATA_DIR/fears.json"
CHALLENGES_LOG_FILE="$DATA_DIR/challenges_completed.json"
SCHEDULE_FILE="$DATA_DIR/challenge_schedule.json"

# Challenge settings
CHALLENGE_FREQUENCY=7  # Days between challenges
DIFFICULTY_PROGRESSION=1  # Gradually increase difficulty
ACCOUNTABILITY_MODE=1  # Send reminders
EVIDENCE_REQUIRED=1  # Require proof of completion

# Motivation
ENABLE_MOTIVATIONAL_QUOTES=1
ENABLE_HARSH_MODE=0  # Brutal honesty mode

#=============================================================================
# Fear Database
#=============================================================================

init_fears_db() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$FEARS_DB_FILE" ]]; then
        cat > "$FEARS_DB_FILE" <<'EOF'
{
  "fears": [
    {
      "category": "social",
      "difficulty": 1,
      "challenges": [
        "Make eye contact with a stranger for 5 seconds",
        "Say hello to someone you don't know",
        "Ask a stranger what time it is",
        "Compliment someone you don't know",
        "Start a conversation in an elevator"
      ]
    },
    {
      "category": "social",
      "difficulty": 3,
      "challenges": [
        "Speak up in a meeting/group",
        "Ask a question in front of 10+ people",
        "Tell a joke to a group",
        "Approach someone at a networking event",
        "Call someone instead of texting"
      ]
    },
    {
      "category": "social",
      "difficulty": 5,
      "challenges": [
        "Give a 5-minute presentation",
        "Attend a social event alone",
        "Ask someone to hang out",
        "Share an unpopular opinion in a group",
        "Do karaoke in front of people"
      ]
    },
    {
      "category": "physical",
      "difficulty": 2,
      "challenges": [
        "Do 10 pushups",
        "Go for a 10-minute jog",
        "Try a new physical activity",
        "Take the stairs instead of elevator",
        "Stretch for 5 minutes"
      ]
    },
    {
      "category": "physical",
      "difficulty": 4,
      "challenges": [
        "Go to the gym alone",
        "Try a group fitness class",
        "Go rock climbing",
        "Learn to swim",
        "Do a pull-up"
      ]
    },
    {
      "category": "creative",
      "difficulty": 2,
      "challenges": [
        "Write 500 words about anything",
        "Draw something and show someone",
        "Play music in front of someone",
        "Post your work online",
        "Try a new creative hobby"
      ]
    },
    {
      "category": "creative",
      "difficulty": 4,
      "challenges": [
        "Publish a blog post",
        "Share your creative work on social media",
        "Perform music/art publicly",
        "Enter a creative competition",
        "Teach someone your skill"
      ]
    },
    {
      "category": "professional",
      "difficulty": 3,
      "challenges": [
        "Ask for a raise",
        "Ask for help at work",
        "Admit you made a mistake publicly",
        "Give constructive feedback",
        "Network with someone senior"
      ]
    },
    {
      "category": "professional",
      "difficulty": 5,
      "challenges": [
        "Apply to a stretch job",
        "Ask someone to be your mentor",
        "Speak at a conference",
        "Start a side project publicly",
        "Negotiate your salary"
      ]
    },
    {
      "category": "personal",
      "difficulty": 2,
      "challenges": [
        "Try food you've never had",
        "Go somewhere alone",
        "Take a different route to work",
        "Strike up a conversation with a neighbor",
        "Attend an event alone"
      ]
    },
    {
      "category": "personal",
      "difficulty": 4,
      "challenges": [
        "Travel somewhere new alone",
        "Tell someone how you really feel",
        "Set a boundary with someone",
        "Apologize to someone you hurt",
        "Ask for what you want directly"
      ]
    },
    {
      "category": "extreme",
      "difficulty": 7,
      "challenges": [
        "Stand-up comedy open mic",
        "Cold approach someone you find attractive",
        "Quit something that's making you miserable",
        "Go skydiving",
        "Shave your head"
      ]
    }
  ],
  "custom_fears": []
}
EOF
        log_success "Initialized fears database"
    fi

    if [[ ! -f "$CHALLENGES_LOG_FILE" ]]; then
        echo '{"completed": []}' > "$CHALLENGES_LOG_FILE"
    fi

    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        echo '{"scheduled": []}' > "$SCHEDULE_FILE"
    fi
}

add_custom_fear() {
    local category=$1
    local difficulty=$2
    local challenge=$3

    init_fears_db

    local tmp_file=$(mktemp)

    jq --arg cat "$category" \
       --argjson diff "$difficulty" \
       --arg challenge "$challenge" \
       '.custom_fears += [{
           category: $cat,
           difficulty: $diff,
           challenge: $challenge
       }]' \
       "$FEARS_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$FEARS_DB_FILE"

    log_success "Added custom challenge: $challenge"
}

list_fears() {
    init_fears_db

    echo -e "\n${BOLD}😱 Available Challenges${NC}\n"

    jq -r '.fears[] |
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
        "\u001b[1m\(.category | ascii_upcase) (Difficulty: \(.difficulty)/10)\u001b[0m\n" +
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
        (.challenges[] | "  • \(.)\n")' "$FEARS_DB_FILE"

    # Show custom fears
    local custom_count=$(jq '.custom_fears | length' "$FEARS_DB_FILE")
    if [[ $custom_count -gt 0 ]]; then
        echo -e "\n${BOLD}Custom Challenges:${NC}\n"
        jq -r '.custom_fears[] |
            "  [\(.category)] \(.challenge) (Difficulty: \(.difficulty))"' \
            "$FEARS_DB_FILE"
        echo
    fi
}

#=============================================================================
# Challenge Selection
#=============================================================================

pick_random_challenge() {
    local max_difficulty=${1:-5}
    local category=${2:-""}

    init_fears_db

    local filter="."
    if [[ -n "$category" ]]; then
        filter="select(.category == \"$category\")"
    fi

    # Get challenges within difficulty range
    local challenges=$(jq -r --argjson max "$max_difficulty" \
        "[.fears[] | $filter | select(.difficulty <= \$max) | .challenges[]] | unique | .[]" \
        "$FEARS_DB_FILE")

    # Pick random challenge
    local count=$(echo "$challenges" | wc -l)
    if [[ $count -eq 0 ]]; then
        log_error "No challenges found"
        return 1
    fi

    local random_index=$(( RANDOM % count ))
    echo "$challenges" | sed -n "$((random_index + 1))p"
}

pick_progressive_challenge() {
    # Pick challenge based on current progress
    local completed_count=$(jq '.completed | length' "$CHALLENGES_LOG_FILE")

    # Calculate current difficulty level (1-10)
    local current_difficulty=$(( (completed_count / 3) + 1 ))
    [[ $current_difficulty -gt 10 ]] && current_difficulty=10

    log_debug "Current difficulty level: $current_difficulty"

    pick_random_challenge "$current_difficulty"
}

#=============================================================================
# Challenge Scheduling
#=============================================================================

schedule_challenge() {
    local challenge=$1
    local due_date=${2:-$(date -d "+7 days" +%Y-%m-%d 2>/dev/null || date -v+7d +%Y-%m-%d 2>/dev/null)}

    init_fears_db

    local tmp_file=$(mktemp)

    jq --arg challenge "$challenge" \
       --arg due_date "$due_date" \
       --arg scheduled "$(date -Iseconds)" \
       '.scheduled += [{
           challenge: $challenge,
           due_date: $due_date,
           scheduled_at: $scheduled,
           completed: false,
           evidence: null
       }]' \
       "$SCHEDULE_FILE" > "$tmp_file"

    mv "$tmp_file" "$SCHEDULE_FILE"

    log_success "Challenge scheduled for $due_date"
}

#=============================================================================
# The Algorithm - Pick and Schedule
#=============================================================================

the_algorithm() {
    local difficulty=${1:-"progressive"}

    echo -e "${BOLD}${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║                                                            ║${NC}"
    echo -e "${BOLD}${RED}║          🎲 THE ALGORITHM HAS DECIDED 🎲                ║${NC}"
    echo -e "${BOLD}${RED}║                                                            ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"

    # Pick challenge
    local challenge
    if [[ "$difficulty" == "progressive" ]]; then
        challenge=$(pick_progressive_challenge)
    else
        challenge=$(pick_random_challenge "$difficulty")
    fi

    if [[ -z "$challenge" ]]; then
        log_error "Failed to pick challenge"
        return 1
    fi

    echo -e "${BOLD}Your challenge:${NC}\n"
    echo -e "${YELLOW}${BOLD}    $challenge${NC}\n"

    # Schedule it
    local due_date=$(date -d "+${CHALLENGE_FREQUENCY} days" +%Y-%m-%d 2>/dev/null || date -v+${CHALLENGE_FREQUENCY}d +%Y-%m-%d 2>/dev/null)

    schedule_challenge "$challenge" "$due_date"

    echo -e "${BOLD}Due date:${NC} $due_date"
    echo

    # Show motivation
    if [[ $ENABLE_MOTIVATIONAL_QUOTES -eq 1 ]]; then
        show_motivation
    fi

    echo
    echo -e "${RED}${BOLD}No excuses. The algorithm has spoken.${NC}"
    echo

    # Set up reminder
    if [[ $ACCOUNTABILITY_MODE -eq 1 ]]; then
        setup_reminder "$challenge" "$due_date"
    fi
}

#=============================================================================
# Completion & Evidence
#=============================================================================

complete_challenge() {
    local challenge_id=${1:-""}

    echo -e "\n${BOLD}Challenge Completion${NC}\n"

    # Get current scheduled challenge if no ID provided
    if [[ -z "$challenge_id" ]]; then
        local current=$(jq -r '.scheduled[] | select(.completed == false) | .challenge' "$SCHEDULE_FILE" | head -1)

        if [[ -z "$current" ]]; then
            log_error "No active challenges found"
            return 1
        fi

        echo "Current challenge: $current"
        echo
        challenge_id="$current"
    fi

    # Ask for evidence
    if [[ $EVIDENCE_REQUIRED -eq 1 ]]; then
        echo "Provide evidence (photo path, description, URL):"
        read -r evidence

        if [[ -z "$evidence" ]]; then
            log_warn "No evidence provided. Are you sure you completed it?"
            read -p "Complete anyway? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                log_info "Challenge not marked complete"
                return 0
            fi
        fi
    else
        evidence="No evidence required"
    fi

    # Mark complete
    local tmp_file=$(mktemp)

    jq --arg challenge "$challenge_id" \
       --arg evidence "$evidence" \
       --arg completed_at "$(date -Iseconds)" \
       '(.scheduled[] | select(.challenge == $challenge)) |= (
           .completed = true |
           .evidence = $evidence |
           .completed_at = $completed_at
       )' \
       "$SCHEDULE_FILE" > "$tmp_file"

    mv "$tmp_file" "$SCHEDULE_FILE"

    # Add to completed log
    record_completion "$challenge_id" "$evidence"

    echo
    echo -e "${GREEN}${BOLD}💪 CHALLENGE COMPLETED!${NC}\n"

    show_celebration

    # Stats
    show_stats

    # Schedule next challenge?
    echo
    read -p "Schedule next challenge now? (yes/no): " schedule_next
    if [[ "$schedule_next" == "yes" ]]; then
        the_algorithm
    fi
}

record_completion() {
    local challenge=$1
    local evidence=$2

    local tmp_file=$(mktemp)

    jq --arg challenge "$challenge" \
       --arg evidence "$evidence" \
       --arg timestamp "$(date -Iseconds)" \
       '.completed += [{
           challenge: $challenge,
           evidence: $evidence,
           completed_at: $timestamp
       }]' \
       "$CHALLENGES_LOG_FILE" > "$tmp_file"

    mv "$tmp_file" "$CHALLENGES_LOG_FILE"
}

#=============================================================================
# Reminders & Accountability
#=============================================================================

setup_reminder() {
    local challenge=$1
    local due_date=$2

    log_info "Setting up reminders..."

    # Calculate days until due
    local due_epoch=$(date -d "$due_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$due_date" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( (due_epoch - now_epoch) / 86400 ))

    if [[ $days_left -le 0 ]]; then
        send_alert "⚠️ CHALLENGE DUE NOW!\n$challenge"
    elif [[ $days_left -le 2 ]]; then
        send_alert "⏰ Challenge due in $days_left days!\n$challenge"
    fi

    # Could set up cron job for daily reminders here
    echo "  • Immediate notification sent"
    echo "  • Add to calendar manually or integrate with calendar app"
}

check_overdue() {
    local overdue=$(jq -r --arg today "$(date +%Y-%m-%d)" \
        '.scheduled[] |
         select(.completed == false and .due_date < $today) |
         .challenge' \
        "$SCHEDULE_FILE")

    if [[ -n "$overdue" ]]; then
        echo -e "\n${RED}${BOLD}⚠️  OVERDUE CHALLENGES:${NC}\n"

        while IFS= read -r challenge; do
            echo -e "${RED}  • $challenge${NC}"
        done <<< "$overdue"

        echo
        echo -e "${RED}${BOLD}No excuses. Do it today.${NC}\n"

        return 1
    fi

    return 0
}

#=============================================================================
# Motivation & Celebration
#=============================================================================

show_motivation() {
    local quotes=(
        "\"Do the thing you fear, and the death of fear is certain.\" - Ralph Waldo Emerson"
        "\"Everything you want is on the other side of fear.\" - Jack Canfield"
        "\"Fear is temporary. Regret is forever.\""
        "\"The cave you fear to enter holds the treasure you seek.\" - Joseph Campbell"
        "\"Courage is not the absence of fear, but triumph over it.\""
        "\"What would you do if you weren't afraid?\""
        "\"Comfort zones are where dreams go to die.\""
        "\"The only way out is through.\""
    )

    local harsh_quotes=(
        "\"Stop being a coward. It's embarrassing.\""
        "\"Everyone else is doing it. You're just afraid.\""
        "\"Your comfort zone is a prison.\""
        "\"The algorithm doesn't care about your feelings.\""
        "\"Do it or admit you're choosing fear.\""
        "\"You'll regret not doing this more than doing it.\""
    )

    local random_index=$(( RANDOM % ${#quotes[@]} ))

    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ $ENABLE_HARSH_MODE -eq 1 ]]; then
        local harsh_index=$(( RANDOM % ${#harsh_quotes[@]} ))
        echo -e "${BOLD}${RED}${harsh_quotes[$harsh_index]}${NC}"
    else
        echo -e "${BOLD}${CYAN}${quotes[$random_index]}${NC}"
    fi

    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_celebration() {
    cat <<EOF
${GREEN}
    ██╗    ██╗███████╗██╗     ██╗         ██████╗  ██████╗ ███╗   ██╗███████╗██╗
    ██║    ██║██╔════╝██║     ██║         ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║
    ██║ █╗ ██║█████╗  ██║     ██║         ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║
    ██║███╗██║██╔══╝  ██║     ██║         ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝
    ╚███╔███╔╝███████╗███████╗███████╗    ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗
     ╚══╝╚══╝ ╚══════╝╚══════╝╚══════╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝
${NC}
EOF

    echo "You faced your fear. That's what matters."
    echo
}

#=============================================================================
# Statistics & Progress
#=============================================================================

show_stats() {
    if [[ ! -f "$CHALLENGES_LOG_FILE" ]]; then
        log_info "No challenges completed yet"
        return 0
    fi

    echo -e "\n${BOLD}📊 Your Progress${NC}\n"

    local total=$(jq '.completed | length' "$CHALLENGES_LOG_FILE")
    local this_month=$(jq --arg month "$(date +%Y-%m)" \
        '[.completed[] | select(.completed_at | startswith($month))] | length' \
        "$CHALLENGES_LOG_FILE")

    echo "Total challenges completed: ${BOLD}$total${NC}"
    echo "This month: ${BOLD}$this_month${NC}"
    echo

    if [[ $total -gt 0 ]]; then
        echo -e "${BOLD}Recent completions:${NC}"
        jq -r '.completed[-5:] | .[] |
            "  • \(.challenge)\n    Completed: \(.completed_at)"' \
            "$CHALLENGES_LOG_FILE"
        echo
    fi

    # Show current difficulty level
    local current_difficulty=$(( (total / 3) + 1 ))
    [[ $current_difficulty -gt 10 ]] && current_difficulty=10

    echo -e "${BOLD}Current difficulty level:${NC} $current_difficulty/10"
    echo
}

show_upcoming() {
    echo -e "\n${BOLD}📅 Upcoming Challenges${NC}\n"

    local upcoming=$(jq -r '.scheduled[] | select(.completed == false) |
        "\(.due_date) - \(.challenge)"' "$SCHEDULE_FILE" | sort)

    if [[ -z "$upcoming" ]]; then
        echo "No challenges scheduled. Run: $0 pick"
        echo
        return 0
    fi

    echo "$upcoming" | while IFS= read -r line; do
        echo "  • $line"
    done

    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Face your fears systematically

COMMANDS:
    pick [DIFFICULTY]            Pick random challenge (1-10 or 'progressive')
    list                         List all available challenges
    add CAT DIFF "CHALLENGE"     Add custom challenge
    complete [CHALLENGE]         Mark challenge as complete
    upcoming                     Show scheduled challenges
    overdue                      Check for overdue challenges
    stats                        Show completion statistics

OPTIONS:
    --harsh                      Enable harsh motivation mode
    --easy                       Pick easy challenges only
    --extreme                    Pick extreme challenges

EXAMPLES:
    # Let the algorithm decide
    $0 pick

    # Pick easy challenge
    $0 pick 3

    # Pick extreme challenge
    $0 pick --extreme

    # List all challenges
    $0 list

    # Add custom challenge
    $0 add social 5 "Give a TED talk"

    # Mark challenge complete
    $0 complete

    # Check progress
    $0 stats

PHILOSOPHY:
    • Fear is a compass pointing to growth
    • Discomfort is where you expand
    • The algorithm removes choice paralysis
    • Proof > Promises
    • Progressive difficulty prevents overwhelming

ACCOUNTABILITY:
    • Evidence required by default
    • Automatic reminders
    • Public commitment (optional)
    • Track your progress
    • No skipping - face it or reschedule

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --harsh)
                ENABLE_HARSH_MODE=1
                shift
                ;;
            --easy)
                shift
                the_algorithm 3
                exit 0
                ;;
            --extreme)
                shift
                the_algorithm 10
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            pick|list|add|complete|upcoming|overdue|stats)
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

    # Initialize
    init_fears_db

    # Check for overdue challenges
    if [[ "$command" != "overdue" ]] && [[ "$command" != "stats" ]]; then
        check_overdue || true
    fi

    # Execute command
    case $command in
        pick)
            the_algorithm "${1:-progressive}"
            ;;
        list)
            list_fears
            ;;
        add)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: add CATEGORY DIFFICULTY \"CHALLENGE\""
                exit 1
            fi
            add_custom_fear "$1" "$2" "$3"
            ;;
        complete)
            complete_challenge "$@"
            ;;
        upcoming)
            show_upcoming
            ;;
        overdue)
            check_overdue
            ;;
        stats)
            show_stats
            ;;
        "")
            # No command, show status and prompt
            check_overdue || true
            show_upcoming
            echo
            echo -e "${BOLD}Ready to face a fear?${NC}"
            echo "  Run: $0 pick"
            echo
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
