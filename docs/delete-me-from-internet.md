# Delete Me From Internet

Mass opt-out campaign for 20+ data brokers with guided workflow, CCPA/GDPR templates, and progress tracking.

## Overview

Automates the process of removing your personal information from major data broker databases. Includes 20+ pre-configured data brokers (Spokeo, WhitePages, BeenVerified, etc.) with step-by-step instructions, CCPA/GDPR email templates, encrypted profile storage, and progress tracking. Makes the tedious opt-out process manageable through guided campaigns and batch processing.

## Features

- 20+ major data brokers pre-configured
- Guided removal campaign workflow
- CCPA/GDPR email templates
- Encrypted profile storage
- Progress tracking and statistics
- "Easy wins" quick start mode
- Priority broker recommendations
- Per-broker instructions
- Verification tracking
- Browser integration (auto-opens opt-out pages)

## Installation

```bash
chmod +x scripts/delete-me-from-internet.sh
```

## Dependencies

- `jq` - JSON processing
- `openssl` - Profile encryption
- Browser: `xdg-open` (Linux) or `open` (macOS)

## Usage

### Initial Setup

```bash
./scripts/delete-me-from-internet.sh setup
```

### Start Easy Wins Campaign

```bash
./scripts/delete-me-from-internet.sh easy
```

### View All Brokers

```bash
./scripts/delete-me-from-internet.sh list
```

### Start Full Campaign

```bash
./scripts/delete-me-from-internet.sh campaign
```

### Check Statistics

```bash
./scripts/delete-me-from-internet.sh stats
```

### Generate CCPA/GDPR Email

```bash
./scripts/delete-me-from-internet.sh ccpa BrokerName
./scripts/delete-me-from-internet.sh gdpr BrokerName
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Set up encrypted profile |
| `list` | List all data brokers |
| `campaign` | Start mass opt-out campaign |
| `broker NAME` | Show details for specific broker |
| `easy` | Show easy wins (start here) |
| `priority` | Show high-priority brokers |
| `stats` | Show opt-out statistics |
| `pending` | Show pending verifications |
| `ccpa BROKER` | Generate CCPA email template |
| `gdpr BROKER` | Generate GDPR email template |

## Included Data Brokers

- Spokeo, WhitePages, BeenVerified
- PeopleFinder, USSearch, PeekYou
- Radaris, Zabasearch, PeopleSearchNow
- FastPeopleSearch, TruePeopleSearch
- Nuwber, NeighborWho, Intelius
- TruthFinder, Instant Checkmate
- MyLife, Pipl, FamilyTreeNow
- And more...

## Data Storage

```
$DATA_DIR/my_profile.enc             # Encrypted profile
$DATA_DIR/optout_requests.json       # Tracking database
$DATA_DIR/data_brokers.json          # Broker configurations
```

## Related Scripts

- `data-breach-stalker.sh` - Monitor for data breaches
- `opsec-paranoia-check.sh` - Overall security validation
