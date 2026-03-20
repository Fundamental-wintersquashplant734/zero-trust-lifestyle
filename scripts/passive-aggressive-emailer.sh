#!/bin/bash
#=============================================================================
# passive-aggressive-emailer.sh
# Sentiment analysis on outgoing emails
# Delays angry/passive-aggressive emails to prevent career damage
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

QUARANTINE_DIR="$DATA_DIR/email-quarantine"
DELAY_MINUTES=${ANGER_DELAY_MINUTES:-60}
MAX_SCORE=${MAX_ANGER_SCORE:-75}  # 0-100 scale
FORCE_MODE=${FORCE_MODE:-0}

mkdir -p "$QUARANTINE_DIR"

#=============================================================================
# Sentiment Analysis Patterns
#=============================================================================

# Passive-aggressive phrases
PASSIVE_AGGRESSIVE_PATTERNS=(
    "per my last email"
    "as I mentioned before"
    "as previously stated"
    "just circling back"
    "gentle reminder"
    "friendly reminder"
    "not sure if you saw"
    "did you get a chance"
    "when you get a chance"
    "thanks in advance"
    "at your earliest convenience"
    "going forward"
    "moving forward"
    "with all due respect"
    "I'm just wondering"
    "I hate to bother you"
    "sorry to bother you again"
    "just following up"
    "bumping this up"
    "circling back"
)

# Aggressive indicators
AGGRESSIVE_PATTERNS=(
    "THIS IS UNACCEPTABLE"
    "ABSOLUTELY"
    "NEVER"
    "ALWAYS"
    "obviously"
    "clearly"
    "seriously\?"
    "are you kidding"
    "this is ridiculous"
    "what were you thinking"
    "I can't believe"
    "disappointed"
    "frustrated"
    "unprofessional"
    "incompetent"
)

# Swear words (mild detection)
SWEAR_PATTERNS=(
    "fuck"
    "shit"
    "damn"
    "hell"
    "crap"
    "bullshit"
    "ass"
    "wtf"
)

# Red flags for late-night emails
EXECUTIVE_KEYWORDS=(
    "CEO"
    "CTO"
    "VP"
    "president"
    "director"
    "board"
    "executive"
)

#=============================================================================
# Analysis Functions
#=============================================================================

analyze_caps_ratio() {
    local text=$1
    local total_chars=$(echo "$text" | tr -d '\n ' | wc -c)
    local caps_chars=$(echo "$text" | grep -o '[A-Z]' | wc -l)

    if [[ $total_chars -gt 0 ]]; then
        echo $(( (caps_chars * 100) / total_chars ))
    else
        echo 0
    fi
}

count_exclamation_marks() {
    local text=$1
    echo "$text" | grep -o '!' | wc -l
}

detect_passive_aggressive() {
    local text=$1
    local count=0

    for pattern in "${PASSIVE_AGGRESSIVE_PATTERNS[@]}"; do
        if echo "$text" | grep -qi "$pattern"; then
            ((count++))
        fi
    done

    echo $count
}

detect_aggressive() {
    local text=$1
    local count=0

    for pattern in "${AGGRESSIVE_PATTERNS[@]}"; do
        if echo "$text" | grep -qiE "$pattern"; then
            ((count++))
        fi
    done

    echo $count
}

detect_swearing() {
    local text=$1
    local count=0

    for pattern in "${SWEAR_PATTERNS[@]}"; do
        if echo "$text" | grep -qiE "\\b$pattern\\b"; then
            ((count++))
        fi
    done

    echo $count
}

is_late_night() {
    local hour=$(date +%H)
    [[ $hour -ge 22 || $hour -le 5 ]]
}

is_to_executive() {
    local recipients=$1

    for keyword in "${EXECUTIVE_KEYWORDS[@]}"; do
        if echo "$recipients" | grep -qi "$keyword"; then
            return 0
        fi
    done

    return 1
}

