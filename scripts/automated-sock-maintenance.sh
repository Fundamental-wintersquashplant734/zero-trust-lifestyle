#!/bin/bash
#=============================================================================
# automated-sock-maintenance.sh
# Automated sockpuppet account maintenance
# "Keep 47 fake identities alive by randomly liking cat videos"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

SOCK_DB="$DATA_DIR/sockpuppets.json"
CHROME_DRIVER=${CHROME_DRIVER:-"chromedriver"}
HEADLESS=${HEADLESS:-1}
USER_AGENTS_FILE="$DATA_DIR/user_agents.txt"

# Activity patterns
MIN_ACTIONS=2
MAX_ACTIONS=5
MIN_DELAY=10
MAX_DELAY=60

# Proxy support
USE_PROXY=${USE_PROXY:-1}
PROXY_LIST="$DATA_DIR/proxies.txt"

#=============================================================================
# Database Functions
#=============================================================================

init_sock_db() {
    if [[ ! -f "$SOCK_DB" ]]; then
        cat > "$SOCK_DB" <<'EOF'
{
    "sockpuppets": []
}
EOF
        log_info "Sockpuppet database initialized"
    fi
}

add_sockpuppet() {
    local platform=$1
    local username=$2
    local email=$3
    local password=$4
    local persona=$5

    local tmp_file=$(mktemp)

    # Encrypt password via the shared encrypt_data helper (fd:3, ENCRYPTION_PASSWORD).
    # base64 the ciphertext so it round-trips through JSON.
    local tmp_enc
    tmp_enc=$(mktemp)
    if ! encrypt_data "$password" "$tmp_enc"; then
        rm -f "$tmp_enc" "$tmp_file"
        log_error "Failed to encrypt sockpuppet password — is ENCRYPTION_PASSWORD set?"
        return 1
    fi
    local encrypted_pass
    encrypted_pass=$(base64 < "$tmp_enc" | tr -d '\n')
    rm -f "$tmp_enc"

    jq --arg platform "$platform" \
       --arg username "$username" \
       --arg email "$email" \
       --arg password "$encrypted_pass" \
       --arg persona "$persona" \
       --arg created "$(date -Iseconds)" \
       '.sockpuppets += [{
           platform: $platform,
           username: $username,
           email: $email,
           password: $password,
           persona: $persona,
           created_at: $created,
           last_activity: null,
           activity_count: 0,
           status: "active"
       }]' "$SOCK_DB" > "$tmp_file"

    mv "$tmp_file" "$SOCK_DB"
    log_success "Added sockpuppet: $username on $platform"
}

list_sockpuppets() {
    local platform=${1:-}

    if [[ -n "$platform" ]]; then
        jq -r --arg p "$platform" '.sockpuppets[] | select(.platform == $p) | "\(.username) (\(.platform)) - Last: \(.last_activity // "never")"' "$SOCK_DB"
    else
        jq -r '.sockpuppets[] | "\(.username) (\(.platform)) - Last: \(.last_activity // "never")"' "$SOCK_DB"
    fi
}

get_sockpuppet() {
    local username=$1

    jq --arg u "$username" '.sockpuppets[] | select(.username == $u)' "$SOCK_DB"
}

update_last_activity() {
    local username=$1

    local tmp_file=$(mktemp)
    jq --arg u "$username" \
       --arg date "$(date -Iseconds)" \
       '(.sockpuppets[] | select(.username == $u) | .last_activity) = $date |
        (.sockpuppets[] | select(.username == $u) | .activity_count) += 1' \
       "$SOCK_DB" > "$tmp_file"

    mv "$tmp_file" "$SOCK_DB"
}

decrypt_password() {
    local encrypted=$1
    local tmp_enc
    tmp_enc=$(mktemp)
    printf '%s' "$encrypted" | base64 -d > "$tmp_enc" 2>/dev/null
    decrypt_data "$tmp_enc"
    rm -f "$tmp_enc"
}

#=============================================================================
# Persona Profiles
#=============================================================================

