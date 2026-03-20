#!/bin/bash
#=============================================================================
# sovereign-routine.sh
# Master your daily routine with time-blocking and habit tracking
# "Own your day, own your life"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

ROUTINE_DB="$DATA_DIR/routine.db"
CONFIG_FILE="$DATA_DIR/routine_config.json"

# Notification settings
NOTIFY_BLOCK_START=${NOTIFY_BLOCK_START:-1}
NOTIFY_BLOCK_END=${NOTIFY_BLOCK_END:-1}
NOTIFY_REMINDERS=${NOTIFY_REMINDERS:-1}
NOTIFY_ACHIEVEMENTS=${NOTIFY_ACHIEVEMENTS:-1}

# Auto-tracking
AUTO_START_DAY=${AUTO_START_DAY:-1}
AUTO_TRACK_BLOCKS=${AUTO_TRACK_BLOCKS:-0}

#=============================================================================
# Database Setup
#=============================================================================

init_database() {
    if [[ ! -f "$ROUTINE_DB" ]]; then
        log_info "Creating routine database..."

        sqlite3 "$ROUTINE_DB" <<'EOF'
-- Daily sessions (one per day)
CREATE TABLE IF NOT EXISTS daily_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date DATE UNIQUE NOT NULL,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    status TEXT DEFAULT 'active',
    completion_percentage INTEGER DEFAULT 0,
    total_blocks_planned INTEGER DEFAULT 0,
    total_blocks_completed INTEGER DEFAULT 0,
    energy_level_morning INTEGER,
    energy_level_evening INTEGER,
    overall_rating INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Time blocks definition (template)
CREATE TABLE IF NOT EXISTS block_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_name TEXT NOT NULL,
    time_slot TEXT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    mandatory BOOLEAN DEFAULT 1,
    order_index INTEGER NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Actual blocks completed each day
CREATE TABLE IF NOT EXISTS daily_blocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    block_template_id INTEGER NOT NULL,
    block_name TEXT NOT NULL,
    scheduled_start TIME NOT NULL,
    scheduled_end TIME NOT NULL,
    actual_start TIMESTAMP,
    actual_end TIMESTAMP,
    status TEXT DEFAULT 'pending',
    completed BOOLEAN DEFAULT 0,
    skipped BOOLEAN DEFAULT 0,
    quality_rating INTEGER,
    energy_level INTEGER,
    focus_level INTEGER,
    notes TEXT,
    FOREIGN KEY (session_id) REFERENCES daily_sessions(id),
    FOREIGN KEY (block_template_id) REFERENCES block_templates(id)
);

-- Activity logging within blocks
CREATE TABLE IF NOT EXISTS block_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    daily_block_id INTEGER NOT NULL,
    activity_type TEXT,
    description TEXT,
    duration_minutes INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (daily_block_id) REFERENCES daily_blocks(id)
);

-- Habit streaks and statistics
CREATE TABLE IF NOT EXISTS habit_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_name TEXT NOT NULL,
    date DATE NOT NULL,
    completed BOOLEAN DEFAULT 0,
    quality_score INTEGER,
    UNIQUE(block_name, date)
);

-- Daily journal/reflection
CREATE TABLE IF NOT EXISTS daily_journal (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    entry_type TEXT,
    content TEXT,
    mood INTEGER,
    gratitude TEXT,
    lessons_learned TEXT,
    tomorrow_focus TEXT,
    FOREIGN KEY (session_id) REFERENCES daily_sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_date ON daily_sessions(date);
CREATE INDEX IF NOT EXISTS idx_blocks_session ON daily_blocks(session_id);
CREATE INDEX IF NOT EXISTS idx_blocks_status ON daily_blocks(status);
CREATE INDEX IF NOT EXISTS idx_habits_date ON habit_stats(date);
CREATE INDEX IF NOT EXISTS idx_habits_block ON habit_stats(block_name);
EOF

        log_success "Database created: $ROUTINE_DB"
        init_default_blocks
    fi
}

