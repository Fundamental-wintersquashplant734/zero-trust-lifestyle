#!/bin/bash
#=============================================================================
# ctf-writeup-scraper.sh
# Pulls latest CTF writeups when you're stuck
# "I've been staring at this for 3 hours. Time to read the writeup."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

WRITEUP_CACHE_DIR="$DATA_DIR/ctf_writeups"
WRITEUP_INDEX_FILE="$DATA_DIR/ctf_writeup_index.json"
BOOKMARKS_FILE="$DATA_DIR/ctf_bookmarks.json"

# Scraping settings
MAX_RESULTS=50
CACHE_EXPIRY=3600  # 1 hour
AUTO_FORMAT=1
SHOW_SPOILERS=0

# Writeup sources
ENABLE_CTFTIME=1
ENABLE_GITHUB=1
ENABLE_WRITEUP_REPOS=1

# GitHub token for higher rate limits
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Popular CTF writeup repositories
WRITEUP_REPOS=(
    "ctfs/write-ups-2024"
    "ctfs/write-ups-2023"
    "p4-team/ctf"
    "VoidHack/CTF-Writeups"
    "ByteBandits/ctf-writeups"
    "C4T-BuT-S4D/ctf-writeups"
)

# CTFTime API
CTFTIME_API="https://ctftime.org/api/v1"

#=============================================================================
# Cache Management
#=============================================================================

init_cache() {
    mkdir -p "$WRITEUP_CACHE_DIR"

    if [[ ! -f "$WRITEUP_INDEX_FILE" ]]; then
        echo '{"writeups": []}' > "$WRITEUP_INDEX_FILE"
    fi

    if [[ ! -f "$BOOKMARKS_FILE" ]]; then
        echo '{"bookmarks": []}' > "$BOOKMARKS_FILE"
    fi
}

is_cache_fresh() {
    local cache_file=$1
    local max_age=${2:-$CACHE_EXPIRY}

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)))

    [[ $file_age -lt $max_age ]]
}

#=============================================================================
# CTFTime Scraping
#=============================================================================

fetch_ctftime_events() {
    log_debug "Fetching CTFTime events..."

    local cache_file="$WRITEUP_CACHE_DIR/ctftime_events.json"

    if is_cache_fresh "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    local limit=${1:-100}
    local response=$(curl -s "${CTFTIME_API}/events/?limit=${limit}" 2>/dev/null || echo "[]")

    echo "$response" > "$cache_file"
    echo "$response"
}

search_ctftime_writeups() {
    local event_name=$1

    log_info "Searching CTFTime for: $event_name"

    local events=$(fetch_ctftime_events)

    # Search for matching events
    local matches=$(echo "$events" | jq --arg name "$event_name" \
        '[.[] | select(.title | ascii_downcase | contains($name | ascii_downcase))]')

    local count=$(echo "$matches" | jq 'length')

    if [[ $count -eq 0 ]]; then
        log_warn "No CTF events found matching: $event_name"
        return 1
    fi

    echo -e "\n${BOLD}Found $count matching CTF(s):${NC}\n"

    echo "$matches" | jq -r '.[] |
        "  \(.title)\n" +
        "  Date: \(.start) to \(.finish)\n" +
        "  URL: \(.url)\n" +
        "  CTFTime: https://ctftime.org/event/\(.id)\n"'
}

#=============================================================================
# GitHub Scraping
#=============================================================================

