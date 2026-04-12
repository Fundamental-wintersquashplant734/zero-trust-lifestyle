#!/bin/bash
# Common library functions for zero-trust-lifestyle
# Provides logging, error handling, notifications, and utilities

# Ensure consistent numeric locale for bc/printf/awk across all scripts
export LC_NUMERIC=C

# Color codes for output (using $'...' so heredocs render them correctly)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
BOLD=$'\033[1m'

# Script directory detection
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$LIB_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/config.sh"
CONFIG_DIR="$PROJECT_ROOT/config"
DATA_DIR="$PROJECT_ROOT/data"
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports"

# Ensure directories exist
mkdir -p "$DATA_DIR" "$LOG_DIR" "$REPORTS_DIR"

# Logging setup
LOG_FILE="$LOG_DIR/$(basename "$0" .sh)_$(date +%Y%m%d).log"
VERBOSE=${VERBOSE:-0}

# Load configuration if exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo -e "${YELLOW}⚠️  Warning: Config file not found at $CONFIG_FILE${NC}"
    echo -e "   Run: cp $PROJECT_ROOT/config/config.example.sh $CONFIG_FILE"
fi

#=============================================================================
# Logging Functions
#=============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    if [[ $VERBOSE -eq 1 ]] || [[ "$level" != "DEBUG" ]]; then
        case $level in
            ERROR)   echo -e "${RED}❌ $message${NC}" ;;
            WARN)    echo -e "${YELLOW}⚠️  $message${NC}" ;;
            SUCCESS) echo -e "${GREEN}✅ $message${NC}" ;;
            INFO)    echo -e "${BLUE}ℹ️  $message${NC}" ;;
            DEBUG)   echo -e "${CYAN}🔍 $message${NC}" ;;
            *)       echo -e "$message" ;;
        esac
    fi
}

log_error() { log "ERROR" "$@"; }
log_warn() { log "WARN" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_info() { log "INFO" "$@"; }
log_debug() { log "DEBUG" "$@"; }

#=============================================================================
# Error Handling
#=============================================================================

die() {
    log_error "$@"
    exit 1
}

check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        die "$cmd is required but not installed. Please install it first."
    fi
}

check_commands() {
    for cmd in "$@"; do
        check_command "$cmd"
    done
}

#=============================================================================
# Notification Functions
#=============================================================================

notify() {
    local title=$1
    local message=$2
    local urgency=${3:-normal}  # low, normal, critical

    # Try different notification methods
    if command -v notify-send &> /dev/null; then
        notify-send -u "$urgency" "$title" "$message"
    elif command -v osascript &> /dev/null; then
        # macOS - sanitize quotes to prevent AppleScript injection
        local safe_msg="${message//\"/\\\"}"
        local safe_title="${title//\"/\\\"}"
        osascript -e "display notification \"$safe_msg\" with title \"$safe_title\""
    elif command -v termux-notification &> /dev/null; then
        # Termux (Android)
        termux-notification --title "$title" --content "$message"
    fi

    # Also log
    log_info "NOTIFICATION: $title - $message"
}

send_alert() {
    local message=$1
    notify "🚨 ALERT" "$message" "critical"

    # Send to configured alert methods
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "$message" | mail -s "Security Alert" "$ALERT_EMAIL" 2>/dev/null || true
    fi

    if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
        local json_body
        json_body=$(jq -n --arg text "$message" '{"text":$text}')
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$json_body" &> /dev/null || true
    fi

    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            --data-urlencode "text=$message" &> /dev/null || true
    fi
}

#=============================================================================
# Network Functions
#=============================================================================

check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null && ! ping -c 1 1.1.1.1 &> /dev/null; then
        return 1
    fi
    return 0
}

check_vpn() {
    # Check if VPN is active by looking for common VPN interfaces
    if ip link show 2>/dev/null | grep -qE "tun0|tap0|wg0|utun"; then
        return 0
    fi

    # Check for VPN processes
    if pgrep -x "openvpn|wireguard|nordvpn|expressvpn" &> /dev/null; then
        return 0
    fi

    return 1
}

get_public_ip() {
    curl -s https://api.ipify.org 2>/dev/null || \
    curl -s https://icanhazip.com 2>/dev/null || \
    curl -s https://ifconfig.me 2>/dev/null || \
    echo "unknown"
}

check_dns_leak() {
    local dns_servers=""
    if command -v nmcli &> /dev/null; then
        dns_servers=$(nmcli dev show 2>/dev/null | grep DNS | awk '{print $2}')
    elif command -v scutil &> /dev/null; then
        # macOS
        dns_servers=$(scutil --dns 2>/dev/null | grep 'nameserver\[' | awk '{print $3}')
    fi

    if [[ -z "$dns_servers" ]]; then
        log_warn "Could not determine DNS servers"
        return 1
    fi

    # Check if DNS is going through common public resolvers that might leak
    if echo "$dns_servers" | grep -qE "^8\.8\.|^1\.1\.1\.1|^208\.67\."; then
        log_warn "Potential DNS leak detected: using public DNS servers"
        return 1
    fi
    return 0
}

get_network_ssid() {
    if command -v nmcli &> /dev/null; then
        nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2
    elif command -v airport &> /dev/null; then
        # macOS
        /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print $2}'
    else
        echo "unknown"
    fi
}

