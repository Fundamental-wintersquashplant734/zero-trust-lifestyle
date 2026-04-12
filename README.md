# zero-trust-lifestyle

**I got so paranoid I automated my paranoia. 33 bash scripts later, my entire life runs on cron jobs.**

```
xxx: So I'm going through my colleague's scripts folder
xxx: This security researcher has automated their entire life
xxx: You're not gonna believe this shit
```

```bash
$ ./scripts/wife-happy-score.sh
  REMINDER SUMMARY:
  Days since flowers: 47
  Days since date night: 23
  Anniversary in: 3 days
  SUGGESTION: Maybe plan something thoughtful? Here are some ideas.
```

## The Greatest Hits

These are the scripts people can't stop sharing:

**[wife-happy-score.sh](scripts/wife-happy-score.sh)** - _Daily morning reminder_
A scheduling aid and reminder tool for relationship-related dates: date nights, flower deliveries, upcoming anniversaries, and similar events. Can also do basic text message sentiment analysis (keyword and emoji frequency). **Disclaimer: this is a reminder/tracking tool only, not a substitute for genuine emotional connection.** Sending flowers on schedule does not guarantee relationship health -- it just means you won't forget the date. Sentiment tracking measures word frequency, not how your partner actually feels. Use these reminders as a starting point for real conversations, not as a replacement for them.

**[definitely-working.sh](scripts/definitely-working.sh)** - _You're definitely at your desk_
Simulates mouse activity to prevent idle status using xdotool. Supports subtle mode and optional keyboard activity. Note: many corporate endpoint monitoring tools (e.g., CrowdStrike, Microsoft Defender for Endpoint, Teramind) can distinguish software-generated input from physical device input by inspecting event flags, process origins, and input timing patterns. This script may fool basic idle timers but should not be assumed to evade dedicated monitoring software. Use of this script may also violate your employer's acceptable use policy.

**[passive-aggressive-emailer.sh](scripts/passive-aggressive-emailer.sh)** - _Career insurance_
Sentiment analysis on outgoing emails. Detects ALL CAPS, "per my last email", swearing, sending to executives at 2am. Can enforce a configurable cooling-off period before sending.

**[meeting-excuse-generator.sh](scripts/meeting-excuse-generator.sh)** - _Calendar liberation_
Auto-declines low-value meetings with professional excuses. Tracks time saved. "This week: 4.5 hours saved from declined meetings."

**[standup-bot.sh](scripts/standup-bot.sh)** - _Daily at 9am_
Generates standup updates from git commits. Translates "fixed bug" -> "Resolved critical production system issue impacting user experience". Corporate speak mode. Auto-posts to Slack.

**[expense-shame-dashboard.sh](scripts/expense-shame-dashboard.sh)** - _Financial reality check_
Import bank CSV, generate shame reports showing how much you waste on coffee, subscriptions, and impulse buys. Converts to work hours.

**[bullshit-jargon-translator.sh](scripts/bullshit-jargon-translator.sh)** - _Decode the corporate matrix_
Translates "let's circle back and synergize on the deliverables" into what they actually mean.

```
xxx: The meeting prep one is actually genius
xxx: It pulled up the guy's recent tweets and GitHub commits
xxx: I looked SO prepared in that meeting
xxx: I'm keeping all of these
```

## Security & OPSEC

**[opsec-paranoia-check.sh](scripts/opsec-paranoia-check.sh)** - _Every 15 minutes_
VPN status, webcam check, DNS leak detection, clipboard scanning, GPS metadata in recent files, microphone status, Tor running... the full paranoia suite.

**[coffee-shop-lockdown.sh](scripts/coffee-shop-lockdown.sh)** - _Continuous monitoring_
Detects public WiFi, immediately kills sensitive apps, enables VPN tunnel, blocks non-HTTPS traffic, clears clipboard, locks password manager. Giant red warning on screen.

**[automated-sock-maintenance.sh](scripts/automated-sock-maintenance.sh)** - _Daily at 3am_
Automates activity on multiple accounts by performing randomized interactions (likes, generic comments). Each persona has a configurable personality profile. Uses Headless Chrome with proxy support. Note: this violates most platforms' Terms of Service and accounts may still be detected and banned despite countermeasures.

**[git-secret-scanner.sh](scripts/git-secret-scanner.sh)** - _Pre-commit hook_
Scans for AWS keys, GitHub tokens, private keys, and passwords using regex and entropy checks before you commit them. Catches common patterns but won't detect obfuscated or encoded secrets, and can be bypassed with `--no-verify`. Shows cost estimate of what you almost leaked.

