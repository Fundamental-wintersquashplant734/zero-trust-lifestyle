#!/bin/bash
#=============================================================================
# canary-token-generator.sh
# Generate and manage canary tokens to detect unauthorized access
# "They opened the file. I know exactly when, where, and from what IP."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

TOKENS_DB_FILE="$DATA_DIR/canary_tokens.json"
TRIGGERS_LOG_FILE="$DATA_DIR/canary_triggers.json"
WEBHOOK_LOG_FILE="$LOG_DIR/webhook_server.log"

# Server settings (for self-hosted tokens)
WEBHOOK_PORT=8888
WEBHOOK_HOST="0.0.0.0"
PUBLIC_URL=${PUBLIC_URL:-""}  # Your public URL/IP for callbacks

# External services
USE_CANARYTOKENS_ORG=1  # Use canarytokens.org free service
CANARYTOKENS_API="https://canarytokens.org/generate"

# Alert settings
ALERT_ON_TRIGGER=1
ALERT_EMAIL=${ALERT_EMAIL:-""}
ALERT_WEBHOOK=${ALERT_WEBHOOK:-""}

#=============================================================================
# Token Database Management
#=============================================================================

init_tokens_db() {
    mkdir -p "$DATA_DIR" "$LOG_DIR"

    if [[ ! -f "$TOKENS_DB_FILE" ]]; then
        echo '{"tokens": []}' > "$TOKENS_DB_FILE"
        log_success "Initialized canary tokens database"
    fi

    if [[ ! -f "$TRIGGERS_LOG_FILE" ]]; then
        echo '{"triggers": []}' > "$TRIGGERS_LOG_FILE"
        log_success "Initialized triggers log"
    fi
}

add_token() {
    local type=$1
    local token=$2
    local description=$3
    local callback_url=${4:-""}

    init_tokens_db

    local tmp_file=$(mktemp)

    jq --arg type "$type" \
       --arg token "$token" \
       --arg desc "$description" \
       --arg callback "$callback_url" \
       --arg created "$(date -Iseconds)" \
       '.tokens += [{
           id: (now | tostring),
           type: $type,
           token: $token,
           description: $desc,
           callback_url: $callback,
           created: $created,
           triggered: false,
           trigger_count: 0,
           last_triggered: null
       }]' \
       "$TOKENS_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$TOKENS_DB_FILE"

    log_success "Token added: $description"
}

list_tokens() {
    init_tokens_db

    echo -e "\n${BOLD}🕯️  Canary Tokens${NC}\n"

    jq -r '.tokens[] |
        "[\(.type)] \(.description)\n" +
        "  Token: \(.token)\n" +
        "  Triggered: \(.triggered) (\(.trigger_count) times)\n" +
        "  Last trigger: \(.last_triggered // "never")\n" +
        "  Created: \(.created)\n"' \
        "$TOKENS_DB_FILE"

    echo
}

mark_triggered() {
    local token=$1

    init_tokens_db

    local tmp_file=$(mktemp)

    jq --arg token "$token" \
       --arg timestamp "$(date -Iseconds)" \
       '(.tokens[] | select(.token == $token)) |= (
           .triggered = true |
           .trigger_count = (.trigger_count + 1) |
           .last_triggered = $timestamp
       )' \
       "$TOKENS_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$TOKENS_DB_FILE"
}

#=============================================================================
# Email Tracking Pixel
#=============================================================================

generate_email_tracker() {
    local description=$1
    local email=${2:-""}

    log_info "Generating email tracking pixel..."

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        # Use canarytokens.org service
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "web" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local token_url=$(echo "$response" | grep -oP 'token_url":"[^"]+' | cut -d'"' -f3 | sed 's/\\//g')

            if [[ -n "$token_url" ]]; then
                cat <<EOF

${GREEN}✅ Email Tracking Pixel Generated!${NC}

${BOLD}HTML Code to embed in email:${NC}

<img src="$token_url" width="1" height="1" style="display:none" />

${BOLD}Or use this in HTML email:${NC}

<img src="$token_url" width="1" height="1" alt="" />

${BOLD}Usage:${NC}
1. Copy the HTML code above
2. Paste it into your HTML email body
3. When recipient opens the email, you'll get an alert

${BOLD}What you'll learn:${NC}
• When email was opened
• IP address of opener
• User agent (email client/browser)
• Approximate location

EOF
                add_token "email_pixel" "$token_url" "$description" "$token_url"
                return 0
            fi
        fi
    fi

    # Fallback: self-hosted tracker
    if [[ -z "$PUBLIC_URL" ]]; then
        log_error "PUBLIC_URL not set. Configure it in config or use canarytokens.org"
        return 1
    fi

    local token=$(openssl rand -hex 16)
    local tracker_url="$PUBLIC_URL:$WEBHOOK_PORT/track/$token.gif"

    cat <<EOF

${GREEN}✅ Self-Hosted Email Tracking Pixel Generated!${NC}

${BOLD}HTML Code:${NC}

<img src="$tracker_url" width="1" height="1" style="display:none" />

${BOLD}IMPORTANT:${NC}
1. Start the webhook server: $0 server
2. Ensure port $WEBHOOK_PORT is accessible from internet
3. Configure firewall/port forwarding if needed

EOF

    add_token "email_pixel" "$token" "$description" "$tracker_url"
}