init_default_blocks() {
    log_info "Setting up default routine blocks..."

    sqlite3 "$ROUTINE_DB" <<'EOF'
-- Morning Routine
INSERT INTO block_templates (block_name, time_slot, start_time, end_time, duration_minutes, category, description, order_index, mandatory)
VALUES
    ('Morning Walk', 'morning', '06:00', '06:30', 30, 'exercise', 'Morning walk for fresh air and movement', 1, 1),
    ('Morning Reading', 'morning', '06:30', '07:00', 30, 'learning', 'Read books, articles, or educational content', 2, 1),
    ('Personal Work', 'morning', '07:00', '12:00', 300, 'deep_work', 'Work on personal projects and goals', 3, 1);

-- Lunch Block
INSERT INTO block_templates (block_name, time_slot, start_time, end_time, duration_minutes, category, description, order_index, mandatory)
VALUES
    ('Lunch Sport', 'lunch', '12:00', '13:00', 60, 'exercise', 'Workout, gym, or sports activity', 4, 1),
    ('Lunch Meal', 'lunch', '13:00', '13:30', 30, 'nutrition', 'Healthy lunch and refuel', 5, 1);

-- Afternoon Routine
INSERT INTO block_templates (block_name, time_slot, start_time, end_time, duration_minutes, category, description, order_index, mandatory)
VALUES
    ('Business Work', 'afternoon', '13:30', '18:00', 270, 'deep_work', 'Professional work and business tasks', 6, 1);

-- Evening Routine
INSERT INTO block_templates (block_name, time_slot, start_time, end_time, duration_minutes, category, description, order_index, mandatory)
VALUES
    ('Dinner', 'evening', '18:00', '19:00', 60, 'nutrition', 'Evening meal', 7, 1),
    ('Evening Reading', 'evening', '19:00', '20:00', 60, 'learning', 'Reading for knowledge or pleasure', 8, 1),
    ('Chill Time', 'evening', '20:00', '22:00', 120, 'rest', 'Relax, unwind, and recharge', 9, 1);
EOF

    log_success "Default routine configured"
}

#=============================================================================
# Daily Session Management
#=============================================================================

start_day() {
    local today=$(date +%Y-%m-%d)

    # Check if session already exists
    local existing=$(sqlite3 "$ROUTINE_DB" "SELECT id FROM daily_sessions WHERE date = '$today';")

    if [[ -n "$existing" ]]; then
        log_warn "Today's session already started (ID: $existing)"
        echo "Use '$0 status' to see current progress"
        return 1
    fi

    local start_time=$(date -Iseconds)

    # Create daily session
    sqlite3 "$ROUTINE_DB" <<EOF
INSERT INTO daily_sessions (date, started_at, status)
VALUES ('$today', '$start_time', 'active');
EOF

    local session_id=$(sqlite3 "$ROUTINE_DB" "SELECT last_insert_rowid();")

    # Create blocks for today based on templates
    create_daily_blocks "$session_id"

    log_success "New day started!"
    echo ""
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║              TODAY'S ROUTINE - $today              ║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Session ID:${NC} $session_id"
    echo -e "${BOLD}Started:${NC} $(date)"
    echo ""

    # Show today's blocks
    show_blocks_summary "$session_id"

    # Send notification
    if [[ $NOTIFY_BLOCK_START -eq 1 ]]; then
        notify "🌅 New Day Started" "Time to conquer your routine!" "normal"
    fi

    # Prompt for morning energy
    read -p "Morning energy level (1-10): " energy
    local safe_energy="${energy//\'/\'\'}"
    sqlite3 "$ROUTINE_DB" "UPDATE daily_sessions SET energy_level_morning = '$safe_energy' WHERE id = $session_id;"

    echo ""
    echo -e "${CYAN}Track progress with:${NC} $0 status"
    echo -e "${CYAN}Start first block with:${NC} $0 start <block-name>"
    echo ""
}

create_daily_blocks() {
    local session_id=$1

    # Get all enabled block templates
    sqlite3 "$ROUTINE_DB" <<EOF
INSERT INTO daily_blocks (session_id, block_template_id, block_name, scheduled_start, scheduled_end, status)
SELECT
    $session_id,
    id,
    block_name,
    start_time,
    end_time,
    'pending'
FROM block_templates
WHERE enabled = 1
ORDER BY order_index;
EOF

    # Update total blocks planned
    local total=$(sqlite3 "$ROUTINE_DB" "SELECT COUNT(*) FROM daily_blocks WHERE session_id = $session_id;")
    sqlite3 "$ROUTINE_DB" "UPDATE daily_sessions SET total_blocks_planned = $total WHERE id = $session_id;"
}

