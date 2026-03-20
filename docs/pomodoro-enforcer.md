# Pomodoro Enforcer

Nuclear Pomodoro timer that actually blocks apps and websites during work sessions. No mercy, no escape.

## Overview

Implements the Pomodoro Technique with enforcement. Automatically blocks distracting websites and applications during 25-minute work sessions, then prompts for a break when the session completes. Unlike gentle timers, this script actively prevents procrastination through website blocking (via /etc/hosts), app visibility hiding/killing, and notification silencing. All durations are specified in **seconds**.

## Features

- True Pomodoro enforcement (25 min work, 5 min break)
- Website blocking via /etc/hosts (requires sudo)
- App process blocking or nuclear kill
- Notification silencing (GNOME/macOS)
- Long breaks after 4 pomodoros
- Session history and statistics
- Emergency unblock command
- Customizable block lists

## Installation

```bash
chmod +x scripts/pomodoro-enforcer.sh
```

## Dependencies

Required:
- `sudo` access (for hosts file modification)

Optional:
- `paplay` / `afplay` - Completion sound
- `notify-send` - Desktop notifications

## Quick Start

```bash
# Start standard 25-minute Pomodoro session
./scripts/pomodoro-enforcer.sh start

# Start a break manually
./scripts/pomodoro-enforcer.sh break

# Take a long break
./scripts/pomodoro-enforcer.sh break LONG

# View statistics
./scripts/pomodoro-enforcer.sh stats
```

## Usage

### Start Pomodoro

```bash
# Standard (25 min work)
./scripts/pomodoro-enforcer.sh start

# Custom work duration (20 minutes = 1200 seconds)
./scripts/pomodoro-enforcer.sh --work-duration 1200 start

# Nuclear mode (actually kills apps)
sudo ./scripts/pomodoro-enforcer.sh --nuclear start
```

### Start a Break

```bash
# Short break (default: 5 minutes)
./scripts/pomodoro-enforcer.sh break

# Short break explicitly
./scripts/pomodoro-enforcer.sh break SHORT

# Long break (default: 15 minutes)
./scripts/pomodoro-enforcer.sh break LONG
```

### Stop Session

```bash
./scripts/pomodoro-enforcer.sh stop
```

Stops the current session and removes all blocks immediately.

### View Statistics

```bash
./scripts/pomodoro-enforcer.sh stats
```

Shows total pomodoros, today's count, this week's count, and total focus time.

### Emergency Unblock

```bash
sudo ./scripts/pomodoro-enforcer.sh emergency-unblock
```

Removes all blocks immediately regardless of timer state. Also triggered automatically on Ctrl+C.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `start` | - | Start a work session |
| `break` | [SHORT\|LONG] | Start a break (default: SHORT) |
| `stop` | - | Stop current session and unblock |
| `stats` | - | View pomodoro statistics |
| `emergency-unblock` | - | Remove all blocks immediately |

## Options

| Option | Description |
|--------|-------------|
| `--work-duration SECS` | Work session duration in seconds (default: 1500 = 25 min) |
| `--short-break SECS` | Short break duration in seconds (default: 300 = 5 min) |
| `--long-break SECS` | Long break duration in seconds (default: 900 = 15 min) |
| `--nuclear` | Kill apps instead of just hiding them |
| `--no-websites` | Don't block websites |
| `--no-apps` | Don't block apps |
| `--no-notifications` | Don't block notifications |

**Note: All duration values are in seconds, not minutes.**

Example:
```bash
# 45-minute work session (2700 seconds) with 10-minute break (600 seconds)
sudo ./scripts/pomodoro-enforcer.sh --work-duration 2700 --short-break 600 start
```

## Pomodoro Technique

### Standard Cycle

1. **Work Session**: 1500 seconds (25 minutes)
   - All distractions blocked
   - Focus on single task
   - No interruptions

2. **Short Break**: 300 seconds (5 minutes)
   - Blocks removed
   - Move, stretch, hydrate

3. **Long Break**: 900 seconds (15 minutes)
   - After every 4 pomodoros
   - Proper rest

### What Gets Blocked During Work

