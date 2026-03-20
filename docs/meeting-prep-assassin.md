# Meeting Prep Assassin

Auto-OSINT meeting attendees 5 minutes before meetings. Generates briefings with recent activity, conversation starters, and intel.

## Overview

Automated meeting preparation system that monitors your calendar and performs OSINT (Open Source Intelligence) research on meeting attendees 5 minutes before meetings start. Generates comprehensive briefings with recent activity from GitHub, Twitter, LinkedIn, and blogs. Provides conversation starters, recent projects, and relevant intel to walk into every meeting prepared and informed.

## Features

- Automatic calendar monitoring (Google Calendar/khal)
- Multi-platform OSINT gathering (GitHub, LinkedIn, Twitter)
- Intelligent caching (1-hour TTL)
- Automated briefing generation (Markdown format)
- Recent activity tracking
- Conversation starter suggestions
- Desktop notifications
- Continuous background mode
- Markdown rendering (glow integration)
- Rate limiting protection

## Installation

```bash
chmod +x scripts/meeting-prep-assassin.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - API requests
- `gcalcli` or `khal` - Calendar integration
- `glow` - Markdown rendering (optional)
- `googler` - Blog/article search (optional)

## Optional API Keys

For enhanced functionality:
```bash
export LINKEDIN_API_KEY="your_key"
export GITHUB_TOKEN="your_token"
export TWITTER_BEARER_TOKEN="your_token"
```

## Setup

### Install Calendar Integration

**Google Calendar (Recommended)**
```bash
# Install gcalcli
pip3 install gcalcli

# Authenticate
gcalcli init

# Test
gcalcli agenda
```

**Alternative: khal**
```bash
# Install khal (simpler, no OAuth)
pip3 install khal

# Configure
khal configure
```

### Optional: Install glow for Pretty Briefings

```bash
# macOS
brew install glow

# Linux
# Download from https://github.com/charmbracelet/glow
```

## Usage

### One-Time Briefing

```bash
# Generate briefing for meetings in next 5 minutes
./scripts/meeting-prep-assassin.sh

# Check meetings in next 15 minutes
./scripts/meeting-prep-assassin.sh --minutes 15

# Force briefing for specific meeting
./scripts/meeting-prep-assassin.sh --force "Weekly standup"
```

### Background Monitoring

```bash
# Run continuously (checks every minute)
./scripts/meeting-prep-assassin.sh --continuous &

# Or use nohup for persistent background
nohup ./scripts/meeting-prep-assassin.sh --continuous > ~/meeting-prep.log 2>&1 &
```

### List Upcoming Meetings

```bash
# View upcoming meetings
./scripts/meeting-prep-assassin.sh --list
```

## Commands

| Command | Description |
|---------|-------------|
| Default (no args) | Generate briefing for meetings in next 5 minutes |
| `-m, --minutes MINS` | Check meetings in next MINS minutes |
| `-c, --continuous` | Run continuously in background |
| `-f, --force MEETING` | Force briefing for specific meeting title |
| `-l, --list` | List upcoming meetings |
| `-h, --help` | Show help message |

## OSINT Data Sources

### GitHub
- User profile information
- Recent commits (last 10 events)
- Active repositories
- Issue activity
- Pull request activity

**Example Output:**
```
💻 Recently pushed to awesome-project on GitHub
🎉 Just created new repo: security-tools
🐛 Active in open source - recently worked on issues
```

### Twitter
- Bio and description
- Recent tweets (last 10)
- Follower metrics
- Account creation date

**Example Output:**
```
🐦 Recent tweet: "Just shipped a major feature..."
```

### LinkedIn
- Current company
- Job title
- Recent activity
- Connections

**Example Output:**
```
🏢 Works at Tech Company Inc.
```

### Blog Posts (via googler)
- Recent articles
- Technical blog posts
- Publications

## Briefing Format

Generated briefings are saved as Markdown:

```markdown
# Meeting Brief: Weekly Team Sync
**Time**: 2025-12-05 14:00
**Generated**: 2025-12-05 13:55:00

---

## John Doe (john.doe@company.com)

**Intel:**
💻 Recently pushed to awesome-project on GitHub
🐦 Recent tweet: "Excited about our new architecture..."
🏢 Works at Tech Company Inc.

**Conversation Starters:**
- Ask about recent GitHub projects
- Reference their latest tweets/posts
- Congratulate on recent achievements

