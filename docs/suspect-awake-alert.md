# Suspect Awake Alert

Monitor online activity patterns across multiple platforms with authorization and consent.

## Overview

Activity monitoring system that tracks when targets go online/offline on platforms like GitHub, Steam, and Discord. Features pattern analysis to detect unusual activity times, encrypted target storage, and consent-based monitoring. Designed for legitimate use cases: monitoring your own accounts for security, authorized employee monitoring, parental controls, or security research with explicit permission.

## Features

- Multi-platform monitoring (GitHub, Steam, Discord)
- Encrypted target database with consent tracking
- Real-time activity pattern analysis
- Unusual activity detection (3+ standard deviations from normal)
- Historical pattern tracking (hourly/daily patterns)
- Live monitoring dashboard
- Automatic alerts for online/offline status changes
- Legal compliance checks built-in
- Privacy-first design (local storage only)
- Rate limiting and API key support

## Installation

```bash
chmod +x scripts/suspect-awake-alert.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - API requests
- `openssl` - Encrypted storage

## Legal Requirements

### WARNING: AUTHORIZATION REQUIRED

This tool is ONLY for:
- Monitoring YOUR OWN accounts across platforms
- Authorized employee/contractor monitoring (with written consent)
- Parental controls (monitoring your children)
- Security research with explicit authorization

### Prohibited Uses

NEVER use for:
- Stalking or harassment
- Unauthorized surveillance
- Violating platform Terms of Service
- Any illegal activity

Unauthorized monitoring may violate:
- Computer Fraud and Abuse Act (CFAA)
- Electronic Communications Privacy Act (ECPA)
- State/local privacy laws
- Platform Terms of Service

### Consent Process

On first run, the script:
1. Shows legal warning
2. Requires explicit acknowledgment
3. Creates consent record at `$DATA_DIR/monitoring_consent.txt`
4. Requires 'yes' parameter when adding each target

## Platform Support

### GitHub (Enabled by Default)
- Monitors public activity events
- Detects activity within last hour
- Optional: Use `GITHUB_TOKEN` for higher rate limits
- No API key required for basic use

### Steam (Enabled by Default)
- Monitors online status and current game
- Requires Steam API key
- Public profiles only
- States: Offline, Online, Busy, Away, etc.

### Discord (Disabled by Default)
- Monitors user online status
- Requires Discord bot token
- Requires shared server with target
- Needs presence intent enabled

## Setup

### 1. Install Dependencies

```bash
# Debian/Ubuntu
sudo apt install jq curl openssl

# macOS
brew install jq curl openssl
```

### 2. Configure API Keys (Optional)

Create or edit `config/config.sh`:

```bash
# GitHub (optional - increases rate limits)
export GITHUB_TOKEN="ghp_your_token_here"

# Steam (required for Steam monitoring)
export STEAM_API_KEY="your_steam_api_key"

# Discord (optional - requires bot setup)
export DISCORD_TOKEN="your_bot_token"
```

### 3. Get API Keys

**GitHub Token:**
```bash
# Go to: https://github.com/settings/tokens
# Generate token with 'read:user' scope
```

**Steam API Key:**
```bash
# Go to: https://steamcommunity.com/dev/apikey
# Register for API key
```

**Discord Bot Token:**
```bash
# Go to: https://discord.com/developers/applications
# Create application > Bot > Get token
# Requires presence intent enabled
```

## Usage

### First Run - Consent

```bash
./scripts/suspect-awake-alert.sh

# Displays legal warning
# Requires acknowledgment
# Creates consent record
```

### Add Targets (With Consent)

```bash
# Add your own GitHub account
./scripts/suspect-awake-alert.sh add github "yourusername" "My account" yes

# Add Steam account (requires API key)
./scripts/suspect-awake-alert.sh add steam "76561198012345678" "My Steam" yes

# Add Discord user (requires bot token)
./scripts/suspect-awake-alert.sh add discord "123456789012345678" "Description" yes
```

**Important:** The 4th parameter `yes` confirms you have authorization to monitor this account.

### List Targets

```bash
./scripts/suspect-awake-alert.sh list

