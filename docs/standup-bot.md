# Standup Bot

Automates daily standup updates to Slack. Generates plausible-sounding status updates so you don't have to attend or write them manually.

## Overview

Automated standup message generator that posts to Slack on schedule. Uses templates, commit history, and issue tracking to generate realistic updates. Learns your writing style and project context. Handles async standups without human intervention.

## Features

- Automated daily standup posting
- Generates updates from Git commits
- Pulls from issue trackers (Jira, GitHub)
- Template-based responses
- Style mimicry (sounds like you)
- Blocker detection and reporting
- Scheduled posting
- Weekend/holiday awareness
- Customizable formats
- Emergency human override

## Installation

```bash
chmod +x scripts/standup-bot.sh
```

## Dependencies

Required:
- Slack API token
- `jq` - JSON processing
- `curl` - HTTP requests

Optional:
- `git` - Commit analysis
- `gh` - GitHub CLI
- Jira API access

## Setup

### Slack Token

```bash
# Set token
export SLACK_TOKEN="xoxb-your-bot-token"

# Or configure
./scripts/standup-bot.sh config set-token "xoxb-..."
```

### Standup Channel

```bash
./scripts/standup-bot.sh config set-channel "#standup"
```

## Quick Start

```bash
# Generate and post standup
./scripts/standup-bot.sh post

# Schedule daily at 9 AM
./scripts/standup-bot.sh schedule "09:00"

# Manual mode (preview before posting)
./scripts/standup-bot.sh generate
```

## Usage

### Generate Standup

```bash
# Auto-generate from recent activity
./scripts/standup-bot.sh generate

# Use specific template
./scripts/standup-bot.sh generate --template productive

# Edit generated standup before saving
./scripts/standup-bot.sh --edit generate
```

### Post to Slack

```bash
# Generate and post
./scripts/standup-bot.sh post

# Post manually written update
./scripts/standup-bot.sh post "Yesterday: X, Today: Y, Blockers: None"

# Preview before posting
./scripts/standup-bot.sh post --dry-run
```

### Schedule Automation

```bash
# Daily at 9 AM (Mon-Fri)
./scripts/standup-bot.sh schedule "09:00"

# Custom days
./scripts/standup-bot.sh schedule "09:00" "Mon,Wed,Fri"

# Stop automated posts
./scripts/standup-bot.sh schedule stop
```

## Message Generation

### Data Sources