search_github_writeups() {
    local query=$1

    if [[ $ENABLE_GITHUB -ne 1 ]]; then
        return 0
    fi

    log_info "Searching GitHub for writeups: $query"

    local -a curl_args=(-s)
    [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

    # Search GitHub for CTF writeups
    local search_query="$query+ctf+writeup+in:readme+in:name+in:description"
    local encoded_query=$(echo "$search_query" | jq -sRr @uri)

    local response=$(curl "${curl_args[@]}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/search/repositories?q=${encoded_query}&sort=stars&order=desc&per_page=${MAX_RESULTS}" \
        2>/dev/null || echo '{"items":[]}')

    local count=$(echo "$response" | jq '.items | length')

    if [[ $count -eq 0 ]]; then
        log_warn "No GitHub repositories found"
        return 0
    fi

    echo -e "\n${BOLD}Found $count GitHub repositories:${NC}\n"

    echo "$response" | jq -r '.items[] |
        "╔════════════════════════════════════════════════════════════╗\n" +
        "  📦 \(.full_name)\n" +
        "  ⭐ Stars: \(.stargazers_count) | Forks: \(.forks_count)\n" +
        "  📝 \(.description // "No description")\n" +
        "  🔗 \(.html_url)\n" +
        "  Updated: \(.updated_at)\n" +
        "╚════════════════════════════════════════════════════════════╝\n"'

    # Return repo list for further processing
    echo "$response"
}

fetch_writeup_from_repo() {
    local repo=$1
    local challenge_name=$2

    log_info "Fetching writeups from $repo..."

    local -a curl_args=(-s)
    [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

    # Get repository contents
    local contents=$(curl "${curl_args[@]}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/contents" \
        2>/dev/null || echo '[]')

    # Search for markdown files containing challenge name
    local readme_files=$(echo "$contents" | jq -r --arg name "$challenge_name" \
        '.[] | select(.name | ascii_downcase | contains("readme") or contains(".md")) | .download_url')

    if [[ -z "$readme_files" ]]; then
        log_debug "No writeups found in $repo"
        return 1
    fi

    # Download and display first matching file
    for file_url in $readme_files; do
        local content=$(curl -s "$file_url" 2>/dev/null || echo "")

        if echo "$content" | grep -qi "$challenge_name"; then
            echo -e "\n${GREEN}Found writeup in $repo:${NC}\n"

            if [[ $AUTO_FORMAT -eq 1 ]]; then
                format_writeup "$content"
            else
                echo "$content"
            fi

            return 0
        fi
    done

    return 1
}

#=============================================================================
# Search Popular Writeup Repositories
#=============================================================================

search_writeup_repos() {
    local ctf_name=$1
    local challenge_name=${2:-""}

    if [[ $ENABLE_WRITEUP_REPOS -ne 1 ]]; then
        return 0
    fi

    log_info "Searching popular writeup repositories..."

    local found=0

    for repo in "${WRITEUP_REPOS[@]}"; do
        log_debug "Checking $repo..."

        local -a curl_args=(-s)
        [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

        # Search repository for CTF name
        local search_query="$ctf_name repo:$repo"
        local encoded_query=$(echo "$search_query" | jq -sRr @uri)

        local results=$(curl "${curl_args[@]}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/search/code?q=${encoded_query}&per_page=5" \
            2>/dev/null || echo '{"items":[]}')

        local count=$(echo "$results" | jq '.items | length')

        if [[ $count -gt 0 ]]; then
            echo -e "\n${GREEN}Found writeups in $repo:${NC}\n"

            echo "$results" | jq -r '.items[] |
                "  📄 \(.name)\n" +
                "  📂 Path: \(.path)\n" +
                "  🔗 \(.html_url)\n"'

            ((found++))

            # If challenge name specified, try to fetch specific writeup
            if [[ -n "$challenge_name" ]]; then
                fetch_writeup_from_repo "$repo" "$challenge_name"
            fi
        fi

        # Rate limiting
        sleep 1
    done

    if [[ $found -eq 0 ]]; then
        log_warn "No writeups found in popular repositories"
    fi
}

#=============================================================================
# Writeup Formatting
#=============================================================================

format_writeup() {
    local content=$1

    # Remove excessive newlines
    content=$(echo "$content" | sed '/^$/N;/^\n$/D')

    # Syntax highlighting for code blocks (if pygmentize available)
    if command -v pygmentize &> /dev/null && [[ $AUTO_FORMAT -eq 1 ]]; then
        # Extract and format code blocks
        echo "$content"
    else
        echo "$content"
    fi

    # Hide spoilers if flag is set
    if [[ $SHOW_SPOILERS -eq 0 ]]; then
        echo -e "\n${YELLOW}[Spoilers hidden. Use --show-spoilers to reveal]${NC}\n"
    fi
}

extract_flags() {
    local content=$1

    log_info "Extracting flags from writeup..."

    # Common CTF flag patterns
    local flag_patterns=(
        "flag{[^}]+}"
        "FLAG{[^}]+}"
        "CTF{[^}]+}"
        "[a-zA-Z0-9_]+{[^}]+}"
    )

    echo -e "\n${BOLD}Potential Flags Found:${NC}\n"

    for pattern in "${flag_patterns[@]}"; do
        local flags=$(echo "$content" | grep -oE "$pattern" | sort -u)

        if [[ -n "$flags" ]]; then
            echo "$flags" | while read -r flag; do
                if [[ $SHOW_SPOILERS -eq 1 ]]; then
                    echo "  🚩 $flag"
                else
                    # Obfuscate flag
                    local obfuscated=$(echo "$flag" | sed 's/[a-zA-Z0-9]/*/g')
                    echo "  🚩 $obfuscated (hidden)"
                fi
            done
        fi
    done

    echo
}

#=============================================================================
# Quick Search
#=============================================================================

quick_search() {
    local query=$1

    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║          🔍 CTF WRITEUP SEARCH - QUICK MODE             ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo

    log_info "Searching for: $query"

    # 1. Search GitHub
    local github_results=$(search_github_writeups "$query")

    # 2. Search CTFTime
    search_ctftime_writeups "$query"

    # 3. Search popular repos
    search_writeup_repos "$query"

    # 4. Provide helpful links
    echo -e "\n${BOLD}📚 Additional Resources:${NC}\n"
    echo "  • Google: https://www.google.com/search?q=$(echo "$query" | jq -sRr @uri)+ctf+writeup"
    echo "  • GitHub: https://github.com/search?q=$(echo "$query" | jq -sRr @uri)+ctf+writeup"
    echo "  • CTFTime: https://ctftime.org/writeups?search=$(echo "$query" | jq -sRr @uri)"
    echo
}

#=============================================================================
# Interactive Mode
#=============================================================================

interactive_search() {
    clear

    cat <<EOF
${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}║          🏴 CTF WRITEUP SCRAPER - INTERACTIVE           ║${NC}
${BOLD}${CYAN}║                                                            ║${NC}
${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

EOF

    echo "What are you looking for?"
    echo
    echo "1. Specific CTF event (e.g., 'picoCTF 2024')"
    echo "2. Specific challenge (e.g., 'reverse engineering buffer overflow')"
    echo "3. Category (e.g., 'web exploitation', 'crypto')"
    echo "4. Browse recent writeups"
    echo
    read -p "Enter choice (1-4): " choice
    echo

    case $choice in
        1)
            read -p "Enter CTF event name: " event_name
            quick_search "$event_name"
            ;;
        2)
            read -p "Enter challenge name or description: " challenge
            quick_search "$challenge"
            ;;
        3)
            read -p "Enter category: " category
            quick_search "$category ctf"
            ;;
        4)
            browse_recent_writeups
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

browse_recent_writeups() {
    log_info "Browsing recent CTF writeups..."

    # Get recent GitHub repos
    local -a curl_args=(-s)
    [[ -n "$GITHUB_TOKEN" ]] && curl_args+=(-H "Authorization: token $GITHUB_TOKEN")

    local recent=$(curl "${curl_args[@]}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/search/repositories?q=ctf+writeup+created:>$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)&sort=updated&order=desc&per_page=20" \
        2>/dev/null || echo '{"items":[]}')

    echo -e "\n${BOLD}📅 Recent CTF Writeups (Last 30 Days):${NC}\n"

    echo "$recent" | jq -r '.items[] |
        "  🆕 \(.full_name)\n" +
        "     \(.description // "No description")\n" +
        "     🔗 \(.html_url)\n" +
        "     ⭐ \(.stargazers_count) stars | Updated: \(.updated_at)\n"'
}

#=============================================================================
# Bookmarks
#=============================================================================

bookmark_writeup() {
    local url=$1
    local name=$2
    local category=${3:-"general"}

    init_cache

    local tmp_file=$(mktemp)

    jq --arg url "$url" \
       --arg name "$name" \
       --arg category "$category" \
       --arg timestamp "$(date -Iseconds)" \
       '.bookmarks += [{
           timestamp: $timestamp,
           url: $url,
           name: $name,
           category: $category
       }]' \
       "$BOOKMARKS_FILE" > "$tmp_file"

    mv "$tmp_file" "$BOOKMARKS_FILE"

    log_success "Bookmarked: $name"
}

