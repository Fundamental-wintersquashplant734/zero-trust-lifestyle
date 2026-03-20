# Git Secret Scanner

Pre-commit hook that scans for secrets and credentials before you accidentally commit them to version control.

## Overview

Prevents accidental commits of sensitive data like API keys, passwords, private keys, and credentials. Integrates with Git as a pre-commit hook and scans staged changes for over 30 types of secrets across AWS, GitHub, Google Cloud, Slack, databases, and more. Run `scan` with no file argument to scan the entire tracked repository, or pass a file path to scan a specific file.

## Features

- 30+ secret pattern matchers
- Severity-based blocking (critical, high, medium, low)
- Automatic pre-commit hook installation
- Cost estimates for leaked CRITICAL secrets
- Scan history tracking (last 100 scans)
- Whitelist support for false positives
- File-based and whole-repository scanning

## Installation

```bash
chmod +x scripts/git-secret-scanner.sh
```

## Dependencies

- `git` - Version control
- `jq` - JSON processing
- `grep` - Pattern matching

## Usage

### Install Pre-commit Hook

```bash
cd your-git-repo
./scripts/git-secret-scanner.sh install
```

Installs hook in `.git/hooks/pre-commit` of the current repository. Backs up any existing hook. Now runs automatically on every `git commit`.

### Uninstall Hook

```bash
./scripts/git-secret-scanner.sh uninstall
```

Removes hook or restores the previous hook from backup.

### Manual Scan

```bash
# Scan entire tracked repository
./scripts/git-secret-scanner.sh scan

# Scan specific file
./scripts/git-secret-scanner.sh scan config/secrets.yaml
```

### Manage Whitelist

```bash
# Add a false positive to whitelist
./scripts/git-secret-scanner.sh whitelist "example-api-key-do-not-use"
```

Whitelist entries are matched against both the matched content and the filename. Stored in `$DATA_DIR/secret_whitelist.txt`.

### View Scan History

```bash
./scripts/git-secret-scanner.sh history
```

Shows last 10 scans with timestamp, result (passed/blocked), and finding count.

## Options

| Option | Description |
|--------|-------------|
| `--pre-commit` | Run as pre-commit hook (called internally by hook script) |
| `--no-block` | Warn about secrets but don't block the commit |

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `install` | - | Install pre-commit hook in current repo |
| `uninstall` | - | Remove pre-commit hook |
| `scan` | [FILE] | Scan file or entire repository |
| `history` | - | View scan history |
| `whitelist` | ITEM | Add item to whitelist |

## Secret Patterns Detected

### Critical Severity

**AWS Credentials**
- Access keys (`AKIA[0-9A-Z]{16}`)
- Secret keys
- PostgreSQL, MySQL, MongoDB connection strings
- DigitalOcean tokens
- Stripe secret keys (`sk_live_...`)

**Cloud Provider Tokens**
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghr_`)
- Google Cloud API keys (`AIza...`)
- GCP service account JSON

**Private Keys**
- RSA private keys (`-----BEGIN RSA PRIVATE KEY-----`)
- OpenSSH private keys
- PGP private keys
- DSA/EC private keys
- SSH private key files (`.ssh/id_rsa`, etc.)

**Communication Platforms**
- Slack tokens (`xox[baprs]-...`)

### High Severity

- Generic API keys (`api_key = "..."`)
- Generic secrets and tokens
- Slack webhooks
- Heroku API keys
- Twilio API keys
- Passwords in URLs
- Basic auth headers
- Credentials files (`.json`, `.yaml`, `.yml`, `.xml`)
- Private key files (`.pem`, `.key`, `.p12`, `.pfx`)

### Medium Severity

- AWS account IDs
- Bearer tokens
- `.env` files
- Hardcoded passwords (`password = "..."`)

### Low Severity

- Possible credit card numbers

## Example Output

When secrets are found:

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║            🚨 SECRETS DETECTED IN COMMIT 🚨              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Found 2 potential secret(s):

🔴 CRITICAL (1):
  - AWS Access Key in config/aws.js
    Matched: AKIA1234567890ABCDEF

🟡 HIGH (1):
  - Generic API Key in src/api.js
    Matched: api_key = "sk_live_abc123...

💰 Potential Cost if Leaked:
   $5,000 - $50,000/month (compromised cloud account)

📋 Next Steps:
  1. Remove secrets from files
  2. Use environment variables instead
  3. Add .env files to .gitignore
  4. Use git secret or git-crypt for sensitive data
  5. Rotate any leaked credentials immediately

COMMIT BLOCKED!
Fix the issues above or use: git commit --no-verify to bypass (not recommended)
```

When clean:
```
✅ No secrets found - safe to commit!
```

## Whitelist Management

Add false positives so they don't block future commits:

```bash
# Add a specific matched value
./scripts/git-secret-scanner.sh whitelist "example-api-key-do-not-use"

# Add a filename to ignore entirely
./scripts/git-secret-scanner.sh whitelist "tests/fixtures/fake_keys.json"
```

Whitelist stored in: `$DATA_DIR/secret_whitelist.txt`

## Cost Estimates

When CRITICAL secrets are found, the script estimates potential damage:

- CRITICAL: $5,000 - $50,000/month (compromised cloud account)
- HIGH: $500 - $5,000/month (API abuse)
- MEDIUM: $100 - $500/month (potential abuse)

## Pattern File Format

Custom patterns are auto-initialized in `$DATA_DIR/secret_patterns.txt`:

```
pattern_name:regex_pattern:SEVERITY:Description
```

Example custom pattern:
```
custom_api:api_v2_[0-9a-f]{32}:HIGH:Custom API v2 key
```

## Best Practices

1. **Install hook in every repository**
   ```bash
   cd your-repo
   ./scripts/git-secret-scanner.sh install
   ```

2. **Scan before pushing to shared repos**
   ```bash
   ./scripts/git-secret-scanner.sh scan
   ```

3. **Review whitelist periodically**
   - Remove outdated entries
   - Ensure no real secrets are whitelisted

4. **Use environment variables**
   - Never hardcode secrets in source files
   - Use `.env` files and add them to `.gitignore`

5. **Rotate immediately if leaked**
   - Assume compromised the moment it's pushed
   - Rotate all related credentials
   - Check access logs for abuse

## If You Accidentally Commit Secrets

1. **Do NOT just delete in next commit**
   - Secrets remain in Git history

2. **Rotate credentials immediately**
   - Assume they're compromised

3. **Remove from Git history**
   ```bash
   # Use git-filter-repo or BFG Repo Cleaner
   git filter-repo --path-glob '*credentials.json' --invert-paths
   ```

4. **Force push (coordinate with team)**
   ```bash
   git push --force
   ```

5. **Notify your security team**

## Data Location

```
$DATA_DIR/secret_patterns.txt    # Pattern definitions
$DATA_DIR/secret_whitelist.txt   # Whitelisted patterns
$DATA_DIR/scan_history.json      # Scan history (last 100)
```

## Related Scripts

- `opsec-paranoia-check.sh` - Overall OPSEC validation
- `browser-history-cleanser.sh` - Remove sensitive browsing data
- `coffee-shop-lockdown.sh` - Public WiFi security
