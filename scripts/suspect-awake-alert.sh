#!/bin/bash
#=============================================================================
# suspect-awake-alert.sh
# Monitors target's online activity patterns, alerts when they go online
# "They ALWAYS come online at 3 AM. Every. Single. Night."
#
# ⚠️  LEGAL WARNING ⚠️
# This tool is for:
# - Monitoring YOUR OWN accounts across platforms
# - Authorized employee/contractor monitoring (with written consent)
# - Parental controls (monitoring your children)
# - Security research with explicit authorization
#
# NEVER use for unauthorized surveillance, stalking, or harassment.
# Unauthorized monitoring is illegal. Get written consent first.
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

TARGETS_FILE="$DATA_DIR/surveillance_targets.enc"
ACTIVITY_LOG_FILE="$DATA_DIR/activity_patterns.json"
ALERTS_FILE="$DATA_DIR/activity_alerts.json"
CONSENT_FILE="$DATA_DIR/monitoring_consent.txt"

# Monitoring settings
CHECK_INTERVAL=300  # 5 minutes
ALERT_ON_ONLINE=1
ALERT_ON_OFFLINE=0
ALERT_ON_PATTERN_CHANGE=1
TRACK_ACTIVITY_PATTERNS=1

# Pattern detection
MIN_SAMPLES_FOR_PATTERN=20  # Need this many samples to establish pattern
UNUSUAL_ACTIVITY_THRESHOLD=3  # Standard deviations from normal

# Privacy settings
ENCRYPTED_STORAGE=1
REQUIRE_CONSENT=1

# Monitoring methods
ENABLE_GITHUB=1
ENABLE_DISCORD=0  # Requires bot token
ENABLE_SLACK=0    # Requires workspace access
ENABLE_TWITTER=0  # Requires API access
ENABLE_STEAM=1    # Public profiles only

# API keys (set in config)
DISCORD_TOKEN=${DISCORD_TOKEN:-""}
SLACK_TOKEN=${SLACK_TOKEN:-""}
TWITTER_API_KEY=${TWITTER_API_KEY:-""}
STEAM_API_KEY=${STEAM_API_KEY:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

#=============================================================================
# Legal/Ethical Compliance
#=============================================================================

check_consent() {
    if [[ $REQUIRE_CONSENT -ne 1 ]]; then
        return 0
    fi

    if [[ ! -f "$CONSENT_FILE" ]]; then
        cat <<EOF

${RED}${BOLD}⚠️  LEGAL COMPLIANCE REQUIRED ⚠️${NC}

This tool monitors online activity. Before proceeding, you MUST:

1. Have written consent from the person being monitored, OR
2. Be monitoring your own accounts, OR
3. Have legal authority (parent/guardian, employer with policy)

Unauthorized monitoring may violate:
- Computer Fraud and Abuse Act (CFAA)
- Electronic Communications Privacy Act (ECPA)
- State/local privacy laws
- Platform Terms of Service

${BOLD}Do you have authorization to monitor these accounts? (yes/no)${NC}
EOF

        read -p "> " answer

        if [[ "$answer" != "yes" ]]; then
            log_error "Monitoring authorization required. Exiting."
            exit 1
        fi

        cat > "$CONSENT_FILE" <<EOF
Monitoring Authorization Acknowledgment
Date: $(date -Iseconds)
User: $(whoami)

I acknowledge that:
1. I have proper authorization to monitor the configured accounts
2. I understand unauthorized monitoring may be illegal
3. I will use this tool responsibly and ethically
4. I accept full legal responsibility for my use of this tool

Signature: $(whoami)
EOF

        log_success "Authorization recorded"
    fi
}

show_legal_warning() {
    cat <<EOF

${YELLOW}${BOLD}╔════════════════════════════════════════════════════════════╗
║                   ⚠️  LEGAL NOTICE ⚠️                      ║
╚════════════════════════════════════════════════════════════╝${NC}

This tool monitors online activity patterns. You MUST have:
  • Written consent from the monitored individual, OR
  • Legal authority (parent, guardian, employer with policy), OR
  • Be monitoring your own accounts only

Legitimate use cases:
  ✓ Monitoring YOUR OWN accounts for security
  ✓ Authorized employee monitoring (with consent)
  ✓ Parental controls for minors
  ✓ Security research with explicit permission

Prohibited uses:
  ✗ Stalking or harassment
  ✗ Unauthorized surveillance
  ✗ Violating platform ToS
  ✗ Any illegal activity

${BOLD}Press Enter to acknowledge and continue...${NC}
EOF

    read
}

#=============================================================================
# Target Management (Encrypted)
#=============================================================================

init_targets_db() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$TARGETS_FILE" ]]; then
        local empty_db='{"targets": []}'
        encrypt_data "$empty_db" "$TARGETS_FILE"
        log_success "Initialized encrypted targets database"
    fi
}

