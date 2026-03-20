#!/bin/bash
#=============================================================================
# monk-mode-fasting.sh
# Disciplined fasting tracker with notifications and analytics
# "Hunger is the best sauce, discipline is the best meal"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

FASTING_DB="$DATA_DIR/fasting.db"
CONFIG_FILE="$DATA_DIR/fasting_config.json"
SCHEDULE_FILE="$DATA_DIR/fasting_schedule.json"

# Default fasting schedule
DEFAULT_WEEKLY_DAY="friday"          # Every Friday
DEFAULT_QUARTERLY_WEEK=1             # First week of quarter
DEFAULT_DAILY_FASTING_HOURS=16       # 16:8 intermittent fasting

# Notification settings
NOTIFY_START=${NOTIFY_START:-1}
NOTIFY_MILESTONES=${NOTIFY_MILESTONES:-1}
NOTIFY_END=${NOTIFY_END:-1}
NOTIFY_ENCOURAGEMENT=${NOTIFY_ENCOURAGEMENT:-1}

# Milestone hours for notifications
MILESTONES=(6 12 16 24 48 72 120 168)  # 6h, 12h, 16h, 24h, 2d, 3d, 5d, 7d

#=============================================================================
# Database Setup
#=============================================================================

init_database() {
    if [[ ! -f "$FASTING_DB" ]]; then
        log_info "Creating fasting database..."

        sqlite3 "$FASTING_DB" <<'EOF'
CREATE TABLE IF NOT EXISTS fasting_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    planned_duration_hours INTEGER,
    actual_duration_hours REAL,
    fasting_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    notes TEXT,
    weight_before REAL,
    weight_after REAL,
    energy_level INTEGER,
    difficulty_level INTEGER,
    completed BOOLEAN DEFAULT 0,
    broke_early BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fasting_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schedule_type TEXT NOT NULL,
    day_of_week TEXT,
    week_of_quarter INTEGER,
    duration_hours INTEGER NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fasting_milestones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    milestone_hours INTEGER NOT NULL,
    reached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (session_id) REFERENCES fasting_sessions(id)
);

CREATE TABLE IF NOT EXISTS fasting_journal (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    entry_type TEXT,
    content TEXT,
    mood INTEGER,
    hunger_level INTEGER,
    FOREIGN KEY (session_id) REFERENCES fasting_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_start ON fasting_sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON fasting_sessions(status);
CREATE INDEX IF NOT EXISTS idx_milestones_session ON fasting_milestones(session_id);
CREATE INDEX IF NOT EXISTS idx_journal_session ON fasting_journal(session_id);
EOF

        log_success "Database created: $FASTING_DB"

        # Insert default schedule
        init_default_schedule
    fi
}

init_default_schedule() {
    log_info "Setting up default fasting schedule..."

    sqlite3 "$FASTING_DB" <<EOF
-- Weekly Friday fast (24 hours)
INSERT INTO fasting_schedule (schedule_type, day_of_week, duration_hours, enabled)
VALUES ('weekly', 'friday', 24, 1);

-- Quarterly week-long fast (168 hours = 7 days)
INSERT INTO fasting_schedule (schedule_type, week_of_quarter, duration_hours, enabled)
VALUES ('quarterly', 1, 168, 1);

-- Daily intermittent fasting (16 hours)
INSERT INTO fasting_schedule (schedule_type, duration_hours, enabled)
VALUES ('daily', 16, 0);
EOF

    log_success "Default schedule configured"
}

#=============================================================================
# Fasting Session Management
#=============================================================================