calculate_anger_score() {
    local text=$1
    local recipients=$2

    local score=0

    # CAPS analysis (0-25 points)
    local caps_ratio=$(analyze_caps_ratio "$text")
    if [[ $caps_ratio -gt 20 ]]; then
        score=$((score + 25))
    elif [[ $caps_ratio -gt 10 ]]; then
        score=$((score + 15))
    elif [[ $caps_ratio -gt 5 ]]; then
        score=$((score + 5))
    fi

    # Exclamation marks (0-15 points)
    local exclamations=$(count_exclamation_marks "$text")
    if [[ $exclamations -gt 5 ]]; then
        score=$((score + 15))
    elif [[ $exclamations -gt 2 ]]; then
        score=$((score + 8))
    elif [[ $exclamations -gt 0 ]]; then
        score=$((score + 3))
    fi

    # Passive-aggressive (0-20 points)
    local pa_count=$(detect_passive_aggressive "$text")
    score=$((score + pa_count * 5))

    # Aggressive (0-25 points)
    local aggressive_count=$(detect_aggressive "$text")
    score=$((score + aggressive_count * 8))

    # Swearing (0-20 points)
    local swear_count=$(detect_swearing "$text")
    score=$((score + swear_count * 10))

    # Late night email (+10 bonus points)
    if is_late_night; then
        score=$((score + 10))
    fi

    # To executive (+15 bonus points)
    if is_to_executive "$recipients"; then
        score=$((score + 15))
    fi

    # Cap at 100
    [[ $score -gt 100 ]] && score=100

    echo $score
}

generate_feedback() {
    local score=$1
    local text=$2

    local issues=()

    # Identify specific issues
    local caps_ratio=$(analyze_caps_ratio "$text")
    if [[ $caps_ratio -gt 10 ]]; then
        issues+=("🔠 ${caps_ratio}% ALL CAPS - looks like you're shouting")
    fi

    local pa_count=$(detect_passive_aggressive "$text")
    if [[ $pa_count -gt 0 ]]; then
        issues+=("😬 $pa_count passive-aggressive phrases detected")
    fi

    local aggressive_count=$(detect_aggressive "$text")
    if [[ $aggressive_count -gt 0 ]]; then
        issues+=("😠 $aggressive_count aggressive phrases found")
    fi

    local swear_count=$(detect_swearing "$text")
    if [[ $swear_count -gt 0 ]]; then
        issues+=("🤬 $swear_count profanity instances")
    fi

    if is_late_night; then
        issues+=("🌙 It's $(date +%H:%M) - late night emails are rarely a good idea")
    fi

    # Print feedback
    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '%s\n' "${issues[@]}"
    fi
}

#=============================================================================
# Email Handling
#=============================================================================

quarantine_email() {
    local email_file=$1
    local score=$2
    local release_time=$3

    local quarantine_id=$(date +%s)_$(echo "$email_file" | md5sum | cut -d' ' -f1 | cut -c1-8)
    local quarantine_file="$QUARANTINE_DIR/${quarantine_id}.eml"

    # Copy email to quarantine
    cp "$email_file" "$quarantine_file"

    # Create metadata
    cat > "${quarantine_file}.meta" <<EOF
{
    "quarantined_at": "$(date -Iseconds)",
    "release_at": "$(date -Iseconds -d "+${DELAY_MINUTES} minutes" 2>/dev/null || date -Iseconds -v+${DELAY_MINUTES}M)",
    "anger_score": $score,
    "original_file": "$email_file"
}
EOF

    echo "$quarantine_file"
}

release_email() {
    local quarantine_file=$1

    if [[ ! -f "$quarantine_file" ]]; then
        log_error "Quarantine file not found: $quarantine_file"
        return 1
    fi

    log_info "Releasing email from quarantine: $quarantine_file"

    # Read original destination
    local original_file=$(jq -r '.original_file' "${quarantine_file}.meta")

    # Actually send the email (integration with mail client)
    # This would hook into your mail client (sendmail, msmtp, etc.)
    if command -v sendmail &> /dev/null; then
        sendmail -t < "$quarantine_file"
        log_success "Email sent"
    else
        log_warn "No sendmail found - email remains in quarantine"
        cat "$quarantine_file"
    fi

    # Clean up
    rm -f "$quarantine_file" "${quarantine_file}.meta"
}

