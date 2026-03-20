#!/bin/bash
#=============================================================================
# paste-site-monitor.sh
# Monitor pastebin/GitHub gists for leaked credentials and company data
# "Found our prod database credentials on pastebin. Again."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

WATCH_LIST_FILE="$DATA_DIR/paste_watch_list.json"
FINDINGS_FILE="$DATA_DIR/paste_findings.json"
SEEN_PASTES_FILE="$DATA_DIR/seen_pastes.txt"

# Monitoring settings
CHECK_INTERVAL=900  # 15 minutes
ALERT_ON_MATCH=1
AUTO_ARCHIVE=1

# Paste sites to monitor
ENABLE_PASTEBIN=1
ENABLE_GITHUB_GISTS=1
ENABLE_PASTEBINCOM=1
ENABLE_SLEXY=1
ENABLE_GHOSTBIN=1

# API Keys (set in config)
PASTEBIN_API_KEY=${PASTEBIN_API_KEY:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Rate limiting
REQUESTS_PER_MINUTE=10
REQUEST_DELAY=6  # seconds between requests

#=============================================================================
# Watch List Management
#=============================================================================

init_watch_list() {
    if [[ ! -f "$WATCH_LIST_FILE" ]]; then
        cat > "$WATCH_LIST_FILE" <<'EOF'
{
  "keywords": [],
  "domains": [],
  "patterns": [],
  "email_addresses": []
}
EOF
        log_success "Initialized watch list"
    fi

    # Create seen pastes file
    if [[ ! -f "$SEEN_PASTES_FILE" ]]; then
        touch "$SEEN_PASTES_FILE"
    fi
}

add_keyword() {
    local keyword=$1
    init_watch_list

    local tmp_file=$(mktemp)
    jq --arg kw "$keyword" \
       '.keywords += [$kw] | .keywords |= unique' \
       "$WATCH_LIST_FILE" > "$tmp_file"

    mv "$tmp_file" "$WATCH_LIST_FILE"
    log_success "Added keyword: $keyword"
}

add_domain() {
    local domain=$1
    init_watch_list

    local tmp_file=$(mktemp)
    jq --arg domain "$domain" \
       '.domains += [$domain] | .domains |= unique' \
       "$WATCH_LIST_FILE" > "$tmp_file"

    mv "$tmp_file" "$WATCH_LIST_FILE"
    log_success "Added domain: $domain"
}

add_email() {
    local email=$1
    init_watch_list

    local tmp_file=$(mktemp)
    jq --arg email "$email" \
       '.email_addresses += [$email] | .email_addresses |= unique' \
       "$WATCH_LIST_FILE" > "$tmp_file"

    mv "$tmp_file" "$WATCH_LIST_FILE"
    log_success "Added email: $email"
}

add_pattern() {
    local pattern=$1
    init_watch_list

    local tmp_file=$(mktemp)
    jq --arg pattern "$pattern" \
       '.patterns += [$pattern] | .patterns |= unique' \
       "$WATCH_LIST_FILE" > "$tmp_file"

    mv "$tmp_file" "$WATCH_LIST_FILE"
    log_success "Added pattern: $pattern"
}

list_watch_items() {
    init_watch_list

    echo -e "\n${BOLD}👁️  Watch List${NC}\n"

    echo -e "${BOLD}Keywords:${NC}"
    jq -r '.keywords[]' "$WATCH_LIST_FILE" | sed 's/^/  • /'
    echo

    echo -e "${BOLD}Domains:${NC}"
    jq -r '.domains[]' "$WATCH_LIST_FILE" | sed 's/^/  • /'
    echo

    echo -e "${BOLD}Email Addresses:${NC}"
    jq -r '.email_addresses[]' "$WATCH_LIST_FILE" | sed 's/^/  • /'
    echo

    echo -e "${BOLD}Regex Patterns:${NC}"
    jq -r '.patterns[]' "$WATCH_LIST_FILE" | sed 's/^/  • /'
    echo
}

#=============================================================================
# Paste Site Scrapers
#=============================================================================

fetch_pastebin_recent() {
    if [[ $ENABLE_PASTEBIN -ne 1 ]]; then
        return 0
    fi

    if [[ -z "$PASTEBIN_API_KEY" ]]; then
        log_warn "Pastebin API key not set. Skipping."
        return 0
    fi

    log_debug "Fetching recent Pastebin pastes..."

    # Use Pastebin scraping API
    local response=$(curl -s "https://scrape.pastebin.com/api_scraping.php?limit=100" \
        -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "[]")

    echo "$response"
}

fetch_github_gists_recent() {
    if [[ $ENABLE_GITHUB_GISTS -ne 1 ]]; then
        return 0
    fi

    log_debug "Fetching recent GitHub Gists..."

    local -a curl_args=(-s)
    if [[ -n "$GITHUB_TOKEN" ]]; then
        curl_args+=(-H "Authorization: token $GITHUB_TOKEN")
    fi

    local response=$(curl "${curl_args[@]}" "https://api.github.com/gists/public?per_page=100" 2>/dev/null || echo "[]")

    echo "$response"
}

fetch_pastebincom_recent() {
    # Note: pastebin.com doesn't have a public API for recent pastes
    # This would require web scraping

    if [[ $ENABLE_PASTEBINCOM -ne 1 ]]; then
        return 0
    fi

    log_debug "Scraping pastebin.com..."

    # Would scrape https://pastebin.com/archive
    local response=$(curl -s "https://pastebin.com/archive" 2>/dev/null || echo "")

    # Parse HTML for paste links
    echo "$response" | grep -oE '/[a-zA-Z0-9]{8}' | head -100
}

#=============================================================================
# Content Analysis
#=============================================================================

check_paste_content() {
    local paste_id=$1
    local paste_url=$2
    local paste_content=$3

    init_watch_list

    local matches=()

    # Check keywords
    while IFS= read -r keyword; do
        [[ -z "$keyword" ]] && continue

        if echo "$paste_content" | grep -qi "$keyword"; then
            matches+=("keyword:$keyword")
        fi
    done < <(jq -r '.keywords[]' "$WATCH_LIST_FILE")

    # Check domains
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue

        if echo "$paste_content" | grep -qi "$domain"; then
            matches+=("domain:$domain")
        fi
    done < <(jq -r '.domains[]' "$WATCH_LIST_FILE")

    # Check email addresses
    while IFS= read -r email; do
        [[ -z "$email" ]] && continue

        if echo "$paste_content" | grep -qiF "$email"; then
            matches+=("email:$email")
        fi
    done < <(jq -r '.email_addresses[]' "$WATCH_LIST_FILE")

    # Check regex patterns
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue

        if echo "$paste_content" | grep -qE "$pattern"; then
            matches+=("pattern:$pattern")
        fi
    done < <(jq -r '.patterns[]' "$WATCH_LIST_FILE")

    # If matches found, record
    if [[ ${#matches[@]} -gt 0 ]]; then
        record_finding "$paste_id" "$paste_url" "${matches[@]}"
        return 0
    fi

    return 1
}

#=============================================================================
# Finding Management
#=============================================================================

record_finding() {
    local paste_id=$1
    local paste_url=$2
    shift 2
    local matches=("$@")

    mkdir -p "$DATA_DIR"

    if [[ ! -f "$FINDINGS_FILE" ]]; then
        echo '{"findings": []}' > "$FINDINGS_FILE"
    fi

    local matches_json=$(printf '%s\n' "${matches[@]}" | jq -R . | jq -s .)
    local tmp_file=$(mktemp)

    jq --arg id "$paste_id" \
       --arg url "$paste_url" \
       --argjson matches "$matches_json" \
       --arg timestamp "$(date -Iseconds)" \
       '.findings += [{
           timestamp: $timestamp,
           paste_id: $id,
           url: $url,
           matches: $matches,
           archived: false,
           reviewed: false
       }]' \
       "$FINDINGS_FILE" > "$tmp_file"

    mv "$tmp_file" "$FINDINGS_FILE"

    log_success "Found leak: $paste_url"
    echo -e "${YELLOW}Matches: ${matches[*]}${NC}"

    # Alert
    if [[ $ALERT_ON_MATCH -eq 1 ]]; then
        send_alert "🚨 Paste Leak Detected!\n$paste_url\nMatches: ${matches[*]}"
    fi

    # Auto archive
    if [[ $AUTO_ARCHIVE -eq 1 ]]; then
        archive_paste "$paste_id" "$paste_url"
    fi
}

archive_paste() {
    local paste_id=$1
    local paste_url=$2

    log_info "Archiving paste: $paste_id"

    local archive_dir="$DATA_DIR/archived_pastes"
    mkdir -p "$archive_dir"

    # Download paste content
    local content=$(curl -s "$paste_url/raw" 2>/dev/null || curl -s "$paste_url" 2>/dev/null || echo "Failed to download")

    # Save to file
    local archive_file="$archive_dir/${paste_id}_$(date +%Y%m%d_%H%M%S).txt"
    echo "$content" > "$archive_file"

    # Update finding as archived
    local tmp_file=$(mktemp)
    jq --arg id "$paste_id" \
       '(.findings[] | select(.paste_id == $id)).archived = true' \
       "$FINDINGS_FILE" > "$tmp_file"

    mv "$tmp_file" "$FINDINGS_FILE"

    log_success "Archived to: $archive_file"
}

#=============================================================================
# Monitoring Loop
#=============================================================================

is_seen() {
    local paste_id=$1
    grep -qF "$paste_id" "$SEEN_PASTES_FILE"
}

mark_seen() {
    local paste_id=$1
    echo "$paste_id" >> "$SEEN_PASTES_FILE"

    # Keep only last 10000 entries
    tail -10000 "$SEEN_PASTES_FILE" > "${SEEN_PASTES_FILE}.tmp"
    mv "${SEEN_PASTES_FILE}.tmp" "$SEEN_PASTES_FILE"
}

scan_pastebin() {
    log_info "Scanning Pastebin..."

    local pastes=$(fetch_pastebin_recent)

    local checked=0
    local found=0

    while read -r paste; do
        local paste_key=$(echo "$paste" | jq -r '.key')
        local paste_url="https://pastebin.com/$paste_key"

        # Skip if already seen
        if is_seen "$paste_key"; then
            continue
        fi

        # Rate limiting
        sleep "$REQUEST_DELAY"

        # Fetch content
        local content=$(curl -s "https://pastebin.com/raw/$paste_key" 2>/dev/null || echo "")

        if [[ -z "$content" ]]; then
            continue
        fi

        # Check for matches
        if check_paste_content "$paste_key" "$paste_url" "$content"; then
            ((found++))
        fi

        mark_seen "$paste_key"
        ((checked++))
    done < <(echo "$pastes" | jq -c '.[]' 2>/dev/null)

    log_info "Checked $checked pastes, found $found matches"
}

scan_github_gists() {
    log_info "Scanning GitHub Gists..."

    local gists=$(fetch_github_gists_recent)

    local checked=0
    local found=0

    while read -r gist; do
        local gist_id=$(echo "$gist" | jq -r '.id')
        local gist_url=$(echo "$gist" | jq -r '.html_url')

        # Skip if already seen
        if is_seen "$gist_id"; then
            continue
        fi

        # Rate limiting
        sleep "$REQUEST_DELAY"

        # Fetch gist content
        local files=$(echo "$gist" | jq -r '.files | to_entries[] | .value.raw_url')

        local content=""
        for file_url in $files; do
            content+=$(curl -s "$file_url" 2>/dev/null || echo "")
            content+=$'\n'
        done

        if [[ -z "$content" ]]; then
            continue
        fi

        # Check for matches
        if check_paste_content "$gist_id" "$gist_url" "$content"; then
            ((found++))
        fi

        mark_seen "$gist_id"
        ((checked++))
    done < <(echo "$gists" | jq -c '.[]' 2>/dev/null)

    log_info "Checked $checked gists, found $found matches"
}

monitor_loop() {
    log_info "Starting paste site monitor (Ctrl+C to stop)..."
    log_info "Check interval: $(human_time_diff "$CHECK_INTERVAL")"

    while true; do
        log_info "=== Starting scan cycle at $(date) ==="

        # Scan each enabled site
        if [[ $ENABLE_PASTEBIN -eq 1 ]]; then
            scan_pastebin
        fi

        if [[ $ENABLE_GITHUB_GISTS -eq 1 ]]; then
            scan_github_gists
        fi

        log_info "Scan cycle complete. Sleeping for $(human_time_diff "$CHECK_INTERVAL")..."
        sleep "$CHECK_INTERVAL"
    done
}

#=============================================================================
# Reports
#=============================================================================

show_findings() {
    if [[ ! -f "$FINDINGS_FILE" ]]; then
        log_info "No findings yet"
        return 0
    fi

    echo -e "\n${BOLD}🚨 Leak Findings${NC}\n"

    local total=$(jq '.findings | length' "$FINDINGS_FILE")
    local unreviewed=$(jq '[.findings[] | select(.reviewed == false)] | length' "$FINDINGS_FILE")

    echo "Total findings: $total"
    echo "Unreviewed: $unreviewed"
    echo

    echo -e "${BOLD}Recent findings:${NC}"
    jq -r '.findings[-20:] | .[] |
        "[\(.timestamp)] \(.url)\n  Matches: \(.matches | join(", "))\n  Archived: \(.archived), Reviewed: \(.reviewed)\n"' \
        "$FINDINGS_FILE"
}

mark_reviewed() {
    local paste_id=$1

    if [[ ! -f "$FINDINGS_FILE" ]]; then
        log_error "No findings file"
        return 1
    fi

    local tmp_file=$(mktemp)
    jq --arg id "$paste_id" \
       '(.findings[] | select(.paste_id == $id)).reviewed = true' \
       "$FINDINGS_FILE" > "$tmp_file"

    mv "$tmp_file" "$FINDINGS_FILE"

    log_success "Marked as reviewed: $paste_id"
}

export_findings() {
    local output_file=${1:-"paste_findings_$(date +%Y%m%d).csv"}

    if [[ ! -f "$FINDINGS_FILE" ]]; then
        log_error "No findings to export"
        return 1
    fi

    log_info "Exporting findings to $output_file..."

    # CSV header
    echo "Timestamp,Paste ID,URL,Matches,Archived,Reviewed" > "$output_file"

    # Export data
    jq -r '.findings[] |
        [.timestamp, .paste_id, .url, (.matches | join(";")), .archived, .reviewed] |
        @csv' \
        "$FINDINGS_FILE" >> "$output_file"

    log_success "Exported $(jq '.findings | length' "$FINDINGS_FILE") findings to $output_file"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Monitor paste sites for leaked credentials and data

COMMANDS:
    scan                         Run single scan cycle
    monitor                      Start continuous monitoring
    findings                     Show all findings
    add-keyword KEYWORD          Add keyword to watch
    add-domain DOMAIN            Add domain to watch
    add-email EMAIL              Add email to watch
    add-pattern PATTERN          Add regex pattern to watch
    list                         List watch items
    review PASTE_ID              Mark finding as reviewed
    export [FILE]                Export findings to CSV

OPTIONS:
    --interval SECONDS           Check interval (default: 900)
    --no-alert                   Don't send alerts on match
    --no-archive                 Don't auto-archive matches
    -h, --help                   Show this help

EXAMPLES:
    # Add items to watch
    $0 add-keyword "company-name"
    $0 add-domain "company.com"
    $0 add-email "admin@company.com"
    $0 add-pattern "api[_-]key.*[A-Za-z0-9]{32}"

    # Run single scan
    $0 scan

    # Start continuous monitoring
    $0 monitor

    # View findings
    $0 findings

    # Export to CSV
    $0 export leaks_report.csv

SETUP:
    1. Get Pastebin API key: https://pastebin.com/doc_scraping_api
    2. Get GitHub token: https://github.com/settings/tokens
    3. Set in config file:
       export PASTEBIN_API_KEY="your_key"
       export GITHUB_TOKEN="your_token"

MONITORED SITES:
    • Pastebin (requires API key)
    • GitHub Gists
    • Pastebin.com archive
    • More coming soon...

AUTOMATION:
    # Run every 15 minutes (crontab)
    */15 * * * * $SCRIPT_DIR/paste-site-monitor.sh scan

    # Continuous monitoring (systemd or screen)
    $0 monitor

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
                ALERT_ON_MATCH=0
                shift
                ;;
            --no-archive)
                AUTO_ARCHIVE=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            scan|monitor|findings|add-keyword|add-domain|add-email|add-pattern|list|review|export)
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
    init_watch_list

    # Execute command
    case $command in
        scan)
            if [[ $ENABLE_PASTEBIN -eq 1 ]]; then
                scan_pastebin
            fi
            if [[ $ENABLE_GITHUB_GISTS -eq 1 ]]; then
                scan_github_gists
            fi
            ;;
        monitor)
            monitor_loop
            ;;
        findings)
            show_findings
            ;;
        add-keyword)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: add-keyword KEYWORD"
                exit 1
            fi
            add_keyword "$1"
            ;;
        add-domain)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: add-domain DOMAIN"
                exit 1
            fi
            add_domain "$1"
            ;;
        add-email)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: add-email EMAIL"
                exit 1
            fi
            add_email "$1"
            ;;
        add-pattern)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: add-pattern PATTERN"
                exit 1
            fi
            add_pattern "$1"
            ;;
        list)
            list_watch_items
            ;;
        review)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: review PASTE_ID"
                exit 1
            fi
            mark_reviewed "$1"
            ;;
        export)
            export_findings "$@"
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