**[canary-token-generator.sh](scripts/canary-token-generator.sh)** - _Know when someone snoops_
Generate canary tokens: email tracking pixels, PDF/Word canaries, DNS tokens, honeypot AWS credentials. Know exactly when, where, and from what IP someone accessed your stuff.

**[delete-me-from-internet.sh](scripts/delete-me-from-internet.sh)** - _Take back your data_
Submits opt-out requests to 20+ data brokers (Spokeo, WhitePages, BeenVerified, and more). CCPA/GDPR email templates, progress tracking. Note: brokers often re-aggregate data from other sources, so opt-outs need to be re-run periodically to stay effective.

**[data-breach-stalker.sh](scripts/data-breach-stalker.sh)** - _Know when you're exposed_
Monitor your emails and domains across breach databases. HIBP integration, dark web paste monitoring, alerts on new exposures.

**[paste-site-monitor.sh](scripts/paste-site-monitor.sh)** - _Monitor for your data in the wild_
Scans Pastebin and GitHub gists for your emails, domains, or keywords. Scheduled monitoring with alerts.

## Productivity & Focus

**[meeting-prep-assassin.sh](scripts/meeting-prep-assassin.sh)** - _5 mins before meetings_
Auto-OSINT's everyone in your calendar. LinkedIn, GitHub, Twitter, blog posts. "Sarah just launched a side project, ask about it."

**[slack-auto-responder.sh](scripts/slack-auto-responder.sh)** - _Professional ignoring_
Auto-responds to Slack with configurable replies. 1-10 minute delays, urgency detection, won't spam the same person. Intended to reduce interruptions during focus time.

**[focus-mode-nuclear.sh](scripts/focus-mode-nuclear.sh)** - _The nuclear option_
4 escalation levels from gentle website blocking to full system lockdown. Kills distracting apps, blocks social media at hosts level, disables notifications.

**[pomodoro-enforcer.sh](scripts/pomodoro-enforcer.sh)** - _Pomodoro with teeth_
Pomodoro timer that actually blocks distractions during work sessions. App killing, notification silencing. Emergency unblock for real emergencies.

**[youtube-rabbit-hole-killer.sh](scripts/youtube-rabbit-hole-killer.sh)** - _2 videos maximum_
After 2 videos, blocks YouTube and shows "GO DO SOMETHING USEFUL". Daily reset at 4 AM. "You've watched 2 videos. That's enough. Go build something."

**[random-skill-learner.sh](scripts/random-skill-learner.sh)** - _Learn or stay blocked_
Picks random skill, blocks ALL distractions until you complete checkpoints. 12 skills: Rust, Docker, SQL, Vim, ML, Spanish... "You have 30 days. Twitter is blocked. Learn Rust or stay blocked."

## Personal Life & Self-Improvement

**[fear-challenge.sh](scripts/fear-challenge.sh)** - _The algorithm picks your growth_
Randomly selects something you're afraid of and schedules you to face it. Progressive difficulty, evidence required. "The algorithm decided. You're doing it."

**[health-nag-bot.sh](scripts/health-nag-bot.sh)** - _Your passive-aggressive fitness coach_
Tracks steps, water, sleep, workouts. Escalating nag levels from gentle reminders to lockout mode.

**[monk-mode-fasting.sh](scripts/monk-mode-fasting.sh)** - _Intermittent fasting tracker_
Fasting timer with multiple protocols (16:8, 20:4, OMAD). Journal, streak tracking, statistics. SQLite-backed.

**[sovereign-routine.sh](scripts/sovereign-routine.sh)** - _Full daily routine automation_
Morning routine, daily tracking, habit management, journaling, energy levels. SQLite-backed with streaks.

**[birthday-reminder-pro.sh](scripts/birthday-reminder-pro.sh)** - _Never forget again_
Birthday tracking with auto gift suggestions. Because forgetting is not an option.

## More Tools

**[tech-interview-revenge.sh](scripts/tech-interview-revenge.sh)** - _Flip the script_
Research companies, detect red flags, generate reverse interview questions, detect free labor in take-homes. "They asked me to do a take-home. I automated their entire hiring process."

**[cofounder-background-check.sh](scripts/cofounder-background-check.sh)** - _Before you sign anything_
OSINT background check for potential co-founders. Court records, social media, business history, red flags.

