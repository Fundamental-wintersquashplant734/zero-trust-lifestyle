# GitHub Contribution Faker

Keep your GitHub contribution graph green during vacation with realistic commit patterns and fake streak maintenance.

## Overview

Automates GitHub commits to maintain contribution streaks while on vacation or during private work periods. Creates realistic commit patterns based on your actual habits, generates believable commit messages, supports multiple modes (normal, vacation, stealth, learning), and includes extensive safeguards. A statement about the meaninglessness of contribution graphs as productivity metrics.

## Features

- Realistic commit timing and frequency
- Multiple operation modes
- Pattern analysis of your actual commits
- Believable commit messages (doc updates, learning notes, TIL entries)
- Dry-run mode (default, safe)
- Auto-creates daily notes or TIL repository
- Streak tracking and statistics
- GitHub CLI integration
- Stealth mode (mimics your patterns)

## Installation

```bash
chmod +x scripts/github-contribution-faker.sh
```

## Dependencies

- `git` - Version control
- `jq` - JSON processing
- `gh` - GitHub CLI (optional, for repo creation)

## Usage

### Initialize Repository

```bash
./scripts/github-contribution-faker.sh init notes
# or
./scripts/github-contribution-faker.sh init til
```

Creates a notes/TIL repository for commits.

### Analyze Your Patterns

```bash
./scripts/github-contribution-faker.sh analyze ~/code/my-project
```

Analyzes your actual commit patterns for stealth mode.

### Test (Dry Run)

```bash
./scripts/github-contribution-faker.sh commit-if-needed
```

Shows what would be committed (safe, no actual commits).

### Enable and Run

```bash
./scripts/github-contribution-faker.sh enable
./scripts/github-contribution-faker.sh --no-dry-run commit-if-needed
```

### View Status

```bash
./scripts/github-contribution-faker.sh status
```

## Commands

| Command | Description |
|---------|-------------|
| `init [notes\|til]` | Initialize repository |
| `start` | Start faker (respects dry-run mode) |
| `commit-if-needed` | Make commit if needed today |
| `status` | Show statistics |
| `enable` | Enable faker (disable dry-run) |
| `disable` | Disable faker |
| `analyze [REPO]` | Analyze your commit patterns |

## Modes

### Normal Mode
- 1-5 commits per weekday
- 20% chance of weekend commits
- Mixed message types
- Morning/afternoon/evening windows

### Vacation Mode
```bash
./scripts/github-contribution-faker.sh --mode vacation commit-if-needed
```
- 1-2 commits per week
- Looks like light maintenance
- Lower frequency

### Stealth Mode
```bash
./scripts/github-contribution-faker.sh --mode stealth commit-if-needed
```
- Mimics your actual patterns
- Uses analyzed time windows
- Matches your typical frequency

### Learning Mode
```bash
./scripts/github-contribution-faker.sh --mode learning commit-if-needed
```
- 1 commit per day
- Learning journal entries
- TIL format

## Commit Message Types

### Documentation
- "Update README"
- "Fix typos in documentation"
- "Improve documentation clarity"
- "Add examples to README"

### Maintenance
- "Refactor for clarity"
- "Clean up code"
- "Update dependencies"
- "Improve code organization"

### Learning/TIL
- "TIL: async programming patterns"
- "Today I learned about database optimization"
- "Add daily notes"
- "Update learning journal"

## Automation

### Cron Job

```bash
# Random time daily
0 */6 * * * /path/to/github-contribution-faker.sh commit-if-needed
```

### Options

```bash
--mode MODE          # normal, vacation, stealth, learning, til
--dry-run            # Show what would happen (default)
--no-dry-run         # Actually create commits (CAREFUL!)
```

## Ethical Disclaimer

### Why This Exists

GitHub contribution graphs are **broken metrics**. They:
- Ignore private repository work
- Punish vacation time
- Ignore code review, mentoring, documentation
- Create performative commit behavior
- Measure visibility, not value

### Acceptable Use

✅ Maintain streaks during legitimate time off
✅ Reflect work not captured by public commits
✅ Make a statement about meaningless metrics
✅ Keep consistent appearance during private work

### Unacceptable Use

❌ Lie to employers about your work
❌ Fake experience for job applications
❌ Spam public repositories
❌ Misrepresent actual productivity

## Configuration

Edit in script:
```bash
WEEKDAY_MIN_COMMITS=1
WEEKDAY_MAX_COMMITS=5
WEEKEND_PROBABILITY=20
DRY_RUN=1  # Always start with dry-run
```

## Data Storage

```
$DATA_DIR/github_faker_config.json   # Configuration
$DATA_DIR/github_faker_history.json  # Commit history
$DATA_DIR/.commit_pattern            # Analyzed patterns
```

## Safety Features

1. **Dry-run by default** - Must explicitly enable
2. **Requires explicit enable command**
3. **Tracks fake vs. real commits**
4. **Easy to disable**
5. **Disclaimer on first run**

## Example Output

```
╔════════════════════════════════════════╗
║  GitHub Contribution Faker Status      ║
╚════════════════════════════════════════╝

Current Streak: 45 days
Total Commits: 250
  Real: 180 (72%)
  Fake: 70 (28%)

Target Repo: /home/user/code/daily-notes
Mode: vacation
Faker: ENABLED
Dry Run: OFF

Recent Commits:
  - 2024-12-05 14:30: Update learning journal
  - 2024-12-04 10:15: TIL: system design
  - 2024-12-03 16:45: Add daily notes
```

## Related Scripts

- `automated-sock-maintenance.sh` - Sockpuppet account maintenance
- `definitely-working.sh` - Anti-AFK script
