# Canary Token Generator

Generate and manage canary tokens to detect unauthorized document access, email opens, credential usage, and data exfiltration attempts.

## Overview

Creates honeytoken tripwires that alert you when accessed. Supports email tracking pixels, PDF/Word documents with web bugs, DNS canaries, fake AWS credentials, and URL tokens. Uses free canarytokens.org service or self-hosted webhook server. Perfect for detecting document leaks, credential theft, insider threats, and unauthorized access.

## Features

- Multiple token types (email, PDF, Word, DNS, AWS, URL)
- Free canarytokens.org integration
- Self-hosted webhook server option
- Email/desktop notifications on trigger
- Trigger history and analytics
- Token management database
- Automatic archival of triggers
- Multiple alert channels

## Installation

```bash
chmod +x scripts/canary-token-generator.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - HTTP requests
- `python3` - Webhook server (optional, for self-hosted)

## Usage

### Quick Interactive Setup

```bash
./scripts/canary-token-generator.sh setup
```

Walks you through creating your first canary token.

### Generate Email Tracking Pixel

```bash
./scripts/canary-token-generator.sh email "Sent to suspect"
```

Returns HTML code to embed in emails. Alerts when email is opened with:
- When it was opened
- IP address of opener
- User agent (email client/browser)
- Approximate location

### Generate PDF Canary

```bash
./scripts/canary-token-generator.sh pdf "Confidential document"
```

Creates a PDF file with hidden web bug that triggers when opened.

### Generate Word Document Canary

```bash
./scripts/canary-token-generator.sh word "Financial report"
```

Creates a .docx file that alerts when opened in Word/LibreOffice.

### Generate DNS Canary

```bash
./scripts/canary-token-generator.sh dns "Config file monitor"
```

Returns a hostname to embed in config files, scripts, or environment variables. Alerts when DNS lookup occurs.

### Generate AWS Credential Canary

```bash
./scripts/canary-token-generator.sh aws "Fake production keys"
```

Generates fake but valid-looking AWS credentials that alert when used.

### Generate URL Canary

```bash
./scripts/canary-token-generator.sh url "Documentation link"
```

Creates a URL that alerts when clicked.

### List All Tokens

```bash
./scripts/canary-token-generator.sh list
```

### View Trigger History

```bash
./scripts/canary-token-generator.sh triggers
```

### Start Self-Hosted Server

```bash
./scripts/canary-token-generator.sh server
```

Runs webhook server on port 8888 to receive self-hosted token triggers.

## Token Types

### Email Tracking Pixel

**Use case**: Know when emails are opened

**How it works**: Embeds 1x1 invisible image in HTML email

**What you learn**:
- When email was opened
- IP address
- User agent (email client)
- Approximate location

**Example**:
```html
<img src="https://canarytokens.org/xxx/image.png" width="1" height="1" style="display:none" />
```

### PDF Canary

**Use case**: Detect when documents are accessed

**How it works**: PDF contains hidden web bug that phones home when opened

**What you learn**:
- Time of access
- IP address
- User agent

**Setup**:
```bash
./scripts/canary-token-generator.sh pdf "Q4 Financial Report"
# Rename to: Q4_Financial_Report.pdf
# Distribute or place in honeypot location
```

### Word Document Canary

**Use case**: Monitor document access

**How it works**: .docx contains hidden web request

**What you learn**:
- When opened
- IP address
- User agent

### DNS Canary

**Use case**: Detect when config files/scripts are read

**How it works**: Unique hostname that alerts on DNS lookup

**Examples**:
```bash
# In bash script
API_HOST=monitoring.canarytokens.com

# In config file
database_host: db.unique-token.canarytokens.com

# In environment variable
export DB_HOST="monitoring-token.canarytokens.com"

# In SQL injection payload
'; SELECT * FROM users WHERE id=1 AND (SELECT load_file('\\\\token.canarytokens.com\\a'))--
```

### AWS Credential Canary

**Use case**: Honeypot cloud credentials

**How it works**: Valid-format but fake AWS keys that alert when API called

**What you learn**:
- When used
- Which AWS service accessed
- Source IP
- User agent

**Examples**:
```bash
# In .env file
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# In credentials file
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### URL Canary

