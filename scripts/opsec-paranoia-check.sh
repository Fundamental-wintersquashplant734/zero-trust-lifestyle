#!/bin/bash
#=============================================================================
# opsec-paranoia-check.sh
# Comprehensive OPSEC validation for security researchers
# "Because one mistake can burn your entire operation"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

# Required security tools
REQUIRED_VPNS=("openvpn" "wireguard" "nordvpn")  # At least one must be active
ALLOWED_DNS=("127.0.0.1" "10.0.0.1")  # Trusted DNS servers only

# Monitoring
CHECK_INTERVAL=${OPSEC_CHECK_INTERVAL:-900}  # 15 minutes default
ALERT_ON_FAILURE=${ALERT_ON_FAILURE:-1}

# Checks to perform
CHECK_VPN=1
CHECK_DNS=1
CHECK_WEBCAM=1
CHECK_MICROPHONE=1
CHECK_CLIPBOARD=1
CHECK_METADATA=1
CHECK_TOR=1
CHECK_PROCESSES=1
CHECK_NETWORK=1
CHECK_FILES=1

#=============================================================================
# VPN Checks
#=============================================================================

check_vpn_status() {
    log_info "Checking VPN status..."

    if check_vpn; then
        log_success "VPN is active"
        return 0
    else
        log_error "VPN is NOT active!"
        send_alert "🚨 OPSEC FAILURE: VPN is down!"
        return 1
    fi
}

check_vpn_kill_switch() {
    log_info "Checking VPN kill switch..."

    # Check if firewall rules prevent non-VPN traffic
    if command -v iptables &> /dev/null && is_root; then
        local rules=$(iptables -L OUTPUT -n 2>/dev/null || echo "")

        if echo "$rules" | grep -q "REJECT.*--.*0.0.0.0/0"; then
            log_success "Kill switch appears to be configured"
            return 0
        else
            log_warn "No kill switch detected - traffic may leak if VPN drops"
            return 1
        fi
    else
        log_debug "Cannot check kill switch (need root or iptables)"
        return 0
    fi
}

#=============================================================================
# DNS Leak Detection
#=============================================================================

check_dns_config() {
    log_info "Checking DNS configuration..."

    local dns_servers=""

    # Get DNS servers based on OS
    case $(get_os) in
        linux)
            if command -v nmcli &> /dev/null; then
                dns_servers=$(nmcli dev show | grep -i dns | awk '{print $2}')
            elif [[ -f /etc/resolv.conf ]]; then
                dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
            fi
            ;;
        macos)
            dns_servers=$(scutil --dns | grep nameserver | awk '{print $3}')
            ;;
    esac

    log_debug "DNS servers: $dns_servers"

    # Check against allowed DNS list
    local issues=0
    while IFS= read -r server; do
        [[ -z "$server" ]] && continue

        local allowed=0
        for allowed_dns in "${ALLOWED_DNS[@]}"; do
            if [[ "$server" == "$allowed_dns"* ]]; then
                allowed=1
                break
            fi
        done

        if [[ $allowed -eq 0 ]]; then
            log_warn "Untrusted DNS server detected: $server"
            ((issues++))
        fi
    done <<< "$dns_servers"

    if [[ $issues -eq 0 ]]; then
        log_success "DNS configuration looks good"
        return 0
    else
        log_error "DNS leak potential detected!"
        return 1
    fi
}