get_targets() {
    init_targets_db
    decrypt_data "$TARGETS_FILE" 2>/dev/null || echo '{"targets": []}'
}

add_target() {
    local platform=$1
    local identifier=$2  # username, user_id, etc.
    local description=${3:-""}
    local consent=${4:-"no"}

    if [[ "$consent" != "yes" ]] && [[ $REQUIRE_CONSENT -eq 1 ]]; then
        log_error "Consent required. Add 'yes' as 4th parameter if you have authorization."
        return 1
    fi

    init_targets_db

    local targets=$(get_targets)

    # Check if already exists
    if echo "$targets" | jq -e --arg plat "$platform" --arg id "$identifier" \
        '.targets[] | select(.platform == $plat and .identifier == $id)' &>/dev/null; then
        log_warn "Target already monitored: $identifier on $platform"
        return 0
    fi

    # Add target
    targets=$(echo "$targets" | jq --arg platform "$platform" \
                                    --arg identifier "$identifier" \
                                    --arg desc "$description" \
                                    --arg consent "$consent" \
                                    --arg added "$(date -Iseconds)" \
        '.targets += [{
            platform: $platform,
            identifier: $identifier,
            description: $desc,
            consent: $consent,
            added: $added,
            last_seen: null,
            last_status: "unknown",
            check_count: 0
        }]')

    # Save encrypted
    encrypt_data "$targets" "$TARGETS_FILE"

    log_success "Added target: $identifier on $platform (consent: $consent)"
}

remove_target() {
    local platform=$1
    local identifier=$2

    init_targets_db

    local targets=$(get_targets)

    targets=$(echo "$targets" | jq --arg plat "$platform" --arg id "$identifier" \
        '.targets = [.targets[] | select(.platform != $plat or .identifier != $id)]')

    encrypt_data "$targets" "$TARGETS_FILE"

    log_success "Removed target: $identifier"
}

list_targets() {
    init_targets_db

    echo -e "\n${BOLD}👁️  Monitored Targets${NC}\n"

    get_targets | jq -r '.targets[] |
        "[\(.platform)] \(.identifier)\n" +
        "  Description: \(.description // "N/A")\n" +
        "  Consent: \(.consent)\n" +
        "  Last seen: \(.last_seen // "never")\n" +
        "  Status: \(.last_status)\n"'

    echo
}

update_target_status() {
    local platform=$1
    local identifier=$2
    local status=$3

    init_targets_db

    local targets=$(get_targets)

    targets=$(echo "$targets" | jq --arg plat "$platform" \
                                    --arg id "$identifier" \
                                    --arg status "$status" \
                                    --arg timestamp "$(date -Iseconds)" \
        '(.targets[] | select(.platform == $plat and .identifier == $id)) |= (
            .last_seen = $timestamp |
            .last_status = $status |
            .check_count = (.check_count + 1)
        )')

    encrypt_data "$targets" "$TARGETS_FILE"
}

#=============================================================================
# Platform Monitoring - GitHub
#=============================================================================

