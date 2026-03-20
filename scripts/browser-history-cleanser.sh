#!/bin/bash
#=============================================================================
# browser-history-cleanser.sh
# Nuclear option for browser history when you've been researching... stuff
# "What malware sites? I was just browsing cat videos!"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

# Browsers to clean
CLEAN_FIREFOX=${CLEAN_FIREFOX:-1}
CLEAN_CHROME=${CLEAN_CHROME:-1}
CLEAN_CHROMIUM=${CLEAN_CHROMIUM:-1}
CLEAN_BRAVE=${CLEAN_BRAVE:-1}
CLEAN_EDGE=${CLEAN_EDGE:-1}
CLEAN_OPERA=${CLEAN_OPERA:-1}

# What to clean
CLEAN_HISTORY=${CLEAN_HISTORY:-1}
CLEAN_COOKIES=${CLEAN_COOKIES:-1}
CLEAN_CACHE=${CLEAN_CACHE:-1}
CLEAN_DOWNLOADS=${CLEAN_DOWNLOADS:-1}
CLEAN_SESSIONS=${CLEAN_SESSIONS:-1}
CLEAN_PASSWORDS=${CLEAN_PASSWORDS:-0}  # Disabled by default!

# Safety
CREATE_BACKUP=${CREATE_BACKUP:-1}
BACKUP_DIR="$DATA_DIR/browser_backups"
MAX_BACKUPS=${MAX_BACKUPS:-5}

# Whitelist (sites you DON'T want to delete)
WHITELIST_DOMAINS=(
    "github.com"
    "stackoverflow.com"
    "localhost"
)

#=============================================================================
# Browser Profile Detection
#=============================================================================

get_firefox_profiles() {
    local profiles=()

    case $(get_os) in
        linux)
            local ff_dir="$HOME/.mozilla/firefox"
            ;;
        macos)
            local ff_dir="$HOME/Library/Application Support/Firefox/Profiles"
            ;;
        *)
            return 1
            ;;
    esac

    if [[ -d "$ff_dir" ]]; then
        while IFS= read -r profile; do
            profiles+=("$profile")
        done < <(find "$ff_dir" -maxdepth 1 -type d -name "*.default*" 2>/dev/null)
    fi

    printf '%s\n' "${profiles[@]}"
}

get_chrome_profiles() {
    local profiles=()
    local chrome_dirs=()

    case $(get_os) in
        linux)
            chrome_dirs=(
                "$HOME/.config/google-chrome"
                "$HOME/.config/chromium"
                "$HOME/.config/BraveSoftware/Brave-Browser"
                "$HOME/.config/microsoft-edge"
            )
            ;;
        macos)
            chrome_dirs=(
                "$HOME/Library/Application Support/Google/Chrome"
                "$HOME/Library/Application Support/Chromium"
                "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
                "$HOME/Library/Application Support/Microsoft Edge"
            )
            ;;
        *)
            return 1
            ;;
    esac

    for dir in "${chrome_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Default profile
            [[ -d "$dir/Default" ]] && profiles+=("$dir/Default")

            # Additional profiles
            while IFS= read -r profile; do
                profiles+=("$profile")
            done < <(find "$dir" -maxdepth 1 -type d -name "Profile *" 2>/dev/null)
        fi
    done

    printf '%s\n' "${profiles[@]}"
}

#=============================================================================
# Backup Functions
#=============================================================================

create_backup() {
    local source=$1
    local browser_name=$2

    if [[ $CREATE_BACKUP -eq 0 ]]; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/${browser_name}_${timestamp}.tar.gz"

    log_info "Creating backup: $backup_file"

    if tar -czf "$backup_file" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null; then
        log_success "Backup created successfully"

        # Cleanup old backups
        local backup_count=$(find "$BACKUP_DIR" -name "${browser_name}_*.tar.gz" | wc -l)
        if [[ $backup_count -gt $MAX_BACKUPS ]]; then
            log_info "Cleaning up old backups (keeping last $MAX_BACKUPS)"
            find "$BACKUP_DIR" -name "${browser_name}_*.tar.gz" -type f -printf '%T+ %p\n' | \
                sort -r | tail -n +$((MAX_BACKUPS + 1)) | cut -d' ' -f2- | xargs -r rm
        fi

        return 0
    else
        log_warn "Failed to create backup"
        return 1
    fi
}

