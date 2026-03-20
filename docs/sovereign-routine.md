# Sovereign Routine

Master your daily routine with time-blocking, habit tracking, and analytics. Full Datasette integration for visualizing your productivity patterns.

## Overview

Comprehensive daily routine tracker that helps you own your day through structured time-blocking. Tracks completion, quality, energy levels, and builds long-term habit data. Exports to Datasette for deep analysis of your productivity patterns.

## Features

- SQLite database (Datasette-compatible)
- Time-block tracking with start/complete workflow
- Quality, energy, and focus ratings per block
- Daily progress visualization
- Habit streaks and consistency tracking
- Comprehensive statistics and analytics
- Customizable routine templates
- Daily journal entries
- Background monitor with notifications
- Data export (JSON, CSV, Datasette)

## Installation

```bash
chmod +x scripts/sovereign-routine.sh
```

## Dependencies

Required:
- `jq` - JSON processing
- `sqlite3` - Database storage

Optional:
- `bc` - Calculations
- `notify-send` or `osascript` - Notifications

Install dependencies:
```bash
# Debian/Ubuntu
sudo apt-get install jq sqlite3 bc libnotify-bin

# macOS
brew install jq sqlite3 bc
```

## Quick Start

```bash
# Start your day
./scripts/sovereign-routine.sh start-day

# Check progress
./scripts/sovereign-routine.sh status

# Start a block
./scripts/sovereign-routine.sh start "Morning Walk"

# Complete block
./scripts/sovereign-routine.sh complete "Morning Walk"

# End of day review
./scripts/sovereign-routine.sh end-day
```

## Default Routine

The script includes a pre-configured daily routine:

### Morning (6 hours)
- 06:00-06:30 - Morning Walk (30m)
- 06:30-07:00 - Morning Reading (30m)
- 07:00-12:00 - Personal Work (5h)

### Lunch (1.5 hours)
- 12:00-13:00 - Lunch Sport (1h)
- 13:00-13:30 - Lunch Meal (30m)

### Afternoon (4.5 hours)
- 13:30-18:00 - Business Work (4.5h)

### Evening (4 hours)
- 18:00-19:00 - Dinner (1h)
- 19:00-20:00 - Evening Reading (1h)
- 20:00-22:00 - Chill Time (2h)

**Total: 12 hours of structured time across 9 blocks**

## Daily Workflow

### 1. Start Your Day

```bash
./scripts/sovereign-routine.sh start-day
```

Prompts for:
- Morning energy level (1-10)

Creates:
- Daily session record
- All scheduled blocks for the day

### 2. Execute Blocks

```bash
# Start a block
./scripts/sovereign-routine.sh start "Morning Walk"

# Complete with ratings
./scripts/sovereign-routine.sh complete "Morning Walk"
```

When completing, you rate:
- Quality (1-10)
- Energy level (1-10)
- Focus level (1-10)
- Optional notes

### 3. Track Progress

```bash
./scripts/sovereign-routine.sh status
```

Shows:
- Completion percentage
- Progress bar
- Blocks completed/active/pending
- Current time and next block
- Motivational messages

### 4. End Your Day

```bash
./scripts/sovereign-routine.sh end-day
```

Prompts for:
- Evening energy level (1-10)
- Overall day rating (1-10)
- Quick wins
- What to improve tomorrow

Generates:
- Daily summary
- Completion statistics
- Streak updates

## Block Management

### Start Block

```bash
./scripts/sovereign-routine.sh start "Personal Work"
```

Marks block as active and records start time.

### Complete Block

```bash
./scripts/sovereign-routine.sh complete "Personal Work"
```

Prompts for quality/energy/focus ratings and notes.

### Skip Block

```bash
./scripts/sovereign-routine.sh skip "Lunch Sport" "Injured ankle"
```

Marks block as skipped with reason.

## Customization

### View Template

```bash
./scripts/sovereign-routine.sh templates
```

Shows all configured blocks with times and categories.

### Add Custom Block

```bash
./scripts/sovereign-routine.sh templates add "Meditation" morning 05:30 06:00 mindfulness "Morning meditation"
```