check_github_activity() {
    local username=$1

    if [[ $ENABLE_GITHUB -ne 1 ]]; then
        return 0
    fi

    log_debug "Checking GitHub activity: $username"

    local -a curl_args=(-s)
    [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

    # Get user info
    local user_data=$(curl "${curl_args[@]}" \
        "https://api.github.com/users/$username" 2>/dev/null || echo '{}')

    if [[ "$user_data" == "{}" ]] || echo "$user_data" | jq -e '.message == "Not Found"' &>/dev/null; then
        echo "offline"
        return 1
    fi

    # Check recent events (activity in last hour = online)
    local events=$(curl "${curl_args[@]}" \
        "https://api.github.com/users/$username/events/public" 2>/dev/null || echo '[]')

    local recent_activity=$(echo "$events" | jq --arg cutoff "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" \
        '[.[] | select(.created_at > $cutoff)] | length')

    if [[ $recent_activity -gt 0 ]]; then
        echo "online"
        return 0
    else
        echo "offline"
        return 1
    fi
}

#=============================================================================
# Platform Monitoring - Steam
#=============================================================================

check_steam_activity() {
    local steam_id=$1

    if [[ $ENABLE_STEAM -ne 1 ]]; then
        return 0
    fi

    if [[ -z "$STEAM_API_KEY" ]]; then
        log_warn "Steam API key not configured"
        return 1
    fi

    log_debug "Checking Steam activity: $steam_id"

    # Get player summary
    local player_data=$(curl -s \
        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=${STEAM_API_KEY}&steamids=${steam_id}" \
        2>/dev/null || echo '{"response":{"players":[]}}')

    local player=$(echo "$player_data" | jq -r '.response.players[0]')

    if [[ -z "$player" ]] || [[ "$player" == "null" ]]; then
        echo "offline"
        return 1
    fi

    # Check online status
    local state=$(echo "$player" | jq -r '.personastate')
    # 0 = Offline, 1 = Online, 2 = Busy, 3 = Away, 4 = Snooze, 5 = Looking to trade, 6 = Looking to play

    if [[ $state -ge 1 ]]; then
        local game=$(echo "$player" | jq -r '.gameextrainfo // "Online"')
        echo "online:$game"
        return 0
    else
        echo "offline"
        return 1
    fi
}

#=============================================================================
# Platform Monitoring - Discord (requires bot)
#=============================================================================

check_discord_activity() {
    local user_id=$1

    if [[ $ENABLE_DISCORD -ne 1 ]]; then
        return 0
    fi

    if [[ -z "$DISCORD_TOKEN" ]]; then
        log_warn "Discord bot token not configured"
        return 1
    fi

    log_debug "Checking Discord activity: $user_id"

    # Get user info (requires shared server)
    local user_data=$(curl -s \
        -H "Authorization: Bot $DISCORD_TOKEN" \
        "https://discord.com/api/v10/users/$user_id" 2>/dev/null || echo '{}')

    # Note: Getting online status requires presence intent and shared server
    # This is a simplified check

    if [[ "$user_data" != "{}" ]]; then
        echo "unknown"  # Can't reliably check without presence intent
    else
        echo "offline"
    fi
}

#=============================================================================
# Activity Pattern Analysis
#=============================================================================

record_activity() {
    local platform=$1
    local identifier=$2
    local status=$3

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$ACTIVITY_LOG_FILE" ]]; then
        echo '{"activities": []}' > "$ACTIVITY_LOG_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --arg platform "$platform" \
       --arg identifier "$identifier" \
       --arg status "$status" \
       --arg timestamp "$(date -Iseconds)" \
       --arg hour "$(date +%H)" \
       --arg day "$(date +%u)" \
       '.activities += [{
           timestamp: $timestamp,
           platform: $platform,
           identifier: $identifier,
           status: $status,
           hour: ($hour | tonumber),
           day_of_week: ($day | tonumber)
       }]' \
       "$ACTIVITY_LOG_FILE" > "$tmp_file"

    mv "$tmp_file" "$ACTIVITY_LOG_FILE"

    # Keep only last 10000 records
    jq '.activities = .activities[-10000:]' "$ACTIVITY_LOG_FILE" > "$tmp_file"
    mv "$tmp_file" "$ACTIVITY_LOG_FILE"
}

analyze_patterns() {
    local platform=$1
    local identifier=$2

    if [[ ! -f "$ACTIVITY_LOG_FILE" ]]; then
        log_info "No activity data available"
        return 0
    fi

    echo -e "\n${BOLD}📊 Activity Pattern Analysis${NC}\n"
    echo "Target: $identifier on $platform"
    echo

    # Get activities for this target
    local activities=$(jq --arg plat "$platform" --arg id "$identifier" \
        '[.activities[] | select(.platform == $plat and .identifier == $id)]' \
        "$ACTIVITY_LOG_FILE")

    local total=$(echo "$activities" | jq 'length')

    if [[ $total -lt $MIN_SAMPLES_FOR_PATTERN ]]; then
        log_warn "Not enough data for pattern analysis (need $MIN_SAMPLES_FOR_PATTERN samples, have $total)"
        return 0
    fi

    # Online activity by hour
    echo -e "${BOLD}Most active hours (UTC):${NC}"
    echo "$activities" | jq -r \
        '[.[] | select(.status == "online")] |
         group_by(.hour) |
         map({hour: .[0].hour, count: length}) |
         sort_by(-.count) |
         .[:5][] |
         "\(.hour):00 - \(.count) times"'
    echo

    # Activity by day of week
    echo -e "${BOLD}Most active days:${NC}"
    echo "$activities" | jq -r \
        '[.[] | select(.status == "online")] |
         group_by(.day_of_week) |
         map({day: .[0].day_of_week, count: length}) |
         sort_by(-.count)[] |
         "\(["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][.day]) - \(.count) times"'
    echo

    # Current behavior vs pattern
    local current_hour=$(date +%H)
    local expected_activity=$(echo "$activities" | jq --arg hour "$current_hour" \
        '[.[] | select(.hour == ($hour | tonumber) and .status == "online")] | length')

    echo -e "${BOLD}Pattern prediction:${NC}"
    if [[ $expected_activity -gt 5 ]]; then
        echo "  User is LIKELY ONLINE at this hour (${current_hour}:00)"
    else
        echo "  User is likely offline at this hour (${current_hour}:00)"
    fi
    echo
}

