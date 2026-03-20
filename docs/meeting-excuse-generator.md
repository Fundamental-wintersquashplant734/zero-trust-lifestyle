# Meeting Excuse Generator

Auto-decline low-value meetings with plausible professional excuses.

## Overview

Automated meeting evaluation and declination system that analyzes meeting invitations, classifies them by value, and generates professional excuses for low-value meetings. Features intelligent meeting scoring based on title, attendees, duration, and organizer. Includes focus time protection, daily meeting limits, and async alternative suggestions. Saves hours per week by automatically declining "sync," "touch base," and other low-value calendar pollution.

## Features

- Intelligent meeting value classification (0-100 scoring)
- 8 professional excuse templates
- 6 async alternative suggestions
- Focus time protection (9-11am, 2-4pm)
- Daily meeting limit enforcement
- Automatic calendar integration (gcalcli)
- Decline history and statistics
- Time saved tracking
- Executive meeting protection
- Dry-run mode for safety
- Pattern-based detection (passive-aggressive phrases)

## Installation

```bash
chmod +x scripts/meeting-excuse-generator.sh
```

## Dependencies

- `jq` - JSON processing
- `gcalcli` - Google Calendar CLI
- `bc` - Math calculations

## Setup

### Install gcalcli

```bash
# Python 3
pip3 install gcalcli

# Authenticate with Google
gcalcli init

# Test connection
gcalcli agenda
```

### Configure Script

Script runs in dry-run mode by default for safety:
```bash
AUTO_DECLINE=0          # Disabled by default
DRY_RUN_ONLY=1          # Dry run by default
SEND_NOTIFICATIONS=1    # Desktop notifications
```

## Usage

### Test Mode (Dry Run)

```bash
# See what would be declined
./scripts/meeting-excuse-generator.sh process

# Process next 48 hours
./scripts/meeting-excuse-generator.sh --hours 48 process
```

Output shows:
- Which meetings would be declined
- Reasons (low value, focus time, too many, optional)
- Generated excuses
- Time that would be saved

### Enable Auto-Decline

```bash
# Enable automatic declining
./scripts/meeting-excuse-generator.sh enable

# Process meetings with auto-decline active
./scripts/meeting-excuse-generator.sh process
```

### View Statistics

```bash
# Show decline statistics
./scripts/meeting-excuse-generator.sh stats

# Output:
# ╔════════════════════════════════════════╗
# ║   MEETING DECLINE STATISTICS           ║
# ╚════════════════════════════════════════╝
#
# Total meetings declined: 47
# This week: 8
# Time saved: 23h 30m
#
# Recent declines:
#   - 2025-12-04 - Weekly sync (low_value)
#   - 2025-12-03 - Touch base call (too_many_today)
```

## Commands

| Command | Description |
|---------|-------------|
| `process` | Process upcoming meetings (default) |
| `stats` | Show decline statistics |
| `enable` | Enable auto-decline (removes dry-run mode) |
| `disable` | Disable auto-decline (back to dry-run) |

## Options

| Option | Description |
|--------|-------------|
| `--hours N` | Look ahead N hours (default: 24) |
| `--auto` | Enable automatic declining |
| `--dry-run` | Dry run only (show what would be declined) |

## Meeting Classification Algorithm

### Scoring System (0-100)

Starting score: 50 (neutral)

### Low-Value Indicators (Decrease Score)

**Title Keywords (-20 points)**
- "sync", "standup", "catch up", "touch base"
- "check in", "FYI", "optional"

**Optional Flag (-30 points)**
- Meeting marked as optional

**Too Many Attendees (-15 points)**
- >10 attendees = probably not needed

**Too Long (-10 points)**
- >60 minutes meetings

**All-Hands/Social (-25 points)**
- "all hands", "town hall", "social", "happy hour"
- "team building"

### High-Value Indicators (Increase Score)

**Important Meeting Types (+20 points)**
- "1:1", "one on one", "planning", "review"
- "demo", "retrospective", "postmortem"

**Senior Leadership (+30 points)**
- Organizer contains: "manager", "director", "VP", "CEO", "CTO"

**Decision-Making (+15 points)**
- "decision", "planning", "architecture", "design"

### Decline Threshold

Meetings with score < 40 are declined.

## Excuse Templates

