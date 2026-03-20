# Cofounder Background Check

Deep OSINT background check on potential cofounders before committing to a partnership.

## Overview

Performs comprehensive due diligence on potential cofounders using publicly available data. Analyzes GitHub activity, professional history, legal records, news coverage, and generates risk assessments with actionable recommendations.

## Features

- GitHub profile analysis with credibility scoring
- LinkedIn professional history search
- Legal records checking (lawsuits, bankruptcies)
- News and media coverage search
- Previous startup/company research
- Automated risk scoring (0-100)
- Comprehensive plaintext reports (.txt)
- Privacy-first (all data stays local)

## Installation

```bash
chmod +x scripts/cofounder-background-check.sh
```

## Dependencies

Required:
- `jq` - JSON processing
- `curl` - HTTP requests

Optional:
- `whois` - Domain lookups
- `openssl` - SSL certificate checks

Install dependencies:
```bash
# Debian/Ubuntu
sudo apt-get install jq curl whois openssl

# macOS
brew install jq curl whois openssl
```

## Usage

### Interactive Mode (Recommended)

```bash
./scripts/cofounder-background-check.sh interactive
```

You'll be prompted to enter:
- Full name
- GitHub username (optional)
- LinkedIn URL (optional)
- Current/previous company (optional)

### Quick Check

```bash
./scripts/cofounder-background-check.sh check "John Smith"
```

### Full Check with All Info

```bash
./scripts/cofounder-background-check.sh check "Jane Doe" "janedoe" "https://linkedin.com/in/janedoe" "TechCorp"
```

### List Previous Reports

```bash
./scripts/cofounder-background-check.sh list
```

## Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `check` | NAME [GITHUB] [LINKEDIN] [COMPANY] | Run background check |
| `interactive` | - | Interactive mode with prompts |
| `list` | - | List all previous reports |

## Options

| Option | Description |
|--------|-------------|
| `--no-github` | Skip GitHub analysis |
| `--no-linkedin` | Skip LinkedIn search |
| `--no-legal` | Skip legal records check |
| `--no-social` | Skip social media checks |
| `--shallow` | Quick check only (skip deep search) |

## What It Checks

### 1. GitHub Analysis (Technical Cofounders)

Analyzes:
- Repository count and quality
- Stars and forks received
- Contribution activity (commits, PRs)
- Programming languages used
- Project meaningfulness (repos with traction)
- Account age and history
- Recent activity patterns

**GitHub Score Calculation (0-100):**
- Account age: 20 points
- Repository count: 20 points
- Stars received: 20 points
- Recent activity: 20 points
- Meaningful projects: 20 points

### 2. LinkedIn Profile

Searches for:
- Professional employment history
- Education credentials
- Network and connections
- Endorsements and recommendations

### 3. Legal Records

Checks for:
- Lawsuits and litigation
- Bankruptcy filings
- Criminal records (public only)
- Court case mentions

### 4. News & Media Coverage

Searches:
- Tech news (TechCrunch, Hacker News)
- Business news (Reuters, Bloomberg)
- Industry publications
- Startup coverage

### 5. Previous Companies/Startups

Investigates:
- Failed ventures and shutdowns
- Successful exits or IPOs
- Funding rounds
- Crunchbase history

## Risk Scoring

### Risk Levels

| Score | Level | Action |
|-------|-------|--------|
| 0-30 | **LOW** | Proceed with standard due diligence |
| 30-60 | **MEDIUM** | Additional verification recommended |
| 60-80 | **HIGH** | Proceed with extreme caution |
| 80-100 | **CRITICAL** | Professional investigation required |

### Risk Factors

**Increases Risk:**
- Low GitHub score (< 40)
- No LinkedIn presence
- Legal issues found
- Multiple failed startups
- Negative news coverage
- No social media presence

**Decreases Risk:**
- High GitHub score (> 60)
- Strong LinkedIn profile
- Positive news coverage
- Successful exits
- Clean legal history

## Generated Reports

Reports are saved to: `$DATA_DIR/cofounder_checks/` as plaintext `.txt` files.

Each report includes:
- Risk score and level
- GitHub analysis (if applicable)
- LinkedIn profiles found
- Legal findings
- News coverage
- Specific recommendations
- Next steps checklist

### Report Sections

1. **Risk Assessment** - Overall score and breakdown
2. **GitHub Analysis** - Technical credibility metrics
3. **LinkedIn Profile** - Professional history links
4. **Legal & Background** - Any issues found
5. **News & Media** - Public coverage
6. **Recommendations** - Specific action items
7. **Next Steps** - Due diligence checklist

## Example Workflow

```bash
# 1. Run initial check
./scripts/cofounder-background-check.sh check "Alex Johnson" "alexj"

# Output:
# Risk Score: 35/100
# Risk Level: MEDIUM
# GitHub Score: 68/100

# 2. Review generated report
# Report saved to: data/cofounder_checks/Alex_Johnson_20251205_143022.txt

# 3. Based on findings, decide on next steps:
# - Request references
# - Verify employment history
# - Technical interview
# - Legal background check (if needed)
```

## Recommendations by Risk Level

### LOW Risk (0-30)
- Proceed with standard due diligence
- Verify claims during interviews
- Check 2-3 professional references
- Review work samples

### MEDIUM Risk (30-60)
- Request detailed work history
- Check minimum 3 professional references
- Verify education credentials
- Review previous business ventures
- Conduct technical discussions
- Request code samples or portfolio

### HIGH Risk (60-80)
- Conduct professional background check
- Verify ALL claims independently
- Check with previous co-workers/partners
- Review legal history in detail
- Consider vesting schedule with cliff
- Involve legal counsel in agreements
- Do NOT commit until verification complete

### CRITICAL Risk (80-100)
- Significant red flags detected
- Professional investigation strongly recommended
- Do not enter into agreements without legal counsel
- Consider alternative partnerships
- If proceeding, ensure extensive legal protections

## Important Disclaimers

### Limitations

This tool:
- Uses only publicly available information
- Is NOT a substitute for professional background checks
- Requires manual verification of findings
- May miss non-public information
- Should be one part of due diligence process

### Legal Considerations

- All data collected is from public sources
- No authentication or unauthorized access used
- Complies with terms of service for public APIs
- For research and due diligence purposes only

### Recommendations

1. Use this for **initial screening only**
2. Always **verify information independently**
3. Check **multiple sources**
4. For high-stakes partnerships: **hire a professional service**
5. **Speak with references** and previous partners
6. **Consult legal counsel** before signing agreements

## Data Privacy

- All reports stored locally in `$DATA_DIR/cofounder_checks/`
- No data sent to external services
- Reports contain only public information
- Delete anytime: `rm -rf $DATA_DIR/cofounder_checks/`

## Professional Background Check Services

For formal verification, consider:
- Checkr
- GoodHire
- Sterling
- HireRight
- First Advantage

## Related Scripts

- `bullshit-jargon-translator.sh` - Decode startup speak
- `meeting-cost-calculator.sh` - Calculate opportunity costs