# Output:
# 👁️  Monitored Targets
#
# [github] yourusername
#   Description: My account
#   Consent: yes
#   Last seen: 2025-12-05T10:30:00+00:00
#   Status: online
```

### Check Single Target

```bash
./scripts/suspect-awake-alert.sh check github "yourusername"

# Output: online | offline | online:game_name
```

### Start Monitoring Loop

```bash
# Monitor all targets continuously
./scripts/suspect-awake-alert.sh monitor

# With custom check interval (default: 5 minutes)
./scripts/suspect-awake-alert.sh --interval 600 monitor

# With alerts
./scripts/suspect-awake-alert.sh --alert-online --alert-offline monitor
```

### Show Live Dashboard

```bash
./scripts/suspect-awake-alert.sh dashboard

# Displays:
# ╔════════════════════════════════════════════════════════════╗
# ║          👁️  ACTIVITY MONITORING DASHBOARD              ║
# ╚════════════════════════════════════════════════════════════╝
#
# Monitored targets: 3
#
# 🟢  [github] yourusername - online
#    Last seen: 2025-12-05T10:30:00+00:00
#
# 🔴  [steam] 76561198012345678 - offline
#    Last seen: 2025-12-05T08:15:00+00:00
```

### Analyze Activity Patterns

```bash
./scripts/suspect-awake-alert.sh analyze github "yourusername"

# Output:
# 📊 Activity Pattern Analysis
# Target: yourusername on github
#
# Most active hours (UTC):
# 14:00 - 47 times
# 15:00 - 42 times
# 16:00 - 38 times
#
# Most active days:
# Mon - 82 times
# Wed - 76 times
# Fri - 71 times
#
# Pattern prediction:
# User is LIKELY ONLINE at this hour (14:00)
```

## Commands

| Command | Description |
|---------|-------------|
| `add PLATFORM ID [DESC] [yes]` | Add monitoring target (requires 'yes' for consent) |
| `remove PLATFORM ID` | Remove monitoring target |
| `list` | List all monitored targets |
| `check PLATFORM ID` | Check single target status |
| `monitor` | Start continuous monitoring loop |
| `dashboard` | Show live monitoring dashboard |
| `analyze PLATFORM ID` | Analyze activity patterns |

## Options

| Option | Description |
|--------|-------------|
| `--interval SECONDS` | Check interval for monitoring (default: 300) |
| `--alert-online` | Alert when target goes online |
| `--alert-offline` | Alert when target goes offline |
| `--no-patterns` | Disable pattern tracking |
| `-h, --help` | Show help message |

## Configuration

### Monitoring Settings

Edit in script or set via options:

```bash
CHECK_INTERVAL=300              # 5 minutes between checks
ALERT_ON_ONLINE=1               # Alert when going online
ALERT_ON_OFFLINE=0              # Don't alert when going offline
ALERT_ON_PATTERN_CHANGE=1       # Alert on unusual activity
TRACK_ACTIVITY_PATTERNS=1       # Track patterns for analysis
```

### Pattern Detection

```bash
MIN_SAMPLES_FOR_PATTERN=20      # Samples needed for pattern analysis
UNUSUAL_ACTIVITY_THRESHOLD=3    # Std deviations for unusual activity
```

### Platform Toggles

```bash
ENABLE_GITHUB=1                 # GitHub monitoring (default: on)
ENABLE_DISCORD=0                # Discord monitoring (default: off)
ENABLE_SLACK=0                  # Slack monitoring (default: off)
ENABLE_TWITTER=0                # Twitter monitoring (default: off)
ENABLE_STEAM=1                  # Steam monitoring (default: on)
```

### Privacy Settings

```bash
ENCRYPTED_STORAGE=1             # Encrypt target database
REQUIRE_CONSENT=1               # Require consent for monitoring
```

## Pattern Analysis Features

### Activity Tracking

The script tracks:
- **Timestamp** - When activity was detected
- **Status** - online, offline, or online:game
- **Hour** - Hour of day (0-23 UTC)
- **Day of week** - 1=Monday, 7=Sunday

### Pattern Detection

With 20+ samples, analyze:
- **Most active hours** - When target is typically online
- **Most active days** - Which days show most activity
- **Current prediction** - Likelihood of being online now

### Unusual Activity Detection

Alerts when:
- User online at unusual hours (2-5 AM)
- Activity deviates 3+ standard deviations from normal
- Pattern change detected

## Data Storage

### Encrypted Targets Database

**Location:** `$DATA_DIR/surveillance_targets.enc`

**Format:** Encrypted JSON
```json
{
  "targets": [
    {
      "platform": "github",
      "identifier": "username",
      "description": "My account",
      "consent": "yes",
      "added": "2025-12-05T10:00:00+00:00",
      "last_seen": "2025-12-05T14:30:00+00:00",
      "last_status": "online",
      "check_count": 127
    }
  ]
}
```

### Activity Log

**Location:** `$DATA_DIR/activity_patterns.json`

**Format:** JSON (up to 10,000 records)
```json
{
  "activities": [
    {
      "timestamp": "2025-12-05T14:30:00+00:00",
      "platform": "github",
      "identifier": "username",
      "status": "online",
      "hour": 14,
      "day_of_week": 4
    }
  ]
}
```

### Alerts Log

**Location:** `$DATA_DIR/activity_alerts.json`

Stores alert history.

### Consent Record

**Location:** `$DATA_DIR/monitoring_consent.txt`

Contains:
- Date of acknowledgment
- User who acknowledged
- Legal statement
- Digital signature

## Example Workflows

### Monitor Your Own Accounts for Security

```bash
# 1. Set up monitoring for your accounts
./scripts/suspect-awake-alert.sh add github "yourusername" "My GitHub" yes
./scripts/suspect-awake-alert.sh add steam "your_steam_id" "My Steam" yes

