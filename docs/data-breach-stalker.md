# Data Breach Stalker

Track your identities in data breaches and get instant alerts with Have I Been Pwned integration and encrypted local storage.

## Overview

Monitors email addresses, usernames, and other identities for exposure in data breaches. Integrates with Have I Been Pwned (HIBP) for 800+ million compromised accounts. Checks passwords against 600+ million pwned passwords using k-anonymity. Features encrypted storage, automated monitoring, breach analysis with severity assessment, and comprehensive reporting.

## Features

- Have I Been Pwned (HIBP) integration
- Pwned Passwords checker (k-anonymity, privacy-preserving)
- Encrypted identity storage
- Automated breach monitoring
- Severity analysis (passwords, financial data, sensitive info)
- Breach history tracking
- Email/desktop alerts on new breaches
- Password compromise checking
- Support for multiple identity types
- Privacy-first design (all data local)

## Installation

```bash
chmod +x scripts/data-breach-stalker.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - HTTP requests
- `openssl` - Encryption
- `shasum` - Password hashing

## Usage

### Add Identity to Monitor

```bash
./scripts/data-breach-stalker.sh add TYPE VALUE [DESCRIPTION]

# Examples
./scripts/data-breach-stalker.sh add email "you@example.com"
./scripts/data-breach-stalker.sh add email "work@company.com" "Work email"
./scripts/data-breach-stalker.sh add username "myusername123"
```

### Check for Breaches

```bash
# Check all identities
./scripts/data-breach-stalker.sh check

# Check specific identity
./scripts/data-breach-stalker.sh check "you@example.com"
```

### Check if Password is Compromised

```bash
./scripts/data-breach-stalker.sh check-password
# Enter password (input hidden)
# Uses k-anonymity - only partial hash sent
```

### List Tracked Identities

```bash
./scripts/data-breach-stalker.sh list
```

### View Breach Report

```bash
./scripts/data-breach-stalker.sh report
```

### Start Continuous Monitoring

```bash
./scripts/data-breach-stalker.sh monitor
# Checks every hour by default
```

### Remove Identity

```bash
./scripts/data-breach-stalker.sh remove "email@example.com"
```

### Export Report

```bash
./scripts/data-breach-stalker.sh export breach_report_2024.json
```

## Commands

| Command | Description |
|---------|-------------|
| `add TYPE VALUE [DESC]` | Add identity to track |
| `remove VALUE` | Remove identity |
| `list` | List tracked identities |
| `check [VALUE]` | Check for breaches (all or specific) |
| `monitor` | Start continuous monitoring |
| `report` | Show breach report |
| `export [FILE]` | Export report to JSON |
| `check-password` | Check if password is compromised |

## Identity Types

- `email` - Email addresses (primary supported type)
- `username` - Usernames (requires paid API)
- `phone` - Phone numbers (requires paid API)
- `domain` - Domain names (requires paid API)

## Options

| Option | Description |
|--------|-------------|
| `--interval SECONDS` | Check interval for monitor mode (default: 3600) |
| `--no-alert` | Don't send alerts on new breaches |

## Example Workflows

### 1. Initial Setup

```bash
# Add your email addresses
./scripts/data-breach-stalker.sh add email "personal@gmail.com" "Personal email"
./scripts/data-breach-stalker.sh add email "work@company.com" "Work email"
./scripts/data-breach-stalker.sh add email "old@yahoo.com" "Old email"

# Check immediately
./scripts/data-breach-stalker.sh check
```

### 2. Password Audit

```bash
# Check passwords one at a time (interactive prompt, input hidden)
./scripts/data-breach-stalker.sh check-password
# Repeat for each password you want to check
```

### 3. Automated Monitoring

```bash
# Add to crontab - check every hour
0 * * * * /path/to/data-breach-stalker.sh check

# Or run continuous monitor
./scripts/data-breach-stalker.sh monitor &
```

### 4. Breach Response

```bash
# Check for new breaches
./scripts/data-breach-stalker.sh check

# View detailed report
./scripts/data-breach-stalker.sh report