start_fasting() {
    local fasting_type=${1:-"manual"}
    local duration_hours=${2:-24}
    local notes=${3:-""}

    # Check if there's already an active session
    local active_session=$(sqlite3 "$FASTING_DB" "SELECT id FROM fasting_sessions WHERE status = 'active' LIMIT 1;")

    if [[ -n "$active_session" ]]; then
        log_error "Already have an active fasting session (ID: $active_session)"
        echo "End current session first with: $0 end"
        return 1
    fi

    local start_time=$(date -Iseconds)
    local safe_notes="${notes//\'/\'\'}"
    local safe_fasting_type="${fasting_type//\'/\'\'}"

    # Insert new session
    sqlite3 "$FASTING_DB" <<EOF
INSERT INTO fasting_sessions
    (start_time, planned_duration_hours, fasting_type, status, notes)
VALUES
    ('$start_time', $duration_hours, '$safe_fasting_type', 'active', '$safe_notes');
EOF

    local session_id=$(sqlite3 "$FASTING_DB" "SELECT last_insert_rowid();")

    log_success "Fasting session started!"
    echo ""
    echo -e "${BOLD}Session ID:${NC} $session_id"
    echo -e "${BOLD}Start Time:${NC} $start_time"
    echo -e "${BOLD}Type:${NC} $fasting_type"
    echo -e "${BOLD}Planned Duration:${NC} $duration_hours hours"
    echo -e "${BOLD}Expected End:${NC} $(date -d "$start_time + $duration_hours hours" '+%Y-%m-%d %H:%M' 2>/dev/null || date -v+${duration_hours}H '+%Y-%m-%d %H:%M')"
    echo ""

    # Send notification
    if [[ $NOTIFY_START -eq 1 ]]; then
        notify "🕉️ Fasting Started" "${duration_hours}h $fasting_type fast begins now. Stay strong!" "normal"
    fi

    # Journal entry
    add_journal_entry "$session_id" "start" "Fasting session started. Let's do this!"

    echo -e "${CYAN}Track your progress with:${NC} $0 status"
    echo -e "${CYAN}End early with:${NC} $0 end"
    echo ""
}

end_fasting() {
    local broke_early=${1:-0}
    local notes=${2:-""}

    # Get active session
    local session_data=$(sqlite3 "$FASTING_DB" \
        "SELECT id, start_time, planned_duration_hours FROM fasting_sessions WHERE status = 'active' LIMIT 1;")

    if [[ -z "$session_data" ]]; then
        log_error "No active fasting session found"
        return 1
    fi

    IFS='|' read -r session_id start_time planned_hours <<< "$session_data"

    local end_time=$(date -Iseconds)
    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$start_time" +%s)
    local end_epoch=$(date +%s)
    local actual_hours=$(awk "BEGIN {printf \"%.2f\", ($end_epoch - $start_epoch) / 3600}")

    local completed=0
    [[ $(echo "$actual_hours >= $planned_hours" | bc -l) -eq 1 ]] && completed=1

    local safe_notes="${notes//\'/\'\'}"

    # Update session
    sqlite3 "$FASTING_DB" <<EOF
UPDATE fasting_sessions
SET
    end_time = '$end_time',
    actual_duration_hours = $actual_hours,
    status = 'completed',
    completed = $completed,
    broke_early = $broke_early,
    notes = notes || ' | End: $safe_notes'
WHERE id = $session_id;
EOF

    log_success "Fasting session ended!"
    echo ""
    echo -e "${BOLD}Session ID:${NC} $session_id"
    echo -e "${BOLD}Duration:${NC} ${actual_hours}h / ${planned_hours}h planned"

    if [[ $completed -eq 1 ]]; then
        echo -e "${GREEN}${BOLD}✓ COMPLETED!${NC} You did it!"
        notify "🎉 Fasting Complete!" "Completed ${actual_hours}h fast. Well done!" "normal"
    else
        echo -e "${YELLOW}Ended early after ${actual_hours}h${NC}"
        if [[ $broke_early -eq 1 ]]; then
            notify "Fasting Ended Early" "Completed ${actual_hours}h of ${planned_hours}h. Better luck next time!" "low"
        fi
    fi
    echo ""

    # Journal entry
    add_journal_entry "$session_id" "end" "Session ended. ${notes}"

    # Show stats
    show_session_summary "$session_id"
}

