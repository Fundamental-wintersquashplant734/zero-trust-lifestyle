#!/bin/bash
#=============================================================================
# definitely-working.sh
# Prevents screen lock and away status by simulating activity
# "I'm definitely at my desk. The mouse is moving. See?"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

# Movement settings
MIN_DELAY=5         # Minimum seconds between moves
MAX_DELAY=120       # Maximum seconds between moves
SCREEN_WIDTH=1920   # Adjust to your screen width
SCREEN_HEIGHT=1080  # Adjust to your screen height
MOVEMENT_RANGE=50   # Pixels to move (small movements are less obvious)

# Behavior
SUBTLE_MODE=1       # Move mouse less noticeably
RANDOM_CLICKS=0     # Occasionally click (use with caution!)
KEYBOARD_ACTIVITY=0 # Occasionally press safe keys like Shift

#=============================================================================
# Activity Simulation
#=============================================================================

move_mouse_subtle() {
    # Get current position
    local current_pos=$(xdotool getmouselocation --shell)
    local current_x=$(echo "$current_pos" | grep X= | cut -d= -f2)
    local current_y=$(echo "$current_pos" | grep Y= | cut -d= -f2)

    # Small random movement from current position
    local delta_x=$(( (RANDOM % MOVEMENT_RANGE) - (MOVEMENT_RANGE / 2) ))
    local delta_y=$(( (RANDOM % MOVEMENT_RANGE) - (MOVEMENT_RANGE / 2) ))

    local new_x=$(( current_x + delta_x ))
    local new_y=$(( current_y + delta_y ))

    # Ensure within screen bounds
    [[ $new_x -lt 0 ]] && new_x=0
    [[ $new_y -lt 0 ]] && new_y=0
    [[ $new_x -gt $SCREEN_WIDTH ]] && new_x=$SCREEN_WIDTH
    [[ $new_y -gt $SCREEN_HEIGHT ]] && new_y=$SCREEN_HEIGHT

    xdotool mousemove "$new_x" "$new_y"
}

move_mouse_random() {
    # Large random movement (more obvious)
    local x=$(( (RANDOM % SCREEN_WIDTH) + 1 ))
    local y=$(( (RANDOM % SCREEN_HEIGHT) + 1 ))

    xdotool mousemove "$x" "$y"
}

simulate_activity() {
    if [[ $SUBTLE_MODE -eq 1 ]]; then
        move_mouse_subtle
    else
        move_mouse_random
    fi

    # Optional: Random click (rarely)
    if [[ $RANDOM_CLICKS -eq 1 ]] && [[ $(( RANDOM % 100 )) -lt 5 ]]; then
        log_debug "Simulating click"
        xdotool click 1
    fi

    # Optional: Random keyboard activity
    if [[ $KEYBOARD_ACTIVITY -eq 1 ]] && [[ $(( RANDOM % 100 )) -lt 5 ]]; then
        log_debug "Simulating keypress"
        xdotool key shift  # Safe key that won't mess up your work
    fi
}

#=============================================================================
# Main Loop
#=============================================================================

run_continuous() {
    log_info "Starting activity simulation (Ctrl+C to stop)"
    log_info "Mode: $([ $SUBTLE_MODE -eq 1 ] && echo "Subtle" || echo "Obvious")"

    local count=0

    while true; do
        simulate_activity
        ((count++))

        local delay=$(( (RANDOM % (MAX_DELAY - MIN_DELAY + 1)) + MIN_DELAY ))

        log_debug "Movement #$count - Next move in ${delay}s"
        sleep "$delay"
    done
}

run_timed() {
    local duration=$1
    local end_time=$(( $(date +%s) + duration ))

    log_info "Running for $(human_time_diff "$duration")..."

    while [[ $(date +%s) -lt $end_time ]]; do
        simulate_activity

        local remaining=$(( end_time - $(date +%s) ))
        if [[ $remaining -le 0 ]]; then
            break
        fi

        local delay=$(( (RANDOM % (MAX_DELAY - MIN_DELAY + 1)) + MIN_DELAY ))
        [[ $delay -gt $remaining ]] && delay=$remaining

        sleep "$delay"
    done

    log_success "Session complete!"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [DURATION]

Prevent screen lock and away status by simulating mouse activity

OPTIONS:
    --subtle                 Subtle movements (default)
    --obvious                Large random movements
    --with-clicks            Occasionally click (use carefully!)
    --with-keyboard          Occasionally press Shift key
    --delay MIN MAX          Delay range in seconds (default: 5-120)
    -h, --help              Show this help

DURATION:
    If specified, run for N seconds then stop
    If omitted, run indefinitely

EXAMPLES:
    # Run indefinitely with subtle movements
    $0

    # Run for 1 hour (3600 seconds)
    $0 3600

    # Run for 2 hours with obvious movements
    $0 --obvious 7200

    # Run during meeting with keyboard activity
    $0 --with-keyboard 1800

USE CASES:
    • Prevent screen lock during long downloads
    • Stay "active" during video playback
    • Prevent away status during meetings
    • Keep connection alive on remote desktop

TIPS:
    • Use --subtle for less obvious activity
    • Don't use --with-clicks on important windows!
    • Run in background: $0 &
    • Kill with: pkill -f definitely-working

REQUIREMENTS:
    • xdotool (install: sudo apt install xdotool)

EOF
}

main() {
    local duration=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --subtle)
                SUBTLE_MODE=1
                shift
                ;;
            --obvious)
                SUBTLE_MODE=0
                shift
                ;;
            --with-clicks)
                RANDOM_CLICKS=1
                shift
                ;;
            --with-keyboard)
                KEYBOARD_ACTIVITY=1
                shift
                ;;
            --delay)
                MIN_DELAY=$2
                MAX_DELAY=$3
                shift 3
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            [0-9]*)
                duration=$1
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
    check_commands xdotool

    # Run
    if [[ -n "$duration" ]]; then
        run_timed "$duration"
    else
        run_continuous
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