# Export for documentation
./scripts/data-breach-stalker.sh export breach_report.json

# Change compromised passwords
# Enable 2FA
# Monitor financial accounts
```

## Breach Analysis

### Severity Levels

When breaches are found, script analyzes severity:

**CRITICAL - Passwords Exposed**
```
🔴 CRITICAL: Passwords exposed in N breach(es)
→ Change password immediately!
→ Enable 2FA if not already enabled
```

**CRITICAL - Financial Data**
```
🔴 CRITICAL: Financial data exposed in N breach(es)
→ Monitor bank accounts
→ Consider credit monitoring service
```

**CRITICAL - Sensitive Personal Data**
```
🔴 CRITICAL: Sensitive personal data exposed
→ Consider identity theft protection
→ Monitor credit reports
```

### Breach Details

For each breach, you'll see:
- Breach name (e.g., "Adobe", "LinkedIn")
- Date of breach
- Number of affected accounts
- Types of data leaked (emails, passwords, addresses, etc.)
- Description of the breach

Example output:
```
╔═══════════════════════════════════════════════════════════╗
  Breach: Adobe
  Date: 2013-10-04
  Accounts: 152445165 affected
  Data leaked: Email addresses, Password hints, Passwords, Usernames
  Description: In October 2013, 153 million Adobe accounts were...
╚═══════════════════════════════════════════════════════════╝
```

## Privacy & Security

### Encrypted Storage

All identities stored with AES-256-CBC encryption:
```bash
# Encryption key derived from machine ID
# Identities never stored in plaintext
# Decryption only happens during checks
```

### K-Anonymity for Passwords

Password checking uses k-anonymity:
1. Generates SHA-1 hash of password
2. Sends only first 5 characters to HIBP
3. Receives all hashes starting with those 5 chars
4. Locally matches full hash
5. No full password or hash ever sent to API

Example:
```
Password: "P@ssw0rd"
SHA-1: 21BD12DC183F740EE76F27B78EB39C8AD972A757
Sent to API: "21BD1" (first 5 chars only)
Server returns: All hashes starting with "21BD1"
Local match: Check if full hash in response
```

### No Data Sent to Third Parties

- Identities stored locally (encrypted)
- Only email sent to HIBP for breach check
- Password checks use k-anonymity (partial hash only)
- No telemetry, tracking, or analytics
- HIBP respects privacy (see haveibeenpwned.com/Privacy)

## Configuration

### Set Check Interval

```bash
# Check every 6 hours
./scripts/data-breach-stalker.sh --interval 21600 monitor
```

### Disable Alerts

```bash
./scripts/data-breach-stalker.sh --no-alert check
```

### HIBP API Key (Optional)

Higher rate limits with API key:
```bash
# Get key at: https://haveibeenpwned.com/API/Key
export HIBP_API_KEY="your_api_key_here"
```

Free tier:
- Rate limit: 1 request per 1.5 seconds
- Access to all breach data

Paid tier ($3.50/month):
- Higher rate limits
- API key required for some endpoints

## Data Storage

```
$DATA_DIR/identities.enc            # Encrypted identity database
$DATA_DIR/breach_cache.json         # Temporary cache
$DATA_DIR/breach_history.json       # Historical breach checks
$DATA_DIR/last_breach_check.txt     # Last check timestamp
```

## Example Reports

### Breach Report

```
📊 Breach Report

Total checks performed: 15
Last check: 2024-12-05T14:30:00Z

Identity Summary:
personal@gmail.com: 3 breaches (last checked: 2024-12-05T14:30:00Z)
work@company.com: 0 breaches (last checked: 2024-12-05T14:30:00Z)
old@yahoo.com: 12 breaches (last checked: 2024-12-05T14:25:00Z)

Recent Alerts:
  • old@yahoo.com - 12 breaches (2024-12-05T14:25:00Z)
  • personal@gmail.com - 3 breaches (2024-12-05T14:30:00Z)
```

### Detailed Breach Analysis

```
⚠️  BREACHES FOUND: 3