**Use case**: Track link clicks

**How it works**: Unique URL that alerts when accessed

**Examples**:
```markdown
# In README
[Click here for more info](https://canarytokens.org/xxx/click)

# In documentation
<a href="https://canarytokens.org/xxx/click">Documentation</a>

# In error messages
print("Error! See: https://canarytokens.org/xxx/help")
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Interactive token creation wizard |
| `email [DESC]` | Generate email tracking pixel |
| `pdf [DESC]` | Generate PDF with canary |
| `word [DESC]` | Generate Word doc with canary |
| `dns [DESC]` | Generate DNS canary token |
| `aws [DESC]` | Generate AWS credential canary |
| `url [DESC]` | Generate URL canary |
| `list` | List all generated tokens |
| `triggers` | Show trigger history |
| `server` | Start self-hosted webhook server |

## Configuration

### Set Alert Email

Required for canarytokens.org service:

```bash
export ALERT_EMAIL="you@example.com"
```

Or in config file:
```bash
echo 'export ALERT_EMAIL="you@example.com"' >> ~/.bashrc
```

### Self-Hosted Setup

For self-hosted tokens (more privacy):

```bash
# Set your public URL/IP
export PUBLIC_URL="http://your-server.com"

# Start server
./scripts/canary-token-generator.sh server &

# Ensure port 8888 is accessible
sudo ufw allow 8888/tcp
```

## Use Cases

### Document Leak Detection

Place canary PDFs in sensitive directories:
```bash
./scripts/canary-token-generator.sh pdf "Layoff Plan 2024"
mv canary_Layoff_Plan_2024.pdf ~/Documents/HR/Layoff_Plan_2024.pdf
```

If document is accessed/leaked, you get instant alert.

### Email Read Receipts

```bash
./scripts/canary-token-generator.sh email "Executive outreach"
# Embed pixel in important emails
# Know exactly when (and if) they're read
```

### Credential Theft Detection

```bash
./scripts/canary-token-generator.sh aws "Production DB credentials"
# Place in fake .env file
# Alert if credentials are stolen and used
```

### Data Exfiltration Monitoring

Embed DNS canaries in sensitive files:
```bash
./scripts/canary-token-generator.sh dns "Source code exfiltration"
# Add hostname to code comments
# Alerts if code is executed elsewhere
```

### Insider Threat Detection

```bash
# Create honeypot documents
./scripts/canary-token-generator.sh pdf "Executive Compensation Plan"
./scripts/canary-token-generator.sh word "Acquisition Target List"

# Place in shared drives
# Alert if accessed by unauthorized personnel
```

### Configuration File Monitoring

```bash
./scripts/canary-token-generator.sh dns "Config access monitor"
# Add to config files
# Alert when configs are read/deployed
```

## Example Workflows

### 1. Email Campaign Monitoring

```bash
# Generate tracker
./scripts/canary-token-generator.sh email "Investor pitch email"

# Copy HTML code
# Paste in email body
# Send to investors
# Get notified when each investor opens email
```

### 2. Document Honeypot

```bash
# Generate multiple canary docs
./scripts/canary-token-generator.sh pdf "Strategic Plan 2025"
./scripts/canary-token-generator.sh word "Customer List"
./scripts/canary-token-generator.sh pdf "Salary Information"

# Place in predictable locations
mv canary_Strategic_Plan_2025.pdf ~/Dropbox/Private/
mv canary_Customer_List.docx ~/OneDrive/Business/
mv canary_Salary_Information.pdf ~/GoogleDrive/HR/

# Monitor for unauthorized access
```

### 3. Credential Honeypot

```bash
# Generate fake AWS creds
./scripts/canary-token-generator.sh aws "Production environment keys"

# Create fake .env file
cat > ~/projects/.env.backup <<EOF
# Production credentials - DO NOT COMMIT
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
DB_PASSWORD=MySuperSecretPassword123
EOF

# Wait for alert if credentials used
```

### 4. Network Exfiltration Detection

```bash
# Generate DNS canary
./scripts/canary-token-generator.sh dns "Data exfiltration detector"

# Add to source code comments
# api_server = "monitoring.canarytokens.com"  # Production API endpoint

