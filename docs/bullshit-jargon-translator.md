# Bullshit Jargon Translator

Converts startup and corporate jargon into plain English with severity ratings.

## Overview

Automatically detects and translates corporate speak, startup buzzwords, and meaningless jargon into honest, straightforward language. Helps you understand what people are actually saying in meetings, emails, and job descriptions.

## Features

- 100+ jargon translations organized by category
- Severity levels: buzzword, warning, red_flag, run_away
- Real-time text translation
- Detection statistics and tracking
- Multiple input methods (interactive, file, stdin)
- BS severity scoring

## Installation

```bash
chmod +x scripts/bullshit-jargon-translator.sh
```

## Usage

### Interactive Mode

```bash
./scripts/bullshit-jargon-translator.sh interactive
```

Paste your text and press Enter twice to translate.

### Translate from File

```bash
./scripts/bullshit-jargon-translator.sh translate job_description.txt
```

### Translate from Stdin

```bash
echo "We're pivoting to leverage blockchain synergies" | ./scripts/bullshit-jargon-translator.sh translate
cat email.txt | ./scripts/bullshit-jargon-translator.sh translate
```

### View Common Phrases

```bash
./scripts/bullshit-jargon-translator.sh phrases
```

### View Statistics

```bash
./scripts/bullshit-jargon-translator.sh stats
```

### Run Test

```bash
./scripts/bullshit-jargon-translator.sh test
```

## Commands

| Command | Description |
|---------|-------------|
| `interactive` | Interactive translation mode |
| `translate [FILE]` | Translate from file or stdin |
| `phrases` | Show common jargon reference |
| `stats` | Show detection statistics |
| `test` | Run sample translation |

## Options

| Option | Description |
|--------|-------------|
| `--no-color` | Disable colored output |
| `--no-severity` | Don't show severity levels |
| `--no-category` | Don't show jargon categories |

## Translation Categories

### Failure Disguises
- "we're pivoting" → "we failed"
- "strategic shift" → "we're panicking and changing everything"
- "rightsizing" → "layoffs"
- "course correction" → "we were wrong"

### Finance Red Flags
- "pre-revenue" → "making zero dollars"
- "extending runway" → "desperately trying not to die"
- "investment opportunity" → "give us money before we die"
- "pre-profit" → "losing money"

### HR Red Flags
- "we're like a family" → "toxic workplace pretending to care"
- "wear many hats" → "do 3 jobs for the price of 1"
- "work hard, play hard" → "unpaid overtime disguised as fun"
- "unlimited pto" → "you'll be guilted into taking none"

### Meaningless Buzzwords
- "synergy" → "meaningless buzzword"
- "leverage" → "use"
- "circle back" → "talk about it later (probably never)"
- "low-hanging fruit" → "easy tasks we should've done already"

### Tech Buzzwords
- "ai-powered" → "has a simple algorithm"
- "blockchain" → "slow database"
- "cloud-based" → "runs on someone else's computer"
- "disruptive" → "new (maybe)"

## Severity Levels

| Level | Description | Color |
|-------|-------------|-------|
| **buzzword** | Harmless but annoying | Yellow |
| **warning** | Concerning, investigate further | Bold Yellow |
| **red_flag** | Major warning sign | Red |
| **run_away** | Critical, avoid immediately | Bold Red |

## Example Output

**Input:**
```
We're seeking a rockstar ninja to join our fast-paced, pre-revenue startup.
We're pivoting to leverage blockchain synergies.
```

**Output:**
```
BS DETECTED: 8 instances of corporate jargon found

Severity Breakdown:
  Buzzwords: 3
  Warnings: 3
  Red Flags: 2

Translated Text:
We're seeking someone talented we want to underpay to join our chaotic and
disorganized, making zero dollars startup. We're changing direction because
the first idea failed to use slow database meaningless buzzword.

HIGH BS LEVEL
Assessment: Major red flags detected. Proceed with extreme caution.
```

## Data Storage

All detection history stored in:
```
$DATA_DIR/jargon_detections.json
```

Tracks:
- Total texts analyzed
- Total jargon detected
- Average BS per text
- Recent translations

## Use Cases

1. **Job Descriptions** - Understand what the role actually is
2. **Startup Pitches** - Detect BS and red flags
3. **Emails** - Decode corporate speak from management
4. **Meeting Notes** - Translate what was actually decided
5. **Marketing Copy** - See through the buzzwords
6. **Investor Decks** - Spot the warning signs

## Tips

- Use on job postings before applying
- Run on company "About Us" pages
- Translate investor update emails
- Check startup pitch decks
- Analyze your own writing to avoid jargon

## Dependencies

- `jq` - JSON processing
- `sed` - Text manipulation
- `awk` - Text processing

## Configuration

Edit `$DATA_DIR/jargon_detections.json` to customize settings.

## Related Scripts

- `cofounder-background-check.sh` - Vet potential cofounders
- `meeting-excuse-generator.sh` - Auto-decline low-value meetings
