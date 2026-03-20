# Random Skill Learner

Picks a random skill for you to learn and enforces it with distraction blocking. "You have 30 days. Twitter is blocked. Learn Rust or stay blocked."

## Overview

Combats decision paralysis by randomly selecting from 12 curated skills, then blocks distractions via `/etc/hosts` modification and tracks your progress through checkpoints. Includes resources, daily practice goals, and project ideas for each skill. Makes you actually learn instead of just planning to learn.

## Features

- 12 curated skills across 10 categories
- Random selection by category or fully random
- Distraction blocking (requires sudo for `/etc/hosts` edits)
- Checkpoint-based progress tracking with evidence
- Practice session logging
- Learning statistics across all completed skills
- Custom skill addition

## Installation

```bash
chmod +x scripts/random-skill-learner.sh
```

## Dependencies

Required:
- `jq` - JSON processing

Optional (for distraction blocking):
- `sudo` access to modify `/etc/hosts`

## Quick Start

```bash
# Let the algorithm pick your skill
./scripts/random-skill-learner.sh pick

# See current learning session
./scripts/random-skill-learner.sh current

# Log a practice session
./scripts/random-skill-learner.sh practice 45
```

## Usage

### Pick a Skill

```bash
# Fully random
./scripts/random-skill-learner.sh pick

# From specific category
./scripts/random-skill-learner.sh pick programming
./scripts/random-skill-learner.sh pick creative
./scripts/random-skill-learner.sh pick language
```

Displays the skill, why it matters, time commitment, learning resources, and checkpoints. Asks for confirmation before starting. On confirm, saves the session and enables distraction blocking (if sudo is available).

### View Current Session

```bash
./scripts/random-skill-learner.sh current
```

Shows current skill, start date, deadline, days remaining, total practice time, and checkpoint progress.

### Log Practice

```bash
# Log 45 minutes
./scripts/random-skill-learner.sh practice 45

# Default: 30 minutes
./scripts/random-skill-learner.sh practice
```

### Complete a Checkpoint

```bash
./scripts/random-skill-learner.sh checkpoint "Completed Rust Book Chapter 1"
./scripts/random-skill-learner.sh checkpoint "Built first CLI tool"
```

Prompts for evidence (description, screenshot path, URL). When all checkpoints are complete, prompts to mark the skill as learned.

### Mark Skill as Learned

```bash
./scripts/random-skill-learner.sh complete
```

Moves the current skill to completed log, disables distraction blocking, and offers to pick the next skill.

### View Statistics

```bash
./scripts/random-skill-learner.sh stats
```

Shows all completed skills, total practice time per skill, and overall learning hours.

### List Available Skills

```bash
./scripts/random-skill-learner.sh list
```

Shows all 12 built-in skills with category, difficulty, estimated time, and checkpoint count. Also shows any custom skills you've added.

### Add Custom Skill

```bash
./scripts/random-skill-learner.sh add NAME CATEGORY DIFFICULTY URL [URL...]

# Examples
./scripts/random-skill-learner.sh add "Go Programming" programming 6 https://go.dev/learn
./scripts/random-skill-learner.sh add "Guitar" life_skills 5 https://www.justinguitar.com
```

### Disable Distraction Blocking

```bash
sudo ./scripts/random-skill-learner.sh unblock
```

Restores `/etc/hosts` from backup.

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `pick` | [CATEGORY] | Pick random skill to learn |
| `list` | - | List all available skills |
| `add` | NAME CAT DIFF URL... | Add custom skill |
| `current` | - | Show current learning session |
| `practice` | MINUTES | Log practice session (default: 30) |
| `checkpoint` | "TEXT" | Complete a checkpoint |
| `complete` | - | Mark skill as learned |
| `stats` | - | Show learning statistics |
| `unblock` | - | Disable distraction blocking |

## Options

| Option | Description |
|--------|-------------|
| `--strict` | Block everything except learning resources |
| `--no-blocking` | Skip distraction blocking entirely |

## The 12 Built-in Skills

### Programming

1. **Rust Programming** - `programming`, difficulty 7/10, 30 days
   - Systems programming, performance, safety
   - Resources: The Rust Book, rust-lang.org, Exercism
   - Projects: CLI todo app, web scraper, simple HTTP server

2. **Docker & Containers** - `devops`, difficulty 5/10, 21 days
   - Essential for modern development
   - Resources: Docker docs, 101 tutorial, awesome-compose
   - Projects: Dockerize a web app, multi-container compose, CI/CD pipeline

### Productivity

3. **Touch Typing** - `productivity`, difficulty 4/10, 30 days
   - 60+ WPM increases productivity 20%
   - Resources: Keybr, Monkeytype, TypingClub
   - Projects: Reach 60 WPM, touch type code

4. **Vim/Neovim** - `productivity`, difficulty 6/10, 30 days
   - Edit at the speed of thought
   - Resources: openvim, vim-adventures, vimtutor
   - Projects: Custom vimrc, 20 vim commands mastered

### Language