get_persona_interests() {
    local persona=$1

    case $persona in
        tech_enthusiast)
            echo "programming,linux,opensource,cybersecurity,hacking,python,javascript"
            ;;
        photographer)
            echo "photography,landscape,portrait,camera,nikon,canon,editing"
            ;;
        gamer)
            echo "gaming,esports,steam,playstation,xbox,nintendo,rpg"
            ;;
        fitness)
            echo "fitness,gym,workout,health,nutrition,running,yoga"
            ;;
        foodie)
            echo "food,cooking,recipes,restaurant,chef,baking,cuisine"
            ;;
        traveler)
            echo "travel,vacation,adventure,backpacking,wanderlust,explore"
            ;;
        crypto)
            echo "cryptocurrency,bitcoin,ethereum,blockchain,defi,nft,trading"
            ;;
        *)
            echo "news,technology,science,education,art,music"
            ;;
    esac
}

get_random_action() {
    local platform=$1
    local actions=()

    case $platform in
        twitter)
            actions=("like" "retweet" "follow" "scroll")
            ;;
        reddit)
            actions=("upvote" "comment" "save" "scroll")
            ;;
        linkedin)
            actions=("like" "comment" "connect" "scroll")
            ;;
        instagram)
            actions=("like" "follow" "scroll" "story_view")
            ;;
        *)
            actions=("like" "scroll")
            ;;
    esac

    # Random selection
    echo "${actions[$((RANDOM % ${#actions[@]}))]}"
}

#=============================================================================
# Browser Automation (Headless Chrome)
#=============================================================================

generate_chrome_options() {
    local user_agent=$1
    local proxy=${2:-}

    # Do NOT pass --no-sandbox / --disable-setuid-sandbox / --disable-web-security:
    # those turn off the Chrome sandbox and same-origin policy, which is unacceptable
    # for a tool that types real credentials into web pages.
    local options=(
        "--disable-blink-features=AutomationControlled"
        "--disable-dev-shm-usage"
        "--user-agent=$user_agent"
    )

    if [[ $HEADLESS -eq 1 ]]; then
        options+=("--headless=new")
    fi

    if [[ -n "$proxy" ]]; then
        options+=("--proxy-server=$proxy")
    fi

    printf '%s\n' "${options[@]}"
}

get_random_user_agent() {
    if [[ -f "$USER_AGENTS_FILE" ]]; then
        shuf -n 1 "$USER_AGENTS_FILE"
    else
        # Fallback user agents
        local agents=(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        echo "${agents[$((RANDOM % ${#agents[@]}))]}"
    fi
}

get_random_proxy() {
    if [[ -f "$PROXY_LIST" ]] && [[ $USE_PROXY -eq 1 ]]; then
        shuf -n 1 "$PROXY_LIST"
    else
        echo ""
    fi
}

#=============================================================================
# Platform-Specific Actions
#=============================================================================

twitter_login() {
    local username=$1
    local password=$2
    local user_agent=$3
    local proxy=$4

    log_info "Logging into Twitter as $username"

    # Build the Chrome options list OUTSIDE the heredoc. The heredoc is quoted
    # below, so no bash expansion happens inside — credentials and options are
    # passed in via environment variables and read with os.environ. This closes
    # the previous injection hole where $username / $password were interpolated
    # directly into the Python source (a crafted value broke out of the string).
    local options_json
    options_json=$(generate_chrome_options "$user_agent" "$proxy" | jq -R . | jq -s .)

    ZT_USERNAME="$username" \
    ZT_PASSWORD="$password" \
    ZT_OPTIONS_JSON="$options_json" \
    ZT_MIN_ACTIONS="$MIN_ACTIONS" \
    ZT_MAX_ACTIONS="$MAX_ACTIONS" \
    ZT_MIN_DELAY="$MIN_DELAY" \
    ZT_MAX_DELAY="$MAX_DELAY" \
    python3 - <<'PYTHON'
import json
import os
import random
import time

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

options = Options()
for arg in json.loads(os.environ["ZT_OPTIONS_JSON"]):
    options.add_argument(arg)

username = os.environ["ZT_USERNAME"]
password = os.environ["ZT_PASSWORD"]
min_actions = int(os.environ["ZT_MIN_ACTIONS"])
max_actions = int(os.environ["ZT_MAX_ACTIONS"])
min_delay = int(os.environ["ZT_MIN_DELAY"])
max_delay = int(os.environ["ZT_MAX_DELAY"])

driver = None
try:
    driver = webdriver.Chrome(options=options)
    driver.get("https://twitter.com/login")
    time.sleep(random.uniform(2, 4))

    username_input = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.NAME, "text"))
    )
    username_input.send_keys(username)
    username_input.submit()

    time.sleep(random.uniform(2, 4))
    password_input = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.NAME, "password"))
    )
    password_input.send_keys(password)
    password_input.submit()

    time.sleep(random.uniform(3, 6))

    for _ in range(random.randint(min_actions, max_actions)):
        action = random.choice(["like", "retweet", "scroll"])
        if action == "scroll":
            driver.execute_script("window.scrollBy(0, 500)")
        elif action == "like":
            try:
                like_buttons = driver.find_elements(By.CSS_SELECTOR, '[data-testid="like"]')
                if like_buttons:
                    random.choice(like_buttons[:3]).click()
            except Exception:
                pass
        time.sleep(random.uniform(min_delay, max_delay))

    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}")