detect_unusual_activity() {
    local platform=$1
    local identifier=$2

    # Check if current activity is unusual based on historical patterns
    # This would use statistical analysis to detect anomalies

    log_debug "Checking for unusual activity patterns..."

    # Simplified version - just checks if active at unusual hours
    local current_hour=$(date +%H)

    # Hours 2-5 AM are "unusual" for most people
    if [[ $current_hour -ge 2 ]] && [[ $current_hour -le 5 ]]; then
        return 0  # Unusual
    fi

    return 1  # Normal
}

#=============================================================================
# Monitoring Loop
#=============================================================================

check_target() {
    local platform=$1
    local identifier=$2

    local status="offline"

    case $platform in
        github)
            status=$(check_github_activity "$identifier")
            ;;
        steam)
            status=$(check_steam_activity "$identifier")
            ;;
        discord)
            status=$(check_discord_activity "$identifier")
            ;;
        *)
            log_error "Unknown platform: $platform"
            return 1
            ;;
    esac

    # Get previous status
    local targets=$(get_targets)
    local prev_status=$(echo "$targets" | jq -r --arg plat "$platform" --arg id "$identifier" \
        '.targets[] | select(.platform == $plat and .identifier == $id) | .last_status')

    # Update status
    update_target_status "$platform" "$identifier" "$status"

    # Record activity
    if [[ $TRACK_ACTIVITY_PATTERNS -eq 1 ]]; then
        record_activity "$platform" "$identifier" "$status"
    fi

    # Check for status changes
    if [[ "$prev_status" != "$status" ]]; then
        if [[ "$status" == "online"* ]] && [[ $ALERT_ON_ONLINE -eq 1 ]]; then
            send_alert "🟢 $identifier is NOW ONLINE on $platform!"
            log_success "$identifier went online"
        elif [[ "$status" == "offline" ]] && [[ $ALERT_ON_OFFLINE -eq 1 ]]; then
            send_alert "🔴 $identifier went offline on $platform"
            log_info "$identifier went offline"
        fi

        # Check if unusual activity
        if [[ "$status" == "online"* ]] && detect_unusual_activity "$platform" "$identifier"; then
            if [[ $ALERT_ON_PATTERN_CHANGE -eq 1 ]]; then
                send_alert "⚠️  UNUSUAL ACTIVITY: $identifier online at unusual time!"
            fi
        fi
    fi

    echo "$status"
}

monitor_all_targets() {
    log_info "Monitoring all targets..."

    local targets=$(get_targets)
    local total=$(echo "$targets" | jq '.targets | length')

    if [[ $total -eq 0 ]]; then
        log_warn "No targets configured"
        return 0
    fi

    log_info "Checking $total target(s)..."

    while IFS= read -r target; do
        local platform=$(echo "$target" | jq -r '.platform')
        local identifier=$(echo "$target" | jq -r '.identifier')

        log_debug "Checking: $identifier on $platform"

        check_target "$platform" "$identifier"

        # Rate limiting
        sleep 2
    done < <(echo "$targets" | jq -c '.targets[]')
}

monitor_loop() {
    log_info "Starting activity monitoring (Ctrl+C to stop)..."
    log_info "Check interval: $(human_time_diff "$CHECK_INTERVAL")"

    while true; do
        log_info "=== Monitoring cycle at $(date) ==="

        monitor_all_targets

        log_info "Cycle complete. Sleeping for $(human_time_diff "$CHECK_INTERVAL")..."
        sleep "$CHECK_INTERVAL"
    done
}