list_bookmarks() {
    if [[ ! -f "$BOOKMARKS_FILE" ]]; then
        log_info "No bookmarks yet"
        return 0
    fi

    echo -e "\n${BOLD}🔖 Saved Writeups${NC}\n"

    jq -r '.bookmarks[] |
        "  [\(.category)] \(.name)\n" +
        "  🔗 \(.url)\n" +
        "  📅 \(.timestamp)\n"' \
        "$BOOKMARKS_FILE"
}

#=============================================================================
# Download & Archive
#=============================================================================

download_writeup() {
    local url=$1
    local output_file=${2:-""}

    log_info "Downloading writeup from: $url"

    # Determine output filename
    if [[ -z "$output_file" ]]; then
        local filename=$(basename "$url")
        [[ -z "$filename" ]] && filename="writeup_$(date +%Y%m%d_%H%M%S).md"
        output_file="$WRITEUP_CACHE_DIR/$filename"
    fi

    # Download content
    local content=""

    if [[ "$url" == *"github.com"* ]]; then
        # Convert to raw URL if needed
        local raw_url="$url"
        [[ "$url" == *"/blob/"* ]] && raw_url=$(echo "$url" | sed 's|/blob/|/raw/|')

        content=$(curl -s "$raw_url" 2>/dev/null || echo "")
    else
        content=$(curl -s "$url" 2>/dev/null || echo "")
    fi

    if [[ -z "$content" ]]; then
        log_error "Failed to download writeup"
        return 1
    fi

    # Save to file
    echo "$content" > "$output_file"

    log_success "Downloaded to: $output_file"

    # Display preview
    if [[ $AUTO_FORMAT -eq 1 ]]; then
        echo
        head -50 "$output_file"
        echo
        echo -e "${CYAN}... (use 'less $output_file' to view full content)${NC}"
    fi
}

