#!/bin/bash
#=============================================================================
# data-breach-stalker.sh
# Track your identities in data breaches and get instant alerts
# "Your password was in 47 breaches. Time to change it."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

IDENTITY_DB_FILE="$DATA_DIR/identities.enc"
BREACH_CACHE_FILE="$DATA_DIR/breach_cache.json"
BREACH_HISTORY_FILE="$DATA_DIR/breach_history.json"
LAST_CHECK_FILE="$DATA_DIR/last_breach_check.txt"

# Check settings
CHECK_INTERVAL=3600  # 1 hour
AUTO_CHECK=0
ALERT_ON_NEW_BREACH=1

# Data sources
USE_HIBP=1  # Have I Been Pwned
USE_DEHASHED=0  # DeHashed API (paid)
USE_INTELX=0  # Intelligence X (paid)

# API Keys
HIBP_API_KEY=${HIBP_API_KEY:-""}
DEHASHED_USERNAME=${DEHASHED_USERNAME:-""}
DEHASHED_API_KEY=${DEHASHED_API_KEY:-""}
INTELX_API_KEY=${INTELX_API_KEY:-""}

# Privacy settings
ENCRYPTED_STORAGE=1
HASH_QUERIES=1  # Use k-anonymity for HIBP

#=============================================================================
# Identity Management (Encrypted)
#=============================================================================

init_identity_db() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$IDENTITY_DB_FILE" ]]; then
        local empty_db='{"identities": []}'
        encrypt_data "$empty_db" "$IDENTITY_DB_FILE"
        log_success "Initialized encrypted identity database"
    fi
}

get_identities() {
    init_identity_db
    decrypt_data "$IDENTITY_DB_FILE" 2>/dev/null || echo '{"identities": []}'
}

add_identity() {
    local type=$1  # email, username, phone, domain
    local value=$2
    local description=${3:-""}

    init_identity_db

    local identities=$(get_identities)

    # Check if already exists
    if echo "$identities" | jq -e --arg val "$value" '.identities[] | select(.value == $val)' &>/dev/null; then
        log_warn "Identity already tracked: $value"
        return 0
    fi

    # Add identity
    identities=$(echo "$identities" | jq --arg type "$type" \
                                          --arg value "$value" \
                                          --arg desc "$description" \
                                          --arg added "$(date -Iseconds)" \
        '.identities += [{
            type: $type,
            value: $value,
            description: $desc,
            added: $added,
            last_checked: null,
            breach_count: 0
        }]')

    # Save encrypted
    encrypt_data "$identities" "$IDENTITY_DB_FILE"

    log_success "Added identity: $value ($type)"
}

remove_identity() {
    local value=$1

    init_identity_db

    local identities=$(get_identities)

    identities=$(echo "$identities" | jq --arg val "$value" \
        '.identities = [.identities[] | select(.value != $val)]')

    encrypt_data "$identities" "$IDENTITY_DB_FILE"

    log_success "Removed identity: $value"
}

list_identities() {
    init_identity_db

    echo -e "\n${BOLD}🔒 Tracked Identities${NC}\n"

    get_identities | jq -r '.identities[] |
        "\(.type): \(.value) (\(.breach_count) breaches)"'

    echo
}

update_identity_breach_count() {
    local value=$1
    local count=$2

    init_identity_db

    local identities=$(get_identities)

    identities=$(echo "$identities" | jq --arg val "$value" \
                                          --argjson count "$count" \
                                          --arg checked "$(date -Iseconds)" \
        '(.identities[] | select(.value == $val)) |= (
            .breach_count = $count |
            .last_checked = $checked
        )')

    encrypt_data "$identities" "$IDENTITY_DB_FILE"
}

#=============================================================================
# Have I Been Pwned API
#=============================================================================

