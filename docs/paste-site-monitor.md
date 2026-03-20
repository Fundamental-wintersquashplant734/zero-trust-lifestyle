# Paste Site Monitor

Monitor Pastebin/GitHub Gists for leaked credentials and company data.

## Overview

Automated monitoring system for paste sites (Pastebin, GitHub Gists) that continuously scans for leaked credentials, company data, API keys, and sensitive information. Features customizable watch lists with keywords, domains, email addresses, and regex patterns. Automatic archiving of matches, real-time alerts, and comprehensive finding management. "Found our prod database credentials on pastebin. Again."

## Features

- Multi-platform monitoring (Pastebin, GitHub Gists, more coming)
- Customizable watch lists (keywords, domains, emails, patterns)
- Regex pattern support for complex matching
- Automatic paste archiving
- Real-time desktop alerts
- Seen paste tracking (avoid duplicates)
- Rate limiting protection
- Findings export (CSV)
- Review workflow
- 1-hour caching
- Continuous monitoring mode

## Installation

```bash
chmod +x scripts/paste-site-monitor.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - API requests
- `md5sum` or `md5` - Hash generation
- `grep` - Pattern matching

## API Keys

### Pastebin (Required for Pastebin monitoring)
Get API key: https://pastebin.com/doc_scraping_api

```bash
export PASTEBIN_API_KEY="your_key_here"
```

### GitHub (Optional, increases rate limits)
Get token: https://github.com/settings/tokens

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Usage

### Setup Watch List

```bash
# Add company keywords
./scripts/paste-site-monitor.sh add-keyword "company-name"
./scripts/paste-site-monitor.sh add-keyword "product-name"
./scripts/paste-site-monitor.sh add-keyword "internal-codename"

# Add domains to watch
./scripts/paste-site-monitor.sh add-domain "company.com"
./scripts/paste-site-monitor.sh add-domain "staging.company.com"
./scripts/paste-site-monitor.sh add-domain "api.company.com"

# Add email addresses
./scripts/paste-site-monitor.sh add-email "admin@company.com"
./scripts/paste-site-monitor.sh add-email "support@company.com"

# Add regex patterns (API keys, credentials)
./scripts/paste-site-monitor.sh add-pattern "api[_-]key.*[A-Za-z0-9]{32}"
./scripts/paste-site-monitor.sh add-pattern "sk_live_[A-Za-z0-9]{24}"
./scripts/paste-site-monitor.sh add-pattern "mongodb\+srv://.*"
```

### View Watch List

```bash
./scripts/paste-site-monitor.sh list

# Output:
# 👁️  Watch List
#
# Keywords:
#   • company-name
#   • product-name
#   • internal-codename
#
# Domains:
#   • company.com
#   • api.company.com
#
# Email Addresses:
#   • admin@company.com
#
# Regex Patterns:
#   • api[_-]key.*[A-Za-z0-9]{32}
```

### Run Single Scan

```bash
# Scan all enabled paste sites once
./scripts/paste-site-monitor.sh scan

# Output:
# Scanning Pastebin...
# Checked 100 pastes, found 2 matches
# Scanning GitHub Gists...
# Checked 100 gists, found 1 match
```

### Start Continuous Monitoring

```bash
# Monitor continuously (checks every 15 minutes)
./scripts/paste-site-monitor.sh monitor

# Custom check interval (seconds)
./scripts/paste-site-monitor.sh --interval 600 monitor
```

### View Findings

```bash
# Show all findings
./scripts/paste-site-monitor.sh findings

# Output:
# 🚨 Leak Findings
#
# Total findings: 15
# Unreviewed: 8
#
# Recent findings:
# [2025-12-05T14:23:00Z] https://pastebin.com/abc123
#   Matches: keyword:company-name, domain:company.com
#   Archived: true, Reviewed: false
```

### Mark as Reviewed

```bash
# After investigating a finding
./scripts/paste-site-monitor.sh review abc123
```

### Export Findings

```bash
# Export to CSV
./scripts/paste-site-monitor.sh export leaks_report.csv