check_active_session() {
    local session_data=$(sqlite3 "$FASTING_DB" \
        "SELECT id, start_time, planned_duration_hours, fasting_type FROM fasting_sessions WHERE status = 'active' LIMIT 1;")

    if [[ -z "$session_data" ]]; then
        echo "No active fasting session"
        return 1
    fi

    IFS='|' read -r session_id start_time planned_hours fasting_type <<< "$session_data"

    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$start_time" +%s)
    local now_epoch=$(date +%s)
    local elapsed_seconds=$((now_epoch - start_epoch))
    local elapsed_hours=$(awk "BEGIN {printf \"%.1f\", $elapsed_seconds / 3600}")
    local remaining_hours=$(awk "BEGIN {printf \"%.1f\", $planned_hours - $elapsed_hours}")
    local progress=$(awk "BEGIN {printf \"%.0f\", ($elapsed_hours / $planned_hours) * 100}")

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              ACTIVE FASTING SESSION                       ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Session ID:${NC} $session_id"
    echo -e "${BOLD}Type:${NC} $fasting_type"
    echo -e "${BOLD}Started:${NC} $(date -d "$start_time" '+%Y-%m-%d %H:%M' 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$start_time" '+%Y-%m-%d %H:%M')"
    echo ""
    echo -e "${BOLD}Elapsed:${NC} ${elapsed_hours}h / ${planned_hours}h"
    echo -e "${BOLD}Remaining:${NC} ${remaining_hours}h"
    echo -e "${BOLD}Progress:${NC} ${progress}%"

    # Progress bar
    local bar_width=50
    local filled=$((progress * bar_width / 100))
    local empty=$((bar_width - filled))

    echo -n "["
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    for ((i=0; i<empty; i++)); do echo -n "░"; done
    echo "]"
    echo ""

    # Check for milestones
    check_milestones "$session_id" "$elapsed_hours"

    # Motivational message
    if [[ $progress -lt 25 ]]; then
        echo -e "${CYAN}💪 Just getting started. You've got this!${NC}"
    elif [[ $progress -lt 50 ]]; then
        echo -e "${CYAN}🔥 Keep going! You're building discipline.${NC}"
    elif [[ $progress -lt 75 ]]; then
        echo -e "${YELLOW}⚡ Over halfway! Don't break now.${NC}"
    elif [[ $progress -lt 100 ]]; then
        echo -e "${GREEN}🌟 Almost there! Finish strong!${NC}"
    else
        echo -e "${GREEN}${BOLD}✓ Goal reached! You can end anytime or keep going.${NC}"
    fi
    echo ""
}

check_milestones() {
    local session_id=$1
    local elapsed_hours=$2

    for milestone in "${MILESTONES[@]}"; do
        # Check if we've passed this milestone
        if (( $(echo "$elapsed_hours >= $milestone" | bc -l) )); then
            # Check if we've already recorded it
            local recorded=$(sqlite3 "$FASTING_DB" \
                "SELECT COUNT(*) FROM fasting_milestones WHERE session_id = $session_id AND milestone_hours = $milestone;")

            if [[ $recorded -eq 0 ]]; then
                # Record milestone
                sqlite3 "$FASTING_DB" \
                    "INSERT INTO fasting_milestones (session_id, milestone_hours) VALUES ($session_id, $milestone);"

                # Send notification
                if [[ $NOTIFY_MILESTONES -eq 1 ]]; then
                    local message=$(get_milestone_message "$milestone")
                    notify "🎯 Milestone Reached" "${milestone}h: $message" "normal"
                fi

                log_success "Milestone: ${milestone}h completed!"
            fi
        fi
    done
}

