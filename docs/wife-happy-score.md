# Wife Happy Score

Relationship debt tracker and maintenance reminder system. Tracks date nights, flowers, gifts, compliments, chores, and quality time — then gives you a score so you know exactly how much trouble you're in.

## Overview

Maintains a local JSON database of relationship activities and calculates a score from 0-100 based on how recently you've done the right things. Shows a dashboard with metrics, upcoming important dates, and prioritized recommendations. Alerts when the score drops below 40.

## Features

- Relationship health score (0-100)
- Tracks 6 activity categories: dates, flowers, gifts, compliments, chores, quality time
- Anniversary and birthday reminders (7-day and 30-day warnings)
- Personalized recommendations with flower/restaurant preferences
- Full activity history log
- Setup wizard for initial configuration

## Installation

```bash
chmod +x scripts/wife-happy-score.sh
```

## Dependencies

Required:
- `jq` - JSON processing

## Quick Start

```bash
# First-time setup
./scripts/wife-happy-score.sh --setup

# View dashboard (default)
./scripts/wife-happy-score.sh

# Record a date night
./scripts/wife-happy-score.sh --record date
```

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--setup` | `-s` | Run initial setup wizard |
| `--dashboard` | `-d` | Show dashboard (default) |
| `--record ACTION` | `-r ACTION` | Record an action |
| `--help` | `-h` | Show help |

## Usage

### Initial Setup

```bash
./scripts/wife-happy-score.sh --setup
```

Interactive wizard that configures:
- Partner's name
- Anniversary date (YYYY-MM-DD)
- Partner's birthday (YYYY-MM-DD)
- Favorite flowers (optional, used in recommendations)
- Favorite restaurant (optional, used in recommendations)

Data is stored in `$DATA_DIR/relationship.json`.

### Dashboard

```bash
./scripts/wife-happy-score.sh
# or
./scripts/wife-happy-score.sh --dashboard
```

Shows:
- Current score and urgency level
- Important date alerts (anniversary, birthday)
- Time since each tracked activity
- Prioritized recommendations

### Record an Action

```bash
./scripts/wife-happy-score.sh --record ACTION
```

Valid actions:

| Action | What it records |
|--------|----------------|
| `date` | Date night - updates `last_date_night` |
| `flowers` | Flowers sent - updates `last_flowers` |
| `gift` | Gift given - prompts for description, updates `last_gift` |
| `compliment` | Compliment given - updates `last_compliment` |
| `chore` | Chore done - prompts for description, increments `chores_this_week` |
| `quality-time` | Quality time - prompts for hours, adds to `quality_time_hours` |

After recording, the updated dashboard is displayed.

## Scoring System

The score starts at 100 and deductions are applied based on how overdue each activity is:

| Category | Max Deduction | Threshold (overdue) |
|----------|--------------|---------------------|
| Date night | 25 pts | >14 days |
| Flowers | 20 pts | >30 days |
| Chores this week | 20 pts | <3 chores |
| Compliment | 10 pts | >1 day |
| Quality time this week | 10 pts | <5 hours |
| Gift | 15 pts | >60 days |

Half the deduction applies when only mildly overdue; the full deduction applies when significantly overdue.

### Urgency Levels

| Score | Level |
|-------|-------|
| 80-100 | EXCELLENT |
| 60-79 | GOOD |
| 40-59 | WARNING |
| 20-39 | CRITICAL |
| 0-19 | DEFCON 1 |

## Examples

```bash
# Record a date night
./scripts/wife-happy-score.sh --record date

# Record flowers
./scripts/wife-happy-score.sh --record flowers

# Record a gift (will prompt for description)
./scripts/wife-happy-score.sh --record gift

# Record a compliment
./scripts/wife-happy-score.sh --record compliment

# Record a chore (will prompt for description)
./scripts/wife-happy-score.sh --record chore

# Record quality time (will prompt for hours)
./scripts/wife-happy-score.sh --record quality-time
```

## Dashboard Example

```
╔════════════════════════════════════════╗
║     RELATIONSHIP HAPPINESS SCORE      ║
╚════════════════════════════════════════╝

Partner: Sarah
Score: 65/100 (GOOD)

📌 IMPORTANT DATES:
⚠️  Anniversary coming up in 18 days (2026-04-03)

📊 Metrics:
  📅 Last date night: 10 days ago
  💐 Last flowers: 25 days ago
  🎁 Last gift: 45 days ago
  💬 Last compliment: 2 days ago
  🧹 Chores this week: 2
  ⏰ Quality time this week: 3h

💡 Recommendations:
📅 URGENT: Plan date night at Trattoria Roma (10 days overdue)
💐 Send roses (25 days since last flowers)
   → https://www.amazon.com/s?k=roses
🧹 Do some chores without being asked (current: 2 this week)
```

## Daily Reminder via Crontab

```bash
# Morning dashboard notification
0 9 * * * /path/to/wife-happy-score.sh --dashboard | notify-send "Relationship Status"
```

## Configuration

Scoring thresholds and weights are set in the script:

```bash
# How often things should happen (days)
DATE_NIGHT_THRESHOLD=14
FLOWERS_THRESHOLD=30
GIFT_THRESHOLD=60
COMPLIMENT_THRESHOLD=1

# Point deductions when overdue
WEIGHT_DATE_NIGHT=25
WEIGHT_FLOWERS=20
WEIGHT_GIFT=15
WEIGHT_COMPLIMENT=10
WEIGHT_CHORES=20
WEIGHT_QUALITY_TIME=10
```

### Partner Name via Environment

```bash
PARTNER_NAME="Sarah" ./scripts/wife-happy-score.sh
```

## Data Location

```
$DATA_DIR/relationship.json    # All data: scores, history, preferences, important dates
```

The JSON file includes:
- `partner_name`, `anniversary`, `birthday`
- `last_date_night`, `last_flowers`, `last_gift`, `last_compliment`
- `chores_this_week`, `quality_time_hours`
- `preferences.favorite_flowers`, `preferences.favorite_restaurant`
- `history[]` - timestamped event log

## Privacy

- All data stored locally in `$DATA_DIR/relationship.json`
- No external services or network activity

## Humor Disclaimer

This is a lighthearted tool to gamify relationship maintenance. Real relationships require:
- Communication
- Respect
- Trust
- Actual quality time (not just tracking it)
- Genuine care (not score optimization)

Use as a reminder system, not a replacement for actually caring.

## Related Scripts

- `birthday-reminder-pro.sh` - Remember important dates
- `health-nag-bot.sh` - Self-care reminders
- `social-battery-monitor.sh` - Track social energy
