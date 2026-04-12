#!/bin/bash
#=============================================================================
# coffee-shop-lockdown.sh
# Automatic security lockdown when connected to untrusted networks
# "Because I did Red Team work on Starbucks WiFi. Once."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

TRUSTED_NETWORKS_FILE="$DATA_DIR/trusted_networks.txt"
LOCKDOWN_STATE_FILE="$DATA_DIR/.lockdown_state"
BLOCKED_APPS_FILE="$DATA_DIR/blocked_apps.txt"

# Default blocked applications on untrusted networks
DEFAULT_BLOCKED_APPS=(
    "chrome"
    "firefox"
    "slack"
    "discord"
    "telegram"
    "signal-desktop"
    "thunderbird"
    "evolution"
    "teams"
    "zoom"
)

# Security measures
KILL_APPS=${KILL_APPS:-1}
ENABLE_VPN=${ENABLE_VPN:-1}
BLOCK_HTTP=${BLOCK_HTTP:-1}
CLEAR_CLIPBOARD=${CLEAR_CLIPBOARD:-1}
LOCK_KEYRING=${LOCK_KEYRING:-1}
SHOW_WARNING=${SHOW_WARNING:-1}

# Monitoring
CHECK_INTERVAL=10  # Check network every 10 seconds
LOCKDOWN_ACTIVE=0

# Strip characters that have meaning in osascript/zenity/shell.
# WiFi SSIDs are attacker-controlled (anyone can broadcast). An SSID
# containing AppleScript quoting used to escape into `osascript -e`.
# Whitelist to printable ASCII + a narrow set; cap length to 64 chars.
_sanitize_display() {
    local raw=$1
    printf '%s' "$raw" | LC_ALL=C tr -c 'A-Za-z0-9 ._-' '?' | cut -c1-64
}

#=============================================================================
# Network Detection
#=============================================================================

get_current_network() {
    local ssid=$(get_network_ssid)
    local bssid=""

    # Get BSSID for more precise identification
    if command -v nmcli &> /dev/null; then
        bssid=$(nmcli -t -f active,bssid dev wifi | grep '^yes' | cut -d: -f2)
    elif command -v airport &> /dev/null; then
        bssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ BSSID/ {print $2}')
    fi

    echo "$ssid|$bssid"
}

is_trusted_network() {
    local network=$1

    # Create trusted networks file if it doesn't exist
    if [[ ! -f "$TRUSTED_NETWORKS_FILE" ]]; then
        touch "$TRUSTED_NETWORKS_FILE"
        log_debug "Created trusted networks file"
    fi

    # Check if network is in trusted list
    if grep -qF "$network" "$TRUSTED_NETWORKS_FILE" 2>/dev/null; then
        return 0
    fi

    return 1
}

add_trusted_network() {
    local network=$1

    if ! is_trusted_network "$network"; then
        echo "$network" >> "$TRUSTED_NETWORKS_FILE"
        log_success "Added to trusted networks: $network"
    else
        log_info "Network already trusted: $network"
    fi
}

is_ethernet_connection() {
    # Check if connected via Ethernet
    if command -v nmcli &> /dev/null; then
        nmcli -t -f TYPE,STATE dev | grep -q "^ethernet:connected"
    elif command -v networksetup &> /dev/null; then
        # macOS
        networksetup -listallhardwareports | grep -A1 "Ethernet" | grep -q "Ethernet"
    else
        return 1
    fi
}

#=============================================================================
# Security Actions
#=============================================================================