get_milestone_message() {
    local hours=$1

    case $hours in
        6)  echo "Autophagy begins. Your cells are cleaning house!" ;;
        12) echo "Growth hormone rising. Fat burning accelerating!" ;;
        16) echo "Deep autophagy. Mental clarity peaking!" ;;
        24) echo "One full day! Discipline level: Monk 🕉️" ;;
        48) echo "Two days! You're in rarified air now!" ;;
        72) echo "Three days! Stem cell regeneration activated!" ;;
        120) echo "Five days! You're basically superhuman now!" ;;
        168) echo "SEVEN DAYS! Full week completed! 🏆" ;;
        *) echo "Amazing progress! Keep going!" ;;
    esac
}

#=============================================================================
# Journal Functions
#=============================================================================

add_journal_entry() {
    local session_id=$1
    local entry_type=$2
    local content=$3
    local mood=${4:-5}
    local hunger=${5:-5}
    local safe_content="${content//\'/\'\'}"
    local safe_entry_type="${entry_type//\'/\'\'}"

    sqlite3 "$FASTING_DB" <<EOF
INSERT INTO fasting_journal (session_id, entry_type, content, mood, hunger_level)
VALUES ($session_id, '$safe_entry_type', '$safe_content', $mood, $hunger);
EOF
}

journal_interactive() {
    # Get active session
    local session_id=$(sqlite3 "$FASTING_DB" "SELECT id FROM fasting_sessions WHERE status = 'active' LIMIT 1;")

    if [[ -z "$session_id" ]]; then
        log_error "No active fasting session. Start one first!"
        return 1
    fi

    echo -e "${BOLD}Fasting Journal Entry${NC}"
    echo ""

    read -p "How are you feeling? (1-10): " mood
    read -p "Hunger level? (1-10): " hunger
    read -p "Notes: " notes

    add_journal_entry "$session_id" "manual" "$notes" "$mood" "$hunger"

    log_success "Journal entry saved"
}

show_journal() {
    local session_id=${1:-}

    local query="SELECT timestamp, entry_type, content, mood, hunger_level FROM fasting_journal"
    if [[ -n "$session_id" ]]; then
        query="$query WHERE session_id = $session_id"
    fi
    query="$query ORDER BY timestamp DESC LIMIT 20;"

    echo ""
    echo -e "${BOLD}Recent Journal Entries:${NC}"
    echo ""

    sqlite3 -header -column "$FASTING_DB" "$query"
    echo ""
}

#=============================================================================
# Schedule Management
#=============================================================================

show_schedule() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              FASTING SCHEDULE                             ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    sqlite3 -header -column "$FASTING_DB" \
        "SELECT id, schedule_type, day_of_week, week_of_quarter, duration_hours,
                CASE WHEN enabled = 1 THEN 'Yes' ELSE 'No' END as enabled
         FROM fasting_schedule
         ORDER BY schedule_type;"

    echo ""
}

update_schedule() {
    local schedule_id=$1
    local enabled=$2

    sqlite3 "$FASTING_DB" "UPDATE fasting_schedule SET enabled = $enabled WHERE id = $schedule_id;"
    log_success "Schedule updated"
}

add_custom_schedule() {
    local schedule_type=$1
    local day_of_week=${2:-NULL}
    local duration=$3
    local safe_schedule_type="${schedule_type//\'/\'\'}"
    local safe_day_of_week="${day_of_week//\'/\'\'}"

    sqlite3 "$FASTING_DB" <<EOF
INSERT INTO fasting_schedule (schedule_type, day_of_week, duration_hours, enabled)
VALUES ('$safe_schedule_type', $(if [[ "$day_of_week" != "NULL" ]]; then echo "'$safe_day_of_week'"; else echo "NULL"; fi), $duration, 1);
EOF

    log_success "Custom schedule added"
}