#=============================================================================
# Document Canary Tokens
#=============================================================================

generate_pdf_canary() {
    local description=$1

    log_info "Generating PDF canary token..."

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "pdf" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local pdf_url=$(echo "$response" | grep -oP 'pdf":"[^"]+' | cut -d'"' -f3)

            if [[ -n "$pdf_url" ]]; then
                local output_file="canary_${description// /_}.pdf"
                curl -s "$pdf_url" -o "$output_file"

                cat <<EOF

${GREEN}✅ PDF Canary Token Generated!${NC}

${BOLD}File:${NC} $output_file

${BOLD}How it works:${NC}
1. This PDF contains a hidden web bug
2. When someone opens it, you get alerted
3. Works with most PDF readers

${BOLD}Usage:${NC}
• Rename to something innocuous
• Send to target or leave in honeypot location
• Wait for alert when opened

${BOLD}Alert will include:${NC}
• Time of access
• IP address
• User agent

EOF
                add_token "pdf" "$output_file" "$description" ""
                return 0
            fi
        fi
    fi

    log_warn "PDF generation requires canarytokens.org service"
    log_info "Alternative: Use web bug in Word doc or embed tracking pixel"
}

generate_word_canary() {
    local description=$1

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "msword" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local doc_url=$(echo "$response" | grep -oP 'doc":"[^"]+' | cut -d'"' -f3)

            if [[ -n "$doc_url" ]]; then
                local output_file="canary_${description// /_}.docx"
                curl -s "$doc_url" -o "$output_file"

                cat <<EOF

${GREEN}✅ Word Document Canary Generated!${NC}

${BOLD}File:${NC} $output_file

${BOLD}Usage:${NC}
• Open the document and add your content
• When someone opens it later, you get alerted
• Works with Word/LibreOffice

EOF
                add_token "word" "$output_file" "$description" ""
                return 0
            fi
        fi
    fi

    log_warn "Word doc generation requires canarytokens.org"
}

#=============================================================================
# DNS Canary Tokens
#=============================================================================

generate_dns_canary() {
    local description=$1

    log_info "Generating DNS canary token..."

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "dns" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local hostname=$(echo "$response" | grep -oP 'hostname":"[^"]+' | cut -d'"' -f3)

            if [[ -n "$hostname" ]]; then
                cat <<EOF

${GREEN}✅ DNS Canary Token Generated!${NC}

${BOLD}Hostname:${NC} $hostname

${BOLD}Usage:${NC}

1. In bash scripts:
   nslookup $hostname

2. In config files:
   server = $hostname

3. In environment variables:
   API_HOST=$hostname

4. Test it:
   ping $hostname

${BOLD}When triggered:${NC}
• You get immediate alert
• Shows source IP
• Shows DNS query details

${BOLD}Use cases:${NC}
• Detect when config files are read
• Monitor script execution
• Track data exfiltration attempts
• Honeypot credentials

EOF
                add_token "dns" "$hostname" "$description" "$hostname"
                return 0
            fi
        fi
    fi

    log_warn "DNS tokens require canarytokens.org service"
}

#=============================================================================
# AWS/Cloud Canary Tokens
#=============================================================================

generate_aws_canary() {
    local description=$1

    log_info "Generating AWS API key canary token..."

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "aws-key" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local access_key=$(echo "$response" | grep -oP 'access_key_id":"[^"]+' | cut -d'"' -f3)
            local secret_key=$(echo "$response" | grep -oP 'secret_access_key":"[^"]+' | cut -d'"' -f3)

            if [[ -n "$access_key" ]] && [[ -n "$secret_key" ]]; then
                cat <<EOF

${GREEN}✅ AWS Canary Credentials Generated!${NC}

${BOLD}Access Key ID:${NC}
$access_key

${BOLD}Secret Access Key:${NC}
$secret_key

${BOLD}Usage:${NC}

1. In .env files:
   AWS_ACCESS_KEY_ID=$access_key
   AWS_SECRET_ACCESS_KEY=$secret_key

2. In config files:
   [default]
   aws_access_key_id = $access_key
   aws_secret_access_key = $secret_key

3. In scripts:
   export AWS_ACCESS_KEY_ID=$access_key

${BOLD}When used:${NC}
• Instant alert when API called
• Shows source IP
• Shows which AWS service was accessed

${BOLD}Perfect for:${NC}
• Honeypot AWS credentials
• Detecting credential theft
• Monitoring leaked keys
• Security testing

EOF
                add_token "aws_key" "$access_key" "$description" ""
                return 0
            fi
        fi
    fi

    log_warn "AWS tokens require canarytokens.org service"
}

