# Tech Interview Revenge

Flip the script on technical interviews. Company research, red flag detection, reverse interview questions, salary negotiation, and take-home assignment analysis.

## Overview

Comprehensive tech interview preparation and counter-evaluation tool. Research companies before you walk in, analyze job descriptions for red flags, generate hard reverse questions to evaluate them, calculate your market rate, get negotiation scripts, analyze whether take-home assignments are free labor, and generate professional decline emails. Every interview is a two-way evaluation.

## Features

- Company research with quick-link generation
- Job description red flag analysis (keyword matching)
- Reverse interview question database (30+ questions, 6 categories)
- Market salary estimation by role, YOE, and location
- Salary negotiation assistant with response templates
- Take-home assignment red flag analysis
- Decline email template generator (4 scenarios)
- Interview pipeline tracking

## Installation

```bash
chmod +x scripts/tech-interview-revenge.sh
```

## Dependencies

Required:
- `jq` - JSON processing
- `bc` - Math calculations

## Quick Start

```bash
# Research a company
./scripts/tech-interview-revenge.sh research "SomeStartup"

# Analyze a job description
./scripts/tech-interview-revenge.sh analyze-job job_description.txt

# Get reverse questions to ask them
./scripts/tech-interview-revenge.sh questions all
```

## Usage

### Research a Company

```bash
./scripts/tech-interview-revenge.sh research "Company Name"
```

Outputs quick-research links (Glassdoor, LinkedIn, Crunchbase, Layoffs.fyi) and a checklist of what to look for: Glassdoor rating, LinkedIn turnover, funding status, recent layoffs, exec LinkedIn activity.

### Analyze Job Description

```bash
# From a file
./scripts/tech-interview-revenge.sh analyze-job job_description.txt
```

Scans the text for red flag patterns: "rockstar", "ninja", "guru", "wear many hats", "fast-paced environment", "unlimited PTO", "we're a family", "competitive salary", "must be passionate", and more. Also flags missing salary information and unclear remote policy.

Outputs: flags found, severity (warning vs. high alert), and a recommendation.

### Generate Reverse Interview Questions

```bash
# All categories
./scripts/tech-interview-revenge.sh questions

# Specific category
./scripts/tech-interview-revenge.sh questions culture
./scripts/tech-interview-revenge.sh questions red_team
./scripts/tech-interview-revenge.sh questions technical_debt
```

Available categories:

| Category | Sample Questions |
|----------|-----------------|
| `technical_debt` | "What's your oldest production code?" "What's your test coverage?" |
| `culture` | "Why did the last 3 engineers leave?" "Do people check Slack on weekends?" |
| `process` | "How long does a PR sit before review?" "Who has production access?" |
| `growth` | "What's the career ladder?" "What's the raise/bonus structure?" |
| `business` | "What's the runway?" "Why did the CTO leave?" |
| `red_team` | "What's the biggest lie in your job description?" "Why is this position open?" |
| `all` | All categories |

### Calculate Market Salary

```bash
# Basic - uses defaults from config
./scripts/tech-interview-revenge.sh salary "Senior Engineer"

# With years of experience and location
./scripts/tech-interview-revenge.sh salary "Senior Engineer" 8 "SF"
./scripts/tech-interview-revenge.sh salary "Staff Engineer" 12 "New York"
```

Outputs research links (levels.fyi, Glassdoor, Payscale, Blind) and a rough salary estimate based on YOE and location multiplier (SF: 1.5x, NYC: 1.4x, Seattle: 1.3x, Austin/Boston: 1.2x).

### Salary Negotiation Assistant

```bash
./scripts/tech-interview-revenge.sh negotiate
```

Interactive - prompts for your current salary, the offer, and market rate, then outputs:
- Whether to reject, negotiate, or accept
- A specific counter-offer amount (10% above market)
- A ready-to-send response email template
- Negotiation tips

### Analyze Take-Home Assignment

```bash
./scripts/tech-interview-revenge.sh takehome
```