finally:
    if driver is not None:
        try:
            driver.quit()
        except Exception:
            pass
PYTHON
}

reddit_activity() {
    local username=$1
    local password=$2
    local interests=$3
    local user_agent=$4
    local proxy=$5

    log_info "Performing Reddit activity as $username"

    # OAuth2-based approach for Reddit (the deprecated /api/login endpoint is no longer supported)
    # Requires REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET to be set in environment

    # Get OAuth2 access token
    local auth_response=$(curl -s -X POST \
        -u "${REDDIT_CLIENT_ID:-}:${REDDIT_CLIENT_SECRET:-}" \
        -A "$user_agent" \
        -d "grant_type=password&username=${username}&password=${password}" \
        https://www.reddit.com/api/v1/access_token 2>/dev/null || echo "{}")
    local access_token=$(echo "$auth_response" | jq -r '.access_token // empty')
    if [[ -z "$access_token" ]]; then
        log_error "Failed to login to Reddit (OAuth2)"
        return 1
    fi

    log_success "Logged into Reddit as $username (OAuth2)"

    # Upvote a random post from interests
    local subreddit=$(echo "$interests" | tr ',' '\n' | shuf -n 1)
    local posts=$(curl -s -A "$user_agent" ${proxy:+-x "$proxy"} \
        -H "Authorization: bearer ${access_token}" \
        "https://oauth.reddit.com/r/${subreddit}/hot?limit=10" 2>/dev/null || echo "{}")

    local post_id=$(echo "$posts" | jq -r '.data.children[0].data.name' 2>/dev/null || echo "")

    if [[ -n "$post_id" && "$post_id" != "null" ]]; then
        curl -s -A "$user_agent" ${proxy:+-x "$proxy"} \
            -H "Authorization: bearer ${access_token}" \
            -d "id=${post_id}&dir=1" \
            https://oauth.reddit.com/api/vote &>/dev/null

        log_success "Upvoted post in r/${subreddit}"
    fi
}

generic_platform_activity() {
    local platform=$1
    local username=$2
    local password=$3
    local persona=$4

    log_warn "Generic activity for $platform not fully implemented"
    log_info "Would perform maintenance for $username ($persona persona)"

    # Placeholder - extend with actual automation
    sleep "$(generate_random_delay "$MIN_DELAY" "$MAX_DELAY")"
}

#=============================================================================
# Main Maintenance Logic
#=============================================================================

maintain_sockpuppet() {
    local username=$1

    local sock_data=$(get_sockpuppet "$username")

    if [[ -z "$sock_data" ]]; then
        log_error "Sockpuppet not found: $username"
        return 1
    fi

    local platform=$(echo "$sock_data" | jq -r '.platform')
    local email=$(echo "$sock_data" | jq -r '.email')
    local encrypted_pass=$(echo "$sock_data" | jq -r '.password')
    local persona=$(echo "$sock_data" | jq -r '.persona')

    local password=$(decrypt_password "$encrypted_pass")
    local interests=$(get_persona_interests "$persona")
    local user_agent=$(get_random_user_agent)
    local proxy=$(get_random_proxy)

    log_info "Maintaining sockpuppet: $username on $platform (persona: $persona)"

    # Rate limiting
    if ! rate_limit "sock_$username" 3 3600; then
        log_warn "Rate limit reached for $username, skipping"
        return 0
    fi

    # Platform-specific activity
    case $platform in
        twitter)
            if command -v python3 &> /dev/null && command -v chromedriver &> /dev/null; then
                twitter_login "$username" "$password" "$user_agent" "$proxy"
            else
                log_warn "Twitter automation requires Python3 + Selenium + ChromeDriver"
                generic_platform_activity "$platform" "$username" "$password" "$persona"
            fi
            ;;
        reddit)
            reddit_activity "$username" "$password" "$interests" "$user_agent" "$proxy"
            ;;
        *)
            generic_platform_activity "$platform" "$username" "$password" "$persona"
            ;;
    esac

    # Update last activity
    update_last_activity "$username"
    log_success "Maintenance complete for $username"
}