check_hibp() {
    local email=$1

    if [[ $USE_HIBP -ne 1 ]]; then
        return 0
    fi

    log_debug "Checking Have I Been Pwned for: $email"

    # Rate limiting (HIBP requires 1.5s between requests)
    sleep 2

    local -a curl_args=(-s)
    [[ -n "$HIBP_API_KEY" ]] && curl_args+=(-H "hibp-api-key: $HIBP_API_KEY")

    local response=$(curl "${curl_args[@]}" \
        -H "User-Agent: zero-trust-lifestyle" \
        "https://haveibeenpwned.com/api/v3/breachedaccount/$email?truncateResponse=false" 2>/dev/null || echo "[]")

    # Check for errors
    if echo "$response" | grep -q "Unauthorized"; then
        log_error "HIBP API key required for this query"
        return 1
    fi

    echo "$response"
}

check_hibp_password() {
    local password=$1

    if [[ $USE_HIBP -ne 1 ]]; then
        return 0
    fi

    log_debug "Checking if password has been pwned..."

    # Use k-anonymity (only send first 5 chars of SHA1 hash)
    local hash=$(echo -n "$password" | shasum -a 1 | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    local prefix=${hash:0:5}
    local suffix=${hash:5}

    local response=$(curl -s "https://api.pwnedpasswords.com/range/$prefix" 2>/dev/null)

    # Check if our hash suffix is in the response
    local count=$(echo "$response" | grep -i "^$suffix" | cut -d':' -f2 || echo "0")

    if [[ $count -gt 0 ]]; then
        log_error "Password found in $count breaches! Change it immediately!"
        return 1
    else
        log_success "Password not found in known breaches"
        return 0
    fi
}

#=============================================================================
# DeHashed API
#=============================================================================

check_dehashed() {
    local query=$1
    local query_type=${2:-"email"}

    if [[ $USE_DEHASHED -ne 1 ]]; then
        return 0
    fi

    if [[ -z "$DEHASHED_USERNAME" ]] || [[ -z "$DEHASHED_API_KEY" ]]; then
        log_warn "DeHashed credentials not configured"
        return 0
    fi

    log_debug "Checking DeHashed for: $query"

    local response=$(curl -s \
        -u "$DEHASHED_USERNAME:$DEHASHED_API_KEY" \
        "https://api.dehashed.com/search?query=$query_type:$query" 2>/dev/null || echo '{"entries":[]}')

    echo "$response"
}

#=============================================================================
# Breach Analysis
#=============================================================================

analyze_breaches() {
    local email=$1
    local breaches=$2

    local breach_count=$(echo "$breaches" | jq 'length' 2>/dev/null || echo "0")

    if [[ $breach_count -eq 0 ]]; then
        log_success "No breaches found for: $email"
        return 0
    fi

    echo -e "\n${RED}${BOLD}⚠️  BREACHES FOUND: $breach_count${NC}\n"

    # Show breach details
    echo "$breaches" | jq -r '.[] |
        "╔═══════════════════════════════════════════════════════════╗\n" +
        "  Breach: \(.Name)\n" +
        "  Date: \(.BreachDate)\n" +
        "  Accounts: \(.PwnCount) affected\n" +
        "  Data leaked: \(.DataClasses | join(", "))\n" +
        "  Description: \(.Description)\n" +
        "╚═══════════════════════════════════════════════════════════╝\n"'

    # Analyze severity
    local has_passwords=$(echo "$breaches" | jq '[.[] | select(.DataClasses[] | contains("Passwords"))] | length')
    local has_financial=$(echo "$breaches" | jq '[.[] | select(.DataClasses[] | contains("Credit") or contains("Bank"))] | length')
    local has_sensitive=$(echo "$breaches" | jq '[.[] | select(.DataClasses[] | contains("SSN") or contains("Health"))] | length')

    echo -e "${BOLD}Severity Analysis:${NC}"

    if [[ $has_passwords -gt 0 ]]; then
        echo -e "${RED}  🔴 CRITICAL: Passwords exposed in $has_passwords breach(es)${NC}"
        echo "     → Change password immediately!"
        echo "     → Enable 2FA if not already enabled"
    fi

    if [[ $has_financial -gt 0 ]]; then
        echo -e "${RED}  🔴 CRITICAL: Financial data exposed in $has_financial breach(es)${NC}"
        echo "     → Monitor bank accounts"
        echo "     → Consider credit monitoring service"
    fi

    if [[ $has_sensitive -gt 0 ]]; then
        echo -e "${RED}  🔴 CRITICAL: Sensitive personal data exposed${NC}"
        echo "     → Consider identity theft protection"
        echo "     → Monitor credit reports"
    fi

    echo

    # Alert
    if [[ $ALERT_ON_NEW_BREACH -eq 1 ]]; then
        send_alert "🚨 Data Breach Alert!\n$email found in $breach_count breaches!"
    fi

    return 1
}

#=============================================================================
# Automated Checking
#=============================================================================

check_all_identities() {
    log_info "Checking all tracked identities..."

    local identities=$(get_identities)
    local total=$(echo "$identities" | jq '.identities | length')

    log_info "Checking $total identities..."

    local checked=0
    local found_breaches=0

    while IFS= read -r identity; do
        local type=$(echo "$identity" | jq -r '.type')
        local value=$(echo "$identity" | jq -r '.value')

        log_info "Checking: $value ($type)"

        case $type in
            email)
                local breaches=$(check_hibp "$value")

                if [[ "$breaches" != "[]" ]] && [[ -n "$breaches" ]]; then
                    analyze_breaches "$value" "$breaches"
                    ((found_breaches++))

                    # Update count
                    local count=$(echo "$breaches" | jq 'length')
                    update_identity_breach_count "$value" "$count"

                    # Record in history
                    record_breach_check "$value" "$count" "$breaches"
                else
                    log_success "Clean: $value"
                    update_identity_breach_count "$value" 0
                fi
                ;;
            username)
                # Could check DeHashed or other sources
                log_info "Username checking requires DeHashed subscription"
                ;;
            *)
                log_warn "Unknown identity type: $type"
                ;;
        esac

        ((checked++))

        # Rate limiting
        sleep 2
    done < <(echo "$identities" | jq -c '.identities[]')

    # Update last check time
    date -Iseconds > "$LAST_CHECK_FILE"

    log_info "Check complete: $checked checked, $found_breaches with breaches"
}