# If code is stolen and run elsewhere, DNS lookup triggers alert
```

## Alert Configuration

### Email Alerts

Automatic via canarytokens.org when you set `ALERT_EMAIL`.

### Desktop Notifications

Uses system notifications (macOS/Linux):
```bash
# Already integrated - triggers show desktop popup
```

### Webhook Integration

Forward to your webhook:
```bash
export ALERT_WEBHOOK="https://your-webhook.com/alerts"
```

### Slack Integration

Use webhook:
```bash
export ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Data Storage

```
$DATA_DIR/canary_tokens.json         # Token database
$DATA_DIR/canary_triggers.json       # Trigger history
$LOG_DIR/webhook_server.log          # Webhook server logs
```

## Security & Privacy

### canarytokens.org
- Free service by Thinkst
- Privacy-focused
- No ads or tracking
- Stores: email for alerts, memo/description
- Does NOT store: document contents, sensitive data

### Self-Hosted
- Complete privacy
- All data stays local
- You control webhook server
- No third-party dependencies

### Best Practices
1. Don't include real sensitive data in canary documents
2. Use descriptive memo/description for tracking
3. Monitor trigger logs regularly
4. Rotate tokens periodically
5. Don't share canary URLs publicly

## Troubleshooting

### Tokens Not Triggering

**Issue**: Created token but no alerts

**Solutions**:
- Verify ALERT_EMAIL is set correctly
- Check spam folder
- Test with simple URL token first
- For self-hosted: ensure server is running and accessible
- Check firewall rules (port 8888)

### Email Pixel Not Working

**Issue**: Email opened but no alert

**Solutions**:
- Email client blocks images (common in Gmail)
- Recipient using text-only email client
- Corporate email filters blocking external images
- Try with different email client

### PDF/Word Canary Not Triggering

**Issue**: Document opened but no alert

**Solutions**:
- PDF reader blocks external connections (security setting)
- Offline document viewer
- Corporate network blocks outbound connections
- Try opening with Adobe Reader/Microsoft Word

### Self-Hosted Server Won't Start

**Issue**: Webhook server fails to start

**Solutions**:
- Check if port 8888 already in use: `lsof -i :8888`
- Ensure Python 3 installed: `python3 --version`
- Check firewall allows port 8888
- Try different port: `WEBHOOK_PORT=9999`

## Advanced Usage

### Custom Token Descriptions

```bash
./scripts/canary-token-generator.sh email "Sent to: John Doe, Re: Q4 Budget, Date: 2024-12-05"
```

Detailed descriptions help identify which token triggered.

### Multiple Alert Channels

Combine email + desktop + webhook:
```bash
export ALERT_EMAIL="security@company.com"
export ALERT_WEBHOOK="https://hooks.slack.com/YOUR_WEBHOOK"
export SEND_NOTIFICATIONS=1
```

### Token Expiration

Track token age and rotate:
```bash
# View all tokens and creation dates
./scripts/canary-token-generator.sh list | grep Created

# Manually remove old tokens from database
$EDITOR $DATA_DIR/canary_tokens.json
```

### Bulk Token Generation

Generate multiple tokens for testing:
```bash
for i in {1..10}; do
    ./scripts/canary-token-generator.sh url "Test token $i"
done
```

## Integration Examples

### With incident Response

```bash
# During incident, check if any tokens triggered
./scripts/canary-token-generator.sh triggers | tail -20
```

### With Monitoring Systems

Parse trigger JSON for SIEM integration:
```bash
cat $DATA_DIR/canary_triggers.json | \
    jq '.triggers[] | select(.timestamp > "2024-12-01")' | \
    # Send to your SIEM
```

### With Automation

```bash
# Auto-alert on trigger
tail -f $LOG_DIR/webhook_server.log | \
    grep TRIGGER | \
    while read line; do
        # Send to incident response system
        curl -X POST https://incident.system/api/alert -d "$line"
    done
```

## Related Scripts

- `data-breach-stalker.sh` - Monitor for credential leaks
- `paste-site-monitor.sh` - Monitor Pastebin for data leaks
- `opsec-paranoia-check.sh` - Overall security validation