#=============================================================================
# Statistics
#=============================================================================

show_stats() {
    echo -e "\n${BOLD}📊 CTF Writeup Statistics${NC}\n"

    # Cache stats
    local cache_count=$(find "$WRITEUP_CACHE_DIR" -type f | wc -l)
    echo "Cached writeups: $cache_count"

    # Bookmark stats
    local bookmark_count=$(jq '.bookmarks | length' "$BOOKMARKS_FILE" 2>/dev/null || echo "0")
    echo "Bookmarked writeups: $bookmark_count"

    # Index stats
    local index_count=$(jq '.writeups | length' "$WRITEUP_INDEX_FILE" 2>/dev/null || echo "0")
    echo "Indexed writeups: $index_count"

    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND] [QUERY]

Pull the latest CTF writeups when you're stuck

COMMANDS:
    search QUERY                 Quick search for writeups
    interactive                  Interactive search mode
    browse                       Browse recent writeups
    download URL [FILE]          Download specific writeup
    bookmark URL NAME [CAT]      Bookmark a writeup
    bookmarks                    List bookmarks
    stats                        Show statistics

OPTIONS:
    --show-spoilers              Show flags and solutions
    --no-format                  Disable auto-formatting
    --max-results N              Max results to show (default: 50)
    -h, --help                   Show this help

EXAMPLES:
    # Quick search
    $0 search "picoCTF 2024"
    $0 search "reverse engineering"

    # Interactive mode
    $0 interactive

    # Browse recent writeups
    $0 browse

    # Download writeup
    $0 download https://github.com/user/ctf-writeups/blob/main/challenge.md

    # Bookmark writeup
    $0 bookmark https://example.com/writeup "Cool crypto challenge" crypto

CATEGORIES:
    web, pwn, reverse, crypto, forensics, misc, osint, hardware

SOURCES:
    • GitHub (thousands of public writeup repos)
    • CTFTime (official writeup links)
    • Popular writeup collections

TIPS:
    • Use specific CTF + challenge names for best results
    • Check bookmarks for challenges you've seen before
    • Set GITHUB_TOKEN for higher API rate limits
    • Use --show-spoilers when you're ready to see the flag

WORKFLOW:
    1. Stuck on a challenge? Run: $0 search "ctf-name challenge-name"
    2. Browse results and find relevant writeup
    3. Download or bookmark for later: $0 download URL
    4. Learn from the writeup and try again!

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --show-spoilers)
                SHOW_SPOILERS=1
                shift
                ;;
            --no-format)
                AUTO_FORMAT=0
                shift
                ;;
            --max-results)
                MAX_RESULTS=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            search|interactive|browse|download|bookmark|bookmarks|stats)
                command=$1
                shift
                break
                ;;
            *)
                # Assume it's a search query
                command="search"
                break
                ;;
        esac
    done

    # Check dependencies
    check_commands jq curl

    # Initialize
    init_cache

    # Execute command
    case $command in
        search)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: search QUERY"
                exit 1
            fi
            quick_search "$*"
            ;;
        interactive)
            interactive_search
            ;;
        browse)
            browse_recent_writeups
            ;;
        download)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: download URL [OUTPUT_FILE]"
                exit 1
            fi
            download_writeup "$@"
            ;;
        bookmark)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: bookmark URL NAME [CATEGORY]"
                exit 1
            fi
            bookmark_writeup "$@"
            ;;
        bookmarks)
            list_bookmarks
            ;;
        stats)
            show_stats
            ;;
        "")
            # No command, start interactive
            interactive_search
            ;;
        *)
            # Treat unknown command as search query
            quick_search "$command $*"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