Arguments:
1. Block name
2. Time slot (morning/lunch/afternoon/evening)
3. Start time (HH:MM)
4. End time (HH:MM)
5. Category
6. Description (optional)

### Update Block

```bash
./scripts/sovereign-routine.sh templates update BLOCK_ID FIELD VALUE
```

Example:
```bash
./scripts/sovereign-routine.sh templates update 5 start_time 06:30
```

### Toggle Block On/Off

```bash
# Disable block ID 3
./scripts/sovereign-routine.sh templates toggle 3

# Enable block ID 3
./scripts/sovereign-routine.sh templates toggle 3
```

Disabled blocks won't be included in daily schedules.

## Statistics

### View Stats

```bash
# Last 30 days (default)
./scripts/sovereign-routine.sh stats

# Last 7 days
./scripts/sovereign-routine.sh stats 7
```

Shows:
- Total days tracked
- Average completion percentage
- Perfect days (100% completion)
- Current streak
- Block completion rates
- Average quality per block
- Recent performance history
- Energy level patterns

### Tracked Metrics

Per Day:
- Completion percentage
- Blocks completed vs planned
- Morning and evening energy
- Overall day rating
- Journal entries

Per Block:
- Completion status
- Quality rating (1-10)
- Energy level (1-10)
- Focus level (1-10)
- Actual vs scheduled time
- Notes

Per Habit:
- Completion streak (consecutive days ≥80%)
- Success rate per block
- Long-term consistency

## Data Export

### Export to Datasette

```bash
./scripts/sovereign-routine.sh export datasette
```

Creates database copy ready for Datasette visualization.

### Using Datasette

```bash
# Install
pip install datasette

# Run
datasette data/routine_datasette.db

# Open: http://localhost:8001
```

### Analysis Examples with Datasette

1. **Completion Trends**
   - Chart completion % over time
   - Identify patterns (weekdays vs weekends)

2. **Block Performance**
   - Heatmap of which blocks you complete most
   - Quality ratings by block type
   - Time of day performance

3. **Energy Patterns**
   - Morning vs evening energy trends
   - Correlation with completion rates
   - Best times for different work types

4. **Habit Streaks**
   - Longest streaks per block
   - Consistency visualization
   - Streak breaks analysis

5. **Custom Queries**
   - Filter by date ranges
   - Aggregate by category
   - Compare different time periods

### Export to JSON/CSV

```bash
# JSON export
./scripts/sovereign-routine.sh export json

# CSV export
./scripts/sovereign-routine.sh export csv
```

## Background Monitor

### Start Monitor

```bash
./scripts/sovereign-routine.sh monitor start
```

The monitor daemon:
- Checks every 5 minutes
- Auto-starts day at 6 AM (if enabled)
- Sends 5-minute warnings before blocks
- Tracks progress automatically

### Stop Monitor

```bash
./scripts/sovereign-routine.sh monitor stop
```

### Configuration

```bash
# Auto-start day at 6 AM
AUTO_START_DAY=1

# Enable notifications
NOTIFY_BLOCK_START=1
NOTIFY_BLOCK_END=1
NOTIFY_REMINDERS=1
```

## Database Schema

Database location: `$DATA_DIR/routine.db`

### Tables

**daily_sessions**
- One row per day
- Overall completion and ratings
- Energy levels (morning/evening)
- Status and timestamps

**block_templates**
- Routine template definitions
- Time slots and durations
- Categories and descriptions
- Enabled/disabled status

**daily_blocks**
- Actual blocks each day
- Completion status
- Quality/energy/focus ratings
- Scheduled vs actual times
- Notes

**habit_stats**
- Long-term habit completion data
- One row per block per day
- Quality scores

**daily_journal**
- Daily reflection entries
- Mood tracking
- Gratitude and lessons learned
- Tomorrow's focus

**block_activities**
- Detailed activities within blocks
- Activity types and durations
- Timestamps

### Indexes

Optimized for:
- Date range queries
- Block status lookups
- Habit tracking
- Session searches

## Example Workflows

### Standard Weekday

