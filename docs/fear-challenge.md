# Fear Challenge

Algorithm-driven fear confrontation system. The algorithm picks your fear, schedules it, and requires evidence of completion. No excuses.

## Overview

Systematically face your fears through a challenge scheduling system. Pick challenges from a built-in database of 60+ challenges across 6 categories, add your own, track completions with evidence, and watch your difficulty level progress automatically. The algorithm removes choice paralysis - it decides, you do it.

## Features

- 60+ built-in challenges across 6 categories
- Progressive difficulty (auto-scales as you complete more)
- Custom challenge database (add your own)
- Evidence requirement for completion (photo, URL, description)
- Overdue challenge detection
- Upcoming schedule view
- Completion statistics
- Harsh motivation mode

## Installation

```bash
chmod +x scripts/fear-challenge.sh
```

## Dependencies

- `jq` - JSON processing

## Quick Start

```bash
# Let the algorithm pick your challenge
./scripts/fear-challenge.sh pick

# See what you've got scheduled
./scripts/fear-challenge.sh upcoming

# Mark a challenge complete
./scripts/fear-challenge.sh complete
```

## Usage

### Pick a Challenge

```bash
# Progressive difficulty (recommended - scales with your progress)
./scripts/fear-challenge.sh pick

# Pick within specific difficulty (1-10)
./scripts/fear-challenge.sh pick 3

# Pick with extreme difficulty
./scripts/fear-challenge.sh pick --extreme

# Pick easy challenges
./scripts/fear-challenge.sh pick --easy

# Pick with brutal motivation mode
./scripts/fear-challenge.sh --harsh pick
```

The algorithm picks a random challenge, displays it, schedules it 7 days out, and sets up a reminder.

### List All Challenges

```bash
./scripts/fear-challenge.sh list
```

Lists all challenges in the built-in database grouped by category and difficulty. Also shows any custom challenges you've added.

### Add Custom Challenge

```bash
./scripts/fear-challenge.sh add CATEGORY DIFFICULTY "CHALLENGE TEXT"

# Examples
./scripts/fear-challenge.sh add social 5 "Give a TED talk"
./scripts/fear-challenge.sh add professional 8 "Pitch to investors"
./scripts/fear-challenge.sh add extreme 9 "Shave your head for charity"
```

Difficulty is 1-10. Categories: `social`, `physical`, `creative`, `professional`, `personal`, `extreme`.

### Mark Challenge Complete

```bash
# Complete the current active challenge (prompts for evidence)
./scripts/fear-challenge.sh complete

# Complete a specific challenge by text
./scripts/fear-challenge.sh complete "Give a 5-minute presentation"
```

Prompts for evidence (photo path, URL, or description). Evidence is required by default - if you skip it, you'll be asked to confirm completion without proof.

### View Upcoming Challenges

```bash
./scripts/fear-challenge.sh upcoming
```

Shows all scheduled, incomplete challenges sorted by due date.

### Check Overdue Challenges

```bash
./scripts/fear-challenge.sh overdue
```

Shows challenges past their due date. Also displayed automatically when running any command (except `overdue` and `stats`).

### View Statistics

```bash
./scripts/fear-challenge.sh stats
```

Shows total completions, this month's count, recent completions, and your current difficulty level (calculated from how many challenges you've completed).

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `pick` | [DIFFICULTY] | Pick and schedule a challenge |
| `list` | - | List all available challenges |
| `add` | CAT DIFF "CHALLENGE" | Add custom challenge |
| `complete` | [CHALLENGE] | Mark challenge as complete |
| `upcoming` | - | Show scheduled challenges |
| `overdue` | - | Check for overdue challenges |
| `stats` | - | Show completion statistics |

## Options

| Option | Description |
|--------|-------------|
| `--harsh` | Enable brutal honesty motivation mode |
| `--easy` | Pick challenges with difficulty 3 or lower |
| `--extreme` | Pick challenges with difficulty up to 10 |

## Built-in Challenge Categories

### Social (Difficulties 1-5)

Easy: make eye contact with a stranger, say hello to someone you don't know, ask a stranger the time.

Medium: speak up in a meeting, ask a question in front of 10+ people, call someone instead of texting.

Harder: give a 5-minute presentation, attend a social event alone, do karaoke in front of people.

### Physical (Difficulties 2-4)

Do 10 pushups, go rock climbing, try a group fitness class, learn to swim.

### Creative (Difficulties 2-4)

Write 500 words and show someone, publish a blog post, share your creative work on social media, enter a creative competition.

### Professional (Difficulties 3-5)

Ask for a raise, give constructive feedback, network with someone senior, speak at a conference, negotiate your salary.

### Personal (Difficulties 2-4)

Try food you've never had, travel somewhere new alone, tell someone how you really feel, set a boundary with someone.

### Extreme (Difficulty 7)

Stand-up comedy open mic, quit something making you miserable, go skydiving, shave your head.

## Progressive Difficulty

Your difficulty level starts at 1 and increases automatically:

```
Challenges completed:  0-2   → Difficulty 1
Challenges completed:  3-5   → Difficulty 2
Challenges completed:  6-8   → Difficulty 3
...and so on up to 10
```

When you use `pick` without a difficulty argument, the algorithm matches challenges to your current level.

## Example Workflow

```bash
# Day 1: Get your first challenge
$ ./scripts/fear-challenge.sh pick

╔════════════════════════════════════════════════════════════╗
║          🎲 THE ALGORITHM HAS DECIDED 🎲                ║
╚════════════════════════════════════════════════════════════╝

Your challenge:

    Say hello to someone you don't know

Due date: 2026-03-23

"Everything you want is on the other side of fear." - Jack Canfield

No excuses. The algorithm has spoken.

# Check what's coming up
$ ./scripts/fear-challenge.sh upcoming

📅 Upcoming Challenges

  • 2026-03-23 - Say hello to someone you don't know

# After completing it
$ ./scripts/fear-challenge.sh complete

Challenge Completion

Current challenge: Say hello to someone you don't know

Provide evidence (photo path, description, URL):
> Talked to the barista at the coffee shop, had a full 2-minute conversation

💪 CHALLENGE COMPLETED!

Total challenges completed: 1
This month: 1

Current difficulty level: 1/10

Schedule next challenge now? (yes/no): yes
```

## Data Storage

```
$DATA_DIR/fears.json                   # Challenge database (built-in + custom)
$DATA_DIR/challenges_completed.json    # Completion log
$DATA_DIR/challenge_schedule.json      # Scheduled challenges
```

## Philosophy

- Fear is a compass pointing to growth
- Discomfort is where you expand
- The algorithm removes choice paralysis
- Evidence prevents self-deception
- Progressive difficulty prevents overwhelming
- No skipping - face it or reschedule

## Related Scripts

- `random-skill-learner.sh` - Learn new skills systematically
- `health-nag-bot.sh` - Health accountability tracking