---

## Jane Smith (jane.smith@company.com)

**Intel:**
🎉 Just created new repo: data-pipeline-v2
💻 Recently pushed to ml-models on GitHub

**Conversation Starters:**
- Ask about recent GitHub projects
- Reference their latest tweets/posts
- Congratulate on recent achievements

---
```

## Example Workflow

```bash
# 1. Set up calendar integration
pip3 install gcalcli
gcalcli init

# 2. Test with upcoming meetings
./scripts/meeting-prep-assassin.sh --list

# Output:
# Upcoming meetings:
# 2025-12-05 14:00|Weekly Team Sync|abc123
# 2025-12-05 15:30|1:1 with Manager|def456

# 3. Generate test briefing
./scripts/meeting-prep-assassin.sh --minutes 120

# Output:
# Found meeting: Weekly Team Sync at 2025-12-05 14:00
# Researching: john.doe@company.com
# Researching: jane.smith@company.com
# Briefing created: $DATA_DIR/meeting-briefings/20251205_1400_Weekly_Team_Sync.md

# 4. View briefing
cat $DATA_DIR/meeting-briefings/20251205_1400_Weekly_Team_Sync.md

# Or with glow for pretty rendering:
glow $DATA_DIR/meeting-briefings/20251205_1400_Weekly_Team_Sync.md

# 5. Start continuous monitoring
./scripts/meeting-prep-assassin.sh --continuous &

# Runs in background
# Checks every minute for upcoming meetings
# Auto-generates briefings 5 minutes before
# Sends desktop notifications
```

## Continuous Monitoring

When running in continuous mode:

```bash
./scripts/meeting-prep-assassin.sh --continuous &

# Behavior:
# - Checks calendar every 60 seconds
# - Detects meetings starting in next 5 minutes
# - Generates briefing automatically
# - Sends desktop notification
# - Displays briefing (with glow if available)
# - Continues monitoring
```

### Systemd Service (Linux)

```ini
# /etc/systemd/system/meeting-prep.service
[Unit]
Description=Meeting Prep Assassin
After=network.target

[Service]
Type=simple
User=%i
ExecStart=/path/to/meeting-prep-assassin.sh --continuous
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Enable service
sudo systemctl enable meeting-prep.service
sudo systemctl start meeting-prep.service
```

### Cron Alternative

```bash
# Check every 5 minutes
*/5 * * * * /path/to/meeting-prep-assassin.sh --minutes 10
```

## OSINT Process

### 1. Extract Attendees

```bash
# From calendar event
# Extracts email addresses
# Filters out your own email
# Results: john.doe@company.com, jane.smith@company.com
```

### 2. Derive Usernames

```bash
# From email: john.doe@company.com
# Extracted username: johndoe

# Pattern matching:
# firstname.lastname@domain.com → firstnamelastname
# firstname_lastname@domain.com → firstnamelastname
```

### 3. Query Public APIs

```bash
# GitHub API
curl https://api.github.com/users/johndoe

# Twitter API
curl https://api.twitter.com/2/users/by/username/johndoe

# LinkedIn (requires API key)
# Public profile search
```

### 4. Cache Results

```bash
# Cached for 1 hour (3600 seconds)
# Stored in: $DATA_DIR/osint-cache/
# Files: github_johndoe.json, twitter_johndoe.json
# Prevents API rate limiting
```

### 5. Generate Talking Points

```bash
# Analyze recent activity
# Extract interesting facts
# Generate conversation starters
# Format as Markdown
```

## Configuration

### Cache Settings

```bash
CACHE_TTL=3600                # 1 hour cache
CACHE_DIR="$DATA_DIR/osint-cache"
```

### API Rate Limiting

Script includes built-in delays:
- GitHub: Public API (60 req/hour unauthenticated, 5000 with token)
- Twitter: Bearer token required
- LinkedIn: API key required

### Notification Settings

Desktop notifications sent when briefings are ready:
```bash
notify "Meeting Prep Ready" "Briefing for 'Weekly Standup' is ready!"
```

## Data Storage

All data in `$DATA_DIR`:
```
meeting-briefings/            # Generated briefings
  20251205_1400_Weekly_Team_Sync.md
  20251205_1530_1on1_with_Manager.md

osint-cache/                  # Cached API responses
  github_johndoe.json
  twitter_johndoe.json
  linkedin_abc123.json
