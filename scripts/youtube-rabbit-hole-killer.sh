#!/bin/bash
#=============================================================================
# youtube-rabbit-hole-killer.sh
# After 2 videos, replaces YouTube homepage with "go do something useful"
# "You've watched 2 videos. That's enough. Go build something."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

STATE_FILE="$DATA_DIR/youtube_killer_state.json"
STATS_FILE="$DATA_DIR/youtube_stats.json"
BLOCKED_PAGE_FILE="$DATA_DIR/youtube_blocked.html"
SERVER_PORT=8080

# Limits
VIDEO_LIMIT=2
DAILY_TIME_LIMIT=30  # minutes
RESET_HOUR=4  # Reset counter at 4 AM

# Blocking settings
BLOCK_METHOD="hosts"  # hosts or redirect
STRICT_MODE=0  # If 1, blocks all YouTube
WHITELIST_EDUCATIONAL=1  # Allow educational channels

# Whitelisted channels (educational content)
WHITELIST_CHANNELS=(
    "MIT OpenCourseWare"
    "Computerphile"
    "3Blue1Brown"
    "Khan Academy"
    "Crash Course"
    "Kurzgesagt"
    "Veritasium"
    "Two Minute Papers"
    "The Coding Train"
    "freeCodeCamp.org"
)

#=============================================================================
# State Management
#=============================================================================

init_state() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<EOF
{
  "videos_watched": 0,
  "minutes_watched": 0,
  "last_reset": "$(date -Iseconds)",
  "blocked": false,
  "today": "$(date +%Y-%m-%d)"
}
EOF
    fi

    if [[ ! -f "$STATS_FILE" ]]; then
        echo '{"history": []}' > "$STATS_FILE"
    fi

    # Check if needs daily reset
    check_daily_reset
}

get_state() {
    init_state
    cat "$STATE_FILE"
}

update_state() {
    local key=$1
    local value=$2

    local tmp_file=$(mktemp)

    jq --arg key "$key" --arg value "$value" \
       '.[$key] = $value' \
       "$STATE_FILE" > "$tmp_file"

    mv "$tmp_file" "$STATE_FILE"
}

check_daily_reset() {
    local today=$(date +%Y-%m-%d)
    local state_date=$(jq -r '.today' "$STATE_FILE" 2>/dev/null || echo "")

    if [[ "$state_date" != "$today" ]]; then
        log_debug "Daily reset triggered"
        reset_counter
    fi

    # Also check time-based reset
    local current_hour=$(date +%H)
    local last_reset=$(jq -r '.last_reset' "$STATE_FILE")
    local last_reset_hour=$(date -d "$last_reset" +%H 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$last_reset" +%H 2>/dev/null)

    if [[ $current_hour -eq $RESET_HOUR ]] && [[ $last_reset_hour -ne $RESET_HOUR ]]; then
        log_debug "Hourly reset triggered"
        reset_counter
    fi
}

reset_counter() {
    local tmp_file=$(mktemp)

    jq --arg today "$(date +%Y-%m-%d)" \
       --arg timestamp "$(date -Iseconds)" \
       '.videos_watched = 0 |
        .minutes_watched = 0 |
        .blocked = false |
        .today = $today |
        .last_reset = $timestamp' \
       "$STATE_FILE" > "$tmp_file"

    mv "$tmp_file" "$STATE_FILE"

    # Unblock YouTube
    unblock_youtube

    log_success "Counter reset for new day"
}

#=============================================================================
# Video Tracking
#=============================================================================

log_video_watched() {
    local video_title=${1:-"Unknown"}
    local duration=${2:-0}  # minutes

    init_state

    local current=$(jq -r '.videos_watched' "$STATE_FILE")
    local minutes=$(jq -r '.minutes_watched' "$STATE_FILE")

    ((current++))
    minutes=$(echo "$minutes + $duration" | bc)

    local tmp_file=$(mktemp)

    jq --argjson count "$current" \
       --argjson mins "$minutes" \
       --arg title "$video_title" \
       --arg timestamp "$(date -Iseconds)" \
       '.videos_watched = $count |
        .minutes_watched = $mins' \
       "$STATE_FILE" > "$tmp_file"

    mv "$tmp_file" "$STATE_FILE"

    # Record to history
    record_history "$video_title" "$duration"

    log_info "Logged video: $video_title"
    log_info "Count: $current/$VIDEO_LIMIT | Time: ${minutes}min"

    # Check if limit exceeded
    if [[ $current -ge $VIDEO_LIMIT ]] || [[ $(echo "$minutes >= $DAILY_TIME_LIMIT" | bc) -eq 1 ]]; then
        trigger_block
    fi
}

record_history() {
    local title=$1
    local duration=$2

    local tmp_file=$(mktemp)

    jq --arg title "$title" \
       --argjson duration "$duration" \
       --arg timestamp "$(date -Iseconds)" \
       '.history += [{
           timestamp: $timestamp,
           title: $title,
           duration: $duration
       }]' \
       "$STATS_FILE" > "$tmp_file"

    mv "$tmp_file" "$STATS_FILE"

    # Keep only last 1000 entries
    jq '.history = .history[-1000:]' "$STATS_FILE" > "$tmp_file"
    mv "$tmp_file" "$STATS_FILE"
}