#=============================================================================
# URL Canary Tokens
#=============================================================================

generate_url_canary() {
    local description=$1

    log_info "Generating URL canary token..."

    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]]; then
        local json_body=$(jq -n --arg email "$ALERT_EMAIL" --arg memo "$description" --arg type "web" \
            '{email: $email, memo: $memo, type: $type}')
        local response=$(curl -s -X POST "$CANARYTOKENS_API" \
            -H "Content-Type: application/json" \
            -d "$json_body" 2>/dev/null || echo "")

        if [[ -n "$response" ]]; then
            local url=$(echo "$response" | grep -oP 'token_url":"[^"]+' | cut -d'"' -f3 | sed 's/\\//g')

            if [[ -n "$url" ]]; then
                cat <<EOF

${GREEN}✅ URL Canary Token Generated!${NC}

${BOLD}URL:${NC}
$url

${BOLD}Usage:${NC}

1. Embed in README files
2. Put in documentation
3. Add to error messages
4. Include in config examples
5. Use in honeypot directories

${BOLD}Example markdown:${NC}
[Click here for more info]($url)

${BOLD}Example HTML:${NC}
<a href="$url">Documentation</a>

${BOLD}When clicked:${NC}
• Instant alert
• IP address captured
• User agent logged
• Referrer recorded

EOF
                add_token "url" "$url" "$description" "$url"
                return 0
            fi
        fi
    fi

    log_warn "URL tokens require canarytokens.org"
}

#=============================================================================
# Webhook Server (Self-Hosted)
#=============================================================================

start_webhook_server() {
    log_info "Starting webhook server on port $WEBHOOK_PORT..."

    if command -v python3 &> /dev/null; then
        # Python-based webhook server
        python3 -c "
import http.server
import json
from datetime import datetime
from urllib.parse import urlparse, parse_qs
import sys

class CanaryHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Log all access
        trigger_data = {
            'timestamp': datetime.now().isoformat(),
            'path': self.path,
            'ip': self.client_address[0],
            'user_agent': self.headers.get('User-Agent', 'Unknown'),
            'referer': self.headers.get('Referer', 'None')
        }

        print(f'[TRIGGER] {json.dumps(trigger_data)}', file=sys.stderr)

        # Return 1x1 transparent GIF
        self.send_response(200)
        self.send_header('Content-Type', 'image/gif')
        self.end_headers()

        # 1x1 transparent GIF
        gif = bytes([
            0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00,
            0x01, 0x00, 0x80, 0x00, 0x00, 0xFF, 0xFF, 0xFF,
            0x00, 0x00, 0x00, 0x21, 0xF9, 0x04, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
            0x01, 0x00, 0x3B
        ])
        self.wfile.write(gif)

    def log_message(self, format, *args):
        # Suppress default logging
        pass

server = http.server.HTTPServer(('$WEBHOOK_HOST', $WEBHOOK_PORT), CanaryHandler)
print(f'Webhook server listening on $WEBHOOK_HOST:$WEBHOOK_PORT')
server.serve_forever()
" 2>&1 | while read -r line; do
            if [[ "$line" == *"[TRIGGER]"* ]]; then
                local trigger_json=$(echo "$line" | sed 's/.*\[TRIGGER\] //')

                # Log trigger
                record_trigger "$trigger_json"

                # Alert
                if [[ $ALERT_ON_TRIGGER -eq 1 ]]; then
                    local ip=$(echo "$trigger_json" | jq -r '.ip')
                    local path=$(echo "$trigger_json" | jq -r '.path')
                    send_alert "🚨 CANARY TOKEN TRIGGERED!\nIP: $ip\nPath: $path"
                fi

                log_warn "CANARY TRIGGERED: $trigger_json"
            else
                echo "$line"
            fi
        done
    else
        log_error "Python3 required for webhook server"
        return 1
    fi
}

record_trigger() {
    local trigger_data=$1

    init_tokens_db

    local tmp_file=$(mktemp)

    jq --argjson trigger "$trigger_data" \
       '.triggers += [$trigger]' \
       "$TRIGGERS_LOG_FILE" > "$tmp_file"

    mv "$tmp_file" "$TRIGGERS_LOG_FILE"
}

#=============================================================================
# Trigger History
#=============================================================================

