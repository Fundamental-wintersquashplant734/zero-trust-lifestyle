# Health Nag Bot

Fitness and health nag bot with escalating guilt trips. No workout in 5 days means screen lockout.

## Overview

Persistent health monitoring system that tracks your workouts, steps, water intake, and sleep. Calculates a health score, escalates nagging as you fall behind, and optionally locks your screen if you go too long without exercise. Supports Fitbit and Garmin integration for automatic data sync. Uses four nag levels from polite warning all the way to screen lockout.

## Features

- Workout logging with streak tracking
- Daily step counting
- Water intake tracking
- Sleep recording
- Sedentary time monitoring (resets when you move)
- Escalating nag levels (warning, serious, critical, lockout)
- Health score dashboard (0-100)
- Fitbit and Garmin sync
- Optional screen lockout after 5+ days without exercise

## Installation

```bash
chmod +x scripts/health-nag-bot.sh
```

## Dependencies

Required:
- `jq` - JSON processing
- `bc` - Math calculations

Optional:
- `xprintidle` - Idle time detection (Linux)
- `ioreg` - Idle time detection (macOS)
- `notify-send` or `osascript` - Desktop notifications

## Quick Start

```bash
# Show health dashboard (default)
./scripts/health-nag-bot.sh

# Record a workout
./scripts/health-nag-bot.sh workout gym 45

# Start monitoring daemon
./scripts/health-nag-bot.sh monitor &
```

## Usage

### Show Dashboard

```bash
./scripts/health-nag-bot.sh dashboard
```

Shows health score, workout streak, today's steps and water, last night's sleep, and current nag status.

### Record Workout

```bash
# Gym session, 45 minutes
./scripts/health-nag-bot.sh workout gym 45

# Run, default 30 minutes
./scripts/health-nag-bot.sh workout run

# Other types: walk, bike, yoga, swim, hiit, sports
./scripts/health-nag-bot.sh workout yoga 60
```

### Record Steps

```bash
./scripts/health-nag-bot.sh steps 10000
```

### Log Water Intake

```bash
# Log 1 glass (default)
./scripts/health-nag-bot.sh water

# Log multiple glasses
./scripts/health-nag-bot.sh water 3
```

### Record Sleep

```bash
# Records for yesterday by default
./scripts/health-nag-bot.sh sleep 7.5
```

### Reset Sedentary Timer

```bash
# Tell the bot you moved
./scripts/health-nag-bot.sh moved
```

### Sync Fitness Trackers

```bash
# Sync all configured trackers
./scripts/health-nag-bot.sh sync

# Sync specific tracker
./scripts/health-nag-bot.sh sync fitbit
./scripts/health-nag-bot.sh sync garmin
```

### Start Monitoring Daemon

```bash
# Run in background, checks every hour
./scripts/health-nag-bot.sh monitor &

# With screen lockout enabled
./scripts/health-nag-bot.sh --enable-lockout monitor &

# Disable auto-nagging (tracking only)
./scripts/health-nag-bot.sh --no-nag monitor &
```

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `dashboard` | - | Show health dashboard (default) |
| `monitor` | - | Start monitoring daemon |
| `workout` | TYPE [MIN] | Record workout (default: 30 min) |
| `steps` | COUNT | Record step count |
| `water` | [GLASSES] | Record water intake (default: 1) |
| `sleep` | HOURS | Record sleep for yesterday |
| `sync` | [fitbit\|garmin] | Sync fitness tracker (default: all) |
| `moved` | - | Reset sedentary timer |

## Options

| Option | Description |
|--------|-------------|
| `--enable-lockout` | Enable screen lockout after 5+ days without workout |
| `--no-nag` | Disable auto-nagging (monitoring only) |

## Nag Levels

### Warning (Level 1)

Minor issues: low steps, low water, insufficient sleep.

```
⚠️  Health Check-In
Take a 5-minute walk, drink some water, stretch a bit.
```

### Serious (Level 2)

Sedentary for 3+ hours.

```
🚨 HEALTH ALERT
Stand up RIGHT NOW. Walk for 10 minutes.
```

### Critical (Level 3)

No workout in 3+ days.

```
🔴 CRITICAL HEALTH WARNING
Your workout streak is dead. DO SOMETHING. NOW.
```

### Lockout (Level 4)

No workout in 5+ days. If `--enable-lockout` is set, initiates a 5-minute countdown to screen lock.

```
🔒 SCREEN LOCKOUT IMMINENT
5+ days without exercise is inexcusable.
Screen will lock in 5 minutes if you don't move.
```

## Example Session

```bash
$ ./scripts/health-nag-bot.sh dashboard

╔════════════════════════════════════════╗
║      💪 HEALTH NAG DASHBOARD 💪        ║
╚════════════════════════════════════════╝

Health Score: 75/100

Workout Stats:
  Current Streak: 3 days
  Longest Streak: 14 days
  Total Workouts: 47
  Days Since Last: 0 days

Today's Progress:
  Steps: 6200/8000 ❌
  Water: 5/8 glasses ❌

Last Night:
  Sleep: 7.5h ✅

Current Status:
  ⚠️  Minor issues - easy fixes

$ ./scripts/health-nag-bot.sh workout run 30
[SUCCESS] Recorded run workout (30 min)

$ ./scripts/health-nag-bot.sh water 2
[SUCCESS] Recorded 2 glass(es) of water (total today: 7)

$ ./scripts/health-nag-bot.sh steps 8500
$ ./scripts/health-nag-bot.sh moved
[SUCCESS] Movement detected! Sedentary timer reset.
```

## Setup

### 1. Configure Trackers (Optional)

```bash
# Edit config/config.sh
FITBIT_TOKEN="your_fitbit_oauth_token"
GARMIN_TOKEN="your_garmin_oauth_token"
```

### 2. Start Daemon

```bash
./scripts/health-nag-bot.sh monitor &
```

### 3. Add to Startup

```bash
# Add to ~/.bashrc or system startup
/path/to/health-nag-bot.sh monitor &
```

## Thresholds

Defaults that trigger nag levels:

| Metric | Threshold |
|--------|-----------|
| Max sedentary hours | 3 |
| Min daily steps | 8000 |
| Min workouts per week | 3 |
| Max days without workout | 5 |
| Min water glasses | 8 |
| Min sleep hours | 7 |

## Data Location

```
$DATA_DIR/health_data.json     # Workouts, steps, water, sleep
$DATA_DIR/nag_history.json     # Nag log
```

## Disclaimer

This is a reminder system, not medical advice. Consult healthcare professionals for actual health concerns. The lockout feature is opt-in and intentionally disruptive.

## Related Scripts

- `pomodoro-enforcer.sh` - Timed work sessions
- `sovereign-routine.sh` - Full daily routine tracking
- `expense-shame-dashboard.sh` - Financial health