# Output:
# Exported 15 findings to leaks_report.csv
```

## Commands

| Command | Description |
|---------|-------------|
| `scan` | Run single scan cycle |
| `monitor` | Start continuous monitoring |
| `findings` | Show all findings |
| `add-keyword KEYWORD` | Add keyword to watch |
| `add-domain DOMAIN` | Add domain to watch |
| `add-email EMAIL` | Add email to watch |
| `add-pattern PATTERN` | Add regex pattern to watch |
| `list` | List watch items |
| `review PASTE_ID` | Mark finding as reviewed |
| `export [FILE]` | Export findings to CSV |

## Options

| Option | Description |
|--------|-------------|
| `--interval SECONDS` | Check interval (default: 900) |
| `--no-alert` | Don't send alerts on match |
| `--no-archive` | Don't auto-archive matches |

## Monitored Platforms

### Pastebin (Requires API Key)
- Access to scraping API
- 100 most recent pastes
- Rate limited
- Fast detection

### GitHub Gists
- Public gists only
- 100 most recent
- Higher rate limits with token
- Developer credentials often leaked here

### Future Platforms
- Pastebin.com archive
- Slexy.org
- Ghostbin
- dpaste
- 0bin

## Detection Algorithm

### For Each New Paste

1. **Check if Already Seen**
   ```bash
   # Skip if paste ID in seen_pastes.txt
   # Prevents duplicate processing
   ```

2. **Fetch Content**
   ```bash
   # Download full paste content
   # Rate limiting applied
   ```

3. **Match Against Watch List**
   ```bash
   # Check all keywords (case-insensitive)
   # Check all domains
   # Check all email addresses (exact match)
   # Check all regex patterns
   ```

4. **Record Finding**
   ```bash
   # Save to findings database
   # Record all matches
   # Mark as unreviewed
   ```

5. **Archive Content**
   ```bash
   # Download and save paste content
   # Store in archived_pastes/
   # Evidence preservation
   ```

6. **Send Alert**
   ```bash
   # Desktop notification
   # Show matches
   # Include paste URL
   ```

7. **Mark as Seen**
   ```bash
   # Add to seen_pastes.txt
   # Prevent future reprocessing
   ```

## Example Workflow

```bash
# 1. Initial setup
./scripts/paste-site-monitor.sh add-keyword "acme-corp"
./scripts/paste-site-monitor.sh add-domain "acme.com"
./scripts/paste-site-monitor.sh add-email "admin@acme.com"

# Add common credential patterns
./scripts/paste-site-monitor.sh add-pattern "password.*[:=].*"
./scripts/paste-site-monitor.sh add-pattern "api[_-]?key.*[:=].*"
./scripts/paste-site-monitor.sh add-pattern "secret.*[:=].*"

# 2. Test with single scan
./scripts/paste-site-monitor.sh scan

# 3. Review watch list
./scripts/paste-site-monitor.sh list

# 4. Start continuous monitoring
./scripts/paste-site-monitor.sh monitor

# Output:
# Starting paste site monitor (Ctrl+C to stop)...
# Check interval: 15 minutes
# === Starting scan cycle at Thu Dec  5 14:30:00 2025 ===
# Scanning Pastebin...
# Checked 100 pastes, found 0 matches
# Scanning GitHub Gists...
# Checked 100 gists, found 1 match
# Found leak: https://gist.github.com/abc123
# Matches: keyword:acme-corp domain:acme.com
# Archived to: .../archived_pastes/abc123_20251205_143045.txt
# Scan cycle complete. Sleeping for 15 minutes...

# 5. When alert received, check findings
./scripts/paste-site-monitor.sh findings

# 6. View archived content
cat $DATA_DIR/archived_pastes/abc123_20251205_143045.txt

