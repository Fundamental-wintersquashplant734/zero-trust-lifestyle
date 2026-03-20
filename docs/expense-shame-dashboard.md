# Expense Shame Dashboard

Brutally honest expense tracking that shames you into better financial decisions. "Coffee this month = $347."

## Overview

Tracks expenses by importing bank CSV exports, auto-categorizes transactions by keyword matching, and presents spending in the most shameful way possible. Calculates opportunity costs in hours worked, compares spending to financial goals, highlights wasteful patterns, and optionally emails monthly shame reports.

## Features

- CSV import from bank/credit card exports
- Automatic categorization by keyword matching
- Monthly shame reports with opportunity cost calculations
- Spending trends over 6 months
- Financial goal tracking (monthly budget + category limits)
- Hourly rate conversion ("this coffee = 1.8 hours of work")
- Email reports (requires `ALERT_EMAIL` configured)

## Installation

```bash
chmod +x scripts/expense-shame-dashboard.sh
```

## Dependencies

- `jq` - JSON processing
- `bc` - Math calculations

## Quick Start

```bash
# Import transactions from bank CSV
./scripts/expense-shame-dashboard.sh import ~/Downloads/transactions.csv

# View this month's shame report
./scripts/expense-shame-dashboard.sh report

# See coffee spending trend
./scripts/expense-shame-dashboard.sh trend coffee
```

## Usage

### Import Expenses

```bash
./scripts/expense-shame-dashboard.sh import PATH/TO/FILE.csv
```

CSV format expected:
```
date,description,amount
2024-11-15,"Starbucks",5.50
2024-11-16,"Uber Eats",-25.00
```

Transactions are auto-categorized using keyword matching. Categories detected: `coffee`, `food_delivery`, `subscriptions`, `alcohol`, `impulse_shopping`, `entertainment`, `transportation`, `groceries`, `fitness`.

### Generate Shame Report

```bash
# This month
./scripts/expense-shame-dashboard.sh report

# Specific month
./scripts/expense-shame-dashboard.sh report 2024-11
```

Shows total spend, category breakdown with shame commentary, top 5 individual expenses, and what you could have done with the money instead.

### View Spending Trend

```bash
# Total spending trend (last 6 months)
./scripts/expense-shame-dashboard.sh trend

# Category-specific trend
./scripts/expense-shame-dashboard.sh trend coffee
./scripts/expense-shame-dashboard.sh trend food_delivery
```

Displays a bar chart of monthly spending.

### Track Goals

```bash
# View goal progress vs. current month spending
./scripts/expense-shame-dashboard.sh goals
```

Shows monthly budget usage and category limit progress with color-coded warnings.

### Set Financial Goals

```bash
# Set monthly budget
./scripts/expense-shame-dashboard.sh set-goal budget 3000

# Set category spending limit
./scripts/expense-shame-dashboard.sh set-goal coffee 100
./scripts/expense-shame-dashboard.sh set-goal food_delivery 150
```

### Email Shame Report

```bash
# Email this month's report
./scripts/expense-shame-dashboard.sh email

# Email specific month
./scripts/expense-shame-dashboard.sh email 2024-11
```

Requires `ALERT_EMAIL` set in `config/config.sh`.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `import` | CSV | Import expenses from CSV file |
| `report` | [MONTH] | Generate shame report (default: current month) |
| `trend` | [CATEGORY] | Show 6-month spending trend (default: total) |
| `goals` | - | Compare spending to financial goals |
| `set-goal` | TYPE AMT | Set budget or category limit |
| `email` | [MONTH] | Email shame report |

## Options

| Option | Description |
|--------|-------------|
| `--rate RATE` | Set hourly rate for work-hours conversion (default: $50) |

## Example Report

```bash
$ ./scripts/expense-shame-dashboard.sh report

╔═══════════════════════════════════════════════════════════╗
║              💸 FINANCIAL SHAME REPORT 💸                 ║
║                    November 2024                           ║
╚═══════════════════════════════════════════════════════════╝

Total Spent: $1,247.89  (24.9 hours of work)

☕ COFFEE: $347.00  (6.9h of work)
   ⚠️  You spent more on coffee than on:
   - GitHub Copilot ($10/mo) × 34 months
   - Netflix ($15/mo) × 23 months

🍔 FOOD DELIVERY: $445.20  (8.9h of work)
   🚨 CRITICAL SHAME LEVEL
   If you cooked instead:
   - Could have saved ~$311 (70% of delivery cost)
   - That's 6.2h of freedom

📱 Subscriptions: $89.97
   Recurring monthly drain: $89.97
   Annual cost: $1,079

🍺 Alcohol: $65.00  (1.3h of work)

🛒 Impulse Shopping: $187.32  (3.7h of work)
   Stuff you probably don't need

🏆 Top 5 Individual Expenses:
   food_delivery: DoorDash - $78.50
   food_delivery: Uber Eats - $65.20
   ...

═══════════════════════════════════════════════════════════
SHAME SUMMARY:
You have 3 category(ies) in the danger zone!

What you could have done with that money:
  - Saved $792 (coffee + delivery)
  - Bought 15 nice dinners
  - Invested it (7% return) = $847 next year
  - 15.8 hours of freedom
```

## Shame Categories

Auto-detected from transaction descriptions:

| Category | Keywords | Shame Level |
|----------|----------|-------------|
| ☕ Coffee | Starbucks, coffee, cafe, Dunkin, Peet's | High |
| 🍔 Food Delivery | Uber Eats, DoorDash, Grubhub, Seamless | Critical |
| 📱 Subscriptions | Netflix, Spotify, ChatGPT, GitHub Copilot | Medium |
| 🍺 Alcohol | bar, liquor, beer, wine, brewery | High |
| 🛒 Impulse Shopping | Amazon, eBay, Etsy, Target, Walmart | High |
| 🎮 Entertainment | cinema, Steam, PlayStation, Xbox | Medium |
| 🚗 Transportation | Uber, Lyft, parking, gas | Low |
| 🛒 Groceries | Whole Foods, Trader Joe's, Safeway | Low |
| 💪 Fitness | gym, yoga, Peloton | Low |

## Automation

```bash
# Email monthly report on the 1st of each month at 9am
0 9 1 * * /path/to/expense-shame-dashboard.sh email
```

## Configuration

```bash
# config/config.sh
HOURLY_RATE=75          # Your hourly rate for work-hours math
ALERT_EMAIL="you@example.com"  # For email reports
```

## Data Location

```
$DATA_DIR/expenses.json              # Expense log
$DATA_DIR/expense_categories.json    # Category keyword rules
$DATA_DIR/financial_goals.json       # Budget and limits
```

## Related Scripts

- `wife-happy-score.sh` - Relationship tracking
- `health-nag-bot.sh` - Health reminders
- `birthday-reminder-pro.sh` - Gift budgeting