#=============================================================================
# Dashboard
#=============================================================================

show_dashboard() {
    clear

    cat <<EOF
${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}║          👁️  ACTIVITY MONITORING DASHBOARD              ║${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

EOF

    local targets=$(get_targets)
    local total=$(echo "$targets" | jq '.targets | length')

    echo -e "${BOLD}Monitored targets: $total${NC}\n"

    # Show current status
    while IFS= read -r target; do
        local platform=$(echo "$target" | jq -r '.platform')
        local identifier=$(echo "$target" | jq -r '.identifier')
        local status=$(echo "$target" | jq -r '.last_status')
        local last_seen=$(echo "$target" | jq -r '.last_seen // "never"')

        local status_icon="⚫"
        [[ "$status" == "online"* ]] && status_icon="🟢"
        [[ "$status" == "offline" ]] && status_icon="🔴"

        echo "$status_icon  [$platform] $identifier - $status"
        echo "   Last seen: $last_seen"
        echo
    done < <(echo "$targets" | jq -c '.targets[]')
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Monitor online activity patterns (WITH AUTHORIZATION ONLY)

${RED}${BOLD}⚠️  REQUIRES AUTHORIZATION TO USE ⚠️${NC}

COMMANDS:
    add PLATFORM ID [DESC] [yes]  Add target (must specify 'yes' for consent)
    remove PLATFORM ID            Remove target
    list                          List targets
    check PLATFORM ID             Check single target
    monitor                       Start monitoring loop
    dashboard                     Show live dashboard
    analyze PLATFORM ID           Analyze activity patterns

PLATFORMS:
    github    - GitHub username
    steam     - Steam ID (requires API key)
    discord   - Discord user ID (requires bot token)

OPTIONS:
    --interval SECONDS            Check interval (default: 300)
    --alert-online                Alert when target goes online
    --alert-offline               Alert when target goes offline
    --no-patterns                 Don't track patterns
    -h, --help                    Show this help

EXAMPLES:
    # Add target (YOUR account or with consent)
    $0 add github "myusername" "My account" yes

    # Check activity
    $0 check github "myusername"

    # Analyze patterns
    $0 analyze github "myusername"

    # Start monitoring
    $0 monitor

SETUP:
    1. Set API keys in config (optional):
       export STEAM_API_KEY="your_key"
       export GITHUB_TOKEN="your_token"

    2. Add targets (with consent!)
       $0 add github "username" "description" yes

    3. Start monitoring
       $0 monitor

LEGITIMATE USE CASES:
    ✓ Monitor YOUR OWN accounts for security
    ✓ Authorized employee monitoring (documented policy)
    ✓ Parental monitoring of minors
    ✓ Security research with permission

PROHIBITED:
    ✗ Stalking or harassment
    ✗ Unauthorized surveillance
    ✗ Violating privacy laws
    ✗ Any illegal activity

${BOLD}By using this tool, you accept full legal responsibility.${NC}

EOF
}

main() {
    local command=""

    # Parse options (before consent so --help works non-interactively)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval)
                CHECK_INTERVAL=$2
                shift 2
                ;;
            --alert-online)
                ALERT_ON_ONLINE=1
                shift
                ;;
            --alert-offline)
                ALERT_ON_OFFLINE=1
                shift
                ;;
            --no-patterns)
                TRACK_ACTIVITY_PATTERNS=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            add|remove|list|check|monitor|dashboard|analyze)
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

    # Show legal warning on first run
    if [[ ! -f "$CONSENT_FILE" ]]; then
        show_legal_warning
    fi

    # Check consent
    check_consent

    # Check dependencies
    check_commands jq curl openssl

    # Initialize
    init_targets_db

    # Execute command
    case $command in
        add)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: add PLATFORM IDENTIFIER [DESCRIPTION] [yes]"
                exit 1
            fi
            add_target "$@"
            ;;
        remove)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: remove PLATFORM IDENTIFIER"
                exit 1
            fi
            remove_target "$@"
            ;;
        list)
            list_targets
            ;;
        check)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: check PLATFORM IDENTIFIER"
                exit 1
            fi
            check_target "$1" "$2"
            ;;
        monitor)
            monitor_loop
            ;;
        dashboard)
            show_dashboard
            ;;
        analyze)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: analyze PLATFORM IDENTIFIER"
                exit 1
            fi
            analyze_patterns "$1" "$2"
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