show_triggers() {
    if [[ ! -f "$TRIGGERS_LOG_FILE" ]]; then
        log_info "No triggers recorded yet"
        return 0
    fi

    echo -e "\n${BOLD}🚨 Canary Token Triggers${NC}\n"

    local count=$(jq '.triggers | length' "$TRIGGERS_LOG_FILE")
    echo "Total triggers: $count"
    echo

    jq -r '.triggers[-20:] | .[] |
        "[\(.timestamp)] IP: \(.ip)\n" +
        "  Path: \(.path)\n" +
        "  User-Agent: \(.user_agent)\n" +
        "  Referer: \(.referer)\n"' \
        "$TRIGGERS_LOG_FILE"
}

#=============================================================================
# Quick Setup
#=============================================================================

quick_setup() {
    cat <<EOF
${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}║          🕯️  CANARY TOKEN QUICK SETUP 🕯️               ║${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

${BOLD}What do you want to monitor?${NC}

1. Email tracking - Know when email is opened
2. Document access - PDF/Word with alerts
3. DNS queries - Monitor config files/scripts
4. AWS credentials - Honeypot cloud keys
5. URL clicks - Track link access

EOF

    read -p "Choose (1-5): " choice

    case $choice in
        1)
            read -p "Description (e.g., 'Email to suspect'): " desc
            generate_email_tracker "$desc"
            ;;
        2)
            read -p "Description: " desc
            echo "Choose format:"
            echo "  1. PDF"
            echo "  2. Word document"
            read -p "Choice: " format
            case $format in
                1) generate_pdf_canary "$desc" ;;
                2) generate_word_canary "$desc" ;;
            esac
            ;;
        3)
            read -p "Description: " desc
            generate_dns_canary "$desc"
            ;;
        4)
            read -p "Description: " desc
            generate_aws_canary "$desc"
            ;;
        5)
            read -p "Description: " desc
            generate_url_canary "$desc"
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Generate and manage canary tokens for access detection

COMMANDS:
    email [DESC]                 Generate email tracking pixel
    pdf [DESC]                   Generate PDF with canary
    word [DESC]                  Generate Word doc with canary
    dns [DESC]                   Generate DNS canary token
    aws [DESC]                   Generate AWS credential canary
    url [DESC]                   Generate URL canary
    list                         List all tokens
    triggers                     Show trigger history
    server                       Start webhook server
    setup                        Interactive quick setup

OPTIONS:
    --alert-email EMAIL          Email for alerts
    --public-url URL             Public URL for self-hosted tokens
    --port PORT                  Webhook server port (default: 8888)
    -h, --help                   Show this help

EXAMPLES:
    # Quick interactive setup
    $0 setup

    # Generate email tracker
    $0 email "Sent to suspicious contact"

    # Generate PDF canary
    $0 pdf "Confidential document"

    # Generate AWS honeypot credentials
    $0 aws "Fake production keys"

    # Generate DNS canary
    $0 dns "Config file monitor"

    # Start self-hosted server
    $0 server

    # View triggers
    $0 triggers

SERVICES:
    • Free: canarytokens.org (email tracking, DNS, AWS, etc.)
    • Self-hosted: Built-in webhook server

SETUP:
    1. Set alert email in config:
       export ALERT_EMAIL="you@example.com"

    2. For self-hosted tokens:
       export PUBLIC_URL="http://your-ip-or-domain.com"

    3. Generate tokens:
       $0 setup

USE CASES:
    • Email read receipts
    • Document access tracking
    • Credential theft detection
    • Data exfiltration monitoring
    • Honeypot deployment
    • Insider threat detection

ALERTS:
    • Email notifications
    • Webhook callbacks
    • Desktop notifications
    • Logged to file

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --alert-email)
                ALERT_EMAIL=$2
                shift 2
                ;;
            --public-url)
                PUBLIC_URL=$2
                shift 2
                ;;
            --port)
                WEBHOOK_PORT=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            email|pdf|word|dns|aws|url|list|triggers|server|setup)
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
    check_commands jq curl

    # Initialize
    init_tokens_db

    # Validate alert email for canarytokens.org
    if [[ $USE_CANARYTOKENS_ORG -eq 1 ]] && [[ -z "$ALERT_EMAIL" ]]; then
        log_warn "ALERT_EMAIL not set. Set it in config or use --alert-email"
    fi

    # Execute command
    case $command in
        email)
            generate_email_tracker "${1:-Email tracker}"
            ;;
        pdf)
            generate_pdf_canary "${1:-PDF document}"
            ;;
        word)
            generate_word_canary "${1:-Word document}"
            ;;
        dns)
            generate_dns_canary "${1:-DNS query}"
            ;;
        aws)
            generate_aws_canary "${1:-AWS credentials}"
            ;;
        url)
            generate_url_canary "${1:-URL link}"
            ;;
        list)
            list_tokens
            ;;
        triggers)
            show_triggers
            ;;
        server)
            start_webhook_server
            ;;
        setup)
            quick_setup
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
