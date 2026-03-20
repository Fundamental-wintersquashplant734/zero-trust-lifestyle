# Automated Sockpuppet Maintenance

Automated maintenance for sockpuppet accounts across multiple platforms to keep fake identities alive with realistic activity patterns.

## Overview

Maintains sockpuppet accounts by automatically performing platform-appropriate activities (likes, retweets, upvotes, scrolls) at realistic intervals. Uses encrypted storage for credentials, rotating proxies, randomized user agents, and platform-specific behavior patterns to avoid detection. Designed for OSINT research, security testing, and privacy protection with legitimate personas.

## Features

- Multi-platform support (Twitter, Reddit, LinkedIn, Instagram)
- Encrypted credential storage
- Persona-based activity patterns
- Headless browser automation (Selenium)
- Proxy rotation support
- Randomized timing and delays
- Rate limiting to avoid detection
- Activity logging and tracking
- User agent rotation
- Platform-specific action patterns

## Installation

```bash
chmod +x scripts/automated-sock-maintenance.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - HTTP requests
- `openssl` - Credential encryption
- `python3` - Browser automation
- `selenium` - Web automation (Twitter)
- `chromedriver` - Chrome driver for Selenium

```bash
# Install Python dependencies
pip3 install selenium

# Install ChromeDriver (Ubuntu/Debian)
sudo apt-get install chromium-chromedriver
```

## Usage

### Add Sockpuppet Account

```bash
./scripts/automated-sock-maintenance.sh add PLATFORM USER EMAIL PASS PERSONA

# Examples
./scripts/automated-sock-maintenance.sh add twitter john_doe123 john@example.com 'password123' tech_enthusiast
./scripts/automated-sock-maintenance.sh add reddit jane_dev jane@example.com 'pass456' gamer
```

### List All Sockpuppets

```bash
./scripts/automated-sock-maintenance.sh list

# List specific platform
./scripts/automated-sock-maintenance.sh list twitter
```

### Maintain Specific Account

```bash
./scripts/automated-sock-maintenance.sh maintain john_doe123
```

### Maintain All Accounts

```bash
./scripts/automated-sock-maintenance.sh maintain-all

# Maintain specific platform only
./scripts/automated-sock-maintenance.sh maintain-all twitter
```

### Options

```bash
--no-headless    # Show browser (debugging)
--no-proxy       # Don't use proxies
```

## Supported Platforms

### Twitter
- Like tweets
- Retweet posts
- Follow accounts
- Scroll timeline
- Requires: Selenium + ChromeDriver

### Reddit
- Upvote posts
- Save posts
- Browse subreddits
- Comment (future)
- Uses: curl-based API

### LinkedIn
- Like posts
- Comment on updates
- Connect with people
- Scroll feed

### Instagram
- Like photos
- Follow accounts
- View stories
- Scroll feed

## Personas

Each sockpuppet has a persona that determines interests and activity patterns:

| Persona | Interests |
|---------|-----------|
| `tech_enthusiast` | Programming, Linux, open source, cybersecurity, Python, JavaScript |
| `photographer` | Photography, landscape, portrait, camera gear, editing |
| `gamer` | Gaming, esports, Steam, console gaming, RPGs |
| `fitness` | Fitness, gym, workouts, health, nutrition, running, yoga |
| `foodie` | Food, cooking, recipes, restaurants, baking |
| `traveler` | Travel, vacation, adventure, backpacking, exploration |
| `crypto` | Cryptocurrency, Bitcoin, Ethereum, blockchain, DeFi, NFTs |
| `generic` | News, technology, science, education, art, music |

## Activity Patterns

### Frequency
- Weekdays: 1-5 commits per day
- Weekends: 20% chance of activity
- Time windows: Morning (9-11:30), Afternoon (14-17:30), Evening (20-22)

### Actions Per Session
- Minimum: 2 actions
- Maximum: 5 actions
- Delay between actions: 10-60 seconds
- Delay between accounts: 60-300 seconds

### Realistic Behavior
- Random delays to simulate human behavior
- Platform-specific action mix (likes vs. retweets vs. follows)
- Interest-based content targeting
- Rate limiting (3 sessions per hour max)

## Commands

| Command | Description |
|---------|-------------|
| `add PLATFORM USER EMAIL PASS PERSONA` | Add new sockpuppet |
| `list [PLATFORM]` | List all or platform-specific sockpuppets |
| `maintain USER` | Perform maintenance on specific account |
| `maintain-all [PLATFORM]` | Maintain all sockpuppets (or platform-specific) |

## Configuration

### Proxy Setup (Optional)

Create proxy list:
```bash
echo "http://proxy1.example.com:8080" >> $DATA_DIR/proxies.txt
echo "socks5://proxy2.example.com:1080" >> $DATA_DIR/proxies.txt
```

Enable proxies:
```bash
export USE_PROXY=1
```

### User Agent Rotation (Optional)

Create user agent list:
```bash
cat > $DATA_DIR/user_agents.txt <<EOF
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36
Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
EOF
```

### Activity Settings

Customize in script:
```bash
MIN_ACTIONS=2        # Minimum actions per session
MAX_ACTIONS=5        # Maximum actions per session
MIN_DELAY=10         # Min seconds between actions
MAX_DELAY=60         # Max seconds between actions
```

## Example Workflow

### 1. Setup Sockpuppet

```bash
# Add Twitter account
./scripts/automated-sock-maintenance.sh add twitter securityresearch_bot \
  research@example.com 'StrongP@ss123' tech_enthusiast
