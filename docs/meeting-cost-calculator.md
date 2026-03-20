# Meeting Cost Calculator

Real-time meeting cost tracker that displays the dollar amount spent per minute based on attendee salaries. Makes the true cost of meetings painfully visible.

## Overview

Tracks and displays the cumulative cost of meetings in real-time. Calculates cost based on attendee salaries (or role estimates), including overhead. Shows running total, cost per minute, and breakdown by attendee. Integrates with Google Calendar for automatic tracking.

## Features

- Real-time cost calculation during meetings
- Salary database with role-based estimates
- Overhead multiplier (benefits, office space)
- Per-attendee cost breakdown
- Meeting history tracking
- Expensive meeting alerts
- Calendar integration
- Live dashboard display
- Historical cost analytics

## Installation

```bash
chmod +x scripts/meeting-cost-calculator.sh
```

## Dependencies

Required:
- `jq` - JSON processing
- `bc` - Calculations

Optional:
- `gcalcli` - Google Calendar integration

## Quick Start

```bash
# Quick estimate (5 people, 30 minutes, mid-level devs)
./scripts/meeting-cost-calculator.sh estimate 5 30 mid_dev

# Live meeting cost tracking
./scripts/meeting-cost-calculator.sh live "Alice (Senior Dev)" "Bob (Manager)" "Carol (Junior Dev)"
```

## Usage

### Live Meeting Tracking

```bash
# Track live cost with named attendees
./scripts/meeting-cost-calculator.sh live "Alice (Senior Dev)" "Bob (Manager)" "Carol (Junior Dev)"
```

Output updates live:
```
╔════════════════════════════════════════════════════════════╗
║         💰 MEETING COST CALCULATOR - LIVE 💰              ║
╚════════════════════════════════════════════════════════════╝

Duration: 23 minutes (23.0 minutes)

💵 TOTAL COST: $847.33

Cost per minute: $36.84

Breakdown by attendee:
  Alice (Senior Dev)             $44.30   ($1.93/min)
  Bob (Manager)                  $38.50   ($1.67/min)
  ...

Press Ctrl+C to end meeting
```

### Quick Estimate

```bash
# Estimate cost (number of people, duration in minutes, role)
./scripts/meeting-cost-calculator.sh estimate 5 30 mid_dev

# 10 people, 60 minutes, senior devs
./scripts/meeting-cost-calculator.sh estimate 10 60 senior_dev
```

### View Statistics

```bash
./scripts/meeting-cost-calculator.sh stats
```

### Manage Salary Database

```bash
# Set custom salary for a person
./scripts/meeting-cost-calculator.sh set "Alice" 150000

# View salary database
./scripts/meeting-cost-calculator.sh list
```

## Salary Database

### Default Role Salaries (Annual USD)

| Role | Salary |
|------|--------|
| Junior Dev | $70,000 |
| Mid Dev | $100,000 |
| Senior Dev | $140,000 |
| Staff Dev | $180,000 |
| Principal Dev | $220,000 |
| Tech Lead | $160,000 |
| Manager | $150,000 |
| Senior Manager | $180,000 |
| Director | $200,000 |
| Senior Director | $250,000 |
| VP | $300,000 |
| SVP | $400,000 |
| CEO | $500,000 |
| Unknown | $100,000 |

### Cost Calculation

```
Hourly Rate = (Annual Salary × Overhead Multiplier) / Working Hours
Cost = Hourly Rate × (Meeting Duration / 60)
```

Default:
- Overhead Multiplier: 1.4 (40% for benefits, office, etc.)
- Working Hours: 2080/year (40 hours/week × 52 weeks)

### Customization

Edit `$DATA_DIR/salary_database.json`:

```json
{
  "roles": {
    "senior_dev": 140000,
    "custom_role": 175000
  },
  "people": {
    "Alice": 150000,
    "Bob": "manager"
  }
}
```

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `live` | ATTENDEES... | Start live cost tracking |
| `estimate` | N MINS [ROLE] | Quick cost estimate |
| `stats` | - | Show meeting statistics |
| `set` | NAME SALARY | Set salary for a person |
| `list` | - | List salary database |