test_dns_leak() {
    log_info "Testing for DNS leaks..."

    if ! check_internet; then
        log_warn "No internet connection, skipping DNS leak test"
        return 0
    fi

    # Query DNS leak test service
    local result=$(curl -s https://bash.ws/dnsleak 2>/dev/null || echo "")

    if [[ -n "$result" ]]; then
        log_debug "DNS leak test result: $result"

        if echo "$result" | grep -qi "leak"; then
            log_error "DNS LEAK DETECTED!"
            send_alert "🚨 DNS LEAK: Your DNS queries are leaking!"
            return 1
        else
            log_success "No DNS leak detected"
            return 0
        fi
    else
        log_warn "Could not perform DNS leak test"
        return 0
    fi
}

#=============================================================================
# Hardware Checks
#=============================================================================

check_webcam() {
    log_info "Checking webcam status..."

    local webcam_active=0

    # Check for active webcam usage
    if command -v lsof &> /dev/null; then
        if lsof /dev/video* 2>/dev/null | grep -q video; then
            webcam_active=1
        fi
    fi

    # Check for USB webcams
    if command -v lsusb &> /dev/null; then
        local webcams=$(lsusb | grep -iE "camera|webcam" || true)
        if [[ -n "$webcams" ]]; then
            log_debug "Webcams found: $webcams"

            if [[ $webcam_active -eq 1 ]]; then
                log_warn "⚠️  Webcam is ACTIVE!"
                return 1
            else
                log_info "Webcam present but not active"
                return 0
            fi
        fi
    fi

    log_success "No webcam activity detected"
    return 0
}

check_microphone() {
    log_info "Checking microphone status..."

    local mic_active=0

    # Check PulseAudio/PipeWire sources
    if command -v pactl &> /dev/null; then
        local sources=$(pactl list sources 2>/dev/null | grep -i "state:" | grep -i "running" || true)
        if [[ -n "$sources" ]]; then
            mic_active=1
            log_warn "⚠️  Microphone is ACTIVE!"
        fi
    fi

    # Check ALSA
    if command -v arecord &> /dev/null; then
        if arecord -l 2>/dev/null | grep -q "card"; then
            if [[ $mic_active -eq 1 ]]; then
                return 1
            else
                log_info "Microphone present but not active"
                return 0
            fi
        fi
    fi

    log_success "No microphone activity detected"
    return 0
}

#=============================================================================
# Clipboard Security
#=============================================================================

check_clipboard() {
    log_info "Checking clipboard for sensitive data..."

    local clipboard_content=""

    # Get clipboard content based on available tools
    if command -v xclip &> /dev/null; then
        clipboard_content=$(xclip -o -selection clipboard 2>/dev/null || echo "")
    elif command -v wl-paste &> /dev/null; then
        clipboard_content=$(wl-paste 2>/dev/null || echo "")
    elif command -v pbpaste &> /dev/null; then
        # macOS
        clipboard_content=$(pbpaste 2>/dev/null || echo "")
    fi

    if [[ -z "$clipboard_content" ]]; then
        log_success "Clipboard is empty"
        return 0
    fi

    # Check for sensitive patterns
    local issues=()

    # API keys
    if echo "$clipboard_content" | grep -qE "sk-[A-Za-z0-9]{48}|AKIA[0-9A-Z]{16}"; then
        issues+=("🔑 API key detected")
    fi

    # Private keys
    if echo "$clipboard_content" | grep -q "BEGIN.*PRIVATE KEY"; then
        issues+=("🔐 Private key detected")
    fi

    # Passwords (basic detection)
    if echo "$clipboard_content" | grep -qE "password|passwd|pwd"; then
        issues+=("🔒 Possible password detected")
    fi

    # Email addresses
    if echo "$clipboard_content" | grep -qE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"; then
        issues+=("📧 Email address in clipboard")
    fi

    # Credit card numbers (basic check)
    if echo "$clipboard_content" | grep -qE "[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}"; then
        issues+=("💳 Possible credit card number")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "Sensitive data in clipboard:"
        printf '  %s\n' "${issues[@]}"
        return 1
    else
        log_success "Clipboard content looks safe"
        return 0
    fi
}

#=============================================================================
# File Metadata Checks
#=============================================================================

check_recent_file_metadata() {
    log_info "Checking recent files for GPS/metadata leaks..."

    local home_dir=$HOME
    local issues=0

    # Find recently modified images (last 24 hours)
    while IFS= read -r file; do
        [[ ! -f "$file" ]] && continue

        # Check for EXIF data with GPS coordinates
        if command -v exiftool &> /dev/null; then
            local gps_data=$(exiftool -GPS* "$file" 2>/dev/null | grep -v "GPS.*:" || true)

            if [[ -n "$gps_data" ]]; then
                log_warn "GPS metadata found in: $file"
                ((issues++))
            fi
        fi
    done < <(find "$home_dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) -mtime -1 2>/dev/null || true)

    # Check PDFs for author info
    if command -v pdfinfo &> /dev/null; then
        while IFS= read -r file; do
            [[ ! -f "$file" ]] && continue

            local author=$(pdfinfo "$file" 2>/dev/null | grep "Author:" || true)
            if [[ -n "$author" ]] && [[ "$author" != "Author:" ]]; then
                log_warn "Author metadata in PDF: $file"
                ((issues++))
            fi
        done < <(find "$home_dir" -type f -iname "*.pdf" -mtime -1 2>/dev/null || true)
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "No GPS/metadata leaks found in recent files"
        return 0
    else
        log_error "Found $issues files with metadata issues"
        return 1
    fi
}

#=============================================================================
# Tor Status
#=============================================================================

check_tor_status() {
    log_info "Checking Tor status..."

    # Check if Tor daemon is running
    if pgrep -x tor &> /dev/null; then
        log_success "Tor daemon is running"

        # Verify Tor connectivity
        if command -v torsocks &> /dev/null; then
            local tor_ip=$(torsocks curl -s https://check.torproject.org/api/ip 2>/dev/null | jq -r '.IP' || echo "")

            if [[ -n "$tor_ip" ]]; then
                log_success "Tor is working (exit IP: $tor_ip)"
                return 0
            fi
        fi

        return 0
    else
        log_warn "Tor daemon is not running"
        return 1
    fi
}

#=============================================================================
# Process Monitoring
#=============================================================================

check_suspicious_processes() {
    log_info "Checking for suspicious processes..."

    local suspicious_patterns=(
        "keylog"
        "wireshark"
        "tcpdump"
        "ettercap"
        "burpsuite"
        "mitmproxy"
    )

    local found=()

    for pattern in "${suspicious_patterns[@]}"; do
        if pgrep -i "$pattern" &> /dev/null; then
            found+=("$pattern")
        fi
    done

    if [[ ${#found[@]} -gt 0 ]]; then
        log_warn "Security tools running: ${found[*]}"
        log_warn "Make sure these are YOUR tools!"
        return 1
    else
        log_success "No suspicious processes detected"
        return 0
    fi
}

#=============================================================================
# Network Monitoring
#=============================================================================

check_network_connections() {
    log_info "Checking suspicious network connections..."

    local suspicious_ports=(
        "4444"   # Metasploit default
        "5555"   # ADB
        "6666"   # IRC/malware
        "31337"  # Back Orifice
    )

    local issues=0

    if command -v ss &> /dev/null; then
        for port in "${suspicious_ports[@]}"; do
            if ss -tunlp 2>/dev/null | grep -q ":$port"; then
                log_warn "Suspicious port listening: $port"
                ((issues++))
            fi
        done
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "No suspicious network connections"
        return 0
    else
        return 1
    fi
}

check_public_ip() {
    log_info "Checking public IP address..."

    if ! check_internet; then
        log_warn "No internet connection"
        return 0
    fi

    local public_ip=$(get_public_ip)
    local vpn_ip_file="$DATA_DIR/.vpn_ip"

    log_info "Current public IP: $public_ip"

    # Store VPN IP for comparison
    if [[ -f "$vpn_ip_file" ]]; then
        local saved_ip=$(cat "$vpn_ip_file")

        if [[ "$public_ip" != "$saved_ip" ]]; then
            log_warn "Public IP changed! Was: $saved_ip, Now: $public_ip"
            return 1
        fi
    else
        echo "$public_ip" > "$vpn_ip_file"
    fi

    return 0
}

#=============================================================================
# Main Check
#=============================================================================

run_all_checks() {
    local total_checks=0
    local passed_checks=0
    local failed_checks=()

    echo -e "\n${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║       OPSEC PARANOIA CHECK            ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}\n"

    # VPN checks
    if [[ $CHECK_VPN -eq 1 ]]; then
        ((total_checks++))
        if check_vpn_status && check_vpn_kill_switch; then
            ((passed_checks++))
        else
            failed_checks+=("VPN")
        fi
        echo
    fi

    # DNS checks
    if [[ $CHECK_DNS -eq 1 ]]; then
        ((total_checks++))
        if check_dns_config && test_dns_leak; then
            ((passed_checks++))
        else
            failed_checks+=("DNS")
        fi
        echo
    fi

    # Hardware checks
    if [[ $CHECK_WEBCAM -eq 1 ]]; then
        ((total_checks++))
        if check_webcam; then
            ((passed_checks++))
        else
            failed_checks+=("Webcam")
        fi
    fi

    if [[ $CHECK_MICROPHONE -eq 1 ]]; then
        ((total_checks++))
        if check_microphone; then
            ((passed_checks++))
        else
            failed_checks+=("Microphone")
        fi
        echo
    fi

    # Clipboard check
    if [[ $CHECK_CLIPBOARD -eq 1 ]]; then
        ((total_checks++))
        if check_clipboard; then
            ((passed_checks++))
        else
            failed_checks+=("Clipboard")
        fi
        echo
    fi

    # Metadata check
    if [[ $CHECK_METADATA -eq 1 ]]; then
        ((total_checks++))
        if check_recent_file_metadata; then
            ((passed_checks++))
        else
            failed_checks+=("Metadata")
        fi
        echo
    fi

    # Tor check
    if [[ $CHECK_TOR -eq 1 ]]; then
        ((total_checks++))
        if check_tor_status; then
            ((passed_checks++))
        else
            failed_checks+=("Tor")
        fi
        echo
    fi

    # Process check
    if [[ $CHECK_PROCESSES -eq 1 ]]; then
        ((total_checks++))
        if check_suspicious_processes; then
            ((passed_checks++))
        else
            failed_checks+=("Processes")
        fi
        echo
    fi

    # Network check
    if [[ $CHECK_NETWORK -eq 1 ]]; then
        ((total_checks++))
        if check_network_connections && check_public_ip; then
            ((passed_checks++))
        else
            failed_checks+=("Network")
        fi
        echo
    fi

    # Summary
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}SUMMARY:${NC}"
    echo -e "  Total checks: $total_checks"
    echo -e "  ${GREEN}Passed: $passed_checks${NC}"
    echo -e "  ${RED}Failed: ${#failed_checks[@]}${NC}"

    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed checks: ${failed_checks[*]}${NC}"
        return 1
    else
        echo -e "\n${GREEN}✅ All OPSEC checks passed!${NC}"
        return 0
    fi
}

#=============================================================================
# Daemon Mode
#=============================================================================

run_daemon() {
    log_info "Starting OPSEC monitoring daemon (interval: ${CHECK_INTERVAL}s)"

    while true; do
        if ! run_all_checks; then
            if [[ $ALERT_ON_FAILURE -eq 1 ]]; then
                send_alert "🚨 OPSEC CHECK FAILED - Review immediately!"
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Comprehensive OPSEC validation for security researchers

OPTIONS:
    -d, --daemon         Run as background daemon
    -q, --quick          Quick check (VPN + DNS only)
    -v, --verbose        Verbose output
    -h, --help           Show this help

EXAMPLES:
    # Run all checks once
    $0

    # Run as daemon (checks every 15 min)
    $0 --daemon &

    # Quick check
    $0 --quick

RECOMMENDED SETUP:
    # Add to crontab for periodic checks
    */15 * * * * $0 --quick

EOF
}

main() {
    local daemon_mode=0
    local quick_mode=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--daemon)
                daemon_mode=1
                shift
                ;;
            -q|--quick)
                quick_mode=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
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

    # Quick mode - only critical checks
    if [[ $quick_mode -eq 1 ]]; then
        CHECK_WEBCAM=0
        CHECK_MICROPHONE=0
        CHECK_CLIPBOARD=0
        CHECK_METADATA=0
        CHECK_PROCESSES=0
        CHECK_NETWORK=0
    fi

    # Daemon mode
    if [[ $daemon_mode -eq 1 ]]; then
        run_daemon
        exit 0
    fi

    # Run checks
    if run_all_checks; then
        exit 0
    else
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
