# Passive-Aggressive Emailer

Sentiment analysis on outgoing emails. Delays angry/passive-aggressive emails to prevent career damage.

## Overview

Email sentiment analysis and quarantine system that scans outgoing emails for passive-aggressive phrases, aggressive language, profanity, and other career-damaging patterns. Calculates an "anger score" (0-100) and automatically quarantines high-risk emails for review after a cooling-off period. Prevents late-night rage emails, protects you from passive-aggressive communication patterns, and saves careers one delayed email at a time.

## Features

- Comprehensive sentiment analysis (0-100 anger score)
- 19 passive-aggressive phrase detections
- 14 aggressive pattern matchers
- Profanity detection
- CAPS ratio analysis
- Exclamation mark counting
- Late-night email warnings
- Executive recipient detection
- Email quarantine system with time delay
- Configurable cooling-off periods
- Daemon mode for automatic checking
- Integration with mail clients (sendmail, msmtp)

## Installation

```bash
chmod +x scripts/passive-aggressive-emailer.sh
```

## Dependencies

- `jq` - JSON processing
- `sendmail` or `msmtp` - Email sending (for integration)
- `grep`, `awk`, `sed` - Text processing

## Usage

### Analyze Single Email

```bash
# Analyze email file
./scripts/passive-aggressive-emailer.sh /tmp/outgoing_email.eml

# Show anger score only
./scripts/passive-aggressive-emailer.sh --score email.eml

# Force send even if angry
./scripts/passive-aggressive-emailer.sh --force email.eml
```

### Run Quarantine Daemon

```bash
# Start background daemon
./scripts/passive-aggressive-emailer.sh --daemon &

# Check quarantine for releasable emails
./scripts/passive-aggressive-emailer.sh --check
```

### Mail Client Integration

**With msmtp** (~/.msmtprc):
```ini
sendmail_path = /path/to/passive-aggressive-emailer.sh
```

**With mutt** (~/.muttrc):
```
set sendmail = "/path/to/passive-aggressive-emailer.sh"
```

## Commands

