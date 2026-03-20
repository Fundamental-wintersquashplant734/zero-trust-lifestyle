# Themed Script Packs

Choose the pack that fits your needs, or install everything!

---

## 🔒 Paranoid Developer Pack
**"Because one mistake can burn everything"**

For developers who handle sensitive data and can't afford OPSEC failures.

### Included Scripts:
- ✅ **opsec-paranoia-check.sh** - Comprehensive security validation (VPN, DNS, webcam, clipboard, metadata)
- ✅ **coffee-shop-lockdown.sh** - Auto-lockdown on untrusted WiFi
- ✅ **git-secret-scanner.sh** - Pre-commit hook that catches secrets before you leak them
- 🔜 **screenshot-sanitizer.sh** - Detects sensitive info in screenshots before sharing *(Planned - not yet implemented)*
- ✅ **browser-history-cleanser.sh** - Smart cleanup before screen shares

### Use Cases:
- Security researchers
- Red team operators
- Privacy-focused developers
- Anyone handling secrets/credentials
- Remote workers on public WiFi

### Quick Install:
```bash
./install.sh --pack paranoid-dev
```

### Automation Setup:
```bash
# Run OPSEC check every 15 min
*/15 * * * * ~/zero-trust-lifestyle/scripts/opsec-paranoia-check.sh --quick

# Start coffee shop monitor on boot
@reboot ~/zero-trust-lifestyle/scripts/coffee-shop-lockdown.sh monitor &
```

---

## 💼 Corporate Survival Pack
**"Automating corporate bullshit since 2025"**

For surviving modern corporate hell with your sanity intact.

### Included Scripts:
- ✅ **slack-auto-responder.sh** - Auto-respond with random excuses, intelligent delays
- ✅ **passive-aggressive-emailer.sh** - Prevent career-ending emails
- ✅ **meeting-prep-assassin.sh** - Auto-OSINT meeting attendees
- ✅ **meeting-excuse-generator.sh** - Auto-decline low-value meetings with plausible excuses
- ✅ **standup-bot.sh** - Generate standup updates from git commits
- ✅ **meeting-cost-calculator.sh** - Real-time meeting cost tracker

### Use Cases:
- Corporate developers
- Remote workers
- Meeting-heavy roles
- Anyone with too much Slack
- People who hate standups

### Quick Install:
```bash
./install.sh --pack corporate-survival
```

### Automation Setup:
```bash
# Slack auto-responder daemon
@reboot ~/zero-trust-lifestyle/scripts/slack-auto-responder.sh monitor &

# Daily standup (9am)
0 9 * * * ~/zero-trust-lifestyle/scripts/standup-bot.sh --auto-post
```

---

## 🕵️ OSINT Hunter Pack
**"Professional stalking, automated"**

For OSINT researchers and threat intelligence professionals.

### Included Scripts:
- ✅ **meeting-prep-assassin.sh** - OSINT automation for meetings
- ✅ **automated-sock-maintenance.sh** - Sockpuppet account automation
- ✅ **paste-site-monitor.sh** - Monitor pastebin for leaks
- ✅ **data-breach-stalker.sh** - Track your identities in breaches
- 🔜 **linkedin-stalker-detector.sh** - Detect who's researching you *(Planned - not yet implemented)*
- 🔜 **domain-watch.sh** - Monitor domain registrations *(Planned - not yet implemented)*

### Use Cases:
- OSINT researchers
- Threat intelligence analysts
- Competitive intelligence
- Security researchers
- Investigative journalists

### Quick Install:
```bash
./install.sh --pack osint-hunter
```

### Automation Setup:
```bash
# Sockpuppet maintenance (3am daily)
0 3 * * * ~/zero-trust-lifestyle/scripts/automated-sock-maintenance.sh maintain-all

# Breach monitoring (every hour)
0 * * * * ~/zero-trust-lifestyle/scripts/data-breach-stalker.sh check

# Paste site monitoring (every 15 min)
*/15 * * * * ~/zero-trust-lifestyle/scripts/paste-site-monitor.sh scan
```

---

## 🧘 Deep Work Pack
**"Protect your focus like your life depends on it"**

For people who need to actually get shit done without interruptions.

### Included Scripts:
- ✅ **slack-auto-responder.sh** - Auto-handle Slack interruptions
- ✅ **coffee-shop-lockdown.sh** - Lock down distractions on untrusted networks
- ✅ **focus-mode-nuclear.sh** - Nuclear option: kill ALL distractions
- ✅ **meeting-excuse-generator.sh** - Auto-decline to protect focus time
- ✅ **pomodoro-enforcer.sh** - Enforced Pomodoro with app blocking

### Use Cases:
- Deep work practitioners
- Developers needing focus
- Writers/creators
- Anyone fighting constant interruptions
- ADHD-friendly productivity

### Quick Install:
```bash
./install.sh --pack deep-work
```

