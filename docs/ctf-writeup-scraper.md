# CTF Writeup Scraper

Pull the latest CTF writeups from GitHub, CTFTime, and popular repositories when you're stuck on a challenge.

## Overview

Searches multiple sources for CTF challenge writeups and solutions. Aggregates from GitHub repositories, CTFTime official writeups, and curated writeup collections. Supports quick search, interactive mode, bookmarking, and offline archiving. Perfect for learning from others' solutions, understanding exploit techniques, and getting unstuck on difficult challenges.

## Features

- Multi-source search (GitHub, CTFTime, curated repos)
- Interactive search mode
- Automatic formatting and syntax highlighting
- Flag extraction with spoiler protection
- Bookmark management
- Offline writeup archive
- Browse recent writeups
- Category filtering (web, pwn, reverse, crypto, forensics, etc.)
- Download and save writeups
- Search result caching

## Installation

```bash
chmod +x scripts/ctf-writeup-scraper.sh
```

## Dependencies

- `jq` - JSON processing
- `curl` - HTTP requests
- `pygmentize` - Syntax highlighting (optional)
Optional:
- `GITHUB_TOKEN` - Higher API rate limits

## Usage

### Quick Search

```bash
./scripts/ctf-writeup-scraper.sh search "picoCTF 2024"
./scripts/ctf-writeup-scraper.sh search "reverse engineering buffer overflow"
./scripts/ctf-writeup-scraper.sh search "web exploitation SQL injection"
```

### Interactive Mode

```bash
./scripts/ctf-writeup-scraper.sh interactive
```

Provides menu-driven interface:
1. Search for specific CTF event
2. Search for specific challenge
3. Browse by category
4. View recent writeups

### Browse Recent Writeups

```bash
./scripts/ctf-writeup-scraper.sh browse
```

Shows CTF writeups from last 30 days.

### Download Writeup

```bash
./scripts/ctf-writeup-scraper.sh download https://github.com/user/ctf-writeups/blob/main/challenge.md
```

### Bookmark Writeup

```bash
./scripts/ctf-writeup-scraper.sh bookmark \
    https://example.com/writeup \
    "Cool crypto challenge" \
    crypto
```

### List Bookmarks

```bash
./scripts/ctf-writeup-scraper.sh bookmarks
```

### View Statistics

```bash
./scripts/ctf-writeup-scraper.sh stats
```

## Commands

| Command | Description |
|---------|-------------|
| `search QUERY` | Search for writeups |
| `interactive` | Interactive search mode |
| `browse` | Browse recent writeups (last 30 days) |
| `download URL [FILE]` | Download specific writeup |
| `bookmark URL NAME [CATEGORY]` | Bookmark a writeup |
| `bookmarks` | List saved bookmarks |
| `stats` | Show statistics |

## Options

| Option | Description |
|--------|-------------|
| `--show-spoilers` | Show flags and solutions (default: hidden) |
| `--no-format` | Disable auto-formatting |
| `--max-results N` | Max results to show (default: 50) |

## Search Sources

### 1. GitHub Repositories

Searches thousands of public CTF writeup repos:
- Keyword matching in repo names, descriptions, and README
- Sorted by stars and recency
- Direct links to writeups

### 2. CTFTime

Official CTF writeup links:
- Event-based organization
- Links to official team writeups
- Historical CTF data

### 3. Popular Writeup Repositories

Pre-configured list of top writeup repos:
- `ctfs/write-ups-2024`
- `ctfs/write-ups-2023`
- `p4-team/ctf`
- `VoidHack/CTF-Writeups`
- `ByteBandits/ctf-writeups`
- `C4T-BuT-S4D/ctf-writeups`

## Categories

Supported CTF categories:
- `web` - Web exploitation
- `pwn` - Binary exploitation
- `reverse` - Reverse engineering
- `crypto` - Cryptography
- `forensics` - Digital forensics
- `misc` - Miscellaneous
- `osint` - Open-source intelligence
- `hardware` - Hardware hacking

## Example Workflows

### 1. Stuck on CTF Challenge

```bash
# Quick search for challenge name
./scripts/ctf-writeup-scraper.sh search "picoCTF vault-door"

# If found multiple, browse results
# Download the most helpful one
./scripts/ctf-writeup-scraper.sh download https://github.com/.../writeup.md

# Read, understand, try again
```

### 2. Learning New Technique

```bash
# Search for specific technique
./scripts/ctf-writeup-scraper.sh search "format string exploitation"

# Browse recent examples
./scripts/ctf-writeup-scraper.sh browse

# Bookmark for later reference
./scripts/ctf-writeup-scraper.sh bookmark \
    https://example.com/format-string-writeup \
    "Great format string tutorial" \
    pwn
```

### 3. Preparing for CTF

```bash
# Research past events
./scripts/ctf-writeup-scraper.sh search "DEFCON CTF 2024"

# Download all writeups
# Study common patterns and techniques

# Bookmark the best ones
./scripts/ctf-writeup-scraper.sh bookmarks
```

### 4. Post-CTF Learning

```bash
# After CTF ends, find official writeups
./scripts/ctf-writeup-scraper.sh search "CTF-NAME 2024"

# Compare your approach to others
# Learn new techniques

# Archive for future reference
./scripts/ctf-writeup-scraper.sh download URL1
./scripts/ctf-writeup-scraper.sh download URL2
```

## Configuration

### Set GitHub Token

Higher API rate limits (60 → 5000 requests/hour):

```bash
# Create token at: https://github.com/settings/tokens
export GITHUB_TOKEN="ghp_your_token_here"
```

Or in config:
```bash
echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.bashrc
```

### Cache Settings