| Command | Description |
|---------|-------------|
| `[EMAIL_FILE]` | Analyze email file |
| `--score FILE` | Show anger score only (don't send) |
| `--force` | Force send even if angry (bypass quarantine) |
| `--daemon` | Run as daemon to check quarantine |
| `--check` | Check quarantine for releasable emails |

## Anger Score Algorithm

### Scoring Components (0-100 scale)

**CAPS Analysis (0-25 points)**
- >20% CAPS: +25 points
- >10% CAPS: +15 points
- >5% CAPS: +5 points

**Exclamation Marks (0-15 points)**
- >5 exclamation marks: +15 points
- >2 exclamation marks: +8 points
- >0 exclamation marks: +3 points

**Passive-Aggressive Phrases (0-20 points)**
- Each phrase detected: +5 points
- Cumulative scoring

**Aggressive Language (0-25 points)**
- Each aggressive phrase: +8 points
- Cumulative scoring

**Profanity (0-20 points)**
- Each profane word: +10 points
- Cumulative scoring

**Late Night Bonus (+10 points)**
- Sent between 10 PM - 5 AM

**Executive Recipient Bonus (+15 points)**
- Sent to CEO, CTO, VP, Director, etc.

**Total Score: Capped at 100**

### Anger Thresholds

- **0-54**: Safe to send (low/medium anger)
- **55-74**: Warning shown, user confirmation required
- **75-100**: Automatic quarantine

Default quarantine threshold: 75

## Passive-Aggressive Patterns (19 detected)

1. "per my last email"
2. "as I mentioned before"
3. "as previously stated"
4. "just circling back"
5. "gentle reminder"
6. "friendly reminder"
7. "not sure if you saw"
8. "did you get a chance"
9. "when you get a chance"
10. "thanks in advance"
11. "at your earliest convenience"
12. "going forward"
13. "moving forward"
14. "with all due respect"
15. "I'm just wondering"
16. "I hate to bother you"
17. "sorry to bother you again"
18. "just following up"
19. "bumping this up"

## Aggressive Patterns (14 detected)

1. "THIS IS UNACCEPTABLE"
2. "ABSOLUTELY"
3. "NEVER"
4. "ALWAYS"
5. "obviously"
6. "clearly"
7. "seriously?"
8. "are you kidding"
9. "this is ridiculous"
10. "what were you thinking"
11. "I can't believe"
12. "disappointed"
13. "frustrated"
14. "unprofessional"

## Profanity Detection (8 patterns)

Basic profanity detection (mild):
- Common swear words
- Professional context violations
- Word boundary matching

## Example Analysis

### Low Anger Email (Score: 15)

```
To: colleague@company.com
Subject: Quick question

Hi Sarah,

Hope you're doing well! I had a quick question about the API documentation.

Could you point me to the latest version when you have a moment?

Thanks,
John
```

**Analysis:**
```
📧 Email Sentiment Analysis
To: colleague@company.com
Subject: Quick question
Anger Score: 15/100

✓ Email passed sentiment analysis
```

### Medium Anger Email (Score: 58)

```
To: team@company.com
Subject: Following up AGAIN

Hi team,

Per my last email, I'm just circling back on this.

As I mentioned before, we need this done ASAP!!

Thanks in advance for your immediate attention.
```

**Analysis:**
```
📧 Email Sentiment Analysis
To: team@company.com
Subject: Following up AGAIN
Anger Score: 58/100

⚠️  Issues Detected:
😬 3 passive-aggressive phrases detected
🔠 15% ALL CAPS - looks like you're shouting

⚠️  High anger score - are you sure?
Send this email anyway? (yes/no):
```

### High Anger Email (Score: 87)

```
To: ceo@company.com
Subject: THIS IS UNACCEPTABLE

I CAN'T BELIEVE THIS HAPPENED AGAIN!!!

As I've said MULTIPLE times before, this is RIDICULOUS and COMPLETELY UNACCEPTABLE.

What were you thinking??? This is clearly incompetent.

Seriously frustrated,
John
```

**Analysis:**
```
📧 Email Sentiment Analysis
To: ceo@company.com
Subject: THIS IS UNACCEPTABLE
Anger Score: 87/100

⚠️  Issues Detected:
🔠 42% ALL CAPS - looks like you're shouting
😬 4 passive-aggressive phrases detected
😠 6 aggressive phrases found
🌙 It's 23:47 - late night emails are rarely a good idea

🚨 ANGER THRESHOLD EXCEEDED (87 >= 75)
📦 Email will be quarantined for 60 minutes

Email quarantined: /home/user/.local/share/zero-trust-lifestyle/email-quarantine/1733429847_a3f8c2e1.eml
```

## Quarantine System

### How It Works

1. **Email Analyzed**: Anger score calculated
2. **Threshold Exceeded**: Score >= 75
3. **Quarantine Created**: Email saved with metadata
4. **Cooling Period**: Default 60 minutes
5. **Release Time**: Email ready for review
6. **User Review**: Show email, ask confirmation
7. **Send or Cancel**: User decides final action

### Quarantine Files

```bash
# Location
$DATA_DIR/email-quarantine/

# Files created
1733429847_a3f8c2e1.eml        # Email content
1733429847_a3f8c2e1.eml.meta   # Metadata (JSON)
```

### Metadata Format

```json
{
  "quarantined_at": "2025-12-05T23:47:27+00:00",
  "release_at": "2025-12-06T00:47:27+00:00",
  "anger_score": 87,
  "original_file": "/tmp/outgoing_email.eml"
}
```

## Configuration

### Quarantine Settings

```bash
DELAY_MINUTES=60              # Cooling-off period
MAX_SCORE=75                  # Quarantine threshold
FORCE_MODE=0                  # Bypass quarantine
```

### Detection Patterns

Edit arrays in script:
```bash
PASSIVE_AGGRESSIVE_PATTERNS=( ... )
AGGRESSIVE_PATTERNS=( ... )
SWEAR_PATTERNS=( ... )
EXECUTIVE_KEYWORDS=( ... )
```

## Example Workflows

### Standalone Analysis

```bash
# Write email to file
cat > /tmp/email.eml <<EOF
To: boss@company.com
Subject: Per my last email

As I mentioned before, I need this ASAP!!!

Thanks in advance.
EOF

# Analyze
./scripts/passive-aggressive-emailer.sh /tmp/email.eml

# Output shows anger score and issues
# User decides whether to send
```

### Integrated with Mail Client

```bash
# Configure msmtp to use script
echo "sendmail_path = /path/to/passive-aggressive-emailer.sh" >> ~/.msmtprc

# Now all emails analyzed automatically
# High-anger emails quarantined
# Safe emails sent immediately
```

### Daemon Mode

```bash
# Start daemon in background
./scripts/passive-aggressive-emailer.sh --daemon &

# Daemon checks quarantine every 60 seconds
# When release time reached:
# - Shows email content
# - Asks for confirmation
# - Sends or cancels

# Check manually anytime
./scripts/passive-aggressive-emailer.sh --check
```

## Best Practices

1. **Always Run Analysis First**
   ```bash
   # Don't bypass the check
   # Let the script save you from yourself
   ```

2. **Respect the Quarantine**
   ```bash
   # When email is quarantined, wait it out
   # Use the time to reconsider
   # Often you'll cancel after cooling off
   ```

3. **Review Pattern Matches**
   ```bash
   # Check what triggered the score
   # Learn your communication patterns
   # Adjust behavior accordingly
   ```

4. **Adjust Threshold for Your Role**
   ```bash
   # IC: MAX_SCORE=75 (default)
   # Manager: MAX_SCORE=70 (more strict)
   # Executive: MAX_SCORE=65 (very strict)
   ```

5. **Never Use --force Impulsively**
   ```bash
   # --force defeats the purpose
   # Only use after genuine consideration
   ```

6. **Check Quarantine Daily**
   ```bash
   # Review quarantined emails
   # Delete the ones you shouldn't send
   # Learn from your patterns
   ```

## Late Night Email Protection

Special handling for 10 PM - 5 AM:

```bash
# Automatic +10 points to anger score
# Warning message displayed
# Higher likelihood of quarantine
```

Rationale:
- Tired decision-making
- Emotional exhaustion
- Next-day regret common
- Poor professional judgment

## Executive Recipient Protection

Extra caution when emailing leadership:

```bash
# Auto-detect: CEO, CTO, VP, Director, Board
# +15 points to anger score
# Earlier quarantine trigger
# Career damage prevention
```

## Troubleshooting

### Email Not Being Analyzed

```bash
# Check mail client integration
msmtp --version

# Verify sendmail_path
grep sendmail_path ~/.msmtprc

# Test manually
./scripts/passive-aggressive-emailer.sh /tmp/test.eml
```

### Quarantine Not Working

```bash
# Check quarantine directory
ls -la $DATA_DIR/email-quarantine/

# Verify daemon running
ps aux | grep passive-aggressive-emailer

# Check permissions
chmod +x passive-aggressive-emailer.sh
```

### False Positives

```bash
# Adjust MAX_SCORE threshold
MAX_SCORE=85  # Less sensitive

# Remove specific patterns
# Edit PASSIVE_AGGRESSIVE_PATTERNS array
```

### Can't Send Any Emails

```bash
# Check if FORCE_MODE accidentally enabled
grep FORCE_MODE passive-aggressive-emailer.sh

# Temporarily bypass
./scripts/passive-aggressive-emailer.sh --force email.eml

# Or disable entirely
FORCE_MODE=1
```

## Data Storage

All data in `$DATA_DIR`:
```
email-quarantine/              # Quarantined emails
  *.eml                        # Email content
  *.eml.meta                   # Metadata
```

## Advanced Features

### Custom Pattern Addition

```bash
# Add your own passive-aggressive phrases
PASSIVE_AGGRESSIVE_PATTERNS+=(
    "just a heads up"
    "wanted to touch base"
    "circling back around"
)

# Add your industry-specific patterns
AGGRESSIVE_PATTERNS+=(
    "this is a disaster"
    "completely wrong"
)
```

### Integration with Grammar Check

```bash
# Combine with other email tools
# - Grammar checking (LanguageTool)
# - Spell checking (aspell)
# - Tone analysis (IBM Watson)
```

### Statistics Tracking

Future enhancement ideas:
- Track anger score over time
- Identify triggers
- Show improvement trends
- Hourly anger patterns

## Why This Exists

Email is permanent. Once sent, you can't take it back.

Common scenarios prevented:
- Late-night angry responses
- Passive-aggressive professional communication
- Career-damaging executive emails
- Emotional reactions during stressful times
- Friday evening rage emails

The 60-minute cooling period often results in:
- Canceling the email entirely
- Complete rewrite with better tone
- Realizing you were overreacting
- More productive communication

## Related Scripts

- `meeting-excuse-generator.sh` - Professional meeting declination
- `slack-auto-responder.sh` - Automated professional responses
- `focus-mode-nuclear.sh` - Eliminate distractions