### Automation Setup:
```bash
# Focus mode during core hours (9am-12pm, 2pm-5pm)
0 9,14 * * * ~/zero-trust-lifestyle/scripts/focus-mode-nuclear.sh start --duration 3h
```

---

## 💰 Personal Life Pack
**"Optimizing life so you can focus on work... wait"**

For managing personal life with the same rigor as production systems.

### Included Scripts:
- ✅ **wife-happy-score.sh** - Relationship debt tracker
- ✅ **expense-shame-dashboard.sh** - Financial shame reports
- ✅ **health-nag-bot.sh** - Fitness/health reminders based on activity
- 🔜 **social-battery-monitor.sh** - Track social interaction debt *(Planned - not yet implemented)*
- ✅ **birthday-reminder-pro.sh** - Never forget birthdays with auto gift suggestions

### Use Cases:
- Forgetful partners
- People bad with money
- Health-conscious developers
- Introverts tracking social energy
- Anyone who forgot an anniversary

### Quick Install:
```bash
./install.sh --pack personal-life
```

### Automation Setup:
```bash
# Morning life dashboard (9am)
0 9 * * * ~/zero-trust-lifestyle/scripts/wife-happy-score.sh --dashboard

# Weekly expense shame report (Sunday 8pm)
0 20 * * 0 ~/zero-trust-lifestyle/scripts/expense-shame-dashboard.sh --weekly-report
```

---

## 📦 Installation Options

### Install Everything
```bash
git clone https://github.com/gl0bal01/zero-trust-lifestyle.git
cd zero-trust-lifestyle
./install.sh
```

### Install a Specific Pack
```bash
./install.sh --pack paranoid-dev
./install.sh --pack corporate-survival
./install.sh --pack osint-hunter
./install.sh --pack deep-work
./install.sh --pack personal-life
```

### Mix and Match
```bash
# Install multiple packs
./install.sh --pack corporate-survival --pack deep-work

# Or manually symlink scripts you want
ln -s ~/zero-trust-lifestyle/scripts/slack-auto-responder.sh ~/bin/
```

---

## 🎯 Pack Comparison

| Script | Paranoid Dev | Corporate | OSINT | Deep Work | Personal |
|--------|:------------:|:---------:|:-----:|:---------:|:--------:|
| opsec-paranoia-check.sh | ✅ | | | | |
| coffee-shop-lockdown.sh | ✅ | | | ✅ | |
| git-secret-scanner.sh | ✅ | | | | |
| screenshot-sanitizer.sh | 🔜 | | | | |
| browser-history-cleanser.sh | ✅ | | | | |
| slack-auto-responder.sh | | ✅ | | ✅ | |
| passive-aggressive-emailer.sh | | ✅ | | | |
| meeting-prep-assassin.sh | | ✅ | ✅ | | |
| meeting-excuse-generator.sh | | ✅ | | ✅ | |
| standup-bot.sh | | ✅ | | | |
| meeting-cost-calculator.sh | | ✅ | | | |
| automated-sock-maintenance.sh | | | ✅ | | |
| paste-site-monitor.sh | | | ✅ | | |
| data-breach-stalker.sh | | | ✅ | | |
| linkedin-stalker-detector.sh | | | 🔜 | | |
| domain-watch.sh | | | 🔜 | | |
| focus-mode-nuclear.sh | | | | ✅ | |
| pomodoro-enforcer.sh | | | | ✅ | |
| wife-happy-score.sh | | | | | ✅ |
| expense-shame-dashboard.sh | | | | | ✅ |
| health-nag-bot.sh | | | | | ✅ |
| social-battery-monitor.sh | | | | | 🔜 |
| birthday-reminder-pro.sh | | | | | ✅ |

---

## 🚀 Popular Combinations

### The Remote Worker
```bash
./install.sh --pack corporate-survival --pack deep-work
```
Handle Slack, protect focus time, survive meetings.

### The Security Pro
```bash
./install.sh --pack paranoid-dev --pack osint-hunter
```
OPSEC + research tools for security professionals.

### The Balanced Human
```bash
./install.sh --pack corporate-survival --pack personal-life
```
Survive work, don't forget your anniversary.

### The Hardcore Setup (Everything)
```bash
./install.sh
```
All scripts. Maximum automation. Ultimate paranoia.

---

## 💡 Community Packs

Have an idea for a themed pack? Open an issue or PR!

### Suggested Future Packs:
- **Freelancer Pack** - Invoice tracking, client management, time tracking
- **Content Creator Pack** - Social media automation, engagement tracking
- **DevOps Pack** - Infrastructure monitoring, on-call management
- **Student Pack** - Study tracking, deadline management, grade optimization

---

## 🎓 Learn More

- [Main README](README.md) - Full script list and features
- [Setup Guide](docs/SETUP.md) - Detailed installation instructions
- [License](LICENSE) - MIT License

---

**Choose your pack. Automate your paranoia. Get back to actual work.** 🚀
