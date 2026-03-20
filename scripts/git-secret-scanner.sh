#!/bin/bash
#=============================================================================
# git-secret-scanner.sh
# Pre-commit hook that scans for secrets before you leak them
# "I almost committed AWS keys. Twice. In one week."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

SCAN_PATTERNS_FILE="$DATA_DIR/secret_patterns.txt"
WHITELIST_FILE="$DATA_DIR/secret_whitelist.txt"
SCAN_HISTORY_FILE="$DATA_DIR/scan_history.json"

# Severity levels
SEVERITY_CRITICAL=3
SEVERITY_HIGH=2
SEVERITY_MEDIUM=1
SEVERITY_LOW=0

# Block commits with these severity levels
BLOCK_ON_SEVERITY=${BLOCK_ON_SEVERITY:-$SEVERITY_HIGH}

# Enable/disable features
AUTO_INSTALL_HOOK=${AUTO_INSTALL_HOOK:-1}
SHOW_COST_ESTIMATE=${SHOW_COST_ESTIMATE:-1}
SEND_ALERTS=${SEND_ALERTS:-1}

#=============================================================================
# Secret Patterns Database
#=============================================================================

init_patterns() {
    if [[ ! -f "$SCAN_PATTERNS_FILE" ]]; then
        # Delimiter is | (pipe) to avoid conflicts with : in regex patterns
        cat > "$SCAN_PATTERNS_FILE" <<'EOF'
# Format: name|pattern|severity|description
# AWS Keys
aws_access_key|AKIA[0-9A-Z]{16}|CRITICAL|AWS Access Key
aws_secret_key|aws(.{0,20})?['\"][0-9a-zA-Z/+]{40}['\"]|CRITICAL|AWS Secret Key
aws_account_id|[0-9]{12}|MEDIUM|AWS Account ID

# GitHub
github_token|ghp_[0-9a-zA-Z]{36}|CRITICAL|GitHub Personal Access Token
github_oauth|gho_[0-9a-zA-Z]{36}|CRITICAL|GitHub OAuth Token
github_app|ghu_[0-9a-zA-Z]{36}|CRITICAL|GitHub App Token
github_refresh|ghr_[0-9a-zA-Z]{36}|CRITICAL|GitHub Refresh Token

# Google Cloud
gcp_api_key|AIza[0-9A-Za-z\\-_]{35}|CRITICAL|Google Cloud API Key
gcp_service_account|"type":\s*"service_account"|CRITICAL|GCP Service Account JSON

# Slack
slack_token|xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[0-9a-zA-Z]{24,32}|CRITICAL|Slack Token
slack_webhook|https://hooks\.slack\.com/services/T[a-zA-Z0-9_]+/B[a-zA-Z0-9_]+/[a-zA-Z0-9_]+|HIGH|Slack Webhook

# Private Keys
rsa_private_key|-----BEGIN (RSA )?PRIVATE KEY-----|CRITICAL|RSA Private Key
openssh_private_key|-----BEGIN OPENSSH PRIVATE KEY-----|CRITICAL|OpenSSH Private Key
pgp_private_key|-----BEGIN PGP PRIVATE KEY BLOCK-----|CRITICAL|PGP Private Key
dsa_private_key|-----BEGIN DSA PRIVATE KEY-----|CRITICAL|DSA Private Key
ec_private_key|-----BEGIN EC PRIVATE KEY-----|CRITICAL|EC Private Key

# API Keys (generic)
generic_api_key|api[_-]?key['\"]?\s*[:=]\s*['\"]?[0-9a-zA-Z]{32,}['\"]?|HIGH|Generic API Key
generic_secret|secret['\"]?\s*[:=]\s*['\"]?[0-9a-zA-Z]{32,}['\"]?|HIGH|Generic Secret
generic_token|token['\"]?\s*[:=]\s*['\"]?[0-9a-zA-Z]{32,}['\"]?|HIGH|Generic Token

# Database Credentials
postgres_url|postgres(ql)?://[^:]+:[^@]+@|CRITICAL|PostgreSQL Connection String
mysql_url|mysql://[^:]+:[^@]+@|CRITICAL|MySQL Connection String
mongodb_url|mongodb(\+srv)?://[^:]+:[^@]+@|CRITICAL|MongoDB Connection String

# Cloud Providers
digitalocean_token|dop_v1_[a-f0-9]{64}|CRITICAL|DigitalOcean Token
heroku_api_key|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|HIGH|Heroku API Key
stripe_key|sk_live_[0-9a-zA-Z]{24,}|CRITICAL|Stripe Secret Key
twilio_key|SK[0-9a-fA-F]{32}|HIGH|Twilio API Key

# Password patterns
password_in_url|://[^:]+:[^@]+@|HIGH|Password in URL
basic_auth_header|Authorization:\s*Basic\s+[A-Za-z0-9+/=]+|HIGH|Basic Auth Header
bearer_token|Authorization:\s*Bearer\s+[A-Za-z0-9\-._~+/]+|MEDIUM|Bearer Token

# Common files
env_file|\.env$|MEDIUM|.env file
credentials_file|credentials\.(json|yaml|yml|xml)|HIGH|Credentials file
private_key_file|\.(pem|key|p12|pfx)$|HIGH|Private key file

# Hardcoded passwords (simple)
hardcoded_pass|password\s*=\s*['\"][^'\"]{4,}['\"]|MEDIUM|Hardcoded password
hardcoded_pwd|pwd\s*=\s*['\"][^'\"]{4,}['\"]|MEDIUM|Hardcoded password

# SSH/Certificates
ssh_private_key|\.ssh/id_(rsa|dsa|ecdsa|ed25519)$|CRITICAL|SSH Private Key

# JWT Tokens
jwt_token|eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|MEDIUM|JWT Token

# Credit Cards (basic check)
credit_card|[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}|LOW|Possible Credit Card
EOF
        log_success "Initialized secret patterns database"
    fi
}

get_patterns() {
    init_patterns
    grep -v "^#" "$SCAN_PATTERNS_FILE" | grep -v "^$" || true
}

#=============================================================================
# Scanning Functions
#=============================================================================

scan_text() {
    local text=$1
    local filename=${2:-"unknown"}

    local findings=()

    while IFS='|' read -r pattern_name pattern severity description; do
        [[ -z "$pattern" ]] && continue

        # Check if matches
        if echo "$text" | grep -qE -- "$pattern"; then
            # Get matched content (first 50 chars)
            local matched=$(echo "$text" | grep -oE -- "$pattern" | head -1 | cut -c1-50)

            # Check whitelist
            if is_whitelisted "$matched" "$filename"; then
                log_debug "Whitelisted: $matched in $filename"
                continue
            fi

            local finding_json
            finding_json=$(jq -n \
                --arg pat "$pattern_name" \
                --arg sev "$severity" \
                --arg desc "$description" \
                --arg match "$matched" \
                --arg f "$filename" \
                '{pattern: $pat, severity: $sev, description: $desc, matched: $match, file: $f}')
            findings+=("$finding_json")
        fi
    done < <(get_patterns)

    # Return findings as JSON array
    if [[ ${#findings[@]} -gt 0 ]]; then
        printf '%s\n' "${findings[@]}" | jq -s '.'
    else
        echo "[]"
    fi
}

scan_file() {
    local file=$1

    log_debug "Scanning file: $file"

    # Skip binary files
    if file "$file" 2>/dev/null | grep -q "text\|ASCII\|UTF-8\|empty"; then
        local content=$(cat "$file" 2>/dev/null || echo "")
        scan_text "$content" "$file"
    else
        log_debug "Skipping binary file: $file"
        echo "[]"
    fi
}

scan_staged_files() {
    log_info "Scanning staged files for secrets..."

    local all_findings="[]"

    # Get list of staged files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        # Get staged content
        local staged_content=$(git show ":$file" 2>/dev/null || echo "")

        if [[ -n "$staged_content" ]]; then
            local findings=$(scan_text "$staged_content" "$file")

            # Merge findings
            all_findings=$(echo "$all_findings" | jq --argjson new "$findings" '. + $new')
        fi
    done < <(git diff --cached --name-only --diff-filter=ACM)

    echo "$all_findings"
}

scan_commit_message() {
    local message=$1

    log_debug "Scanning commit message..."

    scan_text "$message" "commit-message"
}

#=============================================================================
# Whitelist Management
#=============================================================================

is_whitelisted() {
    local content=$1
    local file=$2

    if [[ ! -f "$WHITELIST_FILE" ]]; then
        return 1
    fi

    # Check if exact match or file is whitelisted
    if grep -qF "$content" "$WHITELIST_FILE" 2>/dev/null; then
        return 0
    fi

    if grep -qF "$file" "$WHITELIST_FILE" 2>/dev/null; then
        return 0
    fi

    return 1
}

add_to_whitelist() {
    local item=$1

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$WHITELIST_FILE" ]]; then
        touch "$WHITELIST_FILE"
    fi

    if ! grep -qF "$item" "$WHITELIST_FILE"; then
        echo "$item" >> "$WHITELIST_FILE"
        log_success "Added to whitelist: $item"
    else
        log_info "Already whitelisted: $item"
    fi
}

#=============================================================================
# Reporting
#=============================================================================

calculate_cost_estimate() {
    local severity=$1

    case $severity in
        CRITICAL)
            echo "\$5,000 - \$50,000/month (compromised cloud account)"
            ;;
        HIGH)
            echo "\$500 - \$5,000/month (API abuse)"
            ;;
        MEDIUM)
            echo "\$100 - \$500/month (potential abuse)"
            ;;
        LOW)
            echo "\$0 - \$100/month (low risk)"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

show_findings_report() {
    local findings=$1

    local count=$(echo "$findings" | jq 'length')

    if [[ $count -eq 0 ]]; then
        log_success "✅ No secrets found - safe to commit!"
        return 0
    fi

    # Group by severity
    local critical=$(echo "$findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')
    local high=$(echo "$findings" | jq '[.[] | select(.severity == "HIGH")] | length')
    local medium=$(echo "$findings" | jq '[.[] | select(.severity == "MEDIUM")] | length')
    local low=$(echo "$findings" | jq '[.[] | select(.severity == "LOW")] | length')

    cat <<EOF

${RED}${BOLD}╔══════════════════════════════════════════════════════════╗
║                                                          ║
║            🚨 SECRETS DETECTED IN COMMIT 🚨              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝${NC}

${BOLD}Found $count potential secret(s):${NC}

EOF

    # Show by severity
    if [[ $critical -gt 0 ]]; then
        echo -e "${RED}${BOLD}🔴 CRITICAL ($critical):${NC}"
        echo "$findings" | jq -r '.[] | select(.severity == "CRITICAL") | "  - \(.description) in \(.file)\n    Matched: \(.matched)"'
        echo
    fi

    if [[ $high -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}🟡 HIGH ($high):${NC}"
        echo "$findings" | jq -r '.[] | select(.severity == "HIGH") | "  - \(.description) in \(.file)\n    Matched: \(.matched)"'
        echo
    fi

    if [[ $medium -gt 0 ]]; then
        echo -e "${BLUE}${BOLD}🔵 MEDIUM ($medium):${NC}"
        echo "$findings" | jq -r '.[] | select(.severity == "MEDIUM") | "  - \(.description) in \(.file)\n    Matched: \(.matched)"'
        echo
    fi

    if [[ $low -gt 0 ]]; then
        echo -e "${CYAN}${BOLD}⚪ LOW ($low):${NC}"
        echo "$findings" | jq -r '.[] | select(.severity == "LOW") | "  - \(.description) in \(.file)\n    Matched: \(.matched)"'
        echo
    fi

    # Cost estimate
    if [[ $SHOW_COST_ESTIMATE -eq 1 ]] && [[ $critical -gt 0 ]]; then
        echo -e "${RED}${BOLD}💰 Potential Cost if Leaked:${NC}"
        echo -e "   $(calculate_cost_estimate "CRITICAL")"
        echo
    fi

    # Recommendations
    echo -e "${BOLD}📋 Next Steps:${NC}"
    echo "  1. Remove secrets from files"
    echo "  2. Use environment variables instead"
    echo "  3. Add .env files to .gitignore"
    echo "  4. Use git secret or git-crypt for sensitive data"
    echo "  5. Rotate any leaked credentials immediately"
    echo

    return 1
}

#=============================================================================
# Git Hook Management
#=============================================================================

install_git_hook() {
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

    if [[ -z "$git_root" ]]; then
        log_error "Not in a git repository"
        return 1
    fi

    local hook_file="$git_root/.git/hooks/pre-commit"

    # Backup existing hook
    if [[ -f "$hook_file" ]]; then
        cp "$hook_file" "$hook_file.backup"
        log_info "Backed up existing pre-commit hook"
    fi

    # Create hook
    cat > "$hook_file" <<EOF
#!/bin/bash
# Auto-generated by git-secret-scanner.sh

$SCRIPT_DIR/git-secret-scanner.sh --pre-commit

exit \$?
EOF

    chmod +x "$hook_file"

    log_success "Installed pre-commit hook in: $git_root"
    log_info "Hook location: $hook_file"
}

uninstall_git_hook() {
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

    if [[ -z "$git_root" ]]; then
        log_error "Not in a git repository"
        return 1
    fi

    local hook_file="$git_root/.git/hooks/pre-commit"

    if [[ -f "$hook_file.backup" ]]; then
        mv "$hook_file.backup" "$hook_file"
        log_success "Restored original pre-commit hook"
    else
        rm -f "$hook_file"
        log_success "Removed pre-commit hook"
    fi
}

#=============================================================================
# Main Pre-commit Logic
#=============================================================================

run_pre_commit_scan() {
    log_info "Running pre-commit secret scan..."

    # Scan staged files
    local findings=$(scan_staged_files)

    # Show report
    if ! show_findings_report "$findings"; then
        # Send alert
        if [[ $SEND_ALERTS -eq 1 ]]; then
            send_alert "🚨 Secret detected in git commit attempt!"
        fi

        # Record scan
        record_scan "$findings" "blocked"

        echo -e "${RED}${BOLD}COMMIT BLOCKED!${NC}"
        echo -e "Fix the issues above or use: ${YELLOW}git commit --no-verify${NC} to bypass (not recommended)"
        echo

        return 1
    fi

    # Record scan
    record_scan "$findings" "passed"

    return 0
}

#=============================================================================
# History Tracking
#=============================================================================

record_scan() {
    local findings=$1
    local result=$2

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$SCAN_HISTORY_FILE" ]]; then
        echo '{"scans": []}' > "$SCAN_HISTORY_FILE"
    fi

    local tmp_file=$(mktemp)

    jq --argjson findings "$findings" \
       --arg result "$result" \
       --arg timestamp "$(date -Iseconds)" \
       '.scans += [{timestamp: $timestamp, result: $result, findings: $findings}]' \
       "$SCAN_HISTORY_FILE" > "$tmp_file"

    mv "$tmp_file" "$SCAN_HISTORY_FILE"

    # Keep last 100 scans only
    jq '.scans = .scans[-100:]' "$SCAN_HISTORY_FILE" > "$tmp_file"
    mv "$tmp_file" "$SCAN_HISTORY_FILE"
}

show_scan_history() {
    if [[ ! -f "$SCAN_HISTORY_FILE" ]]; then
        log_info "No scan history available"
        return 0
    fi

    echo -e "\n${BOLD}Recent Scans:${NC}\n"

    jq -r '.scans[-10:] | .[] | "\(.timestamp) - \(.result) - \(.findings | length) findings"' "$SCAN_HISTORY_FILE"

    echo
}

#=============================================================================
# Manual Scanning
#=============================================================================

scan_repository() {
    log_info "Scanning entire repository..."

    local findings="[]"

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local file_findings=$(VERBOSE=0 scan_file "$file")
        [[ -z "$file_findings" ]] && file_findings="[]"
        findings=$(echo "$findings" | jq --argjson new "$file_findings" '. + $new')
    done < <(git ls-files)

    show_findings_report "$findings"
}

scan_single_file() {
    local file=$1

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Scanning file: $file"

    local findings=$(scan_file "$file")

    show_findings_report "$findings"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Scan for secrets before committing them to git

COMMANDS:
    install              Install as git pre-commit hook
    uninstall            Remove git pre-commit hook
    scan [FILE]          Scan file or entire repository
    history              Show scan history
    whitelist ITEM       Add item to whitelist

OPTIONS:
    --pre-commit         Run as pre-commit hook (internal use)
    --no-block           Don't block commits (warn only)
    -h, --help           Show this help

EXAMPLES:
    # Install hook in current repo
    $0 install

    # Scan entire repository
    $0 scan

    # Scan specific file
    $0 scan config/secrets.yaml

    # Add false positive to whitelist
    $0 whitelist "example-api-key-do-not-use"

    # View history
    $0 history

SETUP:
    # Install in a repository
    cd your-git-repo
    $SCRIPT_DIR/git-secret-scanner.sh install

    # All commits will now be scanned automatically

PATTERNS DETECTED:
    ✓ AWS Keys (Access Key, Secret Key)
    ✓ GitHub Tokens (PAT, OAuth, App)
    ✓ Google Cloud API Keys
    ✓ Slack Tokens & Webhooks
    ✓ Private Keys (RSA, SSH, PGP)
    ✓ Database Connection Strings
    ✓ API Keys (Generic patterns)
    ✓ Passwords in URLs
    ✓ JWT Tokens
    ✓ And 30+ more patterns...

EOF
}

main() {
    local command=""
    local pre_commit_mode=0

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pre-commit)
                pre_commit_mode=1
                shift
                ;;
            --no-block)
                BLOCK_ON_SEVERITY=999
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            install|uninstall|scan|history|whitelist)
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
    check_commands jq git

    # Initialize patterns
    init_patterns

    # Pre-commit mode
    if [[ $pre_commit_mode -eq 1 ]]; then
        run_pre_commit_scan
        exit $?
    fi

    # Execute command
    case $command in
        install)
            install_git_hook
            ;;
        uninstall)
            uninstall_git_hook
            ;;
        scan)
            if [[ $# -gt 0 ]]; then
                scan_single_file "$1"
            else
                scan_repository
            fi
            ;;
        history)
            show_scan_history
            ;;
        whitelist)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: whitelist ITEM"
                exit 1
            fi
            add_to_whitelist "$1"
            ;;
        "")
            # Default: show help
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