```bash
CACHE_EXPIRY=3600  # 1 hour cache (in seconds)
MAX_RESULTS=50     # Max search results
```

## Features

### Flag Extraction

Automatically finds and displays flags:
```
🚩 flag{example_flag_here}
🚩 CTF{another_flag}
🚩 picoCTF{secret}
```

With `--show-spoilers`:
- Shows actual flags

Without (default):
- Obfuscates flags: `🚩 ********** (hidden)`

### Auto-Formatting

- Removes excessive newlines
- Syntax highlighting for code blocks (if `pygmentize` installed)
- Clean markdown rendering

### Caching

Speeds up repeated searches:
- GitHub API responses cached for 1 hour
- CTFTime events cached
- Reduces API rate limit usage

## Advanced Usage

### Search with Specific Filters

```bash
# Search specific CTF + challenge
./scripts/ctf-writeup-scraper.sh search "DUCTF 2024 web challenge"

# Search by category
./scripts/ctf-writeup-scraper.sh search "crypto RSA"

# Search by technique
./scripts/ctf-writeup-scraper.sh search "SQL injection UNION"
```

### Batch Download

```bash
# Save multiple writeups
for url in $(cat writeup_urls.txt); do
    ./scripts/ctf-writeup-scraper.sh download "$url"
done
```

### Custom Max Results

```bash
# Get more results
./scripts/ctf-writeup-scraper.sh --max-results 100 search "DEFCON"
```

## Data Storage

```
$DATA_DIR/ctf_writeups/           # Cached writeups
$DATA_DIR/ctf_writeup_index.json  # Search index
$DATA_DIR/ctf_bookmarks.json      # Saved bookmarks
```

## Example Output

### Search Results

```
╔════════════════════════════════════════════════════════════╗
  📦 ctfs/write-ups-2024
  ⭐ Stars: 1523 | Forks: 342
  📝 CTF writeups from 2024
  🔗 https://github.com/ctfs/write-ups-2024
  Updated: 2024-12-01T10:30:00Z
╚════════════════════════════════════════════════════════════╝

╔════════════════════════════════════════════════════════════╗
  📦 p4-team/ctf
  ⭐ Stars: 892 | Forks: 156
  📝 CTF writeup repository
  🔗 https://github.com/p4-team/ctf
  Updated: 2024-11-28T15:20:00Z
╚════════════════════════════════════════════════════════════╝
```

### Writeup Preview

```
# Challenge Name

**Category**: Web Exploitation
**Points**: 500
**Solves**: 15

## Description

The challenge gives us a web application with a search function...

## Solution

1. First, I noticed the search parameter is reflected in the response
2. Testing for SQL injection: `' OR 1=1--`
3. Confirmed vulnerable!

## Exploit

```python
import requests

url = "http://challenge.ctf/search"
payload = "' UNION SELECT flag FROM secrets--"
response = requests.get(url, params={'q': payload})
print(response.text)
```

## Flag

🚩 ********** (hidden)
Use --show-spoilers to reveal
```

## Tips for Finding Writeups

### Good Search Terms
- CTF name + year: "picoCTF 2024"
- CTF name + challenge name: "DUCTF web challenge"
- Category + technique: "crypto RSA padding oracle"
- Specific vulnerability: "SQL injection writeup"

### Bad Search Terms
- Too generic: "ctf"
- Too vague: "hard challenge"
- Misspelled event names

### When to Search
- **After trying yourself first** - Learn by attempting
- **After event ends** - Official writeups available
- **For learning** - Study techniques

### When NOT to Search
- **During live CTF** - Against rules, defeats purpose
- **Before attempting** - Miss learning opportunity

## Best Practices

### Ethical Usage
1. **Try first, read later** - Attempt challenge yourself first
2. **Wait for event to end** - Don't cheat during live CTFs
3. **Learn, don't copy** - Understand the technique, not just the solution
4. **Give credit** - Reference the writeup if using techniques

### Learning from Writeups
1. **Compare approaches** - How did they do it differently?
2. **Note new techniques** - Bookmark novel methods
3. **Practice** - Try to reproduce the exploit
4. **Ask questions** - If unclear, research deeper

### Organization
1. **Bookmark the best** - Quality over quantity
2. **Categorize** - Use category tags when bookmarking
3. **Take notes** - Add your own notes to downloaded writeups
4. **Archive locally** - Download important writeups

## Troubleshooting

### No Results Found

**Issue**: Search returns empty

**Solutions**:
- Try different search terms
- Search more specifically (CTF name + challenge)
- Check spelling
- Try category-based search

### GitHub API Rate Limit

**Issue**: "API rate limit exceeded"

**Solutions**:
- Set `GITHUB_TOKEN` for higher limits
- Wait an hour for reset
- Use cached results (automatic)

### Writeup Won't Download

**Issue**: Download fails

**Solutions**:
- Check URL is accessible
- For GitHub, ensure it's a raw or blob URL
- Check network connection
- Try manual download with browser

## Integration with CTF Workflow

### During Practice

```bash
# Search for similar challenges
./scripts/ctf-writeup-scraper.sh search "buffer overflow"

# Study multiple approaches
# Build your toolkit
```

### During Competition

```bash
# Don't use during live CTF!
# Save for after event ends
```

### Post-CTF Analysis

```bash
# Find official writeups
./scripts/ctf-writeup-scraper.sh search "CTFNAME 2024"

# Compare solutions
# Learn what you missed

# Bookmark best writeups
./scripts/ctf-writeup-scraper.sh bookmark URL "Great technique" category
```

## Related Scripts

- `fear-challenge.sh` - Face your fears systematically
- `random-skill-learner.sh` - Learn new skills

## Additional Resources

Provided in search results:
- Google Search link for query
- GitHub Search link
- CTFTime search link