**[ctf-writeup-scraper.sh](scripts/ctf-writeup-scraper.sh)** - _When you're stuck_
Scrapes CTFTime, GitHub, and Medium for CTF writeups. Search by category, difficulty, or challenge name.

**[browser-history-cleanser.sh](scripts/browser-history-cleanser.sh)** - _Before screen shares_
Smart browser history cleanup. By domain, time range, or nuke everything. Firefox, Chrome, Brave.

**[github-contribution-faker.sh](scripts/github-contribution-faker.sh)** - _For demo purposes only_
Create realistic-looking contribution graphs. Multiple patterns (9-to-5, night owl, weekend warrior). Dry-run mode.

**[meeting-cost-calculator.sh](scripts/meeting-cost-calculator.sh)** - _Put a price on wasted time_
Real-time meeting cost based on attendee salaries. Shows what the meeting costs in Starbucks coffees.

**[suspect-awake-alert.sh](scripts/suspect-awake-alert.sh)** - _Activity pattern monitoring_
Detects unusual online activity hours (authorized use only). Requires explicit consent. Encrypted data.

## The Story

These scripts were born from real frustration:

- **OPSEC checks**: After accidentally committing AWS keys with GPS metadata
- **Sock maintenance**: After losing multiple accounts to inactivity purges
- **Meeting prep**: After being embarrassed by not knowing a VC just changed firms
- **Email delay**: After a 2am drunk email to CEO about "agile bullshit"
- **Relationship reminders**: After forgetting anniversary. Twice. Same year. (The script reminds you -- the rest is on you.)
- **Coffee shop lockdown**: After doing Red Team work on Starbucks WiFi

## Installation

```bash
git clone https://github.com/gl0bal01/zero-trust-lifestyle.git
cd zero-trust-lifestyle

# Install everything (with interactive cron/systemd setup)
./install.sh

# Or install a themed pack
./install.sh --pack paranoid-dev

# Or just one script
./install.sh --script wife-happy-score
```

**Requirements**: Bash 4.0+, curl, jq. Some scripts need API keys or Python - see [docs/SETUP.md](docs/SETUP.md).

## Themed Packs

Don't need everything? Pick a pack:

- **`--pack paranoid-dev`** - OPSEC + secrets scanning + lockdown
- **`--pack corporate-survival`** - Slack + meetings + email + standup
- **`--pack osint-hunter`** - Research + sockpuppets + monitoring
- **`--pack deep-work`** - Focus protection + distraction killing
- **`--pack personal-life`** - Reminders & scheduling aids + finances + health

[See all packs and features](PACKS.md)

## Safety & Ethics

- **Sockpuppet automation**: Check platform ToS. Use responsibly.
- **OSINT on colleagues**: Don't be creepy. Public info only.
- **Email sentiment**: Can be bypassed with `--force` flag.
- **Relationship tracking**: These are reminder and scheduling tools only. Automating gift purchases or tracking sentiment metrics is not a substitute for genuine communication, empathy, or emotional effort. Relationships require real human engagement, not optimization.

## FAQ

**Q: Is this legal?**
A: Using public APIs and public information = legal. Violating ToS = your problem. Check local laws.

**Q: Will this get my accounts banned?**
A: Sock-maintenance automates account activity, which violates most platforms' Terms of Service. Even with proxies and rate limiting, detection and bans are likely. Use at your own risk.

**Q: Does wife-happy-score actually work?**
A: It sends date and event reminders -- nothing more. It cannot measure or maintain a relationship. Whether you show up with genuine care and attention determines success, not whether a cron job reminded you to order flowers.

**Q: Can I use this for actual threat intelligence?**
A: Several scripts (OPSEC check, coffee-shop lockdown, git-secret-scanner) perform useful security checks, but they have not been independently audited. Evaluate them against your own requirements before relying on them.

## Contributing

PRs welcome! Especially for:

- [ ] Additional OSINT sources for meeting-prep
- [ ] More email sentiment patterns (corporate speak detection)
- [ ] Platform-specific sock-maintenance (Instagram, TikTok)
- [ ] Mobile companion app for alerts
- [ ] Windows native support (currently WSL only)

## License

MIT License - Use at your own risk. Author not responsible for:
- Account bans
- Relationship problems caused by substituting reminders for genuine effort
- OPSEC failures despite using these scripts
- Career damage from emails sent with `--force` flag

A collection of automation scripts for security-conscious users.