# 2. Start monitoring
./scripts/suspect-awake-alert.sh --alert-online monitor

# 3. Get alerted if someone logs into your accounts
# Alert: "🟢 yourusername is NOW ONLINE on github!"
# (When you're not actually online = potential unauthorized access)
```

### Employee Monitoring (With Written Consent)

```bash
# 1. Obtain written authorization
# Document consent per company policy

# 2. Add authorized targets
./scripts/suspect-awake-alert.sh add github "employee" "Employee GitHub" yes

# 3. Monitor work patterns
./scripts/suspect-awake-alert.sh monitor

# 4. Analyze patterns weekly
./scripts/suspect-awake-alert.sh analyze github "employee"
```

### Parental Controls

```bash
# 1. Add child's accounts (you have parental authority)
./scripts/suspect-awake-alert.sh add steam "child_steam_id" "Child's Steam" yes

# 2. Monitor gaming activity
./scripts/suspect-awake-alert.sh --alert-online monitor

# 3. Check if online during homework time
./scripts/suspect-awake-alert.sh check steam "child_steam_id"
```

### Security Research

```bash
# 1. Get explicit authorization from subject
# Document written permission

# 2. Add research targets
./scripts/suspect-awake-alert.sh add github "research_subject" "Research" yes

# 3. Collect activity data
./scripts/suspect-awake-alert.sh monitor

# 4. Analyze patterns for research
./scripts/suspect-awake-alert.sh analyze github "research_subject"
```

## Alert Examples

### Online Alert

```
🟢 username is NOW ONLINE on github!
```

### Offline Alert

```
🔴 username went offline on platform
```

### Unusual Activity Alert

```
⚠️  UNUSUAL ACTIVITY: username online at unusual time!
```

Desktop notification sent if `SEND_NOTIFICATIONS=1`.

## Monitoring Output

### Monitoring Loop

```bash
./scripts/suspect-awake-alert.sh monitor

# Output:
# ℹ Starting activity monitoring (Ctrl+C to stop)...
# ℹ Check interval: 5 minutes
# ℹ === Monitoring cycle at Thu Dec  5 10:30:00 UTC 2025 ===
# ℹ Monitoring all targets...
# ℹ Checking 3 target(s)...
# ✓ username went online
# ℹ Cycle complete. Sleeping for 5 minutes...
```

### Dashboard

```bash
./scripts/suspect-awake-alert.sh dashboard