### Professional Excuses (8 templates)
1. "I have a conflicting commitment at that time"
2. "I have a hard stop and won't be able to give this my full attention"
3. "I'm at capacity with existing commitments"
4. "I have overlapping priorities that require my focus"
5. "I need to protect some focus time for deep work"
6. "I'm currently heads-down on a critical deliverable"
7. "I have a scheduling conflict that I can't move"
8. "I'm committed to another obligation at that time"

### Async Alternative Suggestions (6 templates)
1. "Happy to review async - can you share notes/agenda beforehand?"
2. "Would love to contribute async - please share the doc and I'll add comments"
3. "Can I review the recording later? I'd like to stay informed"
4. "Could we handle this via email/Slack instead?"
5. "Happy to review the decisions async and provide feedback"
6. "Can someone take notes and share? I'll follow up with thoughts"

### Delegate Responses (4 templates)
1. "I think [PERSON] would be better suited for this discussion"
2. "This might be better suited for [PERSON]'s expertise"
3. "I recommend including [PERSON] instead - they're closer to this work"
4. "[PERSON] from my team can represent our perspective"

### Reschedule Options (4 templates)
1. "Could we find a time next week? I have more flexibility then"
2. "My calendar is packed this week - can we push to next week?"
3. "Would early next week work instead?"
4. "Can we schedule for [DAY] at [TIME] instead?"

## Decline Reasons

Script tracks why each meeting was declined:

### `low_value`
Meeting score < 40 based on classification algorithm

Generated response:
- Random professional excuse
- Random async suggestion

### `too_many_today`
Already at daily limit (default: 5 meetings/day)

Generated response:
- "I'm at capacity with existing commitments"
- "Can we find time next week?"

### `focus_time`
Meeting during protected focus hours (9-11am, 2-4pm)

Generated response:
- "I need to protect some focus time for deep work"
- "Happy to review async - can you share notes/agenda?"

### `optional`
Meeting marked as optional in calendar

Generated response:
- "Thanks for the invite!"
- "Can I review the recording later?"

## Configuration

### Time Thresholds

```bash
MIN_FOCUS_BLOCK=120          # 2 hours minimum for focus
MAX_MEETINGS_PER_DAY=5       # Daily meeting limit
```

### Focus Time Windows

Default protected hours (configurable):
- **Morning**: 9:00-11:00 (deep work)
- **Afternoon**: 14:00-16:00 (focused coding)

### Meeting Classification Tuning

```bash
# Adjust in script
threshold=40                  # Decline meetings below this score
```

## Example Output

### Dry Run Mode

```bash
./scripts/meeting-excuse-generator.sh process

# Processing: Weekly Team Sync
# Meeting score: 32
# [DRY RUN] Would decline with message:
#
# I have a conflicting commitment at that time
#
# Happy to review async - can you share notes/agenda beforehand?
#
# Thanks for understanding!
#
# Time saved: 30 minutes

# Processing: 1:1 with Manager
# Meeting score: 78
# Keeping: 1:1 with Manager (score: 78)
```

### After Enabling

```bash
./scripts/meeting-excuse-generator.sh enable
./scripts/meeting-excuse-generator.sh process

# Declining: Weekly Team Sync (reason: low_value, score: 32)
# Meeting declined successfully
# Time saved: 30 minutes

# Keeping: 1:1 with Manager (score: 78)
```

## Example Workflow

```bash
# 1. Install and authenticate gcalcli
pip3 install gcalcli
gcalcli init

# 2. Test in dry-run mode
./scripts/meeting-excuse-generator.sh process

# Review what would be declined
# Check excuse messages
# Verify nothing important gets declined

# 3. Adjust thresholds if needed
# Edit script: MAX_MEETINGS_PER_DAY, threshold, focus_time windows

# 4. Enable auto-decline when confident
./scripts/meeting-excuse-generator.sh enable

# 5. Run regularly (cron)
echo "0 */4 * * * /path/to/meeting-excuse-generator.sh process" | crontab -

# 6. Monitor statistics
./scripts/meeting-excuse-generator.sh stats
```

## Meeting Classification Examples

### Low Value (Declined)

```
"Weekly Team Sync" - Score: 25
  - Contains "sync" keyword (-20)
  - >10 attendees (-15)
  - Declined: low_value

"Touch Base Call" - Score: 30
  - Contains "touch base" (-20)
  - Declined: low_value

"[OPTIONAL] Q4 Planning" - Score: 20
  - "Optional" in title (-30)
  - Declined: optional

"All Hands Meeting" - Score: 25
  - "All hands" keyword (-25)
  - >10 attendees (-15)
  - Declined: low_value
```