check_scheduled_fasts() {
    local today=$(date +%A | tr '[:upper:]' '[:lower:]')
    local week_of_quarter=$(get_week_of_quarter)

    # Check weekly schedule
    local weekly=$(sqlite3 "$FASTING_DB" \
        "SELECT duration_hours FROM fasting_schedule
         WHERE schedule_type = 'weekly' AND day_of_week = '$today' AND enabled = 1 LIMIT 1;")

    if [[ -n "$weekly" ]]; then
        echo "📅 Scheduled: Weekly $today fast ($weekly hours)"
        if ask_yes_no "Start now?" "y"; then
            start_fasting "weekly" "$weekly" "Scheduled weekly fast"
        fi
    fi

    # Check quarterly schedule
    local quarterly=$(sqlite3 "$FASTING_DB" \
        "SELECT duration_hours FROM fasting_schedule
         WHERE schedule_type = 'quarterly' AND week_of_quarter = $week_of_quarter AND enabled = 1 LIMIT 1;")

    if [[ -n "$quarterly" ]]; then
        echo "📅 Scheduled: Quarterly week-long fast ($quarterly hours)"
        if ask_yes_no "Start now?" "n"; then
            start_fasting "quarterly" "$quarterly" "Scheduled quarterly fast"
        fi
    fi
}

get_week_of_quarter() {
    local month=$(date +%-m)
    local quarter_month=$(( (month - 1) % 3 + 1 ))
    local week=$(( ($(date +%-d) - 1) / 7 + 1 ))

    echo $(( (quarter_month - 1) * 4 + week ))
}

#=============================================================================
# Statistics & Analytics
#=============================================================================

show_stats() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              FASTING STATISTICS                           ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Total sessions
    local total=$(sqlite3 "$FASTING_DB" "SELECT COUNT(*) FROM fasting_sessions;")
    local completed=$(sqlite3 "$FASTING_DB" "SELECT COUNT(*) FROM fasting_sessions WHERE completed = 1;")
    local broke_early=$(sqlite3 "$FASTING_DB" "SELECT COUNT(*) FROM fasting_sessions WHERE broke_early = 1;")
    local completion_rate=$(awk "BEGIN {printf \"%.0f\", ($completed / $total) * 100}")

    echo -e "${BOLD}Overall:${NC}"
    echo "  Total sessions: $total"
    echo "  Completed: $completed"
    echo "  Broke early: $broke_early"
    echo "  Completion rate: ${completion_rate}%"
    echo ""

    # Total fasting time
    local total_hours=$(sqlite3 "$FASTING_DB" \
        "SELECT COALESCE(SUM(actual_duration_hours), 0) FROM fasting_sessions WHERE status = 'completed';")
    local total_days=$(awk "BEGIN {printf \"%.1f\", $total_hours / 24}")

    echo -e "${BOLD}Time Fasted:${NC}"
    echo "  Total: ${total_hours}h (${total_days} days)"
    echo ""

    # By type
    echo -e "${BOLD}By Type:${NC}"
    sqlite3 -column "$FASTING_DB" \
        "SELECT fasting_type as Type,
                COUNT(*) as Sessions,
                ROUND(AVG(actual_duration_hours), 1) as 'Avg Hours',
                SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as Completed
         FROM fasting_sessions
         WHERE status = 'completed'
         GROUP BY fasting_type;"
    echo ""

    # Recent sessions
    echo -e "${BOLD}Recent Sessions (Last 10):${NC}"
    sqlite3 -header -column "$FASTING_DB" \
        "SELECT
            DATE(start_time) as Date,
            fasting_type as Type,
            ROUND(actual_duration_hours, 1) as Hours,
            CASE WHEN completed = 1 THEN '✓' ELSE '✗' END as Done
         FROM fasting_sessions
         WHERE status = 'completed'
         ORDER BY start_time DESC
         LIMIT 10;"
    echo ""

    # Current streak
    calculate_streak
}

calculate_streak() {
    local streak=0
    local last_date=""

    # Get sessions ordered by date (most recent first)
    while IFS='|' read -r session_date completed_flag; do
        if [[ $completed_flag -eq 1 ]]; then
            if [[ -z "$last_date" ]]; then
                streak=1
                last_date=$session_date
            else
                # Check if dates are consecutive (allowing for schedule gaps)
                # For now, simple increment
                ((streak++))
                last_date=$session_date
            fi
        else
            # Broke the streak
            break
        fi
    done < <(sqlite3 "$FASTING_DB" \
        "SELECT DATE(start_time), completed
         FROM fasting_sessions
         WHERE status = 'completed'
         ORDER BY start_time DESC;")

    echo -e "${BOLD}Current Streak:${NC} $streak completed fasts"
    echo ""
}

show_session_summary() {
    local session_id=$1

    echo ""
    echo -e "${BOLD}Session Summary:${NC}"

    sqlite3 -header -column "$FASTING_DB" \
        "SELECT
            id,
            fasting_type,
            DATETIME(start_time) as Started,
            DATETIME(end_time) as Ended,
            ROUND(actual_duration_hours, 2) as Hours,
            CASE WHEN completed = 1 THEN 'Yes' ELSE 'No' END as Completed
         FROM fasting_sessions
         WHERE id = $session_id;"

    # Milestones reached
    local milestones=$(sqlite3 "$FASTING_DB" \
        "SELECT GROUP_CONCAT(milestone_hours || 'h', ', ')
         FROM fasting_milestones
         WHERE session_id = $session_id;")

    if [[ -n "$milestones" ]]; then
        echo ""
        echo -e "${BOLD}Milestones Reached:${NC} $milestones"
    fi
    echo ""
}

export_data() {
    local format=${1:-"json"}
    local output_file="$REPORTS_DIR/fasting_export_$(date +%Y%m%d_%H%M%S).$format"

    mkdir -p "$REPORTS_DIR"

    case $format in
        json)
            sqlite3 "$FASTING_DB" <<EOF > "$output_file"
.mode json
SELECT * FROM fasting_sessions;
EOF
            ;;
        csv)
            sqlite3 "$FASTING_DB" <<EOF > "$output_file"
.mode csv
.headers on
SELECT * FROM fasting_sessions;
EOF
            ;;
        datasette)
            # Copy database for datasette
            cp "$FASTING_DB" "$REPORTS_DIR/fasting_datasette.db"
            output_file="$REPORTS_DIR/fasting_datasette.db"

            echo ""
            echo -e "${GREEN}Database ready for Datasette!${NC}"
            echo ""
            echo "To explore with Datasette:"
            echo "  1. Install: pip install datasette"
            echo "  2. Run: datasette $output_file"
            echo "  3. Open: http://localhost:8001"
            echo ""
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac

    log_success "Data exported to: $output_file"
}