restore_backup() {
    local browser_name=$1

    log_info "Available backups for $browser_name:"

    local backups=()
    while IFS= read -r backup; do
        backups+=("$backup")
        local timestamp=$(basename "$backup" .tar.gz | sed "s/${browser_name}_//")
        echo "  [$((${#backups[@]} - 1))] $timestamp"
    done < <(find "$BACKUP_DIR" -name "${browser_name}_*.tar.gz" -type f 2>/dev/null | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "No backups found for $browser_name"
        return 1
    fi

    read -p "Select backup to restore [0-$((${#backups[@]} - 1))]: " -r selection

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -lt ${#backups[@]} ]]; then
        local backup_file="${backups[$selection]}"
        log_info "Restoring from: $backup_file"

        # Extract to temp location first
        local temp_dir=$(mktemp -d)
        if tar -xzf "$backup_file" -C "$temp_dir"; then
            log_success "Backup restored to: $temp_dir"
            echo "Please manually copy the files to your browser profile directory"
            return 0
        else
            log_error "Failed to restore backup"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        log_error "Invalid selection"
        return 1
    fi
}

#=============================================================================
# Firefox Cleaning
#=============================================================================

clean_firefox_profile() {
    local profile_dir=$1
    local profile_name=$(basename "$profile_dir")

    log_info "Cleaning Firefox profile: $profile_name"

    # Check if Firefox is running
    if pgrep -x firefox &> /dev/null; then
        log_error "Firefox is running! Please close it first."
        return 1
    fi

    # Create backup
    if [[ $CREATE_BACKUP -eq 1 ]]; then
        create_backup "$profile_dir" "firefox_$(basename "$profile_dir")"
    fi

    local cleaned_items=0

    # Clean history
    if [[ $CLEAN_HISTORY -eq 1 ]] && [[ -f "$profile_dir/places.sqlite" ]]; then
        log_info "Cleaning browsing history..."

        # Make a copy for safety
        cp "$profile_dir/places.sqlite" "$profile_dir/places.sqlite.tmp"

        # Clean history using sqlite3
        if command -v sqlite3 &> /dev/null; then
            sqlite3 "$profile_dir/places.sqlite.tmp" "DELETE FROM moz_historyvisits;" 2>/dev/null || true
            sqlite3 "$profile_dir/places.sqlite.tmp" "DELETE FROM moz_places WHERE visit_count = 0;" 2>/dev/null || true
            sqlite3 "$profile_dir/places.sqlite.tmp" "VACUUM;" 2>/dev/null || true
            mv "$profile_dir/places.sqlite.tmp" "$profile_dir/places.sqlite"
            ((cleaned_items++))
            log_success "History cleaned"
        else
            # Fallback: just delete the file
            rm -f "$profile_dir/places.sqlite"
            rm -f "$profile_dir/places.sqlite-shm"
            rm -f "$profile_dir/places.sqlite-wal"
            ((cleaned_items++))
            log_success "History database removed"
        fi
    fi

    # Clean cookies
    if [[ $CLEAN_COOKIES -eq 1 ]] && [[ -f "$profile_dir/cookies.sqlite" ]]; then
        log_info "Cleaning cookies..."
        rm -f "$profile_dir/cookies.sqlite"
        rm -f "$profile_dir/cookies.sqlite-shm"
        rm -f "$profile_dir/cookies.sqlite-wal"
        ((cleaned_items++))
        log_success "Cookies removed"
    fi

    # Clean cache
    if [[ $CLEAN_CACHE -eq 1 ]]; then
        log_info "Cleaning cache..."
        rm -rf "$profile_dir/cache2"
        rm -rf "$profile_dir/startupCache"
        rm -rf "$profile_dir/thumbnails"
        ((cleaned_items++))
        log_success "Cache cleared"
    fi

    # Clean downloads
    if [[ $CLEAN_DOWNLOADS -eq 1 ]] && [[ -f "$profile_dir/downloads.sqlite" ]]; then
        log_info "Cleaning download history..."
        rm -f "$profile_dir/downloads.sqlite"
        ((cleaned_items++))
        log_success "Download history removed"
    fi

    # Clean form history
    if [[ -f "$profile_dir/formhistory.sqlite" ]]; then
        log_info "Cleaning form history..."
        rm -f "$profile_dir/formhistory.sqlite"
        ((cleaned_items++))
        log_success "Form history removed"
    fi

    # Clean sessions
    if [[ $CLEAN_SESSIONS -eq 1 ]]; then
        log_info "Cleaning session data..."
        rm -f "$profile_dir/sessionstore.jsonlz4"
        rm -f "$profile_dir/sessionstore-backups/recovery.jsonlz4"
        rm -f "$profile_dir/sessionstore-backups/previous.jsonlz4"
        ((cleaned_items++))
        log_success "Session data removed"
    fi

    log_success "Firefox profile cleaned ($cleaned_items items)"
    return 0
}

clean_all_firefox() {
    log_info "Scanning for Firefox profiles..."

    local profiles=()
    while IFS= read -r profile; do
        profiles+=("$profile")
    done < <(get_firefox_profiles)

    if [[ ${#profiles[@]} -eq 0 ]]; then
        log_warn "No Firefox profiles found"
        return 0
    fi

    log_info "Found ${#profiles[@]} Firefox profile(s)"

    for profile in "${profiles[@]}"; do
        clean_firefox_profile "$profile"
        echo
    done
}

#=============================================================================
# Chrome/Chromium Cleaning
#=============================================================================

clean_chrome_profile() {
    local profile_dir=$1
    local browser_name=$2

    log_info "Cleaning $browser_name profile: $(basename "$profile_dir")"

    # Check if browser is running
    local process_names=("chrome" "chromium" "brave" "msedge")
    for proc in "${process_names[@]}"; do
        if pgrep -x "$proc" &> /dev/null; then
            log_error "$browser_name is running! Please close it first."
            return 1
        fi
    done

    # Create backup
    if [[ $CREATE_BACKUP -eq 1 ]]; then
        create_backup "$profile_dir" "${browser_name}_$(basename "$profile_dir")"
    fi

    local cleaned_items=0

    # Clean history
    if [[ $CLEAN_HISTORY -eq 1 ]] && [[ -f "$profile_dir/History" ]]; then
        log_info "Cleaning browsing history..."

        if command -v sqlite3 &> /dev/null; then
            cp "$profile_dir/History" "$profile_dir/History.tmp"
            sqlite3 "$profile_dir/History.tmp" "DELETE FROM urls;" 2>/dev/null || true
            sqlite3 "$profile_dir/History.tmp" "DELETE FROM visits;" 2>/dev/null || true
            sqlite3 "$profile_dir/History.tmp" "DELETE FROM visit_source;" 2>/dev/null || true
            sqlite3 "$profile_dir/History.tmp" "VACUUM;" 2>/dev/null || true
            mv "$profile_dir/History.tmp" "$profile_dir/History"
        else
            rm -f "$profile_dir/History"
            rm -f "$profile_dir/History-journal"
        fi
        ((cleaned_items++))
        log_success "History cleaned"
    fi

    # Clean cookies
    if [[ $CLEAN_COOKIES -eq 1 ]] && [[ -f "$profile_dir/Cookies" ]]; then
        log_info "Cleaning cookies..."
        rm -f "$profile_dir/Cookies"
        rm -f "$profile_dir/Cookies-journal"
        rm -f "$profile_dir/Network/Cookies"
        rm -f "$profile_dir/Network/Cookies-journal"
        ((cleaned_items++))
        log_success "Cookies removed"
    fi

    # Clean cache
    if [[ $CLEAN_CACHE -eq 1 ]]; then
        log_info "Cleaning cache..."
        rm -rf "$profile_dir/Cache"
        rm -rf "$profile_dir/Code Cache"
        rm -rf "$profile_dir/GPUCache"
        rm -rf "$profile_dir/Service Worker/CacheStorage"
        rm -rf "$profile_dir/Application Cache"
        ((cleaned_items++))
        log_success "Cache cleared"
    fi

    # Clean downloads
    if [[ $CLEAN_DOWNLOADS -eq 1 ]] && [[ -f "$profile_dir/History" ]]; then
        log_info "Cleaning download history..."
        if command -v sqlite3 &> /dev/null; then
            sqlite3 "$profile_dir/History" "DELETE FROM downloads;" 2>/dev/null || true
            sqlite3 "$profile_dir/History" "DELETE FROM downloads_url_chains;" 2>/dev/null || true
        fi
        ((cleaned_items++))
        log_success "Download history removed"
    fi

    # Clean sessions
    if [[ $CLEAN_SESSIONS -eq 1 ]]; then
        log_info "Cleaning session data..."
        rm -f "$profile_dir/Current Session"
        rm -f "$profile_dir/Current Tabs"
        rm -f "$profile_dir/Last Session"
        rm -f "$profile_dir/Last Tabs"
        ((cleaned_items++))
        log_success "Session data removed"
    fi

    # Clean web data (autofill, etc.)
    if [[ -f "$profile_dir/Web Data" ]]; then
        log_info "Cleaning web data..."
        if command -v sqlite3 &> /dev/null; then
            cp "$profile_dir/Web Data" "$profile_dir/Web Data.tmp"
            sqlite3 "$profile_dir/Web Data.tmp" "DELETE FROM autofill;" 2>/dev/null || true
            sqlite3 "$profile_dir/Web Data.tmp" "DELETE FROM autofill_profiles;" 2>/dev/null || true
            sqlite3 "$profile_dir/Web Data.tmp" "VACUUM;" 2>/dev/null || true
            mv "$profile_dir/Web Data.tmp" "$profile_dir/Web Data"
        fi
        ((cleaned_items++))
        log_success "Web data cleaned"
    fi

    log_success "$browser_name profile cleaned ($cleaned_items items)"
    return 0
}

clean_all_chrome() {
    log_info "Scanning for Chrome-based browser profiles..."

    local profiles=()
    while IFS= read -r profile; do
        profiles+=("$profile")
    done < <(get_chrome_profiles)

    if [[ ${#profiles[@]} -eq 0 ]]; then
        log_warn "No Chrome-based browser profiles found"
        return 0
    fi

    log_info "Found ${#profiles[@]} Chrome-based profile(s)"

    for profile in "${profiles[@]}"; do
        local browser_name="Chrome"
        [[ "$profile" == *"Brave"* ]] && browser_name="Brave"
        [[ "$profile" == *"chromium"* ]] && browser_name="Chromium"
        [[ "$profile" == *"Edge"* ]] && browser_name="Edge"

        clean_chrome_profile "$profile" "$browser_name"
        echo
    done
}

#=============================================================================
# Selective Cleaning
#=============================================================================

clean_by_domain_pattern() {
    local pattern=$1

    log_info "Cleaning history matching pattern: $pattern"

    # Firefox
    local ff_profiles=()
    while IFS= read -r profile; do
        ff_profiles+=("$profile")
    done < <(get_firefox_profiles)

    local safe_pattern="${pattern//\'/\'\'}"
    local like_pattern="${safe_pattern//%/\\%}"
    like_pattern="${like_pattern//_/\\_}"

    for profile in "${ff_profiles[@]}"; do
        if [[ -f "$profile/places.sqlite" ]] && command -v sqlite3 &> /dev/null; then
            log_info "Cleaning Firefox: $(basename "$profile")"

            # Create backup first
            cp "$profile/places.sqlite" "$profile/places.sqlite.tmp"

            # Delete matching URLs
            sqlite3 "$profile/places.sqlite.tmp" \
                "DELETE FROM moz_places WHERE url LIKE '%$like_pattern%' ESCAPE '\\';" 2>/dev/null || true
            sqlite3 "$profile/places.sqlite.tmp" "VACUUM;" 2>/dev/null || true

            mv "$profile/places.sqlite.tmp" "$profile/places.sqlite"
            log_success "Cleaned Firefox profile"
        fi
    done

    # Chrome
    local chrome_profiles=()
    while IFS= read -r profile; do
        chrome_profiles+=("$profile")
    done < <(get_chrome_profiles)

    for profile in "${chrome_profiles[@]}"; do
        if [[ -f "$profile/History" ]] && command -v sqlite3 &> /dev/null; then
            log_info "Cleaning Chrome-based: $(basename "$profile")"

            cp "$profile/History" "$profile/History.tmp"

            sqlite3 "$profile/History.tmp" \
                "DELETE FROM urls WHERE url LIKE '%$like_pattern%' ESCAPE '\\';" 2>/dev/null || true
            sqlite3 "$profile/History.tmp" "VACUUM;" 2>/dev/null || true

            mv "$profile/History.tmp" "$profile/History"
            log_success "Cleaned Chrome-based profile"
        fi
    done

    log_success "Selective cleaning completed"
}

clean_by_time_range() {
    local hours_ago=$1

    log_info "Cleaning history from last $hours_ago hours"

    local cutoff_timestamp=$(($(date +%s) - (hours_ago * 3600)))
    local cutoff_chrome=$((cutoff_timestamp * 1000000))  # Chrome uses microseconds

    # Firefox (uses microseconds since epoch)
    local ff_profiles=()
    while IFS= read -r profile; do
        ff_profiles+=("$profile")
    done < <(get_firefox_profiles)

    for profile in "${ff_profiles[@]}"; do
        if [[ -f "$profile/places.sqlite" ]] && command -v sqlite3 &> /dev/null; then
            log_info "Cleaning Firefox: $(basename "$profile")"

            cp "$profile/places.sqlite" "$profile/places.sqlite.tmp"

            sqlite3 "$profile/places.sqlite.tmp" \
                "DELETE FROM moz_historyvisits WHERE visit_date > ${cutoff_timestamp}000000;" 2>/dev/null || true
            sqlite3 "$profile/places.sqlite.tmp" "VACUUM;" 2>/dev/null || true

            mv "$profile/places.sqlite.tmp" "$profile/places.sqlite"
            log_success "Cleaned Firefox profile"
        fi
    done

    # Chrome
    local chrome_profiles=()
    while IFS= read -r profile; do
        chrome_profiles+=("$profile")
    done < <(get_chrome_profiles)

    for profile in "${chrome_profiles[@]}"; do
        if [[ -f "$profile/History" ]] && command -v sqlite3 &> /dev/null; then
            log_info "Cleaning Chrome-based: $(basename "$profile")"

            cp "$profile/History" "$profile/History.tmp"

            sqlite3 "$profile/History.tmp" \
                "DELETE FROM visits WHERE visit_time > $cutoff_chrome;" 2>/dev/null || true
            sqlite3 "$profile/History.tmp" "VACUUM;" 2>/dev/null || true

            mv "$profile/History.tmp" "$profile/History"
            log_success "Cleaned Chrome-based profile"
        fi
    done

    log_success "Time-range cleaning completed"
}

#=============================================================================
# Statistics
#=============================================================================

show_browser_stats() {
    log_info "Browser History Statistics"
    echo

    # Firefox stats
    local ff_profiles=()
    while IFS= read -r profile; do
        ff_profiles+=("$profile")
    done < <(get_firefox_profiles)

    if [[ ${#ff_profiles[@]} -gt 0 ]]; then
        echo -e "${BOLD}Firefox:${NC}"
        for profile in "${ff_profiles[@]}"; do
            local profile_name=$(basename "$profile")

            if [[ -f "$profile/places.sqlite" ]] && command -v sqlite3 &> /dev/null; then
                local url_count=$(sqlite3 "$profile/places.sqlite" "SELECT COUNT(*) FROM moz_places;" 2>/dev/null || echo "0")
                local visit_count=$(sqlite3 "$profile/places.sqlite" "SELECT COUNT(*) FROM moz_historyvisits;" 2>/dev/null || echo "0")

                echo "  📁 $profile_name"
                echo "     URLs: $url_count"
                echo "     Visits: $visit_count"
            fi
        done
        echo
    fi

    # Chrome stats
    local chrome_profiles=()
    while IFS= read -r profile; do
        chrome_profiles+=("$profile")
    done < <(get_chrome_profiles)

    if [[ ${#chrome_profiles[@]} -gt 0 ]]; then
        echo -e "${BOLD}Chrome-based browsers:${NC}"
        for profile in "${chrome_profiles[@]}"; do
            local profile_name=$(basename "$profile")

            if [[ -f "$profile/History" ]] && command -v sqlite3 &> /dev/null; then
                local url_count=$(sqlite3 "$profile/History" "SELECT COUNT(*) FROM urls;" 2>/dev/null || echo "0")
                local visit_count=$(sqlite3 "$profile/History" "SELECT COUNT(*) FROM visits;" 2>/dev/null || echo "0")

                echo "  📁 $profile_name"
                echo "     URLs: $url_count"
                echo "     Visits: $visit_count"
            fi
        done
        echo
    fi
}

#=============================================================================
# Main Functions
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Nuclear option for browser history when you've been researching... stuff

OPTIONS:
    -a, --all              Clean all browsers (default)
    -f, --firefox          Clean Firefox only
    -c, --chrome           Clean Chrome/Chromium only
    -b, --brave            Clean Brave only

    -d, --domain PATTERN   Clean only URLs matching pattern
    -t, --time HOURS       Clean only last N hours

    -s, --stats            Show browser statistics
    -r, --restore BROWSER  Restore from backup

    --no-backup            Skip backup creation
    --no-history           Skip history cleaning
    --no-cookies           Skip cookie cleaning
    --no-cache             Skip cache cleaning

    -v, --verbose          Verbose output
    -h, --help             Show this help

EXAMPLES:
    # Clean everything (with backup)
    $0 --all

    # Clean only Firefox
    $0 --firefox

    # Clean URLs matching a pattern
    $0 --domain "malware-repo.com"

    # Clean last 24 hours only
    $0 --time 24

    # Show stats without cleaning
    $0 --stats

    # Restore Firefox backup
    $0 --restore firefox

    # Nuclear option - everything, no backup (DANGEROUS!)
    $0 --all --no-backup

NOTES:
    - Browsers MUST be closed before cleaning
    - Backups are stored in: $BACKUP_DIR
    - Only last $MAX_BACKUPS backups are kept per browser

EOF
}

main() {
    local mode="all"
    local selective_domain=""
    local selective_time=""
    local restore_browser=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                mode="all"
                shift
                ;;
            -f|--firefox)
                mode="firefox"
                shift
                ;;
            -c|--chrome)
                mode="chrome"
                shift
                ;;
            -b|--brave)
                mode="brave"
                shift
                ;;
            -d|--domain)
                selective_domain="$2"
                shift 2
                ;;
            -t|--time)
                selective_time="$2"
                shift 2
                ;;
            -s|--stats)
                show_browser_stats
                exit 0
                ;;
            -r|--restore)
                restore_browser="$2"
                shift 2
                ;;
            --no-backup)
                CREATE_BACKUP=0
                shift
                ;;
            --no-history)
                CLEAN_HISTORY=0
                shift
                ;;
            --no-cookies)
                CLEAN_COOKIES=0
                shift
                ;;
            --no-cache)
                CLEAN_CACHE=0
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

    # Restore mode
    if [[ -n "$restore_browser" ]]; then
        restore_backup "$restore_browser"
        exit $?
    fi

    # Selective cleaning
    if [[ -n "$selective_domain" ]]; then
        clean_by_domain_pattern "$selective_domain"
        exit $?
    fi

    if [[ -n "$selective_time" ]]; then
        clean_by_time_range "$selective_time"
        exit $?
    fi

    # Check dependencies
    check_command sqlite3

    # Warning
    echo -e "${BOLD}${YELLOW}⚠️  WARNING ⚠️${NC}"
    echo "This will clean browser data. Make sure all browsers are closed!"
    echo

    if [[ $CREATE_BACKUP -eq 0 ]]; then
        echo -e "${RED}${BOLD}🚨 BACKUP IS DISABLED! 🚨${NC}"
        echo "You will NOT be able to restore this data!"
        echo
    fi

    if ! ask_yes_no "Continue?" "n"; then
        log_info "Cancelled by user"
        exit 0
    fi

    echo
    echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║    BROWSER HISTORY CLEANSER 3000       ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
    echo

    # Run cleaning
    case $mode in
        all)
            clean_all_firefox
            clean_all_chrome
            ;;
        firefox)
            clean_all_firefox
            ;;
        chrome|brave)
            clean_all_chrome
            ;;
    esac

    echo
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    log_success "Browser cleaning complete!"

    if [[ $CREATE_BACKUP -eq 1 ]]; then
        log_info "Backups stored in: $BACKUP_DIR"
    fi

    echo
    log_info "Pro tip: Consider using private/incognito mode for... research"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