# ╔════════════════════════════════════════════════════════════╗
# ║          👁️  ACTIVITY MONITORING DASHBOARD              ║
# ╚════════════════════════════════════════════════════════════╝
#
# Monitored targets: 3
#
# 🟢  [github] alice - online
#    Last seen: 2025-12-05T10:30:00+00:00
#
# 🔴  [steam] bob - offline
#    Last seen: 2025-12-05T08:15:00+00:00
#
# 🟢  [github] charlie - online
#    Last seen: 2025-12-05T10:25:00+00:00
```

## Platform-Specific Notes

### GitHub Monitoring

**How It Works:**
- Fetches user's public events via GitHub API
- Considers "online" if activity in last hour
- Works without authentication (rate limited)
- Use `GITHUB_TOKEN` for higher limits (5000 req/hour)

**Rate Limits:**
- Unauthenticated: 60 requests/hour
- Authenticated: 5000 requests/hour

**Activity Types Tracked:**
- Push events, PR comments, issue activity
- Public commits, releases, stars

### Steam Monitoring

**How It Works:**
- Uses Steam Web API
- Fetches player summary with persona state
- Shows current game if playing
- Public profiles only

**Persona States:**
- 0 = Offline
- 1 = Online
- 2 = Busy
- 3 = Away
- 4 = Snooze
- 5 = Looking to trade
- 6 = Looking to play

**Requirements:**
- Steam API key (free)
- Target profile must be public

### Discord Monitoring

**How It Works:**
- Requires Discord bot token
- Bot must share server with target
- Needs presence intent enabled
- Can only check users in shared servers

**Limitations:**
- Cannot reliably detect online status without presence intent
- Requires bot setup and server access
- More complex than GitHub/Steam

**Status:** Disabled by default due to complexity

## Troubleshooting

### "Not enough data for pattern analysis"

Need 20+ samples. Keep monitoring longer:
```bash
# Run for several days to collect data
./scripts/suspect-awake-alert.sh monitor
```

### GitHub Rate Limit Exceeded

```bash
# Add GitHub token for higher limits
export GITHUB_TOKEN="ghp_your_token"
./scripts/suspect-awake-alert.sh monitor
```

### Steam API Returns No Data

Check:
- API key is valid
- Steam ID is correct (76561198...)
- Profile is set to public

### Consent File Issues

```bash
# Delete and restart to re-acknowledge
rm $DATA_DIR/monitoring_consent.txt
./scripts/suspect-awake-alert.sh
```

### Encrypted Database Corrupted

```bash
# Backup and reinitialize
cp $DATA_DIR/surveillance_targets.enc $DATA_DIR/surveillance_targets.enc.bak
rm $DATA_DIR/surveillance_targets.enc
./scripts/suspect-awake-alert.sh add github "username" "desc" yes
```

## Best Practices

### 1. Document Authorization

- Get written consent before monitoring
- Store consent documentation separately
- Review authorization periodically
- Remove targets when authorization expires

### 2. Respect Privacy

- Only monitor when legally authorized
- Don't share monitoring data
- Delete data when no longer needed
- Use encryption for sensitive data

### 3. Minimize Data Collection

- Only track necessary platforms
- Adjust check intervals (longer = less intrusive)
- Disable pattern tracking if not needed
- Purge old data regularly

### 4. Monitor Your Own Accounts

Primary use case:
```bash
# Detect unauthorized access to your accounts
./scripts/suspect-awake-alert.sh add github "myusername" "My account" yes
./scripts/suspect-awake-alert.sh --alert-online monitor
```

### 5. Pattern Analysis Tips

- Collect 50+ samples for accurate patterns
- Run monitoring for 2+ weeks
- Consider timezone differences
- Account for weekends vs weekdays

## Security Considerations

### Encrypted Storage

- Target database encrypted with OpenSSL
- Password required to decrypt
- Prevents casual data access
- Use strong passwords

### API Keys

- Store API keys in `config/config.sh` (not in repo)
- Add `config/config.sh` to `.gitignore`
- Use environment variables
- Rotate keys periodically

### Rate Limiting

- Built-in 2-second delay between checks
- Respects platform rate limits
- Adjust `CHECK_INTERVAL` to reduce load
- Use authenticated APIs when available

## Legal Considerations

### When You Can Use This Tool

1. **Your Own Accounts**
   - Monitoring your GitHub, Steam, Discord for security
   - Detecting unauthorized access
   - No consent needed (it's your account)

2. **Employee Monitoring**
   - Written company policy
   - Documented consent from employee
   - Legitimate business purpose
   - Compliance with labor laws

3. **Parental Monitoring**
   - You are legal parent/guardian
   - Monitoring minor children
   - In child's best interest
   - Age-appropriate

4. **Security Research**
   - Explicit written authorization
   - Institutional review (if academic)
   - Documented consent
   - Limited scope and duration

### When You CANNOT Use This Tool

- Stalking or harassment
- Monitoring without consent
- Violating platform ToS
- Spying on competitors
- Unauthorized employee monitoring
- Revenge or intimidation

### Legal Liability

By using this tool, you accept full legal responsibility for:
- Obtaining proper authorization
- Complying with applicable laws
- Respecting platform Terms of Service
- Any consequences of misuse

**The script creator is not responsible for misuse.**

## Integration with Other Scripts

### With OPSEC Paranoia Check

```bash
# Check if YOU are being monitored
./scripts/opsec-paranoia-check.sh
```

### With Data Breach Stalker

```bash
# Monitor for compromised credentials
./scripts/data-breach-stalker.sh
```

### With Browser History Cleanser

```bash
# Clean traces of monitoring activity
./scripts/browser-history-cleanser.sh
```

## Advanced Usage

### Custom Alert Scripts

Modify `send_alert()` function to integrate with:
- Slack/Discord webhooks
- Email notifications
- SMS alerts (Twilio)
- Push notifications (Pushover)

### Export Pattern Data

```bash
# Export activity patterns for analysis
cat $DATA_DIR/activity_patterns.json | jq '.activities[] | select(.platform == "github")'
```

### Automated Reporting

```bash
# Weekly pattern report via cron
0 9 * * 1 /path/to/suspect-awake-alert.sh analyze github "username" | mail -s "Weekly Pattern Report" your@email.com
```

## Data Retention

### Activity Log Limits

- Automatically keeps last 10,000 records
- Older records purged automatically
- Adjust in `record_activity()` function

### Manual Cleanup

```bash
# Delete old activity data
rm $DATA_DIR/activity_patterns.json