5. **Spanish (Conversational)** - `language`, difficulty 8/10, 90 days
   - 500M+ speakers worldwide
   - Resources: Duolingo, SpanishDict, Language Transfer
   - Projects: Daily journal in Spanish, conversation with native speaker

### Data

6. **SQL & Databases** - `data`, difficulty 5/10, 21 days
   - Data is everywhere
   - Resources: SQLZoo, PostgreSQL Tutorial, DB-Fiddle
   - Projects: Database design, query optimization, reporting dashboard

### Creative

7. **Photography Basics** - `creative`, difficulty 4/10, 30 days
   - Creative expression + marketable skill
   - Resources: r-photoclass, Cambridge in Colour, YouTube
   - Projects: Photo series (50 photos), portrait session

8. **Drawing/Sketching** - `creative`, difficulty 6/10, 60 days
   - Visual thinking + creativity
   - Resources: Drawabox, Proko (YouTube), ctrlpaint.com
   - Projects: Sketch 365 challenge, portrait from reference

### AI

9. **Machine Learning Basics** - `ai`, difficulty 8/10, 45 days
   - Future of tech
   - Resources: Coursera ML course, Kaggle Learn, scikit-learn
   - Projects: Housing price predictor, image classifier, Kaggle entry

### Soft Skills

10. **Public Speaking** - `soft_skills`, difficulty 7/10, 30 days
    - Career advancement + influence
    - Resources: Toastmasters, speaking.io, TED Talk analysis
    - Projects: Lightning talk at meetup, YouTube video

### Life Skills

11. **Cooking Fundamentals** - `life_skills`, difficulty 4/10, 30 days
    - Save money, healthier, impress people
    - Resources: Serious Eats, Basics with Babish, Salt Fat Acid Heat
    - Projects: Cook 30 meals in 30 days, host dinner party

### Technical

12. **Linux Command Line** - `technical`, difficulty 5/10, 21 days
    - Essential for developers
    - Resources: Linux Journey, OverTheWire Bandit, Learn Enough
    - Projects: Automate daily task, complete Bandit wargame, build CLI tool

## Distraction Blocking

When you confirm starting a skill, the script adds these sites to `/etc/hosts` (requires sudo):

```
reddit.com, twitter.com, x.com, facebook.com, instagram.com,
tiktok.com, youtube.com, netflix.com, twitch.tv, 9gag.com,
imgur.com, news.ycombinator.com, lobste.rs, linkedin.com, discord.com
```

A backup of your original `/etc/hosts` is saved before modification. Use `unblock` to restore it.

## Example Session

```bash
$ ./scripts/random-skill-learner.sh pick

╔════════════════════════════════════════════════════════════╗
║          📚 THE ALGORITHM PICKS YOUR SKILL 📚           ║
╚════════════════════════════════════════════════════════════╝

You will learn:

    Rust Programming

Why this matters:
  Systems programming, performance, safety

Time commitment:
  • Total: 30 days
  • Daily: Write 50 lines of Rust code

Learning resources:
  • https://doc.rust-lang.org/book/
  • https://www.rust-lang.org/learn
  • https://exercism.org/tracks/rust

Checkpoints (must complete all):
  [ ] Install Rust and run 'Hello World'
  [ ] Understand ownership and borrowing
  [ ] Complete 5 Exercism exercises
  [ ] Build a CLI tool
  [ ] Understand lifetimes

Ready to commit to learning this? (yes/no): yes

[SUCCESS] Started learning: Rust Programming
[INFO] You have 30 days to complete the basics
[INFO] Deadline: 2026-04-15

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Distractions are now blocked. Learn or stay blocked.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ ./scripts/random-skill-learner.sh practice 60
[SUCCESS] Logged 60 minutes of practice

Current Progress:
  Checkpoints: 0/5 (0%)
  Days practiced: 1
  Total time: 60 minutes (1.0 hours)

$ ./scripts/random-skill-learner.sh checkpoint "Install Rust and run 'Hello World'"
Provide evidence (description, screenshot path, URL):
> Screenshot: ~/rust-hello.png

[SUCCESS] Checkpoint completed: Install Rust and run 'Hello World'

Progress: 1/5 checkpoints
```

## Workflow

1. Pick skill: `./scripts/random-skill-learner.sh pick`
2. Distractions get blocked automatically (with sudo)
3. Learn daily (track with: `./scripts/random-skill-learner.sh practice 30`)
4. Complete checkpoints as you hit milestones
5. Mark complete when done: `./scripts/random-skill-learner.sh complete`
6. Pick next skill

## Data Location

```
$DATA_DIR/skills.json              # Skill definitions (built-in + custom)
$DATA_DIR/current_skill.json       # Active learning session
$DATA_DIR/skill_progress.json      # Completed skills log
$DATA_DIR/skill_blocker_sites.txt  # Sites to block
```

## Related Scripts

- `focus-mode-nuclear.sh` - Distraction blocking for work sessions
- `pomodoro-enforcer.sh` - Timed practice sessions
- `fear-challenge.sh` - Face fears through action