kill_sensitive_apps() {
    log_warn "Killing sensitive applications..."

    local killed=()

    # Load custom blocked apps
    local blocked_apps=("${DEFAULT_BLOCKED_APPS[@]}")
    if [[ -f "$BLOCKED_APPS_FILE" ]]; then
        while IFS= read -r app; do
            [[ -n "$app" && ! "$app" =~ ^# ]] && blocked_apps+=("$app")
        done < "$BLOCKED_APPS_FILE"
    fi

    for app in "${blocked_apps[@]}"; do
        if pgrep -x "$app" &> /dev/null; then
            if dry_run_execute "Kill $app" pkill -x "$app"; then
                killed+=("$app")
            fi
        fi
    done

    if [[ ${#killed[@]} -gt 0 ]]; then
        log_warn "Killed apps: ${killed[*]}"
        notify "Apps Terminated" "Killed: ${killed[*]}" "critical"
    fi
}

enable_vpn_tunnel() {
    log_info "Ensuring VPN is active..."

    if check_vpn; then
        log_success "VPN already active"
        return 0
    fi

    # Try to start VPN
    local vpn_started=0

    # Try NordVPN
    if command -v nordvpn &> /dev/null; then
        log_info "Starting NordVPN..."
        if nordvpn connect &>/dev/null; then
            vpn_started=1
        fi
    fi

    # Try OpenVPN
    if [[ $vpn_started -eq 0 ]] && command -v openvpn &> /dev/null; then
        local ovpn_config="${OPENVPN_CONFIG:-$HOME/.config/openvpn/client.ovpn}"
        if [[ -f "$ovpn_config" ]]; then
            log_info "Starting OpenVPN..."
            if sudo openvpn --config "$ovpn_config" --daemon; then
                vpn_started=1
            fi
        fi
    fi

    # Try WireGuard
    if [[ $vpn_started -eq 0 ]] && command -v wg-quick &> /dev/null; then
        local wg_interface="${WG_INTERFACE:-wg0}"
        log_info "Starting WireGuard..."
        if sudo wg-quick up "$wg_interface" &>/dev/null; then
            vpn_started=1
        fi
    fi

    if [[ $vpn_started -eq 1 ]]; then
        # Wait for VPN to connect
        sleep 5

        if check_vpn; then
            log_success "VPN activated"
            return 0
        fi
    fi

    log_error "Failed to activate VPN!"
    send_alert "🚨 CRITICAL: VPN failed to start on untrusted network!"
    return 1
}

block_http_traffic() {
    log_info "Blocking non-HTTPS traffic..."

    if ! is_root; then
        log_warn "Need root privileges to configure firewall"
        return 1
    fi

    # Save current iptables rules
    iptables-save > "$DATA_DIR/.iptables_backup" 2>/dev/null || true

    # Block all HTTP (port 80) traffic
    dry_run_execute "Block HTTP" iptables -A OUTPUT -p tcp --dport 80 -j REJECT

    # Allow only HTTPS (443), DNS (53), VPN ports
    dry_run_execute "Allow HTTPS" iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    dry_run_execute "Allow DNS" iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

    log_success "HTTP traffic blocked"
}

clear_clipboard_data() {
    log_info "Clearing clipboard..."

    if command -v xclip &> /dev/null; then
        echo -n "" | xclip -selection clipboard
    elif command -v wl-copy &> /dev/null; then
        wl-copy -c
    elif command -v pbcopy &> /dev/null; then
        echo -n "" | pbcopy
    fi

    log_success "Clipboard cleared"
}

lock_password_manager() {
    log_info "Locking password managers..."

    # Lock KeePassXC
    if pgrep -x keepassxc &> /dev/null; then
        qdbus org.keepassxc.KeePassXC.MainWindow /keepassxc org.keepassxc.KeePassXC.MainWindow.lockAllDatabases 2>/dev/null || true
    fi

    # Lock 1Password
    if command -v op &> /dev/null; then
        op signout 2>/dev/null || true
    fi

    # Lock Bitwarden
    if command -v bw &> /dev/null; then
        bw lock 2>/dev/null || true
    fi

    log_success "Password managers locked"
}

lock_gnome_keyring() {
    log_info "Locking GNOME keyring..."

    if command -v gnome-keyring-daemon &> /dev/null; then
        pkill -USR1 gnome-keyring-daemon 2>/dev/null || true
    fi
}

show_warning_screen() {
    local network
    network=$(_sanitize_display "$1")

    # Terminal warning
    cat <<EOF

${RED}${BOLD}
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    🚨 SECURITY LOCKDOWN 🚨                   ║
║                                                              ║
║         YOU ARE ON AN UNTRUSTED NETWORK                      ║
║                                                              ║
║         Network: ${network}
║                                                              ║
║  Security measures activated:                                ║
║  - Sensitive applications terminated                         ║
║  - VPN tunnel enforced                                       ║
║  - HTTP traffic blocked                                      ║
║  - Clipboard cleared                                         ║
║  - Password managers locked                                  ║
║                                                              ║
║  DO NOT perform sensitive operations!                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
${NC}

EOF

    # Desktop notification
    notify "🚨 SECURITY LOCKDOWN" "Untrusted network detected: $network" "critical"

    # Full-screen warning (if available)
    if command -v zenity &> /dev/null; then
        zenity --warning \
            --title="SECURITY LOCKDOWN" \
            --text="<span size='large' weight='bold'>UNTRUSTED NETWORK DETECTED</span>\n\nNetwork: $network\n\nSecurity measures have been activated.\nDO NOT perform sensitive operations!" \
            --width=400 &
    elif command -v osascript &> /dev/null; then
        # macOS
        osascript -e "display alert \"🚨 SECURITY LOCKDOWN\" message \"Untrusted network detected: $network\n\nSecurity measures activated.\" as critical" &
    fi
}

#=============================================================================
# Lockdown Management
#=============================================================================

activate_lockdown() {
    local network=$1

    log_warn "Activating security lockdown for: $network"

    # Kill sensitive apps
    if [[ $KILL_APPS -eq 1 ]]; then
        kill_sensitive_apps
    fi

    # Enable VPN
    if [[ $ENABLE_VPN -eq 1 ]]; then
        enable_vpn_tunnel
    fi

    # Block HTTP
    if [[ $BLOCK_HTTP -eq 1 ]] && is_root; then
        block_http_traffic
    fi

    # Clear clipboard
    if [[ $CLEAR_CLIPBOARD -eq 1 ]]; then
        clear_clipboard_data
    fi

    # Lock password managers
    if [[ $LOCK_KEYRING -eq 1 ]]; then
        lock_password_manager
        lock_gnome_keyring
    fi

    # Show warning
    if [[ $SHOW_WARNING -eq 1 ]]; then
        show_warning_screen "$network"
    fi

    # Mark as locked down
    echo "$network|$(date +%s)" > "$LOCKDOWN_STATE_FILE"
    LOCKDOWN_ACTIVE=1

    send_alert "🔒 Security lockdown activated for: $network"
    log_success "Lockdown complete"
}

deactivate_lockdown() {
    local network=$1

    log_info "Deactivating lockdown - trusted network: $network"

    # Restore firewall rules
    if [[ -f "$DATA_DIR/.iptables_backup" ]] && is_root; then
        iptables-restore < "$DATA_DIR/.iptables_backup" 2>/dev/null || true
        rm -f "$DATA_DIR/.iptables_backup"
    fi

    # Clear lockdown state
    rm -f "$LOCKDOWN_STATE_FILE"
    LOCKDOWN_ACTIVE=0

    notify "✅ Lockdown Deactivated" "Connected to trusted network: $network" "normal"
    log_success "Lockdown deactivated"
}

is_lockdown_active() {
    [[ -f "$LOCKDOWN_STATE_FILE" ]]
}

#=============================================================================
# Monitoring Daemon
#=============================================================================

monitor_network() {
    log_info "Starting network monitoring daemon (interval: ${CHECK_INTERVAL}s)"

    local last_network=""

    while true; do
        local current_network=$(get_current_network)
        local ssid=$(echo "$current_network" | cut -d'|' -f1)

        # Skip if no network
        if [[ -z "$ssid" || "$ssid" == "unknown" ]]; then
            log_debug "No network connection"
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # Check if network changed
        if [[ "$current_network" != "$last_network" ]]; then
            log_info "Network changed to: $ssid"

            # Check if trusted
            if is_trusted_network "$current_network"; then
                log_info "Connected to trusted network: $ssid"

                # Deactivate lockdown if active
                if is_lockdown_active; then
                    deactivate_lockdown "$ssid"
                fi
            else
                # Check if it's a public network
                if is_public_network; then
                    log_warn "PUBLIC NETWORK DETECTED: $ssid"
                    activate_lockdown "$ssid"
                else
                    log_warn "Unknown network: $ssid"

                    # Ask user if this is a trusted network
                    if [[ $LOCKDOWN_ACTIVE -eq 0 ]]; then
                        notify "New Network Detected" "Is '$ssid' a trusted network?" "normal"

                        if ask_yes_no "Is '$ssid' a trusted network?"; then
                            add_trusted_network "$current_network"
                        else
                            activate_lockdown "$ssid"
                        fi
                    fi
                fi
            fi

            last_network="$current_network"
        fi

        # Check if VPN is still active during lockdown
        if is_lockdown_active && [[ $ENABLE_VPN -eq 1 ]]; then
            if ! check_vpn; then
                log_error "VPN dropped during lockdown!"
                send_alert "🚨 CRITICAL: VPN dropped on untrusted network!"
                enable_vpn_tunnel
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
Usage: $0 [OPTIONS] [COMMAND]

Automatic security lockdown for untrusted networks

COMMANDS:
    monitor              Start network monitoring daemon (default)
    status               Show current lockdown status
    trust                Add current network to trusted list
    untrust              Remove current network from trusted list
    list-trusted         List all trusted networks
    test                 Test lockdown without applying

OPTIONS:
    --no-vpn            Don't enforce VPN
    --no-kill-apps      Don't kill applications
    --no-http-block     Don't block HTTP traffic
    -h, --help          Show this help

EXAMPLES:
    # Start monitoring daemon
    $0 monitor &

    # Check status
    $0 status

    # Trust current network
    $0 trust

    # Test lockdown (dry run)
    DRY_RUN=1 $0 test

SETUP:
    # Auto-start on boot (systemd)
    sudo systemctl enable coffee-shop-lockdown

    # Add to startup applications
    # ~/.config/autostart/coffee-shop-lockdown.desktop

EOF
}

_coffee_cleanup() {
    # If we modified iptables and the script is dying unexpectedly, put the
    # firewall back. Without this, a ^C during lockdown left the user stuck.
    if [[ -f "$DATA_DIR/.iptables_backup" ]] && is_root; then
        iptables-restore < "$DATA_DIR/.iptables_backup" 2>/dev/null || true
    fi
}

main() {
    local command="monitor"
    trap _coffee_cleanup EXIT INT TERM

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-vpn)
                ENABLE_VPN=0
                shift
                ;;
            --no-kill-apps)
                KILL_APPS=0
                shift
                ;;
            --no-http-block)
                BLOCK_HTTP=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            monitor|status|trust|untrust|list-trusted|test)
                command=$1
                shift
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

    # Execute command
    case $command in
        monitor)
            monitor_network
            ;;
        status)
            if is_lockdown_active; then
                echo -e "${RED}🔒 LOCKDOWN ACTIVE${NC}"
                cat "$LOCKDOWN_STATE_FILE"
            else
                echo -e "${GREEN}✅ No lockdown${NC}"
            fi

            local current=$(get_current_network)
            echo "Current network: $current"

            if is_trusted_network "$current"; then
                echo -e "${GREEN}✓ Trusted network${NC}"
            else
                echo -e "${YELLOW}⚠ Untrusted network${NC}"
            fi
            ;;
        trust)
            local current=$(get_current_network)
            add_trusted_network "$current"
            ;;
        untrust)
            local current=$(get_current_network)
            sed -i "\|^${current}$|d" "$TRUSTED_NETWORKS_FILE"
            log_success "Removed from trusted networks"
            ;;
        list-trusted)
            if [[ -f "$TRUSTED_NETWORKS_FILE" ]]; then
                cat "$TRUSTED_NETWORKS_FILE"
            else
                log_info "No trusted networks configured"
            fi
            ;;
        test)
            local current=$(get_current_network)
            log_info "Testing lockdown for: $current"
            activate_lockdown "$current"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