1. **Git Commits** (yesterday's work)
   ```bash
   git log --since="yesterday" --author="you"
   ```

2. **GitHub Issues** (assigned to you)
   ```bash
   gh issue list --assignee @me --state open
   ```

3. **Jira Tickets** (your tickets)
   ```bash
   # Uses Jira API
   ```

4. **Calendar** (meetings attended)

5. **Templates** (fallback patterns)

### Generation Logic

**Yesterday**:
- Closed PRs
- Merged commits
- Completed tickets
- Meetings attended

**Today**:
- Open PRs needing review
- In-progress tickets
- Scheduled meetings
- Planned work from calendar

**Blockers**:
- Stuck PRs (waiting on review >2 days)
- Blocked tickets
- Dependency issues
- Test failures

## Templates

### Productive Template

```
Yesterday:
  - Completed PR #456: User authentication refactor
  - Fixed bug #789: Login timeout issue
  - Code review: 3 PRs

Today:
  - Continuing work on feature X
  - Planning session at 2 PM
  - Code review backlog

Blockers: None
```

### Vague Template (minimal info)

```
Yesterday:
  - Made progress on ongoing tasks
  - Several code reviews

Today:
  - Continuing previous work
  - Some meetings scheduled

Blockers: None
```

### Busy Template (overwhelmed)

```
Yesterday:
  - Multiple critical bugs fixed
  - Emergency production deploy
  - Incident response

Today:
  - Sprint planning
  - Architecture discussion
  - Continuing bug fixes

Blockers: Waiting on infrastructure team for access
```

### Templates

```bash
# List available templates
./scripts/standup-bot.sh templates

# Use specific template
./scripts/standup-bot.sh generate --template busy

# Create custom template
./scripts/standup-bot.sh template create my-template
```

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `generate` | [TEMPLATE] | Generate standup message |
| `post` | [MESSAGE] | Generate and post to Slack |
| `history` | - | View past standups |
| `stats` | - | Show statistics |
| `test` | - | Test configuration |
| `config set-channel` | CHANNEL | Set Slack channel |
| `config set-token` | TOKEN | Set Slack bot token |
| `config show` | - | Show current config |
| `templates` | - | List available templates |
| `template create` | NAME | Create custom template |
| `schedule` | TIME [DAYS] | Schedule daily posts |
| `schedule stop` | - | Stop scheduled posts |
| `learn` | - | Learn from writing style |
| `vacation` | START END | Set vacation mode |
| `github set-repo` | REPO | Set GitHub repo (owner/repo) |
| `github analyze` | - | Analyze GitHub activity |
| `jira` | - | Show JIRA configuration |

## Style Learning

```bash
# Analyze your previous standups
./scripts/standup-bot.sh learn
```

Learns:
- Phrasing patterns
- Common phrases
- Sentence structure
- Emoji usage
- Update length
- Level of detail

## Smart Features

### Blocker Detection

Automatically detects:
- PRs waiting >2 days for review
- Failing CI/CD pipelines
- Tickets blocked in Jira
- Dependency on external teams
- Waiting on design/product

### Weekend Awareness

```
Friday update:
  Today: Wrapping up sprint
  Monday: Will continue with...
```

Doesn't post on weekends (unless configured).

### Holiday Detection

Skips posting on holidays or mentions:
```
Yesterday: Was out (holiday)
Today: Catching up on emails...
```

### Vacation Mode

```bash
# Set vacation
./scripts/standup-bot.sh vacation "2025-12-20" "2025-12-27"
```

Posts:
```
Status: On vacation until 12/27
```

## Example Generated Standup

```bash
$ ./scripts/standup-bot.sh generate

Analyzing recent activity...
  - Git commits: 8 found
  - GitHub issues: 3 open, 1 closed
  - Jira tickets: 2 in progress
  - Calendar: 2 meetings yesterday

Generated standup:

Yesterday:
  - Merged PR #234: Implement user preferences API
  - Fixed bug #567: Date formatting issue in reports
  - Closed JIRA-123: User export feature
  - Code review: PRs #245, #246, #247

Today:
  - Continue work on JIRA-124: Dashboard redesign
  - Sprint planning meeting at 10 AM
  - Code review for backend team PRs
  - Investigate performance issue in production

Blockers:
  - Waiting on design team feedback for dashboard mockups
  - PR #234 needs QA sign-off before deploy

Post this? [y/n/edit]
```

## Customization

### Writing Style

```json
{
  "style": {
    "detail_level": "moderate",
    "use_bullet_points": true,
    "include_pr_numbers": true,
    "include_meeting_count": false,
    "use_emoji": false,
    "max_items_per_section": 4
  }
}
```

### Content Preferences

```json
{
  "content": {
    "include_commits": true,
    "include_prs": true,
    "include_issues": true,
    "include_meetings": false,
    "include_code_reviews": true,
    "mention_blockers": true,
    "mention_pto": true
  }
}
```

## Integration

### With GitHub

```bash
# Configure GitHub repo
./scripts/standup-bot.sh github set-repo "owner/repo"

# Analyze PR activity
./scripts/standup-bot.sh github analyze
```

### With Jira

```bash
# Show JIRA configuration instructions
./scripts/standup-bot.sh jira
```

Set credentials in `config/config.sh`:
```bash
export JIRA_URL="https://your-domain.atlassian.net"
export JIRA_TOKEN="your-api-token"
```

### With Calendar

Calendar integration uses `gcalcli` automatically when installed. No subcommand needed — meetings are pulled during `generate` or `post`.

## Manual Override

When automation fails:

```bash
# Post custom message
./scripts/standup-bot.sh post "Yesterday: A, Today: B, Blockers: C"

# Edit generated message
./scripts/standup-bot.sh generate --edit
```

## Statistics

```bash
./scripts/standup-bot.sh stats
```

Shows:
- Automated posts vs manual
- Average message length
- Most common activities
- Blockers frequency
- Attendance (posted vs missed)

## Best Practices

1. **Review generated messages**
   - Especially first few weeks
   - Catch inaccuracies
   - Adjust templates

2. **Keep activity up-to-date**
   - Commit regularly
   - Update tickets
   - Keep calendar current

3. **Manual on important days**
   - Major launches
   - Incidents
  - Sensitive updates

4. **Customize style**
   - Match team culture
   - Appropriate detail level
   - Professional tone

5. **Monitor for issues**
   - Check Slack reactions
   - Adjust if team notices
   - Don't abuse automation

## Warnings

- Don't use for critical updates
- Team may notice patterns
- Still attend important standups
- Use responsibly
- Be honest if asked

## Example Schedule

```bash
$ ./scripts/standup-bot.sh schedule "09:00" "Mon,Tue,Wed,Thu,Fri"

Scheduled standup posts:
  Time: 09:00
  Days: Mon,Tue,Wed,Thu,Fri
  Command: ...

Next post: Tomorrow at 09:00
```

## Data Location

```
$DATA_DIR/standup_config.json     # Configuration
$DATA_DIR/standup_history.json    # Past standups
$DATA_DIR/standup_templates.json  # Custom templates
```

## Security

- Slack token stored securely
- Messages only to configured channel
- No PII in automated messages
- Audit log of all posts

## Related Scripts

- `slack-auto-responder.sh` - Auto-respond to messages
- `meeting-excuse-generator.sh` - Decline meetings
- `definitely-working.sh` - Appear active