check_quarantine() {
    local now=$(date +%s)

    for meta_file in "$QUARANTINE_DIR"/*.meta; do
        [[ ! -f "$meta_file" ]] && continue

        local release_str=$(jq -r '.release_at' "$meta_file")
        local release_time=$(date -d "$release_str" +%s 2>/dev/null || echo 0)

        if [[ $now -ge $release_time ]]; then
            local email_file="${meta_file%.meta}"
            log_info "Release time reached for: $email_file"

            # Show email and ask for confirmation
            echo -e "\n${YELLOW}=== QUARANTINED EMAIL READY FOR REVIEW ===${NC}\n"
            cat "$email_file"
            echo -e "\n${YELLOW}=========================================${NC}\n"

            if ask_yes_no "Send this email now?"; then
                release_email "$email_file"
            else
                log_warn "Email cancelled by user"
                rm -f "$email_file" "$meta_file"
            fi
        fi
    done
}

#=============================================================================
# Mail Client Integration
#=============================================================================

analyze_email() {
    local email_file=$1

    # Parse email headers and body
    local to=$(grep -i "^To:" "$email_file" | cut -d: -f2- | tr -d '\n\r')
    local subject=$(grep -i "^Subject:" "$email_file" | cut -d: -f2- | tr -d '\n\r')
    local body=$(sed -n '/^$/,$p' "$email_file")

    log_info "Analyzing email to: $to"
    log_debug "Subject: $subject"

    # Calculate anger score
    local full_text="$subject $body"
    local score=$(calculate_anger_score "$full_text" "$to")

    # Generate feedback
    local feedback=$(generate_feedback "$score" "$full_text")

    # Display results
    echo -e "\n${BOLD}📧 Email Sentiment Analysis${NC}"
    echo -e "${BOLD}To:${NC} $to"
    echo -e "${BOLD}Subject:${NC} $subject"
    echo -e "${BOLD}Anger Score:${NC} $score/100"
    echo

    if [[ -n "$feedback" ]]; then
        echo -e "${RED}⚠️  Issues Detected:${NC}"
        echo "$feedback"
        echo
    fi

    # Decision logic
    if [[ $FORCE_MODE -eq 1 ]]; then
        log_warn "FORCE MODE enabled - sending anyway"
        return 0
    fi

    if [[ $score -ge $MAX_SCORE ]]; then
        echo -e "${RED}🚨 ANGER THRESHOLD EXCEEDED ($score >= $MAX_SCORE)${NC}"
        echo -e "${YELLOW}📦 Email will be quarantined for $DELAY_MINUTES minutes${NC}"
        echo

        local quarantine_file=$(quarantine_email "$email_file" "$score" "$DELAY_MINUTES")

        log_warn "Email quarantined: $quarantine_file"
        notify "Email Quarantined" "Anger score: $score - Delayed $DELAY_MINUTES min" "critical"

        return 1
    elif [[ $score -ge $((MAX_SCORE - 20)) ]]; then
        echo -e "${YELLOW}⚠️  High anger score - are you sure?${NC}"

        if ! ask_yes_no "Send this email anyway?" "n"; then
            log_info "User cancelled email send"
            return 1
        fi
    fi

    return 0
}

#=============================================================================
# Daemon Mode
#=============================================================================

run_daemon() {
    log_info "Starting email quarantine daemon"

    while true; do
        check_quarantine
        sleep 60  # Check every minute
    done
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [EMAIL_FILE]

Analyze email sentiment and prevent angry emails

OPTIONS:
    -f, --force          Force send even if angry (bypass quarantine)
    -d, --daemon         Run as daemon to check quarantine
    -c, --check          Check quarantine for releasable emails
    -s, --score FILE     Just show anger score (don't send)
    -h, --help           Show this help

EXAMPLES:
    # Analyze an email (hook into your mail client)
    $0 /tmp/outgoing_email.eml

    # Show anger score only
    $0 --score email.eml

    # Run quarantine checker daemon
    $0 --daemon &

    # Check and release quarantined emails
    $0 --check

INTEGRATION:
    # With msmtp (add to ~/.msmtprc)
    # sendmail_path = /path/to/passive-aggressive-emailer.sh

    # With mutt (add to ~/.muttrc)
    # set sendmail = "/path/to/passive-aggressive-emailer.sh"

EOF
}

main() {
    local daemon_mode=0
    local check_mode=0
    local score_only=0
    local email_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                FORCE_MODE=1
                shift
                ;;
            -d|--daemon)
                daemon_mode=1
                shift
                ;;
            -c|--check)
                check_mode=1
                shift
                ;;
            -s|--score)
                score_only=1
                email_file=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                email_file=$1
                shift
                ;;
        esac
    done

    # Check dependencies
    check_commands jq

    # Daemon mode
    if [[ $daemon_mode -eq 1 ]]; then
        run_daemon
        exit 0
    fi

    # Check quarantine mode
    if [[ $check_mode -eq 1 ]]; then
        check_quarantine
        exit 0
    fi

    # Analyze email
    if [[ -z "$email_file" ]]; then
        log_error "No email file provided"
        show_help
        exit 1
    fi

    if [[ ! -f "$email_file" ]]; then
        log_error "Email file not found: $email_file"
        exit 1
    fi

    if analyze_email "$email_file"; then
        log_success "Email passed sentiment analysis"
        exit 0
    else
        log_error "Email failed sentiment analysis"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