#=============================================================================
# Blocking Mechanism
#=============================================================================

trigger_block() {
    local videos=$(jq -r '.videos_watched' "$STATE_FILE")
    local minutes=$(jq -r '.minutes_watched' "$STATE_FILE")

    echo
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}    ⛔ YOUTUBE LIMIT REACHED ⛔${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  Videos watched: ${BOLD}${videos}/${VIDEO_LIMIT}${NC}"
    echo -e "  Time spent: ${BOLD}${minutes} minutes${NC}"
    echo
    echo -e "${RED}${BOLD}  YouTube is now BLOCKED.${NC}"
    echo -e "${YELLOW}  Go do something productive.${NC}"
    echo
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # Update state
    update_state "blocked" "true"

    # Block YouTube
    block_youtube

    # Send notification
    send_alert "⛔ YouTube blocked! You've watched $videos videos ($minutes min). Go do something useful."
}

block_youtube() {
    if [[ "$BLOCK_METHOD" == "hosts" ]]; then
        block_via_hosts
    else
        start_redirect_server
    fi
}

block_via_hosts() {
    if ! is_root; then
        log_error "Need sudo to block YouTube via hosts file"
        log_info "Run: sudo $0 block"
        return 1
    fi

    log_info "Blocking YouTube via /etc/hosts..."

    # Backup hosts file
    if [[ ! -f /etc/hosts.backup.youtube ]]; then
        cp /etc/hosts /etc/hosts.backup.youtube
    fi

    # Block YouTube domains
    local youtube_domains=(
        "youtube.com"
        "www.youtube.com"
        "m.youtube.com"
        "youtube-nocookie.com"
        "youtubei.googleapis.com"
        "youtu.be"
    )

    for domain in "${youtube_domains[@]}"; do
        if ! grep -q "127.0.0.1 $domain" /etc/hosts; then
            echo "127.0.0.1 $domain" >> /etc/hosts
        fi
    done

    # Flush DNS
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
    fi

    log_success "YouTube blocked via hosts file"

    # Start local server to show message
    start_blocked_page_server
}

unblock_youtube() {
    if ! is_root; then
        log_warn "Need sudo to unblock YouTube"
        return 1
    fi

    log_info "Unblocking YouTube..."

    # Restore hosts file
    if [[ -f /etc/hosts.backup.youtube ]]; then
        cp /etc/hosts.backup.youtube /etc/hosts
        rm /etc/hosts.backup.youtube
    fi

    # Flush DNS
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        dscacheutil -flushcache 2>/dev/null || true
    fi

    update_state "blocked" "false"

    log_success "YouTube unblocked"
}