```bash
# 6:00 AM - Start day
./scripts/sovereign-routine.sh start-day
# Energy: 7

# 6:00 - Morning Walk
./scripts/sovereign-routine.sh start "Morning Walk"
./scripts/sovereign-routine.sh complete "Morning Walk"
# Quality: 8, Energy: 8, Focus: 7

# 6:30 - Reading
./scripts/sovereign-routine.sh start "Morning Reading"
./scripts/sovereign-routine.sh complete "Morning Reading"
# Quality: 9, Energy: 8, Focus: 9

# 7:00 - Personal Work
./scripts/sovereign-routine.sh start "Personal Work"

# 12:00 - Complete work, start sport
./scripts/sovereign-routine.sh complete "Personal Work"
./scripts/sovereign-routine.sh start "Lunch Sport"

# Continue through day...

# 10:00 PM - End day review
./scripts/sovereign-routine.sh end-day
# Evening energy: 6
# Rating: 9
# Wins: Finished project milestone
# Improve: Start earlier
```

### Weekend Variation

```bash
# Disable work blocks for weekend
./scripts/sovereign-routine.sh templates toggle 3  # Personal Work
./scripts/sovereign-routine.sh templates toggle 6  # Business Work

# Start day
./scripts/sovereign-routine.sh start-day

# Re-enable Monday morning
./scripts/sovereign-routine.sh templates toggle 3
./scripts/sovereign-routine.sh templates toggle 6
```

## Streak Tracking

Streaks count consecutive days with ≥80% completion.

Achievements:
- 3+ days: Building momentum
- 7+ days: Week streak
- 30+ days: On fire

Breaks when:
- Day completion < 80%
- Day not tracked

## Notifications

Automatic notifications for:
- New day started
- Block starts
- Block completions
- 5-minute warnings for upcoming blocks
- All blocks completed
- Streak achievements

## Commands Reference

| Command | Arguments | Description |
|---------|-----------|-------------|
| `start-day` | - | Start new daily session |
| `end-day` | - | End day with review |
| `status` | - | Show current progress |
| `start` | BLOCK_NAME | Start time block |
| `complete` | BLOCK_NAME | Complete block with ratings |
| `skip` | BLOCK_NAME [REASON] | Skip block |
| `templates` | - | Show routine template |
| `templates add` | NAME SLOT START END CAT [DESC] | Add block |
| `templates update` | ID FIELD VALUE | Update block |
| `templates toggle` | ID | Enable/disable block |
| `stats` | [DAYS] | Show statistics |
| `export` | [json\|csv\|datasette] | Export data |
| `monitor start` | - | Start background monitor |
| `monitor stop` | - | Stop background monitor |

## Block Categories

- `exercise` - Physical activity
- `learning` - Reading, education
- `deep_work` - Focused work time
- `nutrition` - Meals
- `rest` - Relaxation, sleep prep
- `mindfulness` - Meditation, reflection
- `social` - Social activities
- `admin` - Administrative tasks

## Tips for Success

1. **Consistency Over Perfection**
   - Aim for 80%+ completion
   - Track even partial days

2. **Quality Ratings**
   - Be honest in ratings
   - Use notes to capture context
   - Review patterns monthly

3. **Energy Management**
   - Schedule deep work during high-energy times
   - Track energy patterns over weeks
   - Adjust blocks based on data

4. **Customization**
   - Start with defaults
   - Adjust after 1-2 weeks
   - Remove what doesn't serve you

5. **Weekly Review**
   - Export to Datasette
   - Analyze completion patterns
   - Adjust for next week

6. **Streaks**
   - Focus on the process, not the streak
   - 80% completion counts
   - Bounce back quickly after breaks

## Data Location

All data stored in:
```
$DATA_DIR/routine.db
$DATA_DIR/routine_config.json
```

Backup:
```bash
cp $DATA_DIR/routine.db ~/backups/routine_backup_$(date +%Y%m%d).db
```

## Related Scripts

- `monk-mode-fasting.sh` - Fasting tracker
- `pomodoro-enforcer.sh` - Focus sessions
- `focus-mode-nuclear.sh` - Deep work mode