Paste the assignment description (Ctrl+D to finish). Prompts for estimated hours, whether it resembles their actual product, and whether they'll use your code. Checks for scope red flags: full-stack requirements, infrastructure setup, system design work. Outputs severity verdict and a rejection template if warranted.

### Generate Decline Email

```bash
# Lowball offer
./scripts/tech-interview-revenge.sh decline lowball

# Too many interview rounds
./scripts/tech-interview-revenge.sh decline process

# Too many red flags
./scripts/tech-interview-revenge.sh decline redflags

# Generic / maximum brevity
./scripts/tech-interview-revenge.sh decline generic
```

### View Interview Statistics

```bash
./scripts/tech-interview-revenge.sh stats
```

Shows total applications, offers received, rejections, offer rate percentage, and recent activity.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `research` | COMPANY | Research company |
| `analyze-job` | FILE | Analyze job description for red flags |
| `questions` | [CATEGORY] | Generate reverse interview questions |
| `salary` | ROLE [YOE] [LOCATION] | Calculate market salary |
| `negotiate` | - | Interactive salary negotiation assistant |
| `takehome` | - | Analyze take-home assignment |
| `decline` | REASON | Generate decline email template |
| `stats` | - | Show interview statistics |

## Example Workflow

```bash
# 1. Before applying - research the company
./scripts/tech-interview-revenge.sh research "Acme Corp"

# 2. Analyze the job posting
./scripts/tech-interview-revenge.sh analyze-job acme_job.txt

# 3. Prepare questions to ask them
./scripts/tech-interview-revenge.sh questions all > questions.txt

# 4. Check your market rate before the call
./scripts/tech-interview-revenge.sh salary "Senior Engineer" 6 "SF"

# 5. After getting an offer - negotiate
./scripts/tech-interview-revenge.sh negotiate

# 6. If it's bad - decline professionally
./scripts/tech-interview-revenge.sh decline lowball
```

## Example Outputs

### Red Flag Analysis

```bash
$ ./scripts/tech-interview-revenge.sh analyze-job posting.txt

🚩 Red Flag Analysis

  🚩 Found: 'rockstar'
  🚩 Found: 'wear many hats'
  🚩 Found: 'fast-paced environment'
  🚩 No salary information
  ⚠️  Remote policy unclear

⛔ HIGH ALERT: 4 red flags found!
Consider skipping this one.
```

### Reverse Questions (red_team)

```bash
$ ./scripts/tech-interview-revenge.sh questions red_team

RED_TEAM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • If you could change ONE thing about this company, what would it be?
  • What's the biggest lie in our job description?
  • Why is this position open? Did someone quit or get fired?
  • What would make me want to quit in the first 6 months?
  • Be honest: Is this a good place to work right now?

Pro tips:
  • Ask these at the END of the interview
  • Watch for hesitation and PR-speak
  • Good companies will respect these questions
  • Bad companies will get defensive
```

### Decline Email (lowball)

```bash
$ ./scripts/tech-interview-revenge.sh decline lowball

📧 Decline Email Template

Subject: Re: Offer - [Company Name]

Hi [Recruiter Name],

Thank you for the offer. After careful consideration, I've decided to
pursue other opportunities that better align with my compensation expectations.

I appreciate the time your team spent with me.

Best regards,
[Your Name]
```

## Configuration

```bash
# config/config.sh
YOUR_CURRENT_SALARY=120000
YOUR_YOE=6
YOUR_LOCATION="San Francisco"
```

## Philosophy

- Your time is valuable
- They need you more than you need them
- Every interview is a two-way evaluation
- Bad companies show red flags early
- Always negotiate
- Walk away from bullshit

## Data Location

```
$DATA_DIR/companies_interviewed.json   # Application tracking
$DATA_DIR/red_flags.json               # Red flag patterns
$DATA_DIR/salary_data.json             # Salary research cache
$DATA_DIR/reverse_questions.json       # Question database
```

## Related Scripts

- `meeting-prep-assassin.sh` - Research people before meetings
- `bullshit-jargon-translator.sh` - Decode job posting language
- `cofounder-background-check.sh` - Deep background research
