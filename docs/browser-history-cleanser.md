# Browser History Cleanser

Nuclear option for browser history when you've been researching... stuff. Clears history, cookies, cache, and session data across all major browsers, with backup and selective cleaning options.

## Overview

Wipes browser data from Firefox, Chrome, Chromium, Brave, and Edge. Supports full cleans, per-browser targeting, domain-pattern filtering, and time-range filtering. Creates backups before any changes so you can restore if needed.

## Features

- Full history, cookie, cache, and session cleaning
- Multi-browser support (Firefox, Chrome, Chromium, Brave, Edge)
- Domain pattern filtering (clean only matching URLs)
- Time-based cleaning (clean last N hours)
- Automatic backup before cleaning
- Restore from backup
- Browser statistics (URL/visit counts)
- Backup rotation (keeps last 5 per browser)

## Installation

```bash
chmod +x scripts/browser-history-cleanser.sh
```

## Dependencies

Required:
- `sqlite3` - Browser database access

## Quick Start

```bash
# Clean all browsers (with backup)
./scripts/browser-history-cleanser.sh --all

# Clean only Firefox
./scripts/browser-history-cleanser.sh --firefox

# Show stats without cleaning
./scripts/browser-history-cleanser.sh --stats

# Clean only URLs matching a pattern
./scripts/browser-history-cleanser.sh --domain "malware-repo.com"
```

## Options

| Flag | Short | Arguments | Description |
|------|-------|-----------|-------------|
| `--all` | `-a` | - | Clean all browsers (default) |
| `--firefox` | `-f` | - | Clean Firefox only |
| `--chrome` | `-c` | - | Clean Chrome/Chromium only |
| `--brave` | `-b` | - | Clean Brave only |
| `--domain` | `-d` | `PATTERN` | Clean only URLs matching pattern |
| `--time` | `-t` | `HOURS` | Clean only last N hours |
| `--stats` | `-s` | - | Show browser statistics without cleaning |
| `--restore` | `-r` | `BROWSER` | Restore from backup |
| `--no-backup` | - | - | Skip backup creation (DANGEROUS) |
| `--no-history` | - | - | Skip history cleaning |
| `--no-cookies` | - | - | Skip cookie cleaning |
| `--no-cache` | - | - | Skip cache cleaning |
| `--verbose` | `-v` | - | Verbose output |
| `--help` | `-h` | - | Show help |

## Usage

### Clean All Browsers

```bash
./scripts/browser-history-cleanser.sh --all
```

Cleans all detected Firefox and Chrome-based profiles. Prompts for confirmation before proceeding.

### Clean Specific Browser

```bash
# Firefox only
./scripts/browser-history-cleanser.sh --firefox

# Chrome/Chromium only
./scripts/browser-history-cleanser.sh --chrome

# Brave only
./scripts/browser-history-cleanser.sh --brave
```

### Clean by Domain Pattern

```bash
./scripts/browser-history-cleanser.sh --domain "malware-repo.com"
./scripts/browser-history-cleanser.sh --domain "linkedin"
```

Removes history entries whose URLs contain the given pattern. Works across all detected Firefox and Chrome-based profiles. No confirmation prompt; runs immediately.

### Clean by Time Range

```bash
# Clean last 2 hours
./scripts/browser-history-cleanser.sh --time 2

# Clean last 24 hours
./scripts/browser-history-cleanser.sh --time 24
```

Removes history visits from the last N hours. Works across all detected profiles.

### Show Statistics

```bash
./scripts/browser-history-cleanser.sh --stats
```

Displays URL and visit counts for all detected browser profiles without modifying anything.

### Restore from Backup

```bash
./scripts/browser-history-cleanser.sh --restore firefox
./scripts/browser-history-cleanser.sh --restore chrome
```

Lists available backups for the given browser, prompts for selection, extracts to a temporary directory, and provides instructions to manually copy back.

### Skip Specific Data Types

```bash
# Clean history and cookies, but not cache
./scripts/browser-history-cleanser.sh --all --no-cache

# Clean only cache (skip history and cookies)
./scripts/browser-history-cleanser.sh --all --no-history --no-cookies

# Nuclear option - everything, no backup
./scripts/browser-history-cleanser.sh --all --no-backup
```

## What Gets Cleaned

### Firefox

| Data | File | Cleaned by default |
|------|------|--------------------|
| Browsing history | `places.sqlite` | Yes |
| Cookies | `cookies.sqlite` | Yes |
| Cache | `cache2/`, `startupCache/`, `thumbnails/` | Yes |
| Download history | `downloads.sqlite` | Yes |
| Form history | `formhistory.sqlite` | Yes |
| Session data | `sessionstore.jsonlz4` | Yes |

