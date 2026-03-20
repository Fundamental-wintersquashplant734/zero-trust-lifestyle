# Focus Mode Nuclear

Nuclear-level distraction elimination for deep work. Blocks websites, apps, notifications, and enforces focus periods with extreme prejudice.

## Overview

The most aggressive focus mode available. Goes beyond simple website blocking to enforce deep work sessions by killing distracting apps, blocking network access to time-wasters, disabling notifications system-wide, and creating an environment where focus is the only option.

## Features

- Nuclear website/app blocking (kills processes)
- System-wide notification silencing
- Slack/email client termination
- Social media network blocking at hosts level
- Phone "Do Not Disturb" automation (iOS/Android)
- Focus session timer with break enforcement
- Pomodoro technique support
- Whitelist for essential sites/apps
- Emergency break glass option
- Focus statistics tracking

## Installation

```bash
chmod +x scripts/focus-mode-nuclear.sh
```

## Dependencies

Required:
- `sudo` access (for hosts file modification)

Optional:
- `killall` - Process termination
- `notify-send` - Notifications (ironically)
- `adb` - Android device control
- `shortcuts` - iOS automation (macOS)

## Usage

### Start Focus Session

```bash
# 25-minute focus session (default level: serious)
./scripts/focus-mode-nuclear.sh start 25

# 90-minute session at nuclear level (level 3) with task
./scripts/focus-mode-nuclear.sh start 90 3 "Write documentation"

# 90-minute doomsday session (level 4, disables internet)
./scripts/focus-mode-nuclear.sh start 90 4 "Write thesis chapter"

# Standard Pomodoro (4 cycles of 25 min)
./scripts/focus-mode-nuclear.sh pomodoro

# Custom number of Pomodoro cycles
./scripts/focus-mode-nuclear.sh pomodoro 6
```

### Stop Focus Session

```bash
./scripts/focus-mode-nuclear.sh stop
```

### Emergency Exit

```bash
# Break glass in case of emergency
./scripts/focus-mode-nuclear.sh emergency
```

Requires typing "I AM WEAK" to confirm.

### Check Status

```bash
./scripts/focus-mode-nuclear.sh status
```

### View Dashboard

```bash
./scripts/focus-mode-nuclear.sh dashboard
```

## What Gets Blocked

### Websites (hosts file blocking)

- Social media: facebook.com, twitter.com, instagram.com, tiktok.com, reddit.com
- News: news.ycombinator.com, reddit.com, twitter.com
- Video: youtube.com, netflix.com, twitch.tv
- Shopping: amazon.com, ebay.com
- Custom additions via config

### Applications (process killing)

- Communication: Slack, Discord, Telegram, WhatsApp
- Email: Mail, Outlook, Thunderbird
- Browsers (optional): Chrome, Firefox, Safari
- Social: Facebook, Twitter apps
- Entertainment: Spotify, iTunes, VLC
- Games: Steam, Epic Games, any .exe in Games folder

### Notifications

- macOS: Do Not Disturb enabled
- Linux: notification-daemon killed
- Windows: Focus Assist enabled

### Phone (if connected)

- iOS: Do Not Disturb via Shortcuts
- Android: DND via adb commands

## Pomodoro Mode

```bash
# Standard Pomodoro (4 cycles x 25 min)
./scripts/focus-mode-nuclear.sh pomodoro

# Custom number of cycles
./scripts/focus-mode-nuclear.sh pomodoro 6
```

During Pomodoro:
- Work period: Everything blocked
- Break period: Restrictions lifted
- Automatically cycles
- Tracks completed Pomodoros

## Phone Integration

### iOS (macOS required)

Setup:
1. Create Shortcuts automation for "Focus Mode"
2. Script triggers it via `shortcuts run "Focus Mode"`

### Android (adb required)

Setup:
1. Enable USB debugging
2. Connect phone
3. Script runs: `adb shell cmd notification set_dnd on`

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `start` | MINUTES [LEVEL] [TASK] | Start focus session |
| `stop` | - | End focus session |
| `status` | - | Check current session status |
| `dashboard` | - | Show statistics dashboard |
| `pomodoro` | [CYCLES] | Pomodoro timer (default: 4 cycles) |
| `emergency` | - | Emergency override — remove all blocks |