check_single_identity() {
    local value=$1

    local identities=$(get_identities)

    local identity=$(echo "$identities" | jq --arg val "$value" '.identities[] | select(.value == $val)')

    if [[ -z "$identity" ]]; then
        log_error "Identity not tracked: $value"
        log_info "Add it first with: $0 add email $value"
        return 1
    fi

    local type=$(echo "$identity" | jq -r '.type')

    case $type in
        email)
            local breaches=$(check_hibp "$value")
            analyze_breaches "$value" "$breaches"

            local count=$(echo "$breaches" | jq 'length' 2>/dev/null || echo "0")
            update_identity_breach_count "$value" "$count"
            record_breach_check "$value" "$count" "$breaches"
            ;;
        *)
            log_error "Checking not implemented for type: $type"
            ;;
    esac
}

#=============================================================================
# History & Reports
#=============================================================================

record_breach_check() {
    local identity=$1
    local breach_count=$2
    local breaches=$3

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$BREACH_HISTORY_FILE" ]]; then
        echo '{"checks": []}' > "$BREACH_HISTORY_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --arg identity "$identity" \
       --argjson count "$breach_count" \
       --arg timestamp "$(date -Iseconds)" \
       --argjson breaches "$breaches" \
       '.checks += [{
           timestamp: $timestamp,
           identity: $identity,
           breach_count: $count,
           breaches: $breaches
       }]' \
       "$BREACH_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$BREACH_HISTORY_FILE"

    # Keep only last 1000 checks
    jq '.checks = .checks[-1000:]' "$BREACH_HISTORY_FILE" > "$tmp_file"
    mv "$tmp_file" "$BREACH_HISTORY_FILE"
}

show_breach_report() {
    echo -e "\n${BOLD}📊 Breach Report${NC}\n"

    if [[ ! -f "$BREACH_HISTORY_FILE" ]]; then
        log_info "No breach history available"
        return 0
    fi

    local total_checks=$(jq '.checks | length' "$BREACH_HISTORY_FILE")
    local last_check=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "Never")

    echo "Total checks performed: $total_checks"
    echo "Last check: $last_check"
    echo

    # Show per-identity summary
    echo -e "${BOLD}Identity Summary:${NC}"

    get_identities | jq -r '.identities[] |
        "\(.value): \(.breach_count) breaches (last checked: \(.last_checked // "never"))"'

    echo

    # Show recent new breaches
    echo -e "${BOLD}Recent Alerts:${NC}"

    jq -r '.checks[-10:] | .[] |
        select(.breach_count > 0) |
        "[\(.timestamp)] \(.identity) - \(.breach_count) breaches"' \
        "$BREACH_HISTORY_FILE" 2>/dev/null || echo "No recent breaches"

    echo
}