is_public_network() {
    local ssid=$(get_network_ssid)

    # List of common public WiFi patterns
    local public_patterns=(
        "Starbucks"
        "McDonalds"
        "Airport"
        "Hotel"
        "Guest"
        "Public"
        "Free"
        "Cafe"
        "Coffee"
        "xfinitywifi"
        "attwifi"
    )

    for pattern in "${public_patterns[@]}"; do
        if [[ "$ssid" == *"$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

#=============================================================================
# Data Storage (Encrypted)
#=============================================================================

# Resolve and validate the encryption password (no machine-id fallback).
# Callers MUST set ENCRYPTION_PASSWORD in config/config.sh or the environment.
_get_encryption_password() {
    if [[ -z "${ENCRYPTION_PASSWORD:-}" ]]; then
        echo "ERROR: ENCRYPTION_PASSWORD is not set. Set it in config/config.sh (use a strong secret)." >&2
        return 1
    fi
    printf '%s' "$ENCRYPTION_PASSWORD"
}

encrypt_data() {
    local input=$1
    local output=$2
    local password
    password=$(_get_encryption_password) || return 1

    # Pass key via fd:3 so it never appears in /proc/*/cmdline.
    printf '%s' "$input" | openssl enc -aes-256-cbc -salt -pbkdf2 \
        -iter 200000 -pass fd:3 -out "$output" 2>/dev/null 3<<<"$password"
}

decrypt_data() {
    local input=$1
    local password
    password=$(_get_encryption_password) || return 1

    openssl enc -aes-256-cbc -d -pbkdf2 -iter 200000 \
        -pass fd:3 -in "$input" 2>/dev/null 3<<<"$password"
}

# Deprecated: retained only so any downstream caller gets a clear error instead
# of silently deriving a world-readable key from /etc/machine-id.
get_machine_id() {
    echo "ERROR: get_machine_id() is removed. Use ENCRYPTION_PASSWORD explicitly." >&2
    return 1
}

store_secret() {
    local key=$1
    local value=$2
    local secrets_file="$DATA_DIR/.secrets.enc"

    # Decrypt existing secrets or create new
    local secrets="{}"
    if [[ -f "$secrets_file" ]]; then
        secrets=$(decrypt_data "$secrets_file" 2>/dev/null || echo "{}")
    fi

    # Add/update secret
    secrets=$(echo "$secrets" | jq --arg k "$key" --arg v "$value" '.[$k] = $v')

    # Encrypt and save
    encrypt_data "$secrets" "$secrets_file"
}

get_secret() {
    local key=$1
    local secrets_file="$DATA_DIR/.secrets.enc"

    if [[ ! -f "$secrets_file" ]]; then
        echo ""
        return 1
    fi

    decrypt_data "$secrets_file" 2>/dev/null | jq -r --arg k "$key" '.[$k] // empty'
}

#=============================================================================
# Rate Limiting
#=============================================================================

rate_limit() {
    local action=$1
    local max_calls=$2
    local time_window=$3  # in seconds
    local rate_file="$DATA_DIR/.rate_limit_$action"

    local now=$(date +%s)

    # Clean old entries
    if [[ -f "$rate_file" ]]; then
        awk -v cutoff=$((now - time_window)) '$1 > cutoff' "$rate_file" > "${rate_file}.tmp"
        mv "${rate_file}.tmp" "$rate_file"
    fi

    # Count recent calls
    local call_count=0
    if [[ -f "$rate_file" ]]; then
        call_count=$(wc -l < "$rate_file")
    fi

    if [[ $call_count -ge $max_calls ]]; then
        log_warn "Rate limit exceeded for $action ($call_count/$max_calls in ${time_window}s)"
        return 1
    fi

    # Record this call
    echo "$now" >> "$rate_file"
    return 0
}

#=============================================================================
# HTTP Requests with Retry
#=============================================================================

http_get() {
    local url=$1
    local max_retries=${2:-3}
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        local response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')

        if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
            echo "$body"
            return 0
        fi

        ((retry_count++))
        log_debug "HTTP GET failed (attempt $retry_count/$max_retries): $url - HTTP $http_code"
        sleep $((retry_count * 2))
    done

    log_error "HTTP GET failed after $max_retries attempts: $url"
    return 1
}

#=============================================================================
# User Prompts
#=============================================================================

ask_yes_no() {
    local prompt=$1
    local default=${2:-n}

    local yn_prompt="[y/N]"
    [[ "$default" == "y" ]] && yn_prompt="[Y/n]"

    read -p "$prompt $yn_prompt " -n 1 -r
    echo

    if [[ -z "$REPLY" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    [[ "$REPLY" =~ ^[Yy]$ ]] && return 0 || return 1
}

#=============================================================================
# Dry Run Support
#=============================================================================

DRY_RUN=${DRY_RUN:-0}

dry_run_execute() {
    local description=$1
    shift

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: $description"
        log_debug "[DRY RUN] Command: $*"
        return 0
    else
        log_debug "Executing: $*"
        "$@"
    fi
}

#=============================================================================
# Utility Functions
#=============================================================================

timestamp() {
    date +%s
}

human_time_diff() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

generate_random_delay() {
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Get OS type
get_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

# Export functions for use in scripts
export -f log log_error log_warn log_success log_info log_debug
export -f die check_command check_commands
export -f notify send_alert
export -f check_internet check_vpn get_public_ip check_dns_leak
export -f get_network_ssid is_public_network
# Intentionally NOT exporting encrypt_data/decrypt_data/get_machine_id/store_secret/get_secret.
# Exported functions pollute every child process's environment and make the crypto
# path reachable from scripts that never sourced lib/common.sh directly. Scripts
# that need them must `source lib/common.sh` explicitly.
export -f rate_limit http_get
export -f ask_yes_no dry_run_execute
export -f timestamp human_time_diff generate_random_delay
export -f is_root get_os

log_debug "Common library loaded successfully"