# Remove specific target
./scripts/suspect-awake-alert.sh remove github "username"

# Delete all data
rm -rf $DATA_DIR/surveillance_targets.enc
rm -rf $DATA_DIR/activity_patterns.json
rm -rf $DATA_DIR/monitoring_consent.txt
```

## Related Scripts

- `opsec-paranoia-check.sh` - Check if you're being monitored
- `data-breach-stalker.sh` - Monitor for credential leaks
- `definitely-working.sh` - Anti-AFK status maintenance
- `coffee-shop-lockdown.sh` - Secure public WiFi sessions

## Ethical Guidelines

### The "Would I Want This Done to Me?" Test

Before monitoring someone:
1. Would I be comfortable being monitored this way?
2. Would I want to know if I was being monitored?
3. Is this monitoring proportionate to the concern?
4. Am I the right person to be doing this monitoring?

If you answered "no" to any of these, reconsider.

### Transparency > Secrecy

- Be transparent about monitoring when possible
- Explain why monitoring is necessary
- Share monitoring data with the monitored person
- Allow opt-out when feasible

### Minimize Harm

- Collect only necessary data
- Store data securely
- Delete when no longer needed
- Don't share unnecessarily

## Disclaimer

This tool is provided for educational and authorized security purposes only. The authors are not responsible for misuse, illegal activity, or any damages resulting from use of this tool. Users are solely responsible for ensuring they have proper authorization and comply with all applicable laws.

**Use responsibly. Monitor ethically. Get consent.**