# 7. Mark as reviewed after investigation
./scripts/paste-site-monitor.sh review abc123

# 8. Weekly export for records
./scripts/paste-site-monitor.sh export weekly_report_$(date +%Y%m%d).csv
```

## Watch List Patterns

### Keywords
Best for:
- Company names
- Product names
- Project codenames
- Internal terminology

Example:
```bash
./scripts/paste-site-monitor.sh add-keyword "operation-titan"
```

### Domains
Best for:
- Company domains
- Staging/dev environments
- API endpoints
- Internal domains

Example:
```bash
./scripts/paste-site-monitor.sh add-domain "internal.company.com"
```

### Email Addresses
Best for:
- Admin accounts
- Service accounts
- Executive emails
- Support emails

Example:
```bash
./scripts/paste-site-monitor.sh add-email "root@company.com"
```

### Regex Patterns
Best for:
- API key formats
- Credential patterns
- Database connection strings
- Custom sensitive data

Examples:
```bash
# AWS keys
./scripts/paste-site-monitor.sh add-pattern "AKIA[0-9A-Z]{16}"

# Stripe keys
./scripts/paste-site-monitor.sh add-pattern "sk_(test|live)_[0-9a-zA-Z]{24,}"

# Generic API keys
./scripts/paste-site-monitor.sh add-pattern "[Aa]pi[_-]?[Kk]ey.*[0-9a-f]{32,}"

# Database URLs
./scripts/paste-site-monitor.sh add-pattern "mongodb(\+srv)?://.*@.*"
./scripts/paste-site-monitor.sh add-pattern "postgres://.*:.*@.*"

# Private keys
./scripts/paste-site-monitor.sh add-pattern "-----BEGIN.*PRIVATE KEY-----"

# JWT tokens
./scripts/paste-site-monitor.sh add-pattern "eyJ[A-Za-z0-9-_]+\\.eyJ[A-Za-z0-9-_]+\\."
```

## Alert System

When a match is found:

### Desktop Notification
```bash
# Title: "Paste Leak Detected!"
# Body: URL + Matches
# Priority: Critical
```

### Log Entry
```bash
# Console output
log_success "Found leak: https://pastebin.com/abc123"
echo "Matches: keyword:company-name domain:company.com"
```

### Finding Record
```json
{
  "timestamp": "2025-12-05T14:30:45Z",
  "paste_id": "abc123",
  "url": "https://pastebin.com/abc123",
  "matches": [
    "keyword:company-name",
    "domain:company.com"
  ],
  "archived": true,
  "reviewed": false
}
```

## Automation

### Systemd Service (Linux)

```ini
# /etc/systemd/system/paste-monitor.service
[Unit]
Description=Paste Site Monitor
After=network.target

[Service]
Type=simple
User=%i
Environment="PASTEBIN_API_KEY=your_key"
Environment="GITHUB_TOKEN=your_token"
ExecStart=/path/to/paste-site-monitor.sh monitor
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable paste-monitor.service
sudo systemctl start paste-monitor.service
```

### Cron (Alternative)

```bash
# Run every 15 minutes
*/15 * * * * /path/to/paste-site-monitor.sh scan
```

### Docker

```dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl jq
COPY paste-site-monitor.sh /usr/local/bin/
ENV PASTEBIN_API_KEY=""
ENV GITHUB_TOKEN=""
CMD ["/usr/local/bin/paste-site-monitor.sh", "monitor"]
```

## Configuration

### Rate Limiting

```bash
REQUEST_DELAY=6              # Seconds between requests
REQUESTS_PER_MINUTE=10       # Maximum requests per minute
```

### Monitoring Settings

```bash
CHECK_INTERVAL=900           # 15 minutes between scans
ALERT_ON_MATCH=1             # Send desktop notifications
AUTO_ARCHIVE=1               # Automatically archive findings
```

### Platform Toggles

```bash
ENABLE_PASTEBIN=1            # Monitor Pastebin
ENABLE_GITHUB_GISTS=1        # Monitor GitHub Gists
ENABLE_PASTEBINCOM=1         # Monitor Pastebin.com
```

## Data Storage

All data in `$DATA_DIR`:
```
paste_watch_list.json         # Watch list configuration
paste_findings.json           # All findings
seen_pastes.txt               # Processed paste IDs
archived_pastes/              # Downloaded paste content
  abc123_20251205_143045.txt
  def456_20251205_150022.txt