end_day() {
    local today=$(date +%Y-%m-%d)
    local session_id=$(get_today_session_id)

    if [[ -z "$session_id" ]]; then
        log_error "No active session for today. Start the day first!"
        return 1
    fi

    local end_time=$(date -Iseconds)

    # Calculate completion
    local completed=$(sqlite3 "$ROUTINE_DB" \
        "SELECT COUNT(*) FROM daily_blocks WHERE session_id = $session_id AND completed = 1;")
    local total=$(sqlite3 "$ROUTINE_DB" \
        "SELECT total_blocks_planned FROM daily_sessions WHERE id = $session_id;")
    local percentage=$(awk "BEGIN {printf \"%.0f\", ($completed / $total) * 100}")

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              END OF DAY REVIEW                            ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Prompt for evening reflection
    read -p "Evening energy level (1-10): " energy_evening
    read -p "Overall day rating (1-10): " rating
    read -p "Quick wins today: " wins
    read -p "What to improve tomorrow: " improve

    local safe_wins="${wins//\'/\'\'}"
    local safe_improve="${improve//\'/\'\'}"

    # Update session
    sqlite3 "$ROUTINE_DB" <<EOF
UPDATE daily_sessions
SET
    completed_at = '$end_time',
    status = 'completed',
    completion_percentage = $percentage,
    total_blocks_completed = $completed,
    energy_level_evening = $energy_evening,
    overall_rating = $rating,
    notes = 'Wins: $safe_wins | Improve: $safe_improve'
WHERE id = $session_id;
EOF

    # Add journal entry
    sqlite3 "$ROUTINE_DB" <<EOF
INSERT INTO daily_journal (session_id, entry_type, content, mood, tomorrow_focus)
VALUES ($session_id, 'end_of_day', 'Wins: $safe_wins', $rating, '$safe_improve');
EOF

    # Update habit stats
    update_habit_stats "$session_id"

    echo ""
    echo -e "${BOLD}Day Summary:${NC}"
    echo "  Blocks completed: $completed / $total (${percentage}%)"
    echo "  Energy: Morning $(sqlite3 "$ROUTINE_DB" "SELECT energy_level_morning FROM daily_sessions WHERE id = $session_id;") / Evening $energy_evening"
    echo "  Rating: ${rating}/10"
    echo ""

    if [[ $percentage -eq 100 ]]; then
        echo -e "${GREEN}${BOLD}🏆 PERFECT DAY! All blocks completed!${NC}"
        notify "🏆 Perfect Day!" "100% completion! You're unstoppable!" "normal"
    elif [[ $percentage -ge 80 ]]; then
        echo -e "${GREEN}✓ Excellent day! ${percentage}% completion${NC}"
        notify "✓ Great Day!" "${percentage}% completion!" "normal"
    elif [[ $percentage -ge 60 ]]; then
        echo -e "${YELLOW}Good effort. ${percentage}% completion${NC}"
    else
        echo -e "${RED}Room for improvement. ${percentage}% completion${NC}"
    fi
    echo ""

    # Show streak
    calculate_streak
}

update_habit_stats() {
    local session_id=$1
    local today=$(date +%Y-%m-%d)

    # Get completed blocks
    sqlite3 "$ROUTINE_DB" <<EOF
INSERT OR REPLACE INTO habit_stats (block_name, date, completed, quality_score)
SELECT
    block_name,
    '$today',
    completed,
    quality_rating
FROM daily_blocks
WHERE session_id = $session_id;
EOF
}

#=============================================================================
# Block Management
#=============================================================================

