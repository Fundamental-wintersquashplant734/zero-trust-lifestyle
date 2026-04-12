# Setup Guide

Detailed setup instructions for zero-trust-lifestyle.

## Table of Contents

- [Quick Start](#quick-start)
- [Dependencies](#dependencies)
- [API Keys](#api-keys)
- [Script-Specific Setup](#script-specific-setup)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/gl0bal01/zero-trust-lifestyle.git
cd zero-trust-lifestyle

# Run installation
./install.sh

# Edit configuration
nano config/config.sh

# Test a script
./scripts/opsec-paranoia-check.sh --quick
```

---

## Dependencies

### Required (All Scripts)

```bash
# Ubuntu/Debian
sudo apt install jq curl openssl grep sed gawk bash

# Fedora/RHEL
sudo dnf install jq curl openssl grep sed gawk bash

# macOS
brew install jq curl openssl grep gnu-sed gawk bash
```

### Optional Dependencies

#### For OSINT/Meeting Prep
```bash
# Google Calendar CLI
pip3 install gcalcli

# Or khal (alternative)
sudo apt install khal  # Ubuntu/Debian
brew install khal      # macOS

# Web search
pip3 install googler
```

#### For Email Sentiment Analysis
```bash
# Python NLP libraries
pip3 install transformers torch
```

#### For Sockpuppet Automation
```bash
# Selenium + ChromeDriver
pip3 install selenium

# ChromeDriver (Ubuntu/Debian)
sudo apt install chromium-chromedriver

# ChromeDriver (macOS)
brew install chromedriver

# Xvfb for headless (Linux only)
sudo apt install xvfb
```

#### For OPSEC Checks
```bash
# EXIF tool for metadata
sudo apt install libimage-exiftool-perl  # Ubuntu/Debian
brew install exiftool                    # macOS

# Network tools
sudo apt install network-manager iproute2 iptables
```

#### For Notifications
```bash
# Linux
sudo apt install libnotify-bin  # notify-send

# macOS (built-in osascript)
# No installation needed
```

---

## API Keys

### LinkedIn (Meeting Prep)

1. Create LinkedIn app: https://www.linkedin.com/developers/apps
2. Get OAuth 2.0 credentials
3. Add to config:
   ```bash
   LINKEDIN_API_KEY="your_key_here"
   ```

**Note**: LinkedIn API access is restricted. Alternative: scrape public profiles (respect ToS).

### GitHub (Meeting Prep)

1. Generate Personal Access Token: https://github.com/settings/tokens
2. Scopes needed: `read:user`, `user:email`
3. Add to config:
   ```bash
   GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
   ```

### Twitter/X (Meeting Prep)

1. Apply for developer account: https://developer.twitter.com
2. Create app and get Bearer Token
3. Add to config:
   ```bash
   TWITTER_BEARER_TOKEN="your_bearer_token"
   ```

### Google Calendar (Meeting Prep)

**Method 1: Using gcalcli (Recommended - Easiest)**

1. Install gcalcli:
   ```bash
   pip3 install gcalcli
   ```

2. Authenticate (opens browser):
   ```bash
   gcalcli init
   ```
   - Signs you into Google
   - Requests calendar permissions
   - Saves credentials to `~/.gcalcli_oauth`

3. Test it works:
   ```bash
   gcalcli agenda
   ```

**You're done!** The scripts will automatically use gcalcli's credentials.

---

**Method 2: Manual OAuth Setup (Advanced)**

If you want to create your own OAuth app:

1. Go to **Google Cloud Console**: https://console.cloud.google.com

2. **Create a Project**:
   - Click "Select a project" → "NEW PROJECT"
   - Name: "Standup Bot" (or any name)
   - Click "CREATE"

3. **Enable Google Calendar API**:
   - Go to: APIs & Services → Library
   - Search: "Google Calendar API"
   - Click it and press "ENABLE"

4. **Create OAuth Credentials**:
   - Go to: APIs & Services → Credentials
   - Click "+ CREATE CREDENTIALS" → "OAuth client ID"

   If prompted to configure consent screen:
   - User Type: External
   - App name: "Standup Bot"
   - User support email: your email
   - Developer contact: your email
   - Click "Save and Continue" (skip optional fields)
   - Add test users: your email
   - Save

   Back to Create OAuth client ID:
   - Application type: "Desktop app"
   - Name: "Standup Bot"
   - Click "CREATE"

5. **Download Credentials**:
   - Click download button (⬇) next to your OAuth client
   - Save the JSON file
   - Move it:
   ```bash
   mkdir -p ~/.config
   mv ~/Downloads/client_secret_*.json ~/.config/google-calendar-creds.json
   ```

6. **Set in config** (optional):
   ```bash
   GOOGLE_CALENDAR_CREDS="$HOME/.config/google-calendar-creds.json"
   ```

7. **First Run** (authenticate):
   ```bash
   gcalcli --client-id ~/.config/google-calendar-creds.json init
   ```
   - Browser opens
   - Sign in to Google
   - Click "Allow"
   - Credentials cached

**Troubleshooting**:

- **"Access blocked"**: Add your email to test users in OAuth consent screen
- **"API not enabled"**: Go to console.cloud.google.com → Enable Google Calendar API
- **"Authentication failed"**: Remove old token and re-auth:
  ```bash
  rm ~/.gcalcli_oauth
  gcalcli init
  ```

### Telegram Alerts

1. Create bot with @BotFather on Telegram
2. Get bot token
3. Get your chat ID (use @userinfobot)
4. Add to config:
   ```bash
   TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
   TELEGRAM_CHAT_ID="your_chat_id"
   ```

---

## Script-Specific Setup

### Meeting Prep Assassin

**Setup Steps:**

1. Install calendar client:
   ```bash
   pip3 install gcalcli
   ```

2. Authenticate with Google:
   ```bash
   gcalcli init
   ```

3. Test calendar access:
   ```bash
   gcalcli list
   ```

4. Run script:
   ```bash
   ./scripts/meeting-prep-assassin.sh --list
   ```

**Cron Setup** (check 5 minutes before meetings):
```cron
* * * * * /path/to/scripts/meeting-prep-assassin.sh
```

---

### Passive-Aggressive Emailer

**Setup Steps:**

1. Configure your mail client to use the script as sendmail

   **For Mutt** (`~/.muttrc`):
   ```
   set sendmail = "/path/to/scripts/passive-aggressive-emailer.sh"
   ```

   **For msmtp** (`~/.msmtprc`):
   ```
   sendmail_path = /path/to/scripts/passive-aggressive-emailer.sh
   ```

2. Test with a sample email:
   ```bash
   cat > /tmp/test_email.eml <<EOF
   To: test@example.com
   Subject: Test Email

   THIS IS A TEST EMAIL IN ALL CAPS!!!
   Per my last email, I think this is unacceptable.
   EOF

   ./scripts/passive-aggressive-emailer.sh /tmp/test_email.eml
   ```

3. Run quarantine daemon:
   ```bash
   ./scripts/passive-aggressive-emailer.sh --daemon &
   ```

---

### Wife Happy Score

**Setup Steps:**

1. Run initial setup:
   ```bash
   ./scripts/wife-happy-score.sh --setup
   ```

2. Fill in:
   - Partner's name
   - Anniversary date (YYYY-MM-DD)
   - Birthday (YYYY-MM-DD)
   - Preferences (optional)

3. Test dashboard:
   ```bash
   ./scripts/wife-happy-score.sh
   ```

4. Record an action:
   ```bash
   ./scripts/wife-happy-score.sh --record date
   ```

**Daily Reminder** (cron):
```cron
0 9 * * * /path/to/scripts/wife-happy-score.sh --dashboard
```

---

### OPSEC Paranoia Check

**Setup Steps:**

1. Configure allowed DNS servers in `config/config.sh`:
   ```bash
   ALLOWED_DNS=("127.0.0.1" "10.0.0.1" "192.168.1.1")
   ```

2. Run full check:
   ```bash
   ./scripts/opsec-paranoia-check.sh
   ```

3. Run quick check (VPN + DNS only):
   ```bash
   ./scripts/opsec-paranoia-check.sh --quick
   ```

4. Run as daemon:
   ```bash
   ./scripts/opsec-paranoia-check.sh --daemon &
   ```

**Cron Setup** (every 15 minutes):
```cron
*/15 * * * * /path/to/scripts/opsec-paranoia-check.sh --quick
```

---

### Automated Sock Maintenance

**Setup Steps:**

1. Install Selenium:
   ```bash
   pip3 install selenium
   ```

2. Install ChromeDriver:
   ```bash
   # Ubuntu/Debian
   sudo apt install chromium-chromedriver

   # macOS
   brew install chromedriver
   ```

3. Add sockpuppet account:
   ```bash
   ./scripts/automated-sock-maintenance.sh add \
       twitter \
       "john_doe123" \
       "john@example.com" \
       "password123" \
       "tech_enthusiast"
   ```

4. List sockpuppets:
   ```bash
   ./scripts/automated-sock-maintenance.sh list
   ```

5. Test maintenance:
   ```bash
   ./scripts/automated-sock-maintenance.sh maintain john_doe123
   ```

**Optional: Add proxies** (`data/proxies.txt`):
```
socks5://proxy1.example.com:1080
socks5://proxy2.example.com:1080
http://proxy3.example.com:8080
```

**Cron Setup** (3am daily):
```cron
0 3 * * * /path/to/scripts/automated-sock-maintenance.sh maintain-all
```

---

### Coffee Shop Lockdown

**Setup Steps:**

1. Configure VPN (OpenVPN example):
   ```bash
   # Place your .ovpn config at:
   ~/.config/openvpn/client.ovpn

   # Or set custom path in config.sh:
   OPENVPN_CONFIG="/path/to/config.ovpn"
   ```

2. Add trusted networks:
   ```bash
   # Connect to your home WiFi, then:
   ./scripts/coffee-shop-lockdown.sh trust
   ```

3. Test lockdown (dry run):
   ```bash
   DRY_RUN=1 ./scripts/coffee-shop-lockdown.sh test
   ```

4. Start monitoring:
   ```bash
   ./scripts/coffee-shop-lockdown.sh monitor &
   ```

**Systemd Service** (auto-start on boot):
```bash
# Run during installation:
sudo ./install.sh  # Choose systemd setup

# Or manually:
sudo systemctl enable coffee-shop-lockdown
sudo systemctl start coffee-shop-lockdown
```

---

## Troubleshooting

### Common Issues

#### "jq: command not found"
```bash
# Install jq
sudo apt install jq  # Ubuntu/Debian
brew install jq      # macOS
```

#### "Permission denied" when running scripts
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

#### "VPN check fails but VPN is running"
The script looks for common VPN interfaces (tun0, wg0, utun). If you use a different VPN:

1. Check your VPN interface: `ip link show`
2. Edit `lib/common.sh` and add your interface to `check_vpn()` function

#### "Chrome driver not found"
```bash
# Check if installed
which chromedriver

# If not found, install:
sudo apt install chromium-chromedriver  # Linux
brew install chromedriver               # macOS

# Or download manually:
https://chromedriver.chromium.org/downloads
```

#### "API rate limit exceeded"
The scripts have built-in rate limiting. If you hit external API limits:

1. Check your API quota
2. Reduce frequency in cron jobs
3. Use caching (already implemented)

#### "Notification not showing"
```bash
# Linux - check if notify-send works
notify-send "Test" "Test notification"

# If not working, install:
sudo apt install libnotify-bin

# macOS - notifications should work out of the box
```

### Script-Specific Issues

#### Meeting Prep: "No calendar events found"
```bash
# Test calendar access
gcalcli list

# If authentication fails:
rm ~/.gcalcli_oauth
gcalcli init
```

#### OPSEC Check: "DNS leak detected" (false positive)
Your DNS might be going through VPN but showing public resolver. Edit config:
```bash
# Add your VPN DNS to allowed list
ALLOWED_DNS=("10.8.0.1" "your_vpn_dns_here")
```

#### Sock Maintenance: "Selenium timeout"
Increase timeouts or disable headless mode for debugging:
```bash
# Run without headless to see what's happening
./scripts/automated-sock-maintenance.sh --no-headless maintain username
```

---

## Security Best Practices

1. **Encrypt your data directory**:
   ```bash
   # The scripts use encrypted storage, but you can also:
   sudo cryptsetup luksFormat /dev/sdX
   ```

2. **Restrict file permissions**:
   ```bash
   chmod 700 ~/zero-trust-lifestyle/data
   chmod 600 ~/zero-trust-lifestyle/config/config.sh
   ```

3. **Use strong encryption password** in config.sh

4. **Audit logs regularly**:
   ```bash
   cat ~/zero-trust-lifestyle/logs/*.log
   ```

5. **Keep API keys in environment variables** instead of config file (optional):
   ```bash
   export GITHUB_TOKEN="ghp_xxxx"
   export TWITTER_BEARER_TOKEN="xxxx"
   ```

---

## Advanced Configuration

### Custom Alerts

Add custom alert methods in `config.sh`:

```bash
# Custom webhook
ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Email alerts
ALERT_EMAIL="your@email.com"
```

### Proxy Configuration

For sockpuppet maintenance with proxies:

```bash
# Add proxies to data/proxies.txt
echo "socks5://proxy.example.com:1080" >> data/proxies.txt

# Enable proxy usage
USE_PROXY=1
```

### Custom Personas

Edit `automated-sock-maintenance.sh` to add custom persona interests:

```bash
# Add to get_persona_interests() function
activist)
    echo "politics,activism,social_justice,equality,climate"
    ;;
```

---

## Getting Help

- **Documentation**: Read README.md and all scripts have `--help` flag
- **Issues**: https://github.com/gl0bal01/zero-trust-lifestyle/issues
- **Logs**: Check `logs/` directory for detailed error messages
- **Verbose mode**: Run with `VERBOSE=1 ./script.sh`

---

## Next Steps

Once setup is complete:

1. ✅ Test each script individually
2. ✅ Set up cron jobs for automation
3. ✅ Configure systemd services (optional)
4. ✅ Add API keys for OSINT features
5. ✅ Customize personas and preferences
6. ✅ Set up monitoring dashboards

Enjoy your automated paranoia! 🔒

---

## Required: Encryption Password

Scripts that store secrets (sockpuppet credentials, tokens, etc.) use
`ENCRYPTION_PASSWORD` to derive the AES-256 key for `data/.secrets.enc`.
Set it in `config/config.sh`:

```bash
export ENCRYPTION_PASSWORD="$(openssl rand -base64 48)"
```

- Minimum 32 random characters.
- **Losing this value means losing access to everything in `data/.secrets.enc`.**
  Back it up in a password manager — not in this repo.
- Never commit the real value. `config/config.sh` is `.gitignore`d.
- Previous versions fell back to `/etc/machine-id` when this was unset. That
  fallback was removed: `machine-id` is mode 0444 (world-readable), which
  meant any local user could decrypt `data/.secrets.enc`.

## Config File Permissions

`config/config.sh` is `source`d by every script. `lib/common.sh` now refuses
to source the file if:

- it is owned by a user other than you (or root), or
- it has the group-write or other-write bit set.

`install.sh` will `chmod 600` the file for you. If you hit a `REFUSING to
source` error, run:

```bash
chmod 600 config/config.sh
```

## Log Rotation

Each script writes to `logs/<name>_YYYYMMDD.log`. Nothing rotates these
automatically. Add a weekly cleanup to cron:

```cron
0 4 * * 0 find /path/to/zero-trust-lifestyle/logs -type f -name '*.log' -mtime +30 -delete
```

Adjust `-mtime +30` to suit your retention policy.