#=============================================================================
# Blocked Page Server
#=============================================================================

create_blocked_page() {
    local videos=$(jq -r '.videos_watched' "$STATE_FILE")
    local minutes=$(jq -r '.minutes_watched' "$STATE_FILE")

    cat > "$BLOCKED_PAGE_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>YouTube Blocked</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            text-align: center;
        }
        .container {
            max-width: 600px;
            padding: 40px;
        }
        h1 {
            font-size: 48px;
            margin: 0 0 20px 0;
        }
        .emoji {
            font-size: 80px;
            margin-bottom: 20px;
        }
        .stats {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 20px;
            margin: 30px 0;
        }
        .stat {
            font-size: 24px;
            margin: 10px 0;
        }
        .message {
            font-size: 28px;
            font-weight: bold;
            margin: 30px 0;
            color: #ffd700;
        }
        .alternatives {
            text-align: left;
            margin-top: 30px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 20px;
        }
        .alternatives h2 {
            margin-top: 0;
        }
        .alternatives ul {
            list-style: none;
            padding: 0;
        }
        .alternatives li {
            padding: 10px;
            margin: 5px 0;
            background: rgba(255,255,255,0.1);
            border-radius: 5px;
        }
        .alternatives li::before {
            content: "✓ ";
            color: #4ade80;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">⛔</div>
        <h1>YouTube Blocked</h1>

        <div class="stats">
            <div class="stat">📹 Videos watched: <strong>$videos / $VIDEO_LIMIT</strong></div>
            <div class="stat">⏰ Time spent: <strong>$minutes minutes</strong></div>
        </div>

        <div class="message">
            GO DO SOMETHING USEFUL
        </div>

        <div class="alternatives">
            <h2>Instead, you could:</h2>
            <ul>
                <li>Work on that project you keep postponing</li>
                <li>Read a book (or finish the one you started)</li>
                <li>Learn something new (run random-skill-learner.sh)</li>
                <li>Exercise for 20 minutes</li>
                <li>Call someone you care about</li>
                <li>Go outside and touch grass</li>
                <li>Write code</li>
                <li>Face a fear (run fear-challenge.sh)</li>
            </ul>
        </div>

        <p style="margin-top: 40px; opacity: 0.7;">
            Counter resets at ${RESET_HOUR}:00 AM or run: sudo youtube-rabbit-hole-killer.sh unblock
        </p>
    </div>
</body>
</html>
EOF
}