```

## Privacy and Ethics

### Legitimate Use Cases
- Preparing for professional meetings
- Research on public profiles only
- Understanding team member backgrounds
- Finding common interests
- Professional networking

### Best Practices
1. **Public Data Only** - No private profiles
2. **Professional Context** - Business meetings only
3. **Respectful Use** - Don't weaponize information
4. **Accurate Attribution** - Use info appropriately
5. **Privacy Awareness** - Some people prefer privacy

### What NOT to Do
- Don't stalk people
- Don't use for personal relationships
- Don't share sensitive findings
- Don't violate platform ToS
- Don't bypass privacy settings

## Troubleshooting

### No Meetings Found

```bash
# Check calendar integration
gcalcli agenda

# Verify credentials
ls ~/.gcalcli_oauth

# Re-authenticate
gcalcli init
```

### No Attendees Extracted

```bash
# Meeting might not have attendees in metadata
# Try manual mode:
./scripts/meeting-prep-assassin.sh --force "Meeting Title"

# Check gcalcli output format:
gcalcli search "meeting name"
```

### API Rate Limiting

```bash
# GitHub: Use personal access token
export GITHUB_TOKEN="ghp_your_token_here"

# Increases limit from 60 to 5000 req/hour

# Twitter: Requires bearer token
export TWITTER_BEARER_TOKEN="your_token"

# LinkedIn: Requires API key (complex approval process)
```

### Cache Not Working

```bash
# Clear cache
rm -rf $DATA_DIR/osint-cache/*

# Check cache directory exists
mkdir -p $DATA_DIR/osint-cache

# Verify cache TTL
# Files older than 1 hour are refreshed
```

### Briefing Not Displaying

```bash
# Install glow for pretty rendering
brew install glow  # macOS
# or download from GitHub for Linux

# Without glow, briefings are shown with cat
# Still readable, just not as pretty
```

## Advanced Features

### Custom Research Queries

Edit `search_public_info()` function to add:
- Custom blog searches
- Domain-specific searches
- Company research
- Project background

### Integration with Notes

```bash
# Copy briefings to notes system
cp $DATA_DIR/meeting-briefings/*.md ~/notes/meetings/

# Or create symlinks
ln -s $DATA_DIR/meeting-briefings ~/notes/
```

### Pre-meeting Checklists

Briefings can include:
- Agenda items
- Previous meeting notes
- Action items
- Background context

## Example OSINT Findings

### High-Value Intel

```
## Sarah Johnson (sarah.j@startup.com)

**Intel:**
💻 Recently pushed to payment-gateway-v3 on GitHub
🎉 Just created new repo: microservices-arch
🐦 Recent tweet: "Finally migrated to Kubernetes! 🎉"
🏢 Works at Fast Growth Startup

**Conversation Starters:**
- Ask about the payment gateway v3 project
- Discuss Kubernetes migration experience
- Talk about microservices architecture
```

### Limited Public Info

```
## Bob Smith (bob@corp.com)

**Intel:** Limited public information available

**Approach:** Standard professional introduction
```

## Statistics and Metrics

Track your preparation:
- Briefings generated
- Meetings researched
- OSINT sources used
- Time saved vs manual research

## Best Practices

1. **Run Before Important Meetings**
   ```bash
   # Executive meetings, client calls, interviews
   ./scripts/meeting-prep-assassin.sh --minutes 30
   ```

2. **Review Briefings 5 Min Before**
   - Quick scan of talking points
   - Note recent activity
   - Prepare questions

3. **Respect Privacy**
   - Use public info only
   - Don't mention you researched them
   - Keep intel professional

4. **Combine with Other Prep**
   - Read meeting agenda
   - Review previous notes
   - Prepare your updates

5. **Update API Tokens**
   ```bash
   # Rotate tokens regularly
   # Check rate limits
   # Monitor API usage
   ```

## Integration with Other Scripts

### With Meeting Excuse Generator

```bash
# Generate briefing for meetings you're attending
# Skip declined meetings
```

### With Calendar Management

```bash
# Auto-block prep time before important meetings
# Mark briefing completion in calendar
```

## Related Scripts

- `meeting-excuse-generator.sh` - Auto-decline low-value meetings
- `meeting-cost-calculator.sh` - Real-time meeting cost tracking
- `linkedin-stalker-detector.sh` - Detect who's viewing your profile
- `automated-sock-maintenance.sh` - Manage multiple identities