### Chrome / Chromium / Brave / Edge

| Data | File | Cleaned by default |
|------|------|--------------------|
| Browsing history | `History` (SQLite) | Yes |
| Cookies | `Cookies`, `Network/Cookies` | Yes |
| Cache | `Cache/`, `Code Cache/`, `GPUCache/` | Yes |
| Download history | `History` downloads table | Yes |
| Session data | `Current Session`, `Last Session`, etc. | Yes |
| Autofill / Web Data | `Web Data` | Yes |

## Browser Profile Detection

### Firefox

```
Linux:  ~/.mozilla/firefox/*.default*
macOS:  ~/Library/Application Support/Firefox/Profiles/*.default*
```

### Chrome-based

```
Linux:  ~/.config/google-chrome/Default
        ~/.config/chromium/Default
        ~/.config/BraveSoftware/Brave-Browser/Default
        ~/.config/microsoft-edge/Default
macOS:  ~/Library/Application Support/Google/Chrome/Default
        (and similar paths for Brave, Edge, Chromium)
```

## Backup & Recovery

### Automatic Backups

A backup is created before each cleaning session (unless `--no-backup` is used):

```
$DATA_DIR/browser_backups/firefox_PROFILE_TIMESTAMP.tar.gz
$DATA_DIR/browser_backups/Chrome_Default_TIMESTAMP.tar.gz
```

The last 5 backups per browser are kept. Older ones are removed automatically.

### Restore

```bash
./scripts/browser-history-cleanser.sh --restore firefox
```

Lists available backups, prompts for selection, and extracts to a temp directory. Files must be manually copied back to the profile directory.

## Example Cleaning Session

```bash
$ ./scripts/browser-history-cleanser.sh --firefox

⚠️  WARNING ⚠️
This will clean browser data. Make sure all browsers are closed!

Continue? [y/N]: y

╔════════════════════════════════════════╗
║    BROWSER HISTORY CLEANSER 3000       ║
╚════════════════════════════════════════╝

[INFO] Scanning for Firefox profiles...
[INFO] Found 1 Firefox profile(s)
[INFO] Cleaning Firefox profile: abc123.default-release
[INFO] Creating backup: browser_backups/firefox_abc123.default-release_20260316_120000.tar.gz
[OK] Backup created successfully
[INFO] Cleaning browsing history...
[OK] History cleaned
[INFO] Cleaning cookies...
[OK] Cookies removed
[INFO] Cleaning cache...
[OK] Cache cleared
[INFO] Cleaning download history...
[OK] Download history removed
[INFO] Cleaning form history...
[OK] Form history removed
[INFO] Cleaning session data...
[OK] Session data removed
[OK] Firefox profile cleaned (6 items)

═══════════════════════════════════════
[OK] Browser cleaning complete!
[INFO] Backups stored in: $DATA_DIR/browser_backups
```

## Statistics Output

```bash
$ ./scripts/browser-history-cleanser.sh --stats

Firefox:
  📁 abc123.default-release
     URLs: 4,832
     Visits: 12,741

Chrome-based browsers:
  📁 Default
     URLs: 8,103
     Visits: 31,420
```

## Best Practices

1. **Close browsers before cleaning**
   - The script checks for running processes and refuses to clean if a browser is open
   - Browsers lock their SQLite databases while running

2. **Use selective cleaning first**
   - `--domain` for targeted removal
   - `--time` for recent-only cleanup

3. **Keep backups enabled**
   - Default behavior creates backups
   - Only use `--no-backup` if you're certain

4. **Stats before nuclear**
   - Run `--stats` to understand what you're deleting
   - Then decide if you need `--all` or just `--domain`

5. **Consider incognito for sensitive browsing**
   - Pro tip included at the end of every cleaning run

## Security Considerations

- Browsers must be closed during cleaning
- Creates backups before deletion by default
- No network activity - all local processing
- Does not clean saved passwords (disabled by default via `CLEAN_PASSWORDS=0`)

## Warnings

- Close all browser windows before running
- `--no-backup` is permanent - there is no recovery
- SQLite WAL files are also removed for Firefox to prevent history reconstruction

## Data Location

```
$DATA_DIR/browser_backups/    # Backup archives
```

## Related Scripts

- `opsec-paranoia-check.sh` - Overall OPSEC
- `coffee-shop-lockdown.sh` - Public WiFi security
- `git-secret-scanner.sh` - Prevent credential leaks
