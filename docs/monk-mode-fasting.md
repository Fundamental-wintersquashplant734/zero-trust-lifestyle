# Monk Mode Fasting

Disciplined fasting tracker with notifications, milestones, and analytics. Full Datasette integration for data visualization.

## Overview

Comprehensive fasting tracker that helps you manage intermittent fasting, extended fasts, and scheduled fasting routines. Tracks progress, sends milestone notifications, maintains journals, and exports data for analysis with Datasette.

## Features

- SQLite database (Datasette-compatible)
- Multiple fasting types (daily, weekly, quarterly, custom)
- Real-time progress tracking with visual progress bars
- Milestone notifications at key hours
- Journal entries with mood and hunger tracking
- Comprehensive statistics and streak tracking
- Scheduled fasting automation
- Background monitoring daemon
- Data export (JSON, CSV, Datasette)

## Installation

```bash
chmod +x scripts/monk-mode-fasting.sh
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
# Start a 24-hour fast
./scripts/monk-mode-fasting.sh start manual 24 "Friday fast"

# Check progress
./scripts/monk-mode-fasting.sh status

# End fast
./scripts/monk-mode-fasting.sh end
```

## Usage

### Starting a Fast

```bash
# Manual fast (24 hours)
./scripts/monk-mode-fasting.sh start manual 24

# Weekly scheduled fast
./scripts/monk-mode-fasting.sh start weekly 24

# Quarterly week-long fast
./scripts/monk-mode-fasting.sh start quarterly 168

# Custom duration with notes
./scripts/monk-mode-fasting.sh start manual 36 "Extended fast for clarity"
```

### Tracking Progress

```bash
# Check current status
./scripts/monk-mode-fasting.sh status
```

Output shows:
- Session ID and type
- Elapsed time vs planned duration
- Remaining hours
- Progress percentage with visual bar
- Milestones reached
- Motivational messages

### Ending a Fast

```bash
# Complete successfully
./scripts/monk-mode-fasting.sh end

# End early (broke fast)
./scripts/monk-mode-fasting.sh end --broke
```

### Journal Entries

```bash
# Add journal entry
./scripts/monk-mode-fasting.sh journal

# View journal
./scripts/monk-mode-fasting.sh show-journal
```

Journal tracks:
- Mood (1-10)
- Hunger level (1-10)
- Notes and observations

## Fasting Schedules

### View Schedule

```bash
./scripts/monk-mode-fasting.sh schedule
```

### Default Schedule

| Type | When | Duration |
|------|------|----------|
| Weekly | Every Friday | 24 hours |
| Quarterly | First week of quarter | 168 hours (7 days) |
| Daily | Optional | 16 hours (IF) |

### Add Custom Schedule

```bash
# Weekly Monday fast (18 hours)
./scripts/monk-mode-fasting.sh schedule add weekly monday 18

# Custom daily intermittent fasting
./scripts/monk-mode-fasting.sh schedule add daily NULL 16
```

### Enable/Disable Schedule

```bash
# Disable schedule item #2
./scripts/monk-mode-fasting.sh schedule update 2 0

# Enable schedule item #2
./scripts/monk-mode-fasting.sh schedule update 2 1
```

### Check Today's Schedule

```bash
./scripts/monk-mode-fasting.sh check-schedule
```

## Milestones

Automatic notifications at key fasting milestones:

| Hours | Milestone | Benefits |
|-------|-----------|----------|
| 6h | Autophagy begins | Cellular cleanup starts |
| 12h | Growth hormone rising | Fat burning accelerates |
| 16h | Deep autophagy | Mental clarity peaks |
| 24h | One full day | Discipline achievement |
| 48h | Two days | Deep ketosis |
| 72h | Three days | Stem cell regeneration |
| 120h | Five days | Advanced benefits |
| 168h | Seven days | Full week completed |

## Statistics

### View Stats

```bash
./scripts/monk-mode-fasting.sh stats
```

Shows:
- Total sessions and completion rate
- Total hours/days fasted
- Current streak
- Breakdown by fasting type
- Recent session history
- Average duration per type

### Tracked Metrics

Per Session:
- Start and end times
- Planned vs actual duration
- Completion status
- Milestones reached
- Journal entries

Aggregate:
- Total fasting time
- Completion percentage
- Streak length
- Average session duration

## Data Export

### Export to Datasette

```bash
./scripts/monk-mode-fasting.sh export datasette
```

This creates a copy of the database ready for Datasette visualization.

### Using Datasette

```bash
# Install Datasette
pip install datasette

# Run Datasette
datasette data/fasting_datasette.db

# Open browser to: http://localhost:8001
```