start_blocked_page_server() {
    # Kill existing server if running
    pkill -f "python.*youtube_blocked" 2>/dev/null || true

    create_blocked_page

    log_info "Starting blocked page server on port $SERVER_PORT..."

    # Start simple HTTP server
    if command -v python3 &> /dev/null; then
        cd "$DATA_DIR"
        python3 -c "
import http.server
import socketserver
import os

PORT = $SERVER_PORT
os.chdir('$DATA_DIR')

Handler = http.server.SimpleHTTPRequestHandler

class MyHandler(Handler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        with open('youtube_blocked.html', 'rb') as f:
            self.wfile.write(f.read())

    def log_message(self, format, *args):
        pass  # Suppress logs

with socketserver.TCPServer(('', PORT), MyHandler) as httpd:
    httpd.serve_forever()
" &>/dev/null &

        log_success "Blocked page server started"
        log_info "Try visiting youtube.com - you'll see the blocked page"
    else
        log_error "Python3 required for blocked page server"
    fi
}

#=============================================================================
# Manual Logging
#=============================================================================

manual_log() {
    echo -e "\n${BOLD}Log YouTube Video${NC}\n"

    read -p "Video title (optional): " title
    read -p "Duration in minutes: " duration

    log_video_watched "$title" "$duration"

    # Show current status
    show_status
}

#=============================================================================
# Browser Extension Generator
#=============================================================================

generate_browser_extension() {
    local ext_dir="$DATA_DIR/youtube-killer-extension"
    mkdir -p "$ext_dir"

    # Generate manifest.json
    cat > "$ext_dir/manifest.json" <<'EOF'
{
  "manifest_version": 3,
  "name": "YouTube Rabbit Hole Killer",
  "version": "1.0",
  "description": "Blocks YouTube after 2 videos",
  "permissions": ["storage", "tabs"],
  "host_permissions": ["*://www.youtube.com/*"],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [{
    "matches": ["*://www.youtube.com/*"],
    "js": ["content.js"]
  }]
}
EOF

    # Generate background.js
    cat > "$ext_dir/background.js" <<'EOF'
let videoCount = 0;
const VIDEO_LIMIT = 2;

// Reset daily
chrome.alarms.create('dailyReset', { periodInMinutes: 1440 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'dailyReset') {
    videoCount = 0;
    chrome.storage.local.set({ videoCount: 0, blocked: false });
  }
});

// Initialize
chrome.storage.local.get(['videoCount'], (result) => {
  videoCount = result.videoCount || 0;
});
EOF

    # Generate content.js
    cat > "$ext_dir/content.js" <<'EOF'
let currentVideoId = null;
const VIDEO_LIMIT = 2;

function checkAndBlock() {
  chrome.storage.local.get(['videoCount', 'blocked'], (result) => {
    if (result.blocked || (result.videoCount || 0) >= VIDEO_LIMIT) {
      blockYouTube();
    }
  });
}

function blockYouTube() {
  document.body.innerHTML = `
    <div style="display:flex;justify-content:center;align-items:center;height:100vh;
                background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);
                font-family:sans-serif;color:white;text-align:center;">
      <div>
        <div style="font-size:80px;">⛔</div>
        <h1 style="font-size:48px;">YouTube Blocked</h1>
        <p style="font-size:24px;margin:20px;">You've watched ${VIDEO_LIMIT} videos.</p>
        <p style="font-size:28px;font-weight:bold;color:#ffd700;">GO DO SOMETHING USEFUL</p>
      </div>
    </div>
  `;
}

// Detect video play
let observer = new MutationObserver(() => {
  const video = document.querySelector('video');
  if (video && video.src) {
    const match = window.location.href.match(/v=([^&]+)/);
    if (match && match[1] !== currentVideoId) {
      currentVideoId = match[1];

      chrome.storage.local.get(['videoCount'], (result) => {
        const count = (result.videoCount || 0) + 1;
        chrome.storage.local.set({
          videoCount: count,
          blocked: count >= VIDEO_LIMIT
        });

        if (count >= VIDEO_LIMIT) {
          blockYouTube();
        }
      });
    }
  }
});

observer.observe(document.body, { childList: true, subtree: true });
checkAndBlock();
EOF

    log_success "Browser extension generated at: $ext_dir"
    echo
    echo -e "${BOLD}Installation:${NC}"
    echo "  Chrome/Edge:"
    echo "    1. Go to chrome://extensions"
    echo "    2. Enable 'Developer mode'"
    echo "    3. Click 'Load unpacked'"
    echo "    4. Select: $ext_dir"
    echo
    echo "  Firefox:"
    echo "    1. Go to about:debugging#/runtime/this-firefox"
    echo "    2. Click 'Load Temporary Add-on'"
    echo "    3. Select manifest.json in: $ext_dir"
    echo
}

#=============================================================================
# Statistics
#=============================================================================

show_status() {
    init_state

    local videos=$(jq -r '.videos_watched' "$STATE_FILE")
    local minutes=$(jq -r '.minutes_watched' "$STATE_FILE")
    local blocked=$(jq -r '.blocked' "$STATE_FILE")
    local today=$(jq -r '.today' "$STATE_FILE")

    echo -e "\n${BOLD}📊 YouTube Status${NC}\n"

    echo "Date: $today"
    echo "Videos watched: $videos / $VIDEO_LIMIT"
    echo "Time spent: $minutes / $DAILY_TIME_LIMIT minutes"

    if [[ "$blocked" == "true" ]]; then
        echo -e "Status: ${RED}${BOLD}BLOCKED${NC}"
    else
        local remaining=$(( VIDEO_LIMIT - videos ))
        echo -e "Status: ${GREEN}Active${NC} ($remaining videos remaining)"
    fi

    echo
}