```

### 2. Test Manual Maintenance

```bash
# Run maintenance (with browser visible for debugging)
./scripts/automated-sock-maintenance.sh --no-headless maintain securityresearch_bot
```

### 3. Automate with Cron

```bash
# Daily at 3 AM
0 3 * * * /path/to/automated-sock-maintenance.sh maintain-all

# Specific platform only
0 3 * * * /path/to/automated-sock-maintenance.sh maintain-all twitter
```

## Security Features

### Credential Protection
- Passwords encrypted with AES-256-CBC
- Encryption key derived from machine ID
- Credentials never logged or displayed

### Anti-Detection
- Rotating proxies to avoid IP bans
- Random user agents
- Realistic human-like delays
- Rate limiting enforcement
- Headless mode (no GUI)
- Disabled automation flags

### Privacy
- All data stored locally
- Encrypted database
- No telemetry or external calls

## Data Storage

```
$DATA_DIR/sockpuppets.json        # Encrypted account database
$DATA_DIR/proxies.txt             # Proxy list (optional)
$DATA_DIR/user_agents.txt         # User agent list (optional)
```

## Troubleshooting

### Twitter Login Fails

**Issue**: Selenium can't log in to Twitter

**Solutions**:
- Check username/password
- Verify ChromeDriver installed: `which chromedriver`
- Try with `--no-headless` to see what's happening
- Check if account locked or suspended
- Disable 2FA or use app-specific password

### Reddit API Errors

**Issue**: "Unauthorized" or rate limit errors

**Solutions**:
- Wait a few minutes (rate limited)
- Check credentials
- Verify Reddit account not banned
- Try different subreddit

### Proxy Connection Failed

**Issue**: Can't connect through proxy

**Solutions**:
- Test proxy manually: `curl -x PROXY_URL https://google.com`
- Check proxy format (http:// or socks5://)
- Disable proxies: `--no-proxy`
- Update proxy list with working proxies

## Best Practices

### Account Creation
1. Create accounts with diverse email providers
2. Use realistic profile information
3. Add profile photos (use generated faces)
4. Follow accounts relevant to persona
5. Build history before using for research

### Maintenance Schedule
1. Run maintenance 2-3 times per week minimum
2. Vary timing (don't always run at same time)
3. Lower frequency for older, established accounts
4. Increase activity before important research operations

### OpSec
1. Always use proxies for sensitive personas
2. Don't link sockpuppets to real identity
3. Use separate email for each account
4. Never reuse passwords
5. Keep credentials encrypted
6. Rotate proxies regularly

### Platform Compliance
1. Follow platform Terms of Service where possible
2. Don't use for spam or harassment
3. Keep activity realistic (don't overdo it)
4. Avoid automated bulk actions
5. Be aware of platform automation policies

## Automation Examples

### Cron Schedule

```bash
# Daily maintenance (randomized hour)
0 $((RANDOM % 24)) * * * /path/to/automated-sock-maintenance.sh maintain-all

# Multiple times per day
0 */8 * * * /path/to/automated-sock-maintenance.sh maintain-all twitter

# Weekly full maintenance
0 3 * * 0 /path/to/automated-sock-maintenance.sh maintain-all
```

### Systemd Timer

Create `/etc/systemd/system/sockpuppet-maintenance.service`:
```ini
[Unit]
Description=Sockpuppet Account Maintenance

[Service]
Type=oneshot
ExecStart=/path/to/automated-sock-maintenance.sh maintain-all
User=youruser
```

Create `/etc/systemd/system/sockpuppet-maintenance.timer`:
```ini
[Unit]
Description=Daily Sockpuppet Maintenance

[Timer]
OnCalendar=daily
RandomizedDelaySec=3h

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable sockpuppet-maintenance.timer
sudo systemctl start sockpuppet-maintenance.timer
```

## Ethical Considerations

### Legitimate Use Cases
- OSINT research and investigations
- Security testing with authorization
- Privacy protection (maintaining cover identities)
- Academic research on social platforms
- Testing automation detection systems

### Prohibited Uses
- Harassment or stalking
- Spreading misinformation
- Astroturfing or fake grassroots campaigns
- Election interference
- Terms of Service violations for malicious purposes
- Impersonation with intent to deceive

### Platform Policies
- Most platforms prohibit automated accounts
- Use at your own risk
- Accounts may be suspended
- Always follow applicable laws and regulations

## Related Scripts

- `opsec-paranoia-check.sh` - Verify operational security
- `browser-history-cleanser.sh` - Clean browsing traces
- `coffee-shop-lockdown.sh` - Secure public network connections