## Options

| Option | Description |
|--------|-------------|
| `--no-breakdown` | Hide per-attendee breakdown |
| `--alert-threshold N` | Alert when cost exceeds N dollars (default: 1000) |

## Example Scenarios

### Daily Standup (10 people, 15 min)

```bash
./scripts/meeting-cost-calculator.sh estimate 10 15 mid_dev
```

Output:
```
Quick Estimate:
  • Attendees: 10 (mid_dev)
  • Duration: 15 minutes
  • Cost per person: $17.31

💵 TOTAL COST: $173.08
```

### All-Hands Meeting (50 people, 60 min)

```bash
./scripts/meeting-cost-calculator.sh estimate 50 60 mid_dev
```

Output:
```
Quick Estimate:
  • Attendees: 50 (mid_dev)
  • Duration: 60 minutes
  • Cost per person: $69.23

💵 TOTAL COST: $3,461.54
```

### Executive Planning (5 execs, 120 min, live)

```bash
./scripts/meeting-cost-calculator.sh live "CEO" "VP Engineering" "VP Product" "Director" "Director"
```

## Statistics

```bash
./scripts/meeting-cost-calculator.sh stats
```

Shows:
- Total meetings tracked
- Total cost
- Total meeting time
- Average meeting cost
- Average meeting duration
- Most expensive meetings

## Alerts

### Expensive Meeting Alert

Triggers when meeting cost exceeds threshold (default: $1000). Override with `--alert-threshold`:

```bash
./scripts/meeting-cost-calculator.sh --alert-threshold 500 live "Alice" "Bob" "Carol"
```

## Cost Reduction Suggestions

Script automatically suggests:

**When cost > $500:**
- Could this be an email?
- Does everyone need to attend?
- Can we make it shorter?

**When attendees > 10:**
- Split into smaller groups
- Record and share instead
- Delegate to working group

**When duration > 60 min:**
- Set stricter time limit
- Break into multiple meetings
- Use async communication

## Data Storage

```
$DATA_DIR/salary_database.json    # Salary/role data
$DATA_DIR/meeting_history.json    # Meeting history
$DATA_DIR/calendar_cache.json     # Calendar data
```

## Configuration

Edit in script or environment:

```bash
# Overhead multiplier (1.4 = 40% overhead)
OVERHEAD_MULTIPLIER=1.4

# Working hours per year
WORKING_HOURS_PER_YEAR=2080

# Update interval (seconds)
UPDATE_INTERVAL=60

# Alert threshold
ALERT_EXPENSIVE_THRESHOLD=1000
```

## Best Practices

1. **Track all recurring meetings**
   - Daily standups
   - Weekly syncs
   - Monthly all-hands

2. **Review monthly**
   - Identify most expensive meetings
   - Question necessity
   - Optimize attendance

3. **Share costs with team**
   - Makes impact visible
   - Encourages efficiency
   - Drives better decisions

4. **Set budgets**
   - Weekly meeting budget
   - Per-meeting cost limits
   - Department-wide targets

5. **Optimize**
   - Reduce attendees
   - Shorten duration
   - Switch to async when possible

## Real Cost Examples

Based on default salaries:

| Meeting Type | Attendees | Duration | Est. Cost |
|--------------|-----------|----------|-----------|
| Daily Standup | 10 devs | 15 min | $361 |
| Sprint Planning | 8 devs | 120 min | $2,885 |
| All-Hands | 50 people | 60 min | $7,217 |
| 1-on-1 | 2 people | 30 min | $120 |
| Architecture Review | 6 seniors | 90 min | $1,442 |

Annual recurring meeting costs:
- Daily 15-min standup (10 people): ~$90,000/year
- Weekly 1-hour sync (8 people): ~$74,000/year

## Related Scripts

- `meeting-excuse-generator.sh` - Auto-decline meetings
- `slack-auto-responder.sh` - Avoid meeting requests
- `standup-bot.sh` - Async standups