**Websites** (hosts file blocking, requires sudo):
- Social media: Facebook, Twitter/X, Instagram, TikTok, Reddit
- Video: YouTube, Netflix, Twitch
- News: Hacker News, Lobsters
- Entertainment: 9gag, Imgur, LinkedIn

**Applications**:
- Communication: Slack, Discord, Telegram
- Music: Spotify
- Gaming: Steam
- Browsers: Chrome, Firefox (in nuclear mode)

Safe apps never blocked: vscode, vim, emacs, terminal emulators.

**Notifications**:
- GNOME: `gsettings` show-banners disabled
- macOS: Do Not Disturb enabled

### During Breaks

All blocks removed:
- Websites accessible again
- Apps restored (macOS) or unkilled
- Notifications re-enabled

## Modes

### Standard Mode

- Blocks websites via /etc/hosts
- Notifications disabled
- Running apps noted but not killed

### Nuclear Mode

```bash
sudo ./scripts/pomodoro-enforcer.sh --nuclear start
```

- Kills blocked app processes with `pkill -9`
- On macOS also uses AppleScript to hide apps
- Forces compliance, no escape

## Example Session

```bash
$ sudo ./scripts/pomodoro-enforcer.sh start

Blocking distraction websites...
Websites blocked! Focus time.
Blocking distraction apps...
Apps blocked!
Blocking notifications...
Notifications blocked!

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              🍅 POMODORO TIMER - WORK                      ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Time Remaining:

                    24:59

🚫 Distractions are blocked
📵 Notifications are off

💪 Stay focused!

Press Ctrl+C to cancel

[25 minutes later - timer completes]

Work session complete! Pomodoro #1

Start short break now? [y/n] y

Websites unblocked. Enjoy your break!

╔════════════════════════════════════════════════════════════╗
║              🍅 POMODORO TIMER - BREAK                     ║
╚════════════════════════════════════════════════════════════╝

                    04:59

✅ Take a real break
🚶 Stand up, stretch, move

[Break ends]

Break complete! Ready for next session?
Start work session now? [y/n] y
```

## Statistics Output

```bash
$ ./scripts/pomodoro-enforcer.sh stats

🍅 Pomodoro Statistics

Total pomodoros: 87
Today: 4
This week: 23

Total focus time: 2175 minutes (36.2 hours)

Recent sessions:
2026-03-16T09:00:00 - work (25 minutes)
2026-03-16T09:30:00 - work (25 minutes)
...
```

## Best Practices

1. **Commit to one task per session**
   - Don't multitask
   - If interrupted, restart the timer

2. **Honor the breaks**
   - Actually stand up and move
   - Don't just switch to your phone
   - Hydrate and rest your eyes

3. **Don't fight the timer**
   - If you're in flow, note where you are
   - Take the break, return refreshed
   - Prevents burnout

4. **Use nuclear mode sparingly**
   - Only when you truly can't focus
   - Killing your browser is inconvenient
   - But sometimes that's the point

5. **Review stats weekly**
   - Identify your best focus times
   - Adjust schedule accordingly
   - Celebrate consistency

## Troubleshooting

### Sites still accessible

- Website blocking requires sudo: `sudo ./scripts/pomodoro-enforcer.sh start`
- Flush DNS: `sudo systemd-resolve --flush-caches` (Linux)
- Flush DNS: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` (macOS)
- Check `/etc/hosts` manually

### Need to break out of a blocked session

```bash
sudo ./scripts/pomodoro-enforcer.sh emergency-unblock
```

Or press Ctrl+C — the EXIT trap automatically calls `emergency_unblock`.

### Apps not being killed

- Enable nuclear mode: `--nuclear`
- Requires the exact process name to match `BLOCKED_APPS` list
- Check process name with: `ps aux | grep appname`

## Data Location

```
$DATA_DIR/pomodoro_state.json     # Current state
$DATA_DIR/pomodoro_history.json   # Session history
/etc/hosts.pomodoro.backup        # Hosts file backup
```

## Safety

- Backs up /etc/hosts before modification
- Restores automatically on stop, crash, or Ctrl+C
- Emergency unblock always available
- Never permanently modifies system files

## Related Scripts

- `focus-mode-nuclear.sh` - Extreme focus mode
- `definitely-working.sh` - Anti-AFK
- `slack-auto-responder.sh` - Auto-respond during focus