maintain_all() {
    local platform=${1:-}

    log_info "Running maintenance for all sockpuppets"

    local usernames=()

    if [[ -n "$platform" ]]; then
        while IFS= read -r username; do
            usernames+=("$username")
        done < <(jq -r --arg p "$platform" '.sockpuppets[] | select(.platform == $p and .status == "active") | .username' "$SOCK_DB")
    else
        while IFS= read -r username; do
            usernames+=("$username")
        done < <(jq -r '.sockpuppets[] | select(.status == "active") | .username' "$SOCK_DB")
    fi

    log_info "Found ${#usernames[@]} active sockpuppets"

    for username in "${usernames[@]}"; do
        maintain_sockpuppet "$username"

        # Random delay between accounts
        local delay=$(generate_random_delay 60 300)
        log_debug "Waiting ${delay}s before next account..."
        sleep "$delay"
    done

    log_success "All sockpuppet maintenance complete"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Automated sockpuppet account maintenance

COMMANDS:
    add PLATFORM USER EMAIL PASS PERSONA   Add new sockpuppet
    list [PLATFORM]                         List sockpuppets
    maintain USER                           Maintain specific sockpuppet
    maintain-all [PLATFORM]                 Maintain all sockpuppets

PLATFORMS:
    twitter, reddit, linkedin, instagram, facebook

PERSONAS:
    tech_enthusiast, photographer, gamer, fitness, foodie, traveler, crypto

OPTIONS:
    --no-headless    Show browser (for debugging)
    --no-proxy       Don't use proxies
    -h, --help       Show this help

EXAMPLES:
    # Add sockpuppet
    $0 add twitter john_doe123 john@example.com 'password123' tech_enthusiast

    # List all sockpuppets
    $0 list

    # Maintain specific account
    $0 maintain john_doe123

    # Maintain all Twitter accounts
    $0 maintain-all twitter

    # Cron job (3am daily)
    0 3 * * * $0 maintain-all

SETUP:
    1. Install requirements: selenium, chromedriver
       pip3 install selenium

    2. Add proxies to $PROXY_LIST (optional)

    3. Add user agents to $USER_AGENTS_FILE (optional)

EOF
}

main() {
    # Check dependencies
    check_commands jq curl

    # Initialize database
    init_sock_db

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-headless)
                HEADLESS=0
                shift
                ;;
            --no-proxy)
                USE_PROXY=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            add)
                shift
                if [[ $# -lt 5 ]]; then
                    log_error "Usage: add PLATFORM USER EMAIL PASS PERSONA"
                    exit 1
                fi
                add_sockpuppet "$1" "$2" "$3" "$4" "$5"
                exit 0
                ;;
            list)
                shift
                list_sockpuppets "${1:-}"
                exit 0
                ;;
            maintain)
                shift
                if [[ $# -lt 1 ]]; then
                    log_error "Usage: maintain USERNAME"
                    exit 1
                fi
                maintain_sockpuppet "$1"
                exit 0
                ;;
            maintain-all)
                shift
                maintain_all "${1:-}"
                exit 0
                ;;
            *)
                log_error "Unknown command: $1"
                show_help
                exit 1
                ;;
        esac
    done

    show_help
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