show_stats() {
    if [[ ! -f "$STATS_FILE" ]]; then
        log_info "No history available"
        return 0
    fi

    echo -e "\n${BOLD}📊 YouTube Statistics${NC}\n"

    local total=$(jq '.history | length' "$STATS_FILE")
    local total_time=$(jq '[.history[].duration] | add' "$STATS_FILE" 2>/dev/null || echo "0")

    echo "Total videos logged: $total"
    echo "Total time: $total_time minutes ($(echo "scale=1; $total_time / 60" | bc) hours)"
    echo

    # This week stats
    local week_start=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null)
    local week_videos=$(jq --arg week "$week_start" \
        '[.history[] | select(.timestamp >= $week)] | length' \
        "$STATS_FILE")
    local week_time=$(jq --arg week "$week_start" \
        '[.history[] | select(.timestamp >= $week) | .duration] | add' \
        "$STATS_FILE" 2>/dev/null || echo "0")

    echo "This week: $week_videos videos, $week_time minutes"
    echo

    echo -e "${BOLD}Recent videos:${NC}"
    jq -r '.history[-10:] | .[] |
        "\(.timestamp | split("T")[0]) - \(.title) (\(.duration) min)"' \
        "$STATS_FILE"
    echo
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Kill the YouTube rabbit hole after 2 videos

COMMANDS:
    status                       Show current status
    log                          Manually log a video watched
    stats                        Show viewing statistics
    block                        Manually trigger block (requires sudo)
    unblock                      Unblock YouTube (requires sudo)
    reset                        Reset daily counter
    extension                    Generate browser extension
    server                       Start blocked page server

OPTIONS:
    --limit N                    Set video limit (default: 2)
    --time-limit MINS            Set daily time limit (default: 30)

EXAMPLES:
    # Check current status
    $0 status

    # Manually log watching a video
    $0 log

    # Block YouTube now
    sudo $0 block

    # Unblock (emergency override)
    sudo $0 unblock

    # Generate browser extension
    $0 extension

    # View statistics
    $0 stats

AUTOMATIC BLOCKING:
    1. Install browser extension: $0 extension
    2. Extension tracks videos automatically
    3. After 2 videos, YouTube gets blocked

MANUAL MODE:
    1. Watch YouTube normally
    2. Log each video: $0 log
    3. After 2 videos, block triggers: sudo $0 block

PHILOSOPHY:
    • 2 videos is enough
    • You're not going to "just watch one more"
    • The rabbit hole starts at video 3
    • Your time is more valuable than this
    • Go build something instead

FEATURES:
    • Daily reset at ${RESET_HOUR}:00 AM
    • Blocks via /etc/hosts (requires sudo)
    • Shows motivational blocked page
    • Tracks viewing statistics
    • Emergency unblock available

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --limit)
                VIDEO_LIMIT=$2
                shift 2
                ;;
            --time-limit)
                DAILY_TIME_LIMIT=$2
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            status|log|stats|block|unblock|reset|extension|server)
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
    check_commands jq

    # Initialize
    init_state

    # Execute command
    case $command in
        status)
            show_status
            ;;
        log)
            manual_log
            ;;
        stats)
            show_stats
            ;;
        block)
            trigger_block
            ;;
        unblock)
            unblock_youtube
            ;;
        reset)
            reset_counter
            ;;
        extension)
            generate_browser_extension
            ;;
        server)
            create_blocked_page
            start_blocked_page_server
            echo "Server running on port $SERVER_PORT"
            echo "Press Ctrl+C to stop"
            wait
            ;;
        "")
            show_status
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
