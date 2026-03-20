# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

zero-trust-lifestyle is a collection of ~35 standalone Bash scripts that automate OPSEC, productivity, OSINT, and personal life management tasks. All scripts are designed to be privacy-first (data stays local), cross-platform (Linux, macOS, WSL2), and independently runnable.

## Architecture

- **`scripts/`** - Independently runnable Bash scripts. Each has its own `--help` output, configuration section, and subcommands. All depend on `lib/common.sh`.
- **`lib/common.sh`** - Shared library sourced by all scripts. Provides logging, notifications, encrypted storage, network utilities, rate limiting, HTTP GET helper, and dry-run support.
- **`config/config.example.sh`** - Template for user config; copied to `config/config.sh` by the installer.
- **`install.sh`** - Interactive installer supporting full install, themed packs (`--pack`), or single scripts (`--script`). Sets up directories, config, cron, systemd, and shell integration.
- **`docs/`** - Per-script documentation files plus `SETUP.md` (setup guide).
- **Runtime directories** (gitignored): `data/` (encrypted state/DBs), `logs/` (daily log files), `reports/`.

## Script Conventions

Every script follows the same pattern:
```bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
```

Scripts must:
- Support `--help`
- Use `lib/common.sh` functions for logging, not raw `echo`
- Read config from `config/config.sh` via common.sh auto-sourcing
- Use `$DATA_DIR`, `$LOG_DIR`, `$REPORTS_DIR` for file storage (never hardcode paths)
- Support `DRY_RUN=1` for destructive operations via `dry_run_execute`

## Commands

```bash
make lint              # bash -n syntax check on all scripts
make test              # smoke test: --help must exit 0 or 1 for every script
make check             # lint + test

# Run a single script
./scripts/<name>.sh --help
./scripts/<name>.sh [subcommand] [flags]

# Verbose mode for any script
VERBOSE=1 ./scripts/<name>.sh

# Dry-run mode (where supported)
DRY_RUN=1 ./scripts/<name>.sh [subcommand]

# Install (full, by pack, or single script)
./install.sh
./install.sh --pack paranoid-dev
./install.sh --script standup-bot
./install.sh --list-packs
./install.sh --list-scripts
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs `make lint` and `make test` equivalents on push/PR to `master`. No other tests exist.

## Key Technical Details

- Requires **Bash 4.0+** (macOS ships 3.2 - users need `brew install bash`)
- Required system deps: `jq`, `curl`, `openssl`, `grep`, `sed`, `awk`
- Locale: `lib/common.sh` exports `LC_NUMERIC=C` for consistent numeric handling
- Encryption: AES-256-CBC via openssl with PBKDF2; key defaults to machine-id
- Notifications: tries `notify-send` (Linux), `osascript` (macOS), `termux-notification` (Android) in order
- Alerts can go to email, webhook (Slack/Discord), or Telegram depending on config
- Config is shell-sourced (`config/config.sh`) - variables, not structured data