#=============================================================================
# Background Monitoring
#=============================================================================

start_monitor() {
    log_info "Starting fasting monitor daemon..."

    # Check if already running
    if pgrep -f "monk-mode-fasting.sh monitor" &> /dev/null; then
        log_warn "Monitor already running"
        return 1
    fi

    # Run in background
    nohup "$0" monitor_daemon > "$LOG_DIR/fasting_monitor.log" 2>&1 &
    local pid=$!

    echo $pid > "$DATA_DIR/fasting_monitor.pid"
    log_success "Monitor started (PID: $pid)"
}

stop_monitor() {
    local pid_file="$DATA_DIR/fasting_monitor.pid"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            rm "$pid_file"
            log_success "Monitor stopped"
        else
            log_warn "Monitor not running (stale PID file)"
            rm "$pid_file"
        fi
    else
        log_warn "Monitor not running"
    fi
}

monitor_daemon() {
    while true; do
        sleep 3600  # Check every hour

        # Check active session
        local session_id=$(sqlite3 "$FASTING_DB" "SELECT id FROM fasting_sessions WHERE status = 'active' LIMIT 1;")

        if [[ -n "$session_id" ]]; then
            # Update progress and check milestones
            check_active_session > /dev/null
        fi

        # Check for scheduled fasts
        check_scheduled_fasts > /dev/null
    done
}