## Configuration

Set in `config/config.sh` or export as environment variables:

```bash
# Enable nuclear/doomsday mode (disabled by default for safety)
ENABLE_NUCLEAR=1

# Disable shame report on violations
SHAME_MODE=0

# Toggle blocking features
ENABLE_HOSTS_BLOCKING=1
ENABLE_APP_BLOCKING=1
ENABLE_NOTIFICATION_BLOCKING=1
```

Blocked websites are loaded from the blocklist file:
```
$CONFIG_DIR/focus_blocklist.txt
```

Add custom sites to block, one per line.

## How It Works

### Website Blocking

```bash
# Adds to /etc/hosts:
127.0.0.1 facebook.com
127.0.0.1 www.facebook.com
::1 facebook.com
```

This makes blocked sites unreachable at DNS level.

### App Blocking

```bash
# Kills processes by name
killall Slack
killall Discord
killall Chrome  # If enabled
```

Kills them repeatedly if they restart.

### Notification Blocking

macOS:
```bash
defaults write com.apple.notificationcenterui doNotDisturb -bool true
```

Linux:
```bash
killall notification-daemon
```

## Statistics Tracked

Per session:
- Task name
- Duration (minutes)
- Focus level
- Violations (distraction attempts)

Aggregate:
- Total sessions
- Total focus time
- Current streak (days)
- Longest streak
- Nuclear activations
- Distractions blocked

## Example Session

```bash
# Start a 120-minute serious focus session (level 2)
$ ./scripts/focus-mode-nuclear.sh start 120 2 "Write proposal"

# Check progress
$ ./scripts/focus-mode-nuclear.sh status

# End session when done
$ ./scripts/focus-mode-nuclear.sh stop

# View stats dashboard
$ ./scripts/focus-mode-nuclear.sh dashboard
```

## Emergency Exit

```bash
$ ./scripts/focus-mode-nuclear.sh emergency
```

Immediately removes all focus mode restrictions: unblocks websites, unblocks applications, restores notifications, and restores internet (if doomsday mode was active). Use this if you get locked out or need to end a session immediately.

## Best Practices

1. **Set realistic durations**
   - Start with 45-60 minutes
   - Build up to 90-120 minutes
   - Don't exceed 2 hours without break

2. **Use Pomodoro for learning**
   - 25-minute sessions good for difficult material
   - Forces regular breaks
   - Prevents burnout

3. **Take breaks seriously**
   - Actually stand up and move
   - Don't just switch to phone
   - Hydrate

4. **Track your stats**
   - Review weekly
   - Identify best times for focus
   - Adjust session length

5. **Customize your blocklist**
   - Edit `$CONFIG_DIR/focus_blocklist.txt`
   - Only remove sites you genuinely need
   - Don't defeat the purpose

## Troubleshooting

### Can still access blocked sites

- Clear browser DNS cache
- Flush system DNS: `sudo dscacheutil -flushcache` (macOS)
- Check /etc/hosts file manually
- Restart browser

### Apps keep restarting

- Add to startup blacklist
- Use `killall -9` for force kill
- Disable auto-launch in app preferences

### Emergency exit not working

- Use: `sudo ./scripts/focus-mode-nuclear.sh emergency`
- Or manually edit /etc/hosts
- Remove lines containing "# FOCUS MODE"

## Data Location

```
$DATA_DIR/focus_data.json      # Session history and statistics
$DATA_DIR/current_focus.json   # Active session state
$CONFIG_DIR/focus_blocklist.txt # Sites to block during focus
```

## Safety

- **Requires sudo** - Modifies system hosts file
- **Backup /etc/hosts** - Script creates backup
- **Emergency exit always available** - Never truly locked in
- **Break enforcement optional** - Can disable

## Related Scripts

- `pomodoro-enforcer.sh` - Alternative Pomodoro implementation
- `definitely-working.sh` - Anti-AFK script
- `slack-auto-responder.sh` - Auto-respond during focus
