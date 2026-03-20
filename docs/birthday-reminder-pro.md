# Birthday Reminder Pro

Never forget a birthday again. Tracks birthdays, sends advance reminders, suggests gifts based on interests, and provides budget-appropriate gift ideas.

## Overview

Comprehensive birthday tracking system with multi-level reminders (7 days, 3 days, 1 day before, and day-of), gift suggestions based on stored interests and relationship type, gift history tracking to avoid repeats, and quick shopping links. All data stays local. Run with no arguments to see the full dashboard.

## Features

- Birthday database with relationships and importance levels
- Multi-tier reminder system (7d, 3d, 1d, day-of)
- Gift suggestion engine with interest matching
- Budget-aware suggestions by relationship type
- Gift history tracking
- Social media interest scraping checklist
- Desktop notification support

## Installation

```bash
chmod +x scripts/birthday-reminder-pro.sh
```

## Dependencies

Required:
- `jq` - JSON processing

## Quick Start

```bash
# Add a birthday
./scripts/birthday-reminder-pro.sh add "Alice" "1990-05-15" "spouse" "critical"

# Check upcoming birthdays
./scripts/birthday-reminder-pro.sh check

# Get gift suggestions
./scripts/birthday-reminder-pro.sh suggest "Alice"

# View full dashboard
./scripts/birthday-reminder-pro.sh dashboard
```

## Usage

### Add Birthday

```bash
# Full syntax
./scripts/birthday-reminder-pro.sh add NAME DATE [RELATIONSHIP] [IMPORTANCE]

# With full year
./scripts/birthday-reminder-pro.sh add "Alice" "1990-05-15" "spouse" "critical"

# Month-day only (year-agnostic)
./scripts/birthday-reminder-pro.sh add "Bob" "07-22" "friend" "normal"

# Minimal (defaults: friend, normal)
./scripts/birthday-reminder-pro.sh add "Carol" "1988-11-03"
```

DATE accepts `YYYY-MM-DD` or `MM-DD` format.

### Remove Birthday

```bash
./scripts/birthday-reminder-pro.sh remove "Bob"
```

### List All Birthdays

```bash
./scripts/birthday-reminder-pro.sh list
```

Lists all birthdays sorted by date with relationship and importance.

### Check Upcoming Birthdays

```bash
./scripts/birthday-reminder-pro.sh check
```

Checks for birthdays in the next 7 days and sends desktop notifications. Shows CRITICAL/WARNING/UPCOMING tiers.

### Show Dashboard

```bash
./scripts/birthday-reminder-pro.sh dashboard
```

Clears screen and shows full dashboard: critical alerts, next 30 days, and total people tracked.

### Get Gift Suggestions

```bash
./scripts/birthday-reminder-pro.sh suggest "Alice"
```

Shows budget (based on relationship), relationship type, interest-based ideas, generic suggestions by relationship, and quick shopping links.

### Add Interests

```bash
./scripts/birthday-reminder-pro.sh add-interest "Alice" "coffee" "books" "yoga"
```

Interests are used by `suggest` to generate targeted gift ideas.

### Record a Gift Given

```bash
./scripts/birthday-reminder-pro.sh record-gift "Alice" "Coffee maker" 89
```

Records gift, cost, and year. Prevents repeat gifts.

### View Gift History

```bash
# All gift history
./scripts/birthday-reminder-pro.sh history

# One person's history
./scripts/birthday-reminder-pro.sh history "Alice"
```

### Scrape Social Interests

```bash
./scripts/birthday-reminder-pro.sh scrape "Alice"
```

Prints a manual OSINT checklist for finding someone's interests on social media. Then use `add-interest` to store findings.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `add` | NAME DATE [REL] [IMP] | Add birthday |
| `remove` | NAME | Remove birthday |
| `list` | - | List all birthdays |
| `check` | - | Check upcoming birthdays and send alerts |
| `dashboard` | - | Show full birthday dashboard |
| `suggest` | NAME | Get gift suggestions |
| `add-interest` | NAME INTERESTS... | Add interests for gift suggestions |
| `record-gift` | NAME GIFT [COST] | Record a gift given |
| `history` | [NAME] | Show gift history |
| `scrape` | NAME | OSINT checklist for finding interests |

## Relationships

Controls budget and gift category in suggestions:

| Relationship | Default Budget |
|---|---|
| `spouse` / `partner` | $200 |
| `parent` / `sibling` | $100 |
| `close_friend` | $75 |
| `friend` | $50 |
| `coworker` | $25 |
| `acquaintance` | $15 |

## Importance Levels

Controls alert urgency:
- `critical` - Maximum urgency
- `high` - High priority
- `normal` - Standard reminder
- `low` - Minimal alerts

## Reminder Tiers

**7 Days Before** (advance warning):
```
📅 Upcoming: Alice's birthday in 7 days
```

**3 Days Before** (critical warning):
```
⚠️  Soon: Alice's birthday in 3 days
```

**1 Day Before** (panic mode):
```
🚨 URGENT: Alice's birthday in 1 day!
```

**Birthday Day**:
```
🎂 TODAY: Alice's birthday!
```

## Gift Suggestion Examples

```bash
$ ./scripts/birthday-reminder-pro.sh suggest "Alice"

🎁 Gift Suggestions for Alice

Budget: $200
Relationship: spouse

Based on their interests:
  • Premium coffee beans subscription ($20-60/month)
  • Specialty coffee maker ($50-200)

Generic suggestions:
  • Jewelry ($100-300)
  • Spa day voucher ($100-200)
  • Weekend getaway ($200-500)
  • Personalized photo album ($50-100)

🛒 Quick Shopping Links:
  • Amazon: https://amazon.com/gp/gift-central
  • Etsy (personalized): https://etsy.com/gift-mode
  • Uncommon Goods: https://uncommongoods.com
  • Giftcards: https://giftcards.amazon.com
```

## Automation

```bash
# Daily check at 9 AM (add to crontab)
0 9 * * * /path/to/scripts/birthday-reminder-pro.sh check

# Weekly dashboard email
0 9 * * 0 /path/to/scripts/birthday-reminder-pro.sh dashboard | mail -s "Birthday Report" you@email.com
```

## Best Practices

1. **Add interests right away**
   - Note what they mention in conversation
   - Check `scrape` for a social media checklist
   - Use `add-interest` to store findings

2. **Set accurate relationship types**
   - Budget scales with relationship
   - Generic suggestions change per relationship

3. **Track all gifts given**
   - Use `record-gift` after each birthday
   - Review with `history` before suggesting again
   - Avoids awkward repeats

4. **Run `check` daily**
   - Add to crontab for automatic alerts
   - 7-day window gives time to plan

5. **Review `dashboard` weekly**
   - See everything coming up in the next 30 days
   - Never be caught off guard

## Data Location

```
$DATA_DIR/birthdays.json          # Birthday database
$DATA_DIR/gift_history.json       # Gift purchases
$DATA_DIR/reminder_history.json   # Reminder log
```

## Privacy

- All data stored locally
- No external service required
- Delete anytime: `rm $DATA_DIR/birthdays.json`

## Related Scripts

- `wife-happy-score.sh` - Relationship tracking
- `expense-shame-dashboard.sh` - Gift budget tracking
- `meeting-prep-assassin.sh` - Research people before meetings
