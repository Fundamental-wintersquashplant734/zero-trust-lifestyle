# YouTube Rabbit Hole Killer

Blocks YouTube after watching a set number of videos, preventing endless scrolling and time waste. Enforces discipline with motivational messages.

## Overview

Monitors YouTube usage and automatically blocks access after watching your configured video limit (default: 2 videos). Uses hosts file blocking or a local redirect server with a motivational blocked page explaining why you should go do something useful. Supports daily resets and manual override. Run with no arguments or `status` to see today's count.

## Features

- Video count tracking (videos and minutes)
- Automatic YouTube blocking after limit
- Browser extension generation (Chrome/Firefox)
- Hosts file blocking via /etc/hosts
- Local blocked page server with motivational message
- Daily reset at 4:00 AM
- Viewing statistics and history
- Manual block/unblock control

## Installation

```bash
chmod +x scripts/youtube-rabbit-hole-killer.sh
```

## Dependencies

Required:
- `jq` - JSON processing

Optional:
- `sudo` access (for hosts file blocking)
- `python3` - For blocked page server

## Quick Start

```bash
# Check current status
./scripts/youtube-rabbit-hole-killer.sh status

# Manually log a video watched
./scripts/youtube-rabbit-hole-killer.sh log

# Generate browser extension (recommended)
./scripts/youtube-rabbit-hole-killer.sh extension
```

## Usage

### Check Status

```bash
./scripts/youtube-rabbit-hole-killer.sh status
```

Shows:
- Date and videos watched today (count/limit)
- Time spent vs daily limit
- Current blocked/active status

### Log a Video Manually

```bash
./scripts/youtube-rabbit-hole-killer.sh log
```

Prompts for video title and duration in minutes. After logging, shows current status and triggers block if limit is reached.

### Block YouTube

```bash
# Manually trigger block
sudo ./scripts/youtube-rabbit-hole-killer.sh block

# Unblock (emergency override)
sudo ./scripts/youtube-rabbit-hole-killer.sh unblock
```

Blocking modifies `/etc/hosts` to redirect YouTube domains to 127.0.0.1. Requires sudo.

### Reset Counter

```bash
./scripts/youtube-rabbit-hole-killer.sh reset
```

Resets the daily counter and unblocks YouTube. Also runs automatically at 4:00 AM.

### View Statistics

```bash
./scripts/youtube-rabbit-hole-killer.sh stats
```

Shows total videos logged, total time, this week's stats, and recent video history.

### Generate Browser Extension

```bash
./scripts/youtube-rabbit-hole-killer.sh extension
```

Generates a Manifest V3 browser extension that tracks video views automatically in-browser. Prints step-by-step installation instructions for Chrome/Edge and Firefox.

### Start Blocked Page Server

```bash
./scripts/youtube-rabbit-hole-killer.sh server
```

Starts a local HTTP server on port 8080 serving the motivational blocked page. YouTube's hosts entries point here so you see the "GO DO SOMETHING USEFUL" page instead of an error.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `status` | - | Show current status |
| `log` | - | Manually log a video watched |
| `stats` | - | View viewing statistics |
| `block` | - | Manually trigger block (requires sudo) |
| `unblock` | - | Unblock YouTube (requires sudo) |
| `reset` | - | Reset daily counter |
| `extension` | - | Generate browser extension |
| `server` | - | Start blocked page server |

## Options

| Option | Description |
|--------|-------------|
| `--limit N` | Set video limit (default: 2) |
| `--time-limit MINS` | Set daily time limit in minutes (default: 30) |

Example:
```bash
./scripts/youtube-rabbit-hole-killer.sh --limit 3 status
```

## Blocking Methods

### Browser Extension (Recommended)

Generate and install the companion extension:
```bash
./scripts/youtube-rabbit-hole-killer.sh extension
```

- Counts videos automatically in-browser
- Hard blocks the page at limit
- Displays motivational message inline
- Resets daily via Chrome alarms API

### Hosts File Blocking

Adds to `/etc/hosts` (requires sudo):
```
127.0.0.1 youtube.com
127.0.0.1 www.youtube.com
127.0.0.1 m.youtube.com
127.0.0.1 youtube-nocookie.com
127.0.0.1 youtubei.googleapis.com
127.0.0.1 youtu.be
```

Pair with `server` command to show motivational page instead of a connection error.

## Motivational Blocked Page

When blocked, the local server displays:

```
⛔ YouTube Blocked

Videos watched: 2 / 2
Time spent: 45 minutes

GO DO SOMETHING USEFUL

Instead, you could:
  ✓ Work on that project you keep postponing
  ✓ Read a book (or finish the one you started)
  ✓ Learn something new (run random-skill-learner.sh)
  ✓ Exercise for 20 minutes
  ✓ Call someone you care about
  ✓ Go outside and touch grass
  ✓ Write code
  ✓ Face a fear (run fear-challenge.sh)

Counter resets at 4:00 AM or run: sudo youtube-rabbit-hole-killer.sh unblock
```

## Example Session

```bash
# Check morning status
$ ./scripts/youtube-rabbit-hole-killer.sh status

📊 YouTube Status

Date: 2026-03-16
Videos watched: 0 / 2
Time spent: 0 / 30 minutes
Status: Active (2 videos remaining)

# Watch a video, then log it
$ ./scripts/youtube-rabbit-hole-killer.sh log
Video title (optional): Funny cat compilation
Duration in minutes: 8

Logged video: Funny cat compilation
Count: 1/2 | Time: 8min

# Watch another, hit the limit
$ ./scripts/youtube-rabbit-hole-killer.sh log
Video title (optional): More cats
Duration in minutes: 12

⛔ YOUTUBE LIMIT REACHED ⛔
Videos watched: 2/2
Time spent: 20 minutes
YouTube is now BLOCKED.
Go do something productive.

$ sudo ./scripts/youtube-rabbit-hole-killer.sh block
# Blocks youtube.com and related domains in /etc/hosts

$ ./scripts/youtube-rabbit-hole-killer.sh stats

📊 YouTube Statistics

Total videos logged: 47
Total time: 310 minutes (5.2 hours)

This week: 12 videos, 95 minutes

Recent videos:
2026-03-16 - Funny cat compilation (8 min)
2026-03-16 - More cats (12 min)
...
```

## Data Location

```
$DATA_DIR/youtube_killer_state.json  # Daily state (count, blocked status)
$DATA_DIR/youtube_stats.json         # Full viewing history
$DATA_DIR/youtube_blocked.html       # Blocked page template
```

## Troubleshooting

### Still able to access YouTube

- Check hosts file: `grep youtube /etc/hosts`
- Run: `sudo ./scripts/youtube-rabbit-hole-killer.sh block`
- Flush DNS: `sudo systemd-resolve --flush-caches`
- Install browser extension for in-browser blocking

### Videos not counting

- Use `log` command after each video
- Or install the browser extension for automatic counting

### Emergency unblock

```bash
sudo ./scripts/youtube-rabbit-hole-killer.sh unblock
```

Restores original `/etc/hosts` from backup and resets blocked state.

## Related Scripts

- `focus-mode-nuclear.sh` - Block all distractions
- `pomodoro-enforcer.sh` - Timed focus sessions
- `random-skill-learner.sh` - Learn instead of watching