### High Value (Kept)

```
"1:1 with Director" - Score: 80
  - "1:1" keyword (+20)
  - "Director" in organizer (+30)
  - Kept: high value

"Architecture Decision Meeting" - Score: 65
  - "Decision" keyword (+15)
  - "Architecture" keyword (+15)
  - <5 attendees
  - Kept: high value

"Q4 Planning Session" - Score: 70
  - "Planning" keyword (+20)
  - Kept: high value
```

## Focus Time Protection

Protected time blocks prevent meeting acceptance:

### Morning Block (9:00-11:00)
```bash
# Meeting at 10:00 AM
# Status: Declined (focus_time)
# Excuse: "I need to protect some focus time for deep work"
```

### Afternoon Block (14:00-16:00)
```bash
# Meeting at 15:00
# Status: Declined (focus_time)
# Excuse: "Happy to review async - can you share notes/agenda?"
```

## Statistics and Tracking

### Tracked Data
- Total meetings declined
- Declines this week/month
- Total time saved (assumes 30 min average)
- Decline reasons breakdown
- Recent decline history

### Export Data
```bash
# Stored in JSON format
cat $DATA_DIR/meeting_declines.json

# Contains:
# - Event ID
# - Meeting title
# - Decline reason
# - Score
# - Timestamp
```

## Best Practices

1. **Start with Dry Run**
   - Test for at least a week
   - Review all would-be declines
   - Adjust thresholds

2. **Protect Important Meetings**
   - Script already protects 1:1s
   - Protects executive meetings
   - Add custom patterns if needed

3. **Use Async Alternatives**
   - Actually review shared docs
   - Follow up on decisions
   - Maintain engagement

4. **Monitor Statistics**
   ```bash
   # Weekly review
   ./scripts/meeting-excuse-generator.sh stats
   ```

5. **Communicate Boundaries**
   - Let team know about focus time
   - Share meeting guidelines
   - Set expectations

6. **Adjust for Your Role**
   ```bash
   # IC: MAX_MEETINGS_PER_DAY=3
   # Manager: MAX_MEETINGS_PER_DAY=7
   # Executive: MAX_MEETINGS_PER_DAY=10
   ```

## Troubleshooting

### gcalcli Not Working

```bash
# Re-authenticate
gcalcli init

# Test connection
gcalcli agenda

# Check credentials
ls ~/.gcalcli_oauth
```

### Wrong Meetings Declined

Adjust classification algorithm:
```bash
# Lower threshold for more aggressive declining
threshold=30

# Raise threshold for more conservative
threshold=50
```

### Executive Meeting Declined

Script should protect these automatically. Check:
```bash
# Verify organizer name contains keywords
# manager, director, VP, CEO, CTO

# Add custom keywords to EXECUTIVE_KEYWORDS array
```

### Focus Time Too Aggressive

```bash
# Adjust is_focus_time() function
# Change time windows
# Or disable focus time protection
```

### Not Enough Meetings Declined

```bash
# Lower MAX_MEETINGS_PER_DAY
MAX_MEETINGS_PER_DAY=3

# Lower decline threshold
threshold=35
```

## Integration with Other Tools

### Calendar Blockers

```bash
# Add focus time blocks to calendar
gcalcli add "Focus Time" 9am 2h --calendar="Work" --where="Do Not Disturb"
```

### Slack Status

```bash
# Auto-set Slack status during focus time
# Integrate with slack-auto-responder.sh
```

### Meeting Cost Calculator

```bash
# Combine with meeting-cost-calculator.sh
# Show cost of declined meetings
```

## Data Storage

All data in `$DATA_DIR`:
```
meeting_decline_rules.json    # Custom rules (future)
meeting_declines.json          # Decline history
```

## Safety Features

- Dry-run mode by default
- Never declines 1:1s or exec meetings
- Keeps history of all declines
- Can be disabled anytime
- Preserves high-value meetings

## Related Scripts

- `meeting-prep-assassin.sh` - Auto-OSINT meeting attendees
- `meeting-cost-calculator.sh` - Real-time meeting cost tracking
- `slack-auto-responder.sh` - Auto-respond when in meetings
- `focus-mode-nuclear.sh` - Eliminate all distractions