export_breach_report() {
    local output_file=${1:-"breach_report_$(date +%Y%m%d).json"}

    log_info "Exporting breach report to $output_file..."

    if [[ ! -f "$BREACH_HISTORY_FILE" ]]; then
        log_error "No breach history to export"
        return 1
    fi

    cp "$BREACH_HISTORY_FILE" "$output_file"

    log_success "Exported to: $output_file"
}

#=============================================================================
# Password Checker
#=============================================================================

check_password_interactive() {
    echo -e "${YELLOW}Enter password to check (input hidden):${NC}"
    read -s password
    echo

    check_hibp_password "$password"
}

#=============================================================================
# Monitoring Loop
#=============================================================================

monitor_loop() {
    log_info "Starting breach monitoring (Ctrl+C to stop)..."
    log_info "Check interval: $(human_time_diff "$CHECK_INTERVAL")"

    while true; do
        log_info "=== Starting breach check at $(date) ==="

        check_all_identities

        log_info "Check complete. Sleeping for $(human_time_diff "$CHECK_INTERVAL")..."
        sleep "$CHECK_INTERVAL"
    done
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Track your identities in data breaches

COMMANDS:
    add TYPE VALUE [DESC]        Add identity to track
    remove VALUE                 Remove identity
    list                         List tracked identities
    check [VALUE]                Check for breaches (all or specific)
    monitor                      Start continuous monitoring
    report                       Show breach report
    export [FILE]                Export report to JSON
    check-password               Check if password is compromised

IDENTITY TYPES:
    email, username, phone, domain

OPTIONS:
    --interval SECONDS           Check interval for monitor mode
    --no-alert                   Don't send alerts
    -h, --help                   Show this help

EXAMPLES:
    # Add identities to track
    $0 add email "you@example.com"
    $0 add email "work@company.com" "Work email"
    $0 add username "myusername123"

    # Check for breaches
    $0 check
    $0 check "you@example.com"

    # Check if a password is compromised
    $0 check-password

    # Start monitoring
    $0 monitor

    # View report
    $0 report

SETUP:
    1. Optional: Get HIBP API key for higher rate limits
       https://haveibeenpwned.com/API/Key

    2. Set in config file:
       export HIBP_API_KEY="your_key"

    3. Add your identities
       $0 add email "your@email.com"

AUTOMATION:
    # Check every hour (crontab)
    0 * * * * $SCRIPT_DIR/data-breach-stalker.sh check

    # Continuous monitoring
    $0 monitor

DATA SOURCES:
    • Have I Been Pwned (HIBP) - Free, 800+ million accounts
    • Pwned Passwords - 600+ million compromised passwords
    • Optional: DeHashed, IntelX (paid subscriptions)

PRIVACY:
    • All identities stored encrypted locally
    • Password checks use k-anonymity (only sends partial hash)
    • No data sent to third parties except breach check APIs

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval)
                CHECK_INTERVAL=$2
                shift 2
                ;;
            --no-alert)
                ALERT_ON_NEW_BREACH=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            add|remove|list|check|monitor|report|export|check-password)
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
    check_commands jq curl openssl

    # Initialize
    init_identity_db

    # Execute command
    case $command in
        add)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: add TYPE VALUE [DESCRIPTION]"
                exit 1
            fi
            add_identity "$@"
            ;;
        remove)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: remove VALUE"
                exit 1
            fi
            remove_identity "$1"
            ;;
        list)
            list_identities
            ;;
        check)
            if [[ $# -eq 0 ]]; then
                check_all_identities
            else
                check_single_identity "$1"
            fi
            ;;
        monitor)
            monitor_loop
            ;;
        report)
            show_breach_report
            ;;
        export)
            export_breach_report "$@"
            ;;
        check-password)
            check_password_interactive
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
