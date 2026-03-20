# Slack Auto Responder

Automatically responds to Slack messages when you're busy with context-aware, randomized replies that look natural.

## Overview

Monitors your Slack DMs and mentions, then auto-responds after intelligent delays with casual messages. Makes you look responsive while you focus on actual work. Uses urgency detection to respond faster to critical messages.

## Features

- Auto-respond to DMs and mentions
- Smart delays (1-10 minutes, faster for urgent messages)
- Urgency detection (keywords, ALL CAPS, multiple !!!)
- Activity detection (won't respond if you're actively typing)
- Spam prevention (won't spam same person within 1 hour)
- Office hours mode (optional respond-only-during-work)
- Randomized casual responses for natural feel
- Different response styles based on time of day

## Installation

```bash
chmod +x scripts/slack-auto-responder.sh
```

## Dependencies

Required:
- Slack API token (user token with appropriate scopes)
- `curl` - HTTP requests
- `jq` - JSON processing

## Setup

### Get Slack API Token

1. Go to https://api.slack.com/apps
2. Create new app or use existing
3. Add OAuth scopes:
   - `im:read`
   - `im:history`
   - `mpim:read`
   - `mpim:history`
   - `users:read`
   - `chat:write`
4. Install app to workspace
5. Copy User OAuth Token

### Configure

Add to `config/config.sh`:

```bash
# Slack credentials (USER token required, not bot token!)
export SLACK_USER_TOKEN="xoxp-your-token-here"
export SLACK_USER_ID="U01234567"  # Your Slack user ID
```

**Important:** This script requires a **USER token** (starts with `xoxp-`), not a bot token (xoxb-). User tokens allow the script to act as you and send messages as you.

Get your user ID by going to your Slack profile → More → Copy member ID

## Usage

### Start Auto-Responder Daemon

```bash
# Start monitoring in background
./scripts/slack-auto-responder.sh monitor &

# Or in foreground for testing
./scripts/slack-auto-responder.sh monitor
```

The daemon will:
- Check for new DMs and mentions every 30 seconds
- Wait 1-10 minutes before responding (random delay)
- Respond faster (30 seconds - 2 minutes) for urgent messages
- Skip if you've already responded to that person in the last hour
- Skip if you're actively typing/online

### Control Auto-Response

```bash
# Enable auto-respond
./scripts/slack-auto-responder.sh enable

# Disable auto-respond (daemon keeps running but won't send messages)
./scripts/slack-auto-responder.sh disable

# Toggle on/off
./scripts/slack-auto-responder.sh toggle

# Check current status
./scripts/slack-auto-responder.sh status
```

### Testing

```bash
# Test response for a specific user/channel
./scripts/slack-auto-responder.sh test U12345 C67890
```

## Commands

| Command | Description |
|---------|-------------|
| `monitor` | Start monitoring daemon (checks every 30s) |
| `enable` | Enable auto-respond |
| `disable` | Disable auto-respond |
| `toggle` | Toggle auto-respond on/off |
| `status` | Show current status and recent responses |
| `test USER CHANNEL` | Test auto-respond for specific user |

## Options

```bash
# Custom delay range
./scripts/slack-auto-responder.sh monitor --min-delay 30 --max-delay 300

# Only respond during office hours (9 AM - 6 PM weekdays)
./scripts/slack-auto-responder.sh monitor --office-hours
```

## Response Types

The script randomly selects from different response categories:

### Casual (25%)
- "brb"
- "one sec"
- "give me a min"
- "hang on"
- "just a moment"

### On a Call (25%)
- "on a call, will ping you after"
- "in a meeting, brb"
- "on a quick call"
- "jumping on a call, give me 10"

### Grabbing Something (25%)
- "grabbing coffee, brb"
- "quick coffee break"
- "getting some water"
- "refilling coffee ☕"

### Working on Something (25%)
- "heads down on something, will check in a bit"
- "in the zone, give me a few"
- "debugging something, brb"
- "finishing up a task"
- "wrapping something up"

### Urgent Messages
For messages with "urgent", "asap", "production", "down", etc.:
- "saw this, give me 2 min"
- "on it"
- "checking now"
- "looking"

### After Hours (Night/Weekend)
- "saw this late, will check tomorrow"
- "just seeing this, will respond in the morning"
- "catching up on messages, will get back to you"

## Urgency Detection

The script automatically detects urgent messages by checking for:

**Urgent keywords:**
- urgent, asap, emergency, critical, now, immediately
- 911, p0, production, down, broken, fire
- 🔥, 🚨 emojis

**High priority indicators:**
- important, quick question, need help, blocked
- issue, problem, can you, could you
- Multiple exclamation marks (!!!)
- ALL CAPS (>50% of message)

**Response times:**
- Urgent: 30 seconds - 2 minutes
- High priority: 1-3 minutes
- Normal: 1-10 minutes
- Night/weekend: 5-10 minutes

## Smart Features

### Spam Prevention
Won't respond to the same user in the same channel more than once per hour, even if they send multiple messages.

### Activity Detection
Checks if you're currently active (online/typing). If you are, it won't auto-respond since you're probably about to respond manually.

### Office Hours
Optional mode that only responds during work hours:
- Weekdays: 9 AM - 6 PM
- Weekends: No responses

Enable with `--office-hours` flag.

### Time-Based Responses
- **Night (10 PM - 6 AM):** Longer delays, "saw this late" messages
- **Morning (6 AM - 12 PM):** Normal delays
- **Afternoon (12 PM - 6 PM):** Normal delays
- **Evening (6 PM - 10 PM):** Normal delays

### Status Updates
After responding (except to urgent messages), automatically sets your Slack status to:
- ☕ "Back in a few" (daytime)
- 💤 "Back in a few" (nighttime)

Status expires after 5 minutes.

## Configuration

Edit the script to customize:

```bash
# Delay range (seconds)
MIN_DELAY=60        # 1 minute
MAX_DELAY=600       # 10 minutes

# Spam prevention window (seconds)
SPAM_PREVENTION_WINDOW=3600  # 1 hour

# Office hours (24-hour format)
OFFICE_HOURS_START=9
OFFICE_HOURS_END=18

# Feature toggles
AUTO_RESPOND_ENABLED=1      # 1=on, 0=off
OFFICE_HOURS_ONLY=0         # 1=on, 0=off
DETECT_URGENCY=1            # 1=on, 0=off
DETECT_ACTIVITY=1           # 1=on, 0=off
```

## Status Command

View current configuration and recent activity:

```bash
./scripts/slack-auto-responder.sh status
```

Shows:
- Auto-respond enabled/disabled
- Current settings (office hours, urgency detection, etc.)
- Response delay range
- Current time and office hours status
- Last 5 auto-responses sent

## Data Location

```
$DATA_DIR/slack_responses.json         # Response database
$DATA_DIR/slack_response_cache.json    # Recent responses (spam prevention)
```

Cache is automatically cleaned to keep only last 24 hours of responses.

## How It Works

1. **Monitoring Loop**
   - Every 30 seconds, fetches unread DMs and mentions
   - Checks each message against filters

2. **Should We Respond?**
   - ✅ Auto-respond is enabled
   - ✅ Within office hours (if enabled)
   - ✅ Haven't responded to this person recently
   - ✅ You're not currently active/typing

3. **Calculate Delay**
   - Detect urgency from message content
   - Choose delay based on urgency and time of day
   - Urgent: 30s-2m, High: 1-3m, Normal: 1-10m

4. **Select Response**
   - Random category (casual, call, grabbing, working)
   - Urgent messages get urgent responses
   - Night messages get "saw this late" responses

5. **Send Response**
   - Wait for calculated delay
   - Send message in thread
   - Update Slack status
   - Record in cache to prevent spam

## Best Practices

1. **Test First**
   - Use `test` command before running daemon
   - Monitor logs to see what messages are detected
   - Adjust delays if needed

2. **Don't Overuse**
   - Disable during actual meetings/calls
   - People will notice if you're "on a call" for 8 hours straight
   - Use for focus sessions, not all day

3. **Monitor Urgent Messages**
   - Script responds fast to urgent messages
   - But you should still check for actual emergencies
   - Don't rely on this for critical communications

4. **Combine with Status**
   - Set actual Slack status when in focus mode
   - Auto-responder complements but doesn't replace status

5. **Use Office Hours Mode**
   - Prevents awkward auto-responses at 2 AM
   - Enable with `--office-hours` flag

## Running as Background Service

### Using systemd (Linux)

Create `/etc/systemd/system/slack-auto-responder.service`:

```ini
[Unit]
Description=Slack Auto Responder
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/path/to/security-researcher-scripts
ExecStart=/path/to/security-researcher-scripts/scripts/slack-auto-responder.sh monitor
Restart=always

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable slack-auto-responder
sudo systemctl start slack-auto-responder
sudo systemctl status slack-auto-responder
```

### Using cron (Start on boot)

```bash
@reboot /path/to/scripts/slack-auto-responder.sh monitor >> /tmp/slack-auto-responder.log 2>&1 &
```

### Manual Background

```bash
# Start in background
nohup ./scripts/slack-auto-responder.sh monitor >> /tmp/slack-auto-responder.log 2>&1 &

# Check if running
ps aux | grep slack-auto-responder

# Stop
pkill -f slack-auto-responder.sh
```

## Troubleshooting

### Not responding automatically

**Check Slack user token:**
```bash
# Test API access
curl -H "Authorization: Bearer $SLACK_USER_TOKEN" https://slack.com/api/auth.test

# Verify it's a user token (should start with xoxp-)
echo $SLACK_USER_TOKEN | grep -q "^xoxp-" && echo "✓ User token" || echo "✗ Not a user token"
```

**Check script is running:**
```bash
ps aux | grep slack-auto-responder
```

**Check auto-respond is enabled:**
```bash
./scripts/slack-auto-responder.sh status
```

**Check user isn't active:**
- Script won't respond if you're actively online/typing
- This is intentional to avoid conflicting with manual responses

### Responses delayed

- This is normal! Delays are 1-10 minutes by default
- For faster responses, use: `--min-delay 30 --max-delay 120`
- Urgent messages automatically get faster responses (30s-2m)

### Token errors

Common issues:
- Token expired: Get new token from Slack app settings
- Missing scopes: Add required scopes and reinstall app
- Wrong token type: Use User Token (xoxp-), not Bot Token (xoxb-)

### Not detecting urgency

Check message contains keywords:
- urgent, asap, emergency, critical, now, immediately
- production, down, broken, fire, p0
- Multiple !!! or ALL CAPS

Enable debug logging:
```bash
# Edit script, add at top:
DEBUG=1
```

## Security Notes

- Token stored in `config/config.sh` - don't commit to git
- Add `config/config.sh` to `.gitignore`
- Use environment variables in CI/CD
- Rotate token periodically (every 90 days)
- Response cache only keeps 24 hours of data

## Integration Ideas

### With Focus Scripts

```bash
# Start auto-responder when entering focus mode
./scripts/focus-mode-nuclear.sh start
./scripts/slack-auto-responder.sh enable
```

### With Pomodoro Timer

```bash
# Enable during Pomodoro sessions
./scripts/pomodoro-enforcer.sh start
./scripts/slack-auto-responder.sh --min-delay 300 --max-delay 600 monitor &
```

### Wrapper Script

Create `focus-with-slack.sh`:
```bash
#!/bin/bash
./scripts/slack-auto-responder.sh enable
./scripts/focus-mode-nuclear.sh start --duration 90
# When focus ends
./scripts/slack-auto-responder.sh disable
```

## Limitations

- Only monitors DMs and direct mentions (not all channel messages)
- Requires script to be running (daemon mode)
- 30-second polling interval (not real-time)
- Slack API rate limits apply
- Can't detect if you responded from mobile

## Related Scripts

- `focus-mode-nuclear.sh` - Block distractions during focus sessions
- `pomodoro-enforcer.sh` - Timed focus sessions with enforcement
- `meeting-excuse-generator.sh` - Auto-decline meetings
- `standup-bot.sh` - Automated standup updates

## Examples

```bash
# Basic usage - start and forget
./scripts/slack-auto-responder.sh monitor &

# Focus session - faster responses
./scripts/slack-auto-responder.sh monitor --min-delay 30 --max-delay 120 &

# Work hours only
./scripts/slack-auto-responder.sh monitor --office-hours &

# Check what's happening
./scripts/slack-auto-responder.sh status

# Disable temporarily for actual meeting
./scripts/slack-auto-responder.sh disable

# Re-enable after meeting
./scripts/slack-auto-responder.sh enable

# Test before using
./scripts/slack-auto-responder.sh test U12345 D67890
```

## Tips

1. **Start with longer delays** (5-10 min) to seem more natural
2. **Use office hours mode** to avoid suspicious 3 AM responses
3. **Monitor the status** occasionally to see response patterns
4. **Disable during actual calls** - don't be that person
5. **Combine with real Slack status** for best effect
6. **Test with a friend first** to see what they receive
7. **Don't use for customer support** - only internal team communication