#=============================================================================
# Help & Main
#=============================================================================

show_help() {
    cat <<'EOF'
Usage: monk-mode-fasting.sh [COMMAND] [OPTIONS]

Disciplined fasting tracker with notifications and analytics

COMMANDS:
    start [TYPE] [HOURS] [NOTES]
                         Start a fasting session
    end [--broke]        End active session
    status               Check active session status
    journal              Add journal entry

    schedule             Show fasting schedule
    schedule add TYPE DAY HOURS
                         Add custom schedule
    schedule update ID ENABLED
                         Enable/disable schedule item
    check-schedule       Check for scheduled fasts today

    stats                Show fasting statistics
    history              Show session history
    export [json|csv|datasette]
                         Export data

    monitor start        Start background monitor
    monitor stop         Stop background monitor

START OPTIONS:
    TYPE: manual, weekly, quarterly, daily, custom
    HOURS: duration in hours (default: 24)
    NOTES: optional notes

SCHEDULE TYPES:
    weekly     - Every [day] for [hours]
    quarterly  - Week [N] of quarter for [hours]
    daily      - Daily intermittent fasting
    custom     - Your own schedule

EXAMPLES:
    # Start 24-hour fast
    $0 start manual 24 "Friday fast"

    # Start weekly Friday fast
    $0 start weekly 24

    # Check status
    $0 status

    # Add journal entry
    $0 journal

    # End session
    $0 end

    # End early (broke fast)
    $0 end --broke

    # View statistics
    $0 stats

    # Check today's schedule
    $0 check-schedule

    # Export for Datasette
    $0 export datasette

    # Start monitor daemon
    $0 monitor start

DEFAULT SCHEDULE:
    • Every Friday: 24-hour fast
    • First week of quarter: 7-day (168h) fast
    • Customizable via schedule commands

DATA STORAGE:
    All data stored in SQLite database: $FASTING_DB
    Compatible with Datasette for visualization

    To explore with Datasette:
      pip install datasette
      datasette $FASTING_DB

MILESTONES:
    6h   - Autophagy begins
    12h  - Growth hormone rising
    16h  - Deep autophagy
    24h  - One full day
    48h  - Two days
    72h  - Three days (stem cell regeneration)
    120h - Five days
    168h - Seven days (full week!)

NOTIFICATIONS:
    • Session start
    • Milestone achievements
    • Encouragement messages
    • Session completion

EOF
}

main() {
    local command=${1:-"status"}
    shift || true

    # Initialize database
    init_database

    case $command in
        start)
            start_fasting "${1:-manual}" "${2:-24}" "${3:-}"
            ;;
        end)
            local broke=0
            [[ "${1:-}" == "--broke" ]] && broke=1
            end_fasting "$broke" "${2:-}"
            ;;
        status)
            check_active_session
            ;;
        journal)
            journal_interactive
            ;;
        show-journal)
            show_journal "${1:-}"
            ;;
        schedule)
            if [[ $# -eq 0 ]]; then
                show_schedule
            elif [[ "$1" == "add" ]]; then
                add_custom_schedule "$2" "${3:-NULL}" "$4"
            elif [[ "$1" == "update" ]]; then
                update_schedule "$2" "$3"
            fi
            ;;
        check-schedule)
            check_scheduled_fasts
            ;;
        stats)
            show_stats
            ;;
        history)
            show_stats
            ;;
        export)
            export_data "${1:-json}"
            ;;
        monitor)
            case ${1:-} in
                start) start_monitor ;;
                stop) stop_monitor ;;
                daemon) monitor_daemon ;;
                *) log_error "Usage: $0 monitor [start|stop]" ;;
            esac
            ;;
        -h|--help|help)
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