╔═══════════════════════════════════════════════════════════╗
  Breach: LinkedIn
  Date: 2012-05-05
  Accounts: 164611595 affected
  Data leaked: Email addresses, Passwords
  Description: In May 2012, LinkedIn had 6.5 million...
╚═══════════════════════════════════════════════════════════╝

Severity Analysis:
  🔴 CRITICAL: Passwords exposed in 1 breach(es)
     → Change password immediately!
     → Enable 2FA if not already enabled
```

## Automation

### Cron Job

Check every hour:
```bash
0 * * * * /path/to/data-breach-stalker.sh check
```

Daily report:
```bash
0 8 * * * /path/to/data-breach-stalker.sh report | mail -s "Daily Breach Report" you@example.com
```

### Systemd Timer

Create `~/.config/systemd/user/breach-check.service`:
```ini
[Unit]
Description=Check for data breaches

[Service]
Type=oneshot
ExecStart=/path/to/data-breach-stalker.sh check
```

Create `~/.config/systemd/user/breach-check.timer`:
```ini
[Unit]
Description=Hourly breach check

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
systemctl --user enable breach-check.timer
systemctl --user start breach-check.timer
```

## Best Practices

### What to Monitor
1. All email addresses you've ever used
2. Email addresses on important accounts
3. Old/abandoned emails (highest risk)
4. Work emails
5. Usernames for sensitive services

### How Often to Check
- New identities: Immediately
- Regular checks: Weekly or monthly
- Continuous monitoring: Hourly/daily
- After news of major breach: Immediately

### When Breaches Found

1. **Change passwords immediately**
   - Assume all breached passwords are compromised
   - Use unique passwords for each service

2. **Enable 2FA**
   - Adds extra security layer
   - Protects even if password compromised

3. **Monitor accounts**
   - Check for unauthorized access
   - Review login history
   - Check for suspicious activity

4. **Update security questions**
   - If exposed in breach
   - Use fake answers (record them securely)

5. **Consider credit monitoring**
   - If financial/SSN data exposed
   - Check credit reports

6. **Be alert for phishing**
   - Attackers may target breach victims
   - Verify sender before clicking links

## Troubleshooting

### HIBP API Rate Limit

**Issue**: "Rate limit exceeded" or "Too many requests"

**Solutions**:
- Wait 1.5 seconds between checks (automatic)
- Get HIBP API key for higher limits
- Reduce check frequency
- Script already implements rate limiting

### No Breaches Found (But Should Be)

**Issue**: Email should be in breach but shows clean

**Solutions**:
- HIBP may not have all breaches
- Check spelling of email
- Try different email format (with/without dots in Gmail)
- Some breaches not yet added to HIBP
- Very recent breaches may not be indexed yet

### Password Check Always Says "Found"

**Issue**: All passwords show as compromised

**Solutions**:
- Common passwords are often compromised
- Try checking known-unique password
- Verify internet connection
- Check if HIBP API is accessible

## Advanced Usage

### Bulk Import

```bash
# Import list of emails
while IFS= read -r email; do
    ./scripts/data-breach-stalker.sh add email "$email"
done < email_list.txt
```

### Export to CSV

```bash
# Convert JSON report to CSV
./scripts/data-breach-stalker.sh report | \
    jq -r '.identities[] | [.email, .breach_count] | @csv' > report.csv
```

### Alert Integration

Forward alerts to other systems:
```bash
# Modify send_alert function to call webhook
export ALERT_WEBHOOK="https://your-webhook.com/alerts"
```

## Data Sources

### Have I Been Pwned (HIBP)
- 800+ million compromised accounts
- 600+ data breaches indexed
- Regularly updated
- Privacy-focused
- Free API (with rate limits)

### Pwned Passwords
- 600+ million compromised passwords
- SHA-1 hashes
- k-anonymity queries
- No full passwords/hashes sent
- Completely private

## Related Scripts

- `canary-token-generator.sh` - Detect unauthorized access
- `paste-site-monitor.sh` - Monitor Pastebin for leaks
- `delete-me-from-internet.sh` - Remove from data brokers
- `opsec-paranoia-check.sh` - Overall security validation