```

## Best Practices

1. **Start with High-Value Keywords**
   ```bash
   # Company name, main products
   # High-risk domains (admin, api, staging)
   # Critical email addresses
   ```

2. **Use Specific Patterns**
   ```bash
   # Don't use: add-keyword "api"
   # Too generic, many false positives
   # Better: add-pattern "api[_-]key.*company.*"
   ```

3. **Review Findings Promptly**
   ```bash
   # Check findings daily
   # Investigate immediately
   # Mark as reviewed
   ```

4. **Maintain Watch List**
   ```bash
   # Add new products/domains
   # Remove defunct patterns
   # Update regex patterns
   ```

5. **Archive Everything**
   ```bash
   # Paste sites delete content
   # Original evidence crucial
   # Keep archives indefinitely
   ```

6. **Rotate API Keys Regularly**
   ```bash
   # If credentials found, rotate immediately
   # Document in incident response
   # Update all systems
   ```

## Response to Findings

When credentials are found:

1. **Verify Authenticity**
   - Check if credentials are real
   - Test in safe environment
   - Confirm scope of exposure

2. **Immediate Rotation**
   - Rotate leaked credentials
   - Revoke API keys
   - Update all affected systems

3. **Impact Assessment**
   - What was accessed?
   - Duration of exposure
   - Potential damage

4. **Incident Documentation**
   - Record finding details
   - Document response actions
   - Update security procedures

5. **Preventive Measures**
   - How did leak occur?
   - Implement git-secret-scanner
   - Security awareness training

## Troubleshooting

### No Pastes Found

```bash
# Check API key
echo $PASTEBIN_API_KEY

# Test API directly
curl "https://scrape.pastebin.com/api_scraping.php?limit=10"

# Verify rate limits not exceeded
```

### Too Many False Positives

```bash
# Make patterns more specific
# Bad: add-keyword "api"
# Good: add-keyword "company-api-v2"

# Use anchored regex
./scripts/paste-site-monitor.sh add-pattern "^api[_-]key.*company.*"
```

### Rate Limited

```bash
# Increase REQUEST_DELAY
REQUEST_DELAY=10

# Reduce CHECK_INTERVAL
CHECK_INTERVAL=1800  # 30 minutes

# Use API tokens for higher limits
export GITHUB_TOKEN="ghp_..."
```

### Missing Findings

```bash
# Check watch list
./scripts/paste-site-monitor.sh list

# Verify patterns match
# Test regex: echo "api_key=abc123" | grep -E "pattern"

# Check if paste already seen
grep "paste_id" $DATA_DIR/seen_pastes.txt
```

## CSV Export Format

```csv
Timestamp,Paste ID,URL,Matches,Archived,Reviewed
2025-12-05T14:30:45Z,abc123,https://pastebin.com/abc123,keyword:company;domain:company.com,true,false
2025-12-05T15:45:22Z,def456,https://gist.github.com/def456,email:admin@company.com,true,true
```

## Security Considerations

- API keys stored in environment (not in code)
- Archived pastes contain sensitive data (protect directory)
- Findings database has leak details (encrypt at rest)
- Rate limiting prevents API abuse
- Seen pastes prevent re-alerting

## Related Scripts

- `git-secret-scanner.sh` - Prevent committing secrets
- `data-breach-stalker.sh` - Monitor Have I Been Pwned
- `canary-token-generator.sh` - Generate honeytokens
- `opsec-paranoia-check.sh` - Overall OPSEC validation