### What You Can Explore

With Datasette you can:
- Visualize fasting trends over time
- Analyze completion rates by type
- Track milestone achievements
- View journal entries timeline
- Create custom queries and charts
- Export filtered data

### Export to JSON/CSV

```bash
# JSON export
./scripts/monk-mode-fasting.sh export json

# CSV export
./scripts/monk-mode-fasting.sh export csv
```

## Background Monitor

### Start Monitor

```bash
./scripts/monk-mode-fasting.sh monitor start
```

The monitor daemon:
- Checks every hour for active sessions
- Sends milestone notifications automatically
- Checks for scheduled fasts
- Runs in background

### Stop Monitor

```bash
./scripts/monk-mode-fasting.sh monitor stop
```

## Database Schema

Database location: `$DATA_DIR/fasting.db`

### Tables

**fasting_sessions**
- Session details (start, end, duration, type)
- Completion status
- Weight tracking (optional)
- Energy and difficulty levels

**fasting_schedule**
- Recurring schedule definitions
- Day/week patterns
- Duration and enabled status

**fasting_milestones**
- Milestone achievements per session
- Timestamp reached
- Notes

**fasting_journal**
- Journal entries
- Mood and hunger levels
- Timestamps and content

### Indexes

Optimized queries on:
- Session start times
- Session status
- Milestone lookups
- Journal session links

## Example Workflows

### Weekly Friday Fast

```bash
# Friday morning
./scripts/monk-mode-fasting.sh start weekly 24 "Weekly discipline"

# Saturday morning (24h later)
./scripts/monk-mode-fasting.sh end

# View stats
./scripts/monk-mode-fasting.sh stats
```

### Quarterly Extended Fast

```bash
# First week of quarter
./scripts/monk-mode-fasting.sh start quarterly 168 "Q1 2025 reset"

# Track progress daily
./scripts/monk-mode-fasting.sh status
./scripts/monk-mode-fasting.sh journal

# Day 7
./scripts/monk-mode-fasting.sh end
```

### Intermittent Fasting (16:8)

```bash
# Add daily 16h schedule
./scripts/monk-mode-fasting.sh schedule add daily NULL 16

# Each evening (start eating window ends)
./scripts/monk-mode-fasting.sh start daily 16

# Next morning
./scripts/monk-mode-fasting.sh end
```

## Notifications

Notifications sent for:
- Session start
- Milestone achievements (6h, 12h, 16h, 24h, 48h, 72h, 120h, 168h)
- Session completion
- Scheduled fast reminders

Configure in script or via environment:
```bash
NOTIFY_START=1
NOTIFY_MILESTONES=1
NOTIFY_END=1
```

## Commands Reference

| Command | Arguments | Description |
|---------|-----------|-------------|
| `start` | TYPE HOURS [NOTES] | Start fasting session |
| `end` | [--broke] | End active session |
| `status` | - | Check current progress |
| `journal` | - | Add journal entry |
| `show-journal` | [SESSION_ID] | View journal entries |
| `schedule` | - | Show fasting schedule |
| `schedule add` | TYPE DAY HOURS | Add custom schedule |
| `schedule update` | ID ENABLED | Enable/disable schedule |
| `check-schedule` | - | Check today's scheduled fasts |
| `stats` | - | Show statistics |
| `export` | [json\|csv\|datasette] | Export data |
| `monitor start` | - | Start background monitor |
| `monitor stop` | - | Stop background monitor |

## Fasting Types

- `manual` - One-time fast started manually
- `weekly` - Recurring weekly fast
- `quarterly` - Quarterly extended fast
- `daily` - Daily intermittent fasting
- `custom` - Custom schedule

## Tips

1. **Hydration** - Track water intake in journal
2. **Electrolytes** - Note supplementation
3. **Energy Levels** - Journal helps identify patterns
4. **Breaking Fast** - Plan first meal ahead
5. **Consistency** - Use schedule automation
6. **Data Analysis** - Export to Datasette for insights

## Safety

- Consult healthcare provider before extended fasts
- Stay hydrated
- Listen to your body
- Break fast if experiencing adverse effects
- Not recommended for certain medical conditions

## Data Location

All data stored in:
```
$DATA_DIR/fasting.db
$DATA_DIR/fasting_detections.json
```

To backup:
```bash
cp $DATA_DIR/fasting.db ~/backups/fasting_backup_$(date +%Y%m%d).db
```

## Related Scripts

- `sovereign-routine.sh` - Daily routine tracking
- `health-nag-bot.sh` - Health reminders