start_block() {
    local block_name=$1
    local session_id=$(get_today_session_id)

    if [[ -z "$session_id" ]]; then
        log_error "No active session. Start the day first with: $0 start-day"
        return 1
    fi

    local safe_block_name="${block_name//\'/\'\'}"

    # Get block
    local block_id=$(sqlite3 "$ROUTINE_DB" \
        "SELECT id FROM daily_blocks
         WHERE session_id = $session_id AND block_name LIKE '%$safe_block_name%' AND status = 'pending'
         LIMIT 1;")

    if [[ -z "$block_id" ]]; then
        log_error "Block not found or already completed: $block_name"
        return 1
    fi

    local start_time=$(date -Iseconds)

    # Update block
    sqlite3 "$ROUTINE_DB" \
        "UPDATE daily_blocks SET status = 'active', actual_start = '$start_time' WHERE id = $block_id;"

    # Get block details
    local details=$(sqlite3 "$ROUTINE_DB" \
        "SELECT block_name, scheduled_start, scheduled_end FROM daily_blocks WHERE id = $block_id;")

    IFS='|' read -r name sched_start sched_end <<< "$details"

    log_success "Block started: $name"
    echo ""
    echo -e "${BOLD}Block:${NC} $name"
    echo -e "${BOLD}Scheduled:${NC} $sched_start - $sched_end"
    echo -e "${BOLD}Started:${NC} $(date '+%H:%M')"
    echo ""

    # Send notification
    if [[ $NOTIFY_BLOCK_START -eq 1 ]]; then
        notify "⏰ $name Started" "Focus time! Make it count." "normal"
    fi

    echo -e "${CYAN}Complete with:${NC} $0 complete '$name'"
    echo ""
}

complete_block() {
    local block_name=$1
    local session_id=$(get_today_session_id)

    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi

    local safe_block_name="${block_name//\'/\'\'}"

    # Get active block
    local block_id=$(sqlite3 "$ROUTINE_DB" \
        "SELECT id FROM daily_blocks
         WHERE session_id = $session_id AND block_name LIKE '%$safe_block_name%' AND status = 'active'
         LIMIT 1;")

    if [[ -z "$block_id" ]]; then
        log_error "Block not active or not found: $block_name"
        return 1
    fi

    local end_time=$(date -Iseconds)

    echo ""
    read -p "Quality rating (1-10): " quality
    read -p "Energy level (1-10): " energy
    read -p "Focus level (1-10): " focus
    read -p "Notes: " notes

    local safe_notes="${notes//\'/\'\'}"

    # Update block
    sqlite3 "$ROUTINE_DB" <<EOF
UPDATE daily_blocks
SET
    status = 'completed',
    actual_end = '$end_time',
    completed = 1,
    quality_rating = $quality,
    energy_level = $energy,
    focus_level = $focus,
    notes = '$safe_notes'
WHERE id = $block_id;
EOF

    # Update session completion count
    local completed=$(sqlite3 "$ROUTINE_DB" \
        "SELECT COUNT(*) FROM daily_blocks WHERE session_id = $session_id AND completed = 1;")
    local total=$(sqlite3 "$ROUTINE_DB" \
        "SELECT total_blocks_planned FROM daily_sessions WHERE id = $session_id;")
    local percentage=$(awk "BEGIN {printf \"%.0f\", ($completed / $total) * 100}")

    sqlite3 "$ROUTINE_DB" <<EOF
UPDATE daily_sessions
SET
    total_blocks_completed = $completed,
    completion_percentage = $percentage
WHERE id = $session_id;
EOF

    log_success "Block completed!"
    echo ""
    echo -e "${BOLD}Progress:${NC} $completed / $total blocks (${percentage}%)"
    echo ""

    # Send notification
    if [[ $NOTIFY_BLOCK_END -eq 1 ]]; then
        notify "✓ Block Complete" "$block_name done! Progress: ${percentage}%" "normal"
    fi

    # Check if all blocks done
    if [[ $completed -eq $total ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL BLOCKS COMPLETED TODAY!${NC}"
        notify "🏆 Day Complete!" "All blocks done! Perfect execution!" "normal"
    fi
}

skip_block() {
    local block_name=$1
    local reason=${2:-"No reason provided"}
    local session_id=$(get_today_session_id)

    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        return 1
    fi

    # Get block
    local safe_block_name="${block_name//\'/\'\'}"
    local block_id=$(sqlite3 "$ROUTINE_DB" \
        "SELECT id FROM daily_blocks
         WHERE session_id = $session_id AND block_name LIKE '%$safe_block_name%' AND status IN ('pending', 'active')
         LIMIT 1;")

    if [[ -z "$block_id" ]]; then
        log_error "Block not found: $block_name"
        return 1
    fi

    local safe_reason="${reason//\'/\'\'}"

    # Mark as skipped
    sqlite3 "$ROUTINE_DB" \
        "UPDATE daily_blocks SET status = 'skipped', skipped = 1, notes = 'Skipped: $safe_reason' WHERE id = $block_id;"

    log_warn "Block skipped: $block_name"
    echo "  Reason: $reason"
    echo ""
}

#=============================================================================
# Status & Progress
#=============================================================================

show_status() {
    local session_id=$(get_today_session_id)

    if [[ -z "$session_id" ]]; then
        echo ""
        echo -e "${YELLOW}No active session for today${NC}"
        echo "Start your day with: $0 start-day"
        echo ""
        return 1
    fi

    local today=$(date +%Y-%m-%d)

    # Get session info
    local session_data=$(sqlite3 "$ROUTINE_DB" \
        "SELECT completion_percentage, total_blocks_completed, total_blocks_planned, energy_level_morning
         FROM daily_sessions WHERE id = $session_id;")

    IFS='|' read -r percentage completed total energy_morning <<< "$session_data"

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              TODAY'S PROGRESS - $today              ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Completion:${NC} $completed / $total blocks (${percentage}%)"
    echo -e "${BOLD}Morning Energy:${NC} ${energy_morning}/10"
    echo ""

    # Progress bar
    local bar_width=50
    local filled=$((percentage * bar_width / 100))
    local empty=$((bar_width - filled))

    echo -n "["
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    for ((i=0; i<empty; i++)); do echo -n "░"; done
    echo "] ${percentage}%"
    echo ""

    # Current time and next block
    local current_time=$(date +%H:%M)
    echo -e "${BOLD}Current Time:${NC} $current_time"
    echo ""

    # Show blocks by status
    echo -e "${BOLD}${GREEN}Completed:${NC}"
    sqlite3 -column "$ROUTINE_DB" \
        "SELECT block_name as Block, scheduled_start as Time, quality_rating as Quality
         FROM daily_blocks
         WHERE session_id = $session_id AND completed = 1
         ORDER BY order_index;" 2>/dev/null | grep -v "^$" || echo "  None yet"
    echo ""

    echo -e "${BOLD}${BLUE}Active:${NC}"
    sqlite3 -column "$ROUTINE_DB" \
        "SELECT block_name as Block, scheduled_start as Start, scheduled_end as End
         FROM daily_blocks b
         JOIN block_templates t ON b.block_template_id = t.id
         WHERE session_id = $session_id AND status = 'active'
         ORDER BY b.order_index;" 2>/dev/null | grep -v "^$" || echo "  None"
    echo ""

    echo -e "${BOLD}${YELLOW}Pending:${NC}"
    sqlite3 -column "$ROUTINE_DB" \
        "SELECT block_name as Block, scheduled_start as Time
         FROM daily_blocks b
         JOIN block_templates t ON b.block_template_id = t.id
         WHERE session_id = $session_id AND status = 'pending'
         ORDER BY b.order_index;" 2>/dev/null | grep -v "^$" || echo "  None"
    echo ""

    # Motivational message
    if [[ $percentage -lt 25 ]]; then
        echo -e "${CYAN}💪 Fresh start! Make today count.${NC}"
    elif [[ $percentage -lt 50 ]]; then
        echo -e "${CYAN}🔥 Building momentum! Keep going.${NC}"
    elif [[ $percentage -lt 75 ]]; then
        echo -e "${YELLOW}⚡ Over halfway! Stay focused.${NC}"
    elif [[ $percentage -lt 100 ]]; then
        echo -e "${GREEN}🌟 Almost there! Finish strong!${NC}"
    else
        echo -e "${GREEN}${BOLD}🏆 ALL BLOCKS COMPLETE! Perfect day!${NC}"
    fi
    echo ""
}

show_blocks_summary() {
    local session_id=$1

    echo -e "${BOLD}Today's Schedule:${NC}"
    echo ""

    sqlite3 -header -column "$ROUTINE_DB" \
        "SELECT
            block_name as Block,
            scheduled_start as Start,
            scheduled_end as End,
            ROUND(CAST(duration_minutes AS FLOAT) / 60.0, 1) || 'h' as Duration
         FROM daily_blocks b
         JOIN block_templates t ON b.block_template_id = t.id
         WHERE session_id = $session_id
         ORDER BY b.order_index;" 2>/dev/null

    echo ""
}

#=============================================================================
# Statistics & Analytics
#=============================================================================

show_stats() {
    local days=${1:-30}

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              ROUTINE STATISTICS                           ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Overall stats
    local total_days=$(sqlite3 "$ROUTINE_DB" \
        "SELECT COUNT(*) FROM daily_sessions WHERE status = 'completed';")
    local avg_completion=$(sqlite3 "$ROUTINE_DB" \
        "SELECT ROUND(AVG(completion_percentage)) FROM daily_sessions WHERE status = 'completed';")
    local perfect_days=$(sqlite3 "$ROUTINE_DB" \
        "SELECT COUNT(*) FROM daily_sessions WHERE completion_percentage = 100;")

    echo -e "${BOLD}Overall:${NC}"
    echo "  Total days tracked: $total_days"
    echo "  Average completion: ${avg_completion}%"
    echo "  Perfect days (100%): $perfect_days"
    echo ""

    # Current streak
    calculate_streak

    # Block completion rates
    echo -e "${BOLD}Block Completion Rates (Last $days days):${NC}"
    sqlite3 -header -column "$ROUTINE_DB" <<EOF
SELECT
    block_name as Block,
    COUNT(*) as Total,
    SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as Completed,
    ROUND(100.0 * SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) / COUNT(*)) || '%' as Rate,
    ROUND(AVG(quality_rating), 1) as 'Avg Quality'
FROM daily_blocks
WHERE date(actual_start) >= date('now', '-$days days')
GROUP BY block_name
ORDER BY Rate DESC;
EOF
    echo ""

    # Best and worst days
    echo -e "${BOLD}Recent Performance:${NC}"
    sqlite3 -header -column "$ROUTINE_DB" \
        "SELECT
            date as Date,
            completion_percentage || '%' as Completion,
            overall_rating as Rating,
            total_blocks_completed || '/' || total_blocks_planned as Blocks
         FROM daily_sessions
         WHERE status = 'completed'
         ORDER BY date DESC
         LIMIT 10;"
    echo ""

    # Energy levels
    local avg_morning=$(sqlite3 "$ROUTINE_DB" \
        "SELECT ROUND(AVG(energy_level_morning), 1) FROM daily_sessions WHERE energy_level_morning IS NOT NULL;")
    local avg_evening=$(sqlite3 "$ROUTINE_DB" \
        "SELECT ROUND(AVG(energy_level_evening), 1) FROM daily_sessions WHERE energy_level_evening IS NOT NULL;")

    echo -e "${BOLD}Average Energy Levels:${NC}"
    echo "  Morning: ${avg_morning}/10"
    echo "  Evening: ${avg_evening}/10"
    echo ""
}

calculate_streak() {
    local streak=0
    local last_date=""

    # Get sessions ordered by date (most recent first)
    while IFS='|' read -r session_date completion; do
        if [[ $completion -ge 80 ]]; then
            if [[ -z "$last_date" ]]; then
                streak=1
                last_date=$session_date
            else
                # Check if consecutive days
                local last_epoch=$(date -d "$last_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$last_date" +%s)
                local current_epoch=$(date -d "$session_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$session_date" +%s)
                local diff_days=$(( (last_epoch - current_epoch) / 86400 ))

                if [[ $diff_days -eq 1 ]]; then
                    ((streak++))
                    last_date=$session_date
                else
                    break
                fi
            fi
        else
            break
        fi
    done < <(sqlite3 "$ROUTINE_DB" \
        "SELECT date, completion_percentage
         FROM daily_sessions
         WHERE status = 'completed'
         ORDER BY date DESC;")

    echo -e "${BOLD}Current Streak:${NC} $streak days (≥80% completion)"

    if [[ $streak -ge 30 ]]; then
        echo -e "${GREEN}🔥🔥🔥 ON FIRE! 30+ day streak!${NC}"
    elif [[ $streak -ge 7 ]]; then
        echo -e "${GREEN}🔥 Week+ streak! Keep it up!${NC}"
    elif [[ $streak -ge 3 ]]; then
        echo -e "${YELLOW}📈 Building momentum!${NC}"
    fi
    echo ""
}

#=============================================================================
# Templates & Customization
#=============================================================================

show_templates() {
    echo ""
    echo -e "${BOLD}Current Routine Template:${NC}"
    echo ""

    sqlite3 -header -column "$ROUTINE_DB" \
        "SELECT
            id as ID,
            block_name as Block,
            time_slot as Slot,
            start_time as Start,
            end_time as End,
            ROUND(CAST(duration_minutes AS FLOAT) / 60.0, 1) || 'h' as Duration,
            category as Category,
            CASE WHEN enabled = 1 THEN 'Yes' ELSE 'No' END as Enabled
         FROM block_templates
         ORDER BY order_index;"

    echo ""
}

add_block_template() {
    local name=$1
    local slot=$2
    local start=$3
    local end=$4
    local category=$5
    local description=${6:-""}

    # Calculate duration
    local start_min=$(( $(date -d "$start" +%-H) * 60 + $(date -d "$start" +%-M) ))
    local end_min=$(( $(date -d "$end" +%-H) * 60 + $(date -d "$end" +%-M) ))
    local duration=$((end_min - start_min))

    # Get next order index
    local order=$(sqlite3 "$ROUTINE_DB" "SELECT COALESCE(MAX(order_index), 0) + 1 FROM block_templates;")

    local safe_name="${name//\'/\'\'}"
    local safe_slot="${slot//\'/\'\'}"
    local safe_start="${start//\'/\'\'}"
    local safe_end="${end//\'/\'\'}"
    local safe_category="${category//\'/\'\'}"
    local safe_description="${description//\'/\'\'}"

    sqlite3 "$ROUTINE_DB" <<EOF
INSERT INTO block_templates (block_name, time_slot, start_time, end_time, duration_minutes, category, description, order_index)
VALUES ('$safe_name', '$safe_slot', '$safe_start', '$safe_end', $duration, '$safe_category', '$safe_description', $order);
EOF

    log_success "Block template added: $name"
}

update_block_template() {
    local block_id=$1
    local field=$2
    local value=$3

    local safe_value="${value//\'/\'\'}"

    sqlite3 "$ROUTINE_DB" "UPDATE block_templates SET $field = '$safe_value' WHERE id = $block_id;"
    log_success "Block template updated"
}

toggle_block() {
    local block_id=$1

    local current=$(sqlite3 "$ROUTINE_DB" "SELECT enabled FROM block_templates WHERE id = $block_id;")
    local new=$((1 - current))

    sqlite3 "$ROUTINE_DB" "UPDATE block_templates SET enabled = $new WHERE id = $block_id;"

    if [[ $new -eq 1 ]]; then
        log_success "Block enabled"
    else
        log_warn "Block disabled"
    fi
}

#=============================================================================
# Export & Datasette
#=============================================================================

export_data() {
    local format=${1:-"json"}
    local output_file="$REPORTS_DIR/routine_export_$(date +%Y%m%d_%H%M%S).$format"

    mkdir -p "$REPORTS_DIR"

    case $format in
        json)
            sqlite3 "$ROUTINE_DB" <<EOF > "$output_file"
.mode json
SELECT * FROM daily_sessions;
EOF
            ;;
        csv)
            sqlite3 "$ROUTINE_DB" <<EOF > "$output_file"
.mode csv
.headers on
SELECT * FROM daily_sessions;
EOF
            ;;
        datasette)
            cp "$ROUTINE_DB" "$REPORTS_DIR/routine_datasette.db"
            output_file="$REPORTS_DIR/routine_datasette.db"

            echo ""
            echo -e "${GREEN}Database ready for Datasette!${NC}"
            echo ""
            echo "To explore with Datasette:"
            echo "  1. Install: pip install datasette"
            echo "  2. Run: datasette $output_file"
            echo "  3. Open: http://localhost:8001"
            echo ""
            echo "Explore your data:"
            echo "  • Daily completion trends"
            echo "  • Block performance heatmaps"
            echo "  • Energy level patterns"
            echo "  • Habit streaks visualization"
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
# Utilities
#=============================================================================

get_today_session_id() {
    local today=$(date +%Y-%m-%d)
    sqlite3 "$ROUTINE_DB" "SELECT id FROM daily_sessions WHERE date = '$today' AND status = 'active' LIMIT 1;"
}

#=============================================================================
# Background Monitor
#=============================================================================

start_monitor() {
    log_info "Starting routine monitor daemon..."

    if pgrep -f "sovereign-routine.sh monitor" &> /dev/null; then
        log_warn "Monitor already running"
        return 1
    fi

    nohup "$0" monitor_daemon > "$LOG_DIR/routine_monitor.log" 2>&1 &
    local pid=$!

    echo $pid > "$DATA_DIR/routine_monitor.pid"
    log_success "Monitor started (PID: $pid)"
}

stop_monitor() {
    local pid_file="$DATA_DIR/routine_monitor.pid"

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
        sleep 300  # Check every 5 minutes

        local session_id=$(get_today_session_id)
        if [[ -z "$session_id" ]]; then
            # Auto-start day if enabled
            if [[ $AUTO_START_DAY -eq 1 ]]; then
                local hour=$(date +%-H)
                if [[ $hour -ge 6 ]] && [[ $hour -lt 7 ]]; then
                    start_day > /dev/null 2>&1
                fi
            fi
            continue
        fi

        # Check for block transitions
        local current_time=$(date +%H:%M)

        # Notify about upcoming blocks
        if [[ $NOTIFY_REMINDERS -eq 1 ]]; then
            local upcoming=$(sqlite3 "$ROUTINE_DB" \
                "SELECT block_name FROM daily_blocks
                 WHERE session_id = $session_id
                   AND status = 'pending'
                   AND time(scheduled_start) <= time('$current_time', '+5 minutes')
                   AND time(scheduled_start) > time('$current_time')
                 LIMIT 1;")

            if [[ -n "$upcoming" ]]; then
                notify "⏰ Upcoming Block" "$upcoming starts in 5 minutes" "normal"
            fi
        fi
    done
}

#=============================================================================
# Help & Main
#=============================================================================

show_help() {
    cat <<'EOF'
Usage: sovereign-routine.sh [COMMAND] [OPTIONS]

Master your daily routine with time-blocking and habit tracking

COMMANDS:
    start-day            Start a new day session
    end-day              End day and review performance
    status               Show current progress

    start <block>        Start a time block
    complete <block>     Complete current block
    skip <block> [reason]
                         Skip a block

    templates            Show routine template
    templates add NAME SLOT START END CATEGORY [DESC]
                         Add custom block
    templates toggle ID  Enable/disable block

    stats [days]         Show statistics (default: 30 days)
    export [json|csv|datasette]
                         Export data

    monitor start        Start background monitor
    monitor stop         Stop background monitor

EXAMPLES:
    # Start your day
    $0 start-day

    # Check progress
    $0 status

    # Start morning walk
    $0 start "Morning Walk"

    # Complete block
    $0 complete "Morning Walk"

    # Skip block
    $0 skip "Lunch Sport" "Injured knee"

    # View stats
    $0 stats

    # View last 7 days
    $0 stats 7

    # Export for Datasette
    $0 export datasette

    # Add custom block
    $0 templates add "Meditation" morning 05:30 06:00 mindfulness "Morning meditation"

    # Toggle block
    $0 templates toggle 5

DEFAULT ROUTINE:
    MORNING (6h)
      06:00-06:30  Morning Walk (30m)
      06:30-07:00  Morning Reading (30m)
      07:00-12:00  Personal Work (5h)

    LUNCH (1.5h)
      12:00-13:00  Lunch Sport (1h)
      13:00-13:30  Lunch Meal (30m)

    AFTERNOON (4.5h)
      13:30-18:00  Business Work (4.5h)

    EVENING (4h)
      18:00-19:00  Dinner (1h)
      19:00-20:00  Evening Reading (1h)
      20:00-22:00  Chill Time (2h)

TRACKING:
    • Completion percentage
    • Energy levels (morning/evening)
    • Quality ratings per block
    • Focus levels
    • Daily journal entries
    • Habit streaks

STATISTICS:
    • Overall completion rates
    • Per-block performance
    • Energy patterns
    • Best/worst days
    • Current streak
    • Perfect days (100% completion)

DATASETTE INTEGRATION:
    All data stored in SQLite database: $ROUTINE_DB

    Tables:
      • daily_sessions - Daily overview
      • daily_blocks - Individual time blocks
      • block_templates - Your routine template
      • habit_stats - Long-term habit data
      • daily_journal - Reflections and notes

    Visualize with Datasette:
      datasette $ROUTINE_DB

NOTIFICATIONS:
    • Block start/end reminders
    • 5-minute warnings for upcoming blocks
    • Completion milestones
    • Streak achievements

EOF
}

main() {
    local command=${1:-"status"}
    shift || true

    # Initialize database
    init_database

    case $command in
        start-day)
            start_day
            ;;
        end-day)
            end_day
            ;;
        status)
            show_status
            ;;
        start)
            if [[ $# -lt 1 ]]; then
                log_error "Please provide block name"
                echo "Usage: $0 start <block-name>"
                exit 1
            fi
            start_block "$1"
            ;;
        complete)
            if [[ $# -lt 1 ]]; then
                log_error "Please provide block name"
                echo "Usage: $0 complete <block-name>"
                exit 1
            fi
            complete_block "$1"
            ;;
        skip)
            if [[ $# -lt 1 ]]; then
                log_error "Please provide block name"
                echo "Usage: $0 skip <block-name> [reason]"
                exit 1
            fi
            skip_block "$1" "${2:-No reason provided}"
            ;;
        templates)
            case ${1:-} in
                add)
                    add_block_template "$2" "$3" "$4" "$5" "$6" "${7:-}"
                    ;;
                update)
                    update_block_template "$2" "$3" "$4"
                    ;;
                toggle)
                    toggle_block "$2"
                    ;;
                *)
                    show_templates
                    ;;
            esac
            ;;
        stats)
            show_stats "${1:-30}"
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
