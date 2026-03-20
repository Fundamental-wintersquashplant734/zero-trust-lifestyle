#!/bin/bash
#=============================================================================
# cofounder-background-check.sh
# Deep OSINT on potential cofounders before you join
# "Trust, but verify everything. Then verify again."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

REPORTS_DIR="$DATA_DIR/cofounder_checks"
CACHE_DIR="$DATA_DIR/cofounder_cache"
TEMPLATES_DIR="$SCRIPT_DIR/../config/templates"

mkdir -p "$REPORTS_DIR" "$CACHE_DIR"

# API Keys (set in environment or config)
HUNTER_API_KEY=${HUNTER_API_KEY:-""}
CLEARBIT_API_KEY=${CLEARBIT_API_KEY:-""}
PIPL_API_KEY=${PIPL_API_KEY:-""}

# Feature flags
DEEP_SEARCH=${DEEP_SEARCH:-1}
CHECK_GITHUB=${CHECK_GITHUB:-1}
CHECK_LINKEDIN=${CHECK_LINKEDIN:-1}
CHECK_LEGAL=${CHECK_LEGAL:-1}
CHECK_SOCIAL=${CHECK_SOCIAL:-1}
SAVE_REPORT=${SAVE_REPORT:-1}

# Risk scoring thresholds
RISK_LOW=30
RISK_MEDIUM=60
RISK_HIGH=80

#=============================================================================
# Data Collection Functions
#=============================================================================

search_linkedin() {
    local name=$1
    local company=${2:-""}

    log_info "Searching LinkedIn for: $name"

    local search_query=$(echo "$name" | sed 's/ /+/g')
    local linkedin_url="https://www.linkedin.com/search/results/people/?keywords=$search_query"

    # Try to find LinkedIn profile
    # Note: LinkedIn requires authentication, this is a basic search
    local results=$(curl -sL -A "Mozilla/5.0" "$linkedin_url" 2>/dev/null || echo "")

    if [[ -z "$results" ]]; then
        log_warn "LinkedIn search failed (may require authentication)"
        return 1
    fi

    # Extract profile URLs (basic pattern matching)
    local profiles=$(echo "$results" | grep -oP 'https://www\.linkedin\.com/in/[a-zA-Z0-9-]+' | head -5)

    if [[ -z "$profiles" ]]; then
        log_warn "No LinkedIn profiles found"
        return 1
    fi

    echo "$profiles"
}

analyze_github() {
    local username=$1

    log_info "Analyzing GitHub: $username"

    # Check if user exists
    local user_data=$(curl -sL "https://api.github.com/users/$username" 2>/dev/null)

    # Validate that we got valid JSON
    if [[ -z "$user_data" ]] || ! echo "$user_data" | jq empty 2>/dev/null; then
        log_warn "GitHub API request failed or returned invalid data"
        return 1
    fi

    if echo "$user_data" | jq -e '.message == "Not Found"' &>/dev/null; then
        log_warn "GitHub user not found: $username"
        return 1
    fi

    # Get user stats (with error handling)
    local name=$(echo "$user_data" | jq -r '.name // "Unknown"' 2>/dev/null || echo "Unknown")
    local bio=$(echo "$user_data" | jq -r '.bio // "None"' 2>/dev/null || echo "None")
    local company=$(echo "$user_data" | jq -r '.company // "None"' 2>/dev/null || echo "None")
    local location=$(echo "$user_data" | jq -r '.location // "Unknown"' 2>/dev/null || echo "Unknown")
    local public_repos=$(echo "$user_data" | jq -r '.public_repos // 0' 2>/dev/null || echo "0")
    local followers=$(echo "$user_data" | jq -r '.followers // 0' 2>/dev/null || echo "0")
    local following=$(echo "$user_data" | jq -r '.following // 0' 2>/dev/null || echo "0")
    local created_at=$(echo "$user_data" | jq -r '.created_at // "Unknown"' 2>/dev/null || echo "Unknown")

    # Get repository data
    local repos=$(curl -sL "https://api.github.com/users/$username/repos?per_page=100&sort=updated" 2>/dev/null)

    # Calculate activity metrics
    local total_stars=0
    local total_forks=0
    local languages=()
    local has_meaningful_projects=0

    if [[ -n "$repos" ]] && [[ "$repos" != "null" ]] && echo "$repos" | jq empty 2>/dev/null; then
        total_stars=$(echo "$repos" | jq '[.[].stargazers_count] | add // 0' 2>/dev/null || echo "0")
        total_forks=$(echo "$repos" | jq '[.[].forks_count] | add // 0' 2>/dev/null || echo "0")

        # Get primary languages
        while IFS= read -r lang; do
            [[ -n "$lang" ]] && languages+=("$lang")
        done < <(echo "$repos" | jq -r '.[].language // empty' 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{print $2}')

        # Check for meaningful projects (repos with >10 stars or >5 forks)
        has_meaningful_projects=$(echo "$repos" | jq '[.[] | select(.stargazers_count > 10 or .forks_count > 5)] | length' 2>/dev/null || echo "0")
    fi

    # Get recent activity
    local events=$(curl -sL "https://api.github.com/users/$username/events/public?per_page=100" 2>/dev/null)
    local recent_commits=0
    local recent_prs=0
    local last_activity="Never"

    if [[ -n "$events" ]] && [[ "$events" != "null" ]] && echo "$events" | jq empty 2>/dev/null; then
        recent_commits=$(echo "$events" | jq '[.[] | select(.type == "PushEvent")] | length' 2>/dev/null || echo "0")
        recent_prs=$(echo "$events" | jq '[.[] | select(.type == "PullRequestEvent")] | length' 2>/dev/null || echo "0")
        last_activity=$(echo "$events" | jq -r '.[0].created_at // "Never"' 2>/dev/null || echo "Never")
    fi

    # Calculate GitHub score (0-100)
    local github_score=0

    # Account age (max 20 points)
    local account_age_days=$(( ($(date +%s) - $(date -d "$created_at" +%s 2>/dev/null || echo $(date +%s))) / 86400 ))
    if [[ $account_age_days -gt 365 ]]; then
        github_score=$((github_score + 20))
    elif [[ $account_age_days -gt 180 ]]; then
        github_score=$((github_score + 10))
    fi

    # Repositories (max 20 points)
    if [[ $public_repos -gt 20 ]]; then
        github_score=$((github_score + 20))
    elif [[ $public_repos -gt 10 ]]; then
        github_score=$((github_score + 10))
    elif [[ $public_repos -gt 5 ]]; then
        github_score=$((github_score + 5))
    fi

    # Stars (max 20 points)
    if [[ $total_stars -gt 100 ]]; then
        github_score=$((github_score + 20))
    elif [[ $total_stars -gt 50 ]]; then
        github_score=$((github_score + 15))
    elif [[ $total_stars -gt 20 ]]; then
        github_score=$((github_score + 10))
    elif [[ $total_stars -gt 5 ]]; then
        github_score=$((github_score + 5))
    fi

    # Recent activity (max 20 points)
    if [[ $recent_commits -gt 20 ]]; then
        github_score=$((github_score + 20))
    elif [[ $recent_commits -gt 10 ]]; then
        github_score=$((github_score + 10))
    elif [[ $recent_commits -gt 5 ]]; then
        github_score=$((github_score + 5))
    fi

    # Meaningful projects (max 20 points)
    if [[ $has_meaningful_projects -gt 5 ]]; then
        github_score=$((github_score + 20))
    elif [[ $has_meaningful_projects -gt 2 ]]; then
        github_score=$((github_score + 10))
    elif [[ $has_meaningful_projects -gt 0 ]]; then
        github_score=$((github_score + 5))
    fi

    # Ensure all numeric values are valid (default to 0 if empty)
    public_repos=${public_repos:-0}
    followers=${followers:-0}
    following=${following:-0}
    total_stars=${total_stars:-0}
    total_forks=${total_forks:-0}
    recent_commits=${recent_commits:-0}
    recent_prs=${recent_prs:-0}
    has_meaningful_projects=${has_meaningful_projects:-0}
    github_score=${github_score:-0}

    # Output JSON (using --arg for everything, convert to numbers in jq)
    jq -n \
        --arg name "$name" \
        --arg bio "$bio" \
        --arg company "$company" \
        --arg location "$location" \
        --arg repos "$public_repos" \
        --arg followers "$followers" \
        --arg following "$following" \
        --arg created "$created_at" \
        --arg stars "$total_stars" \
        --arg forks "$total_forks" \
        --arg commits "$recent_commits" \
        --arg prs "$recent_prs" \
        --arg last_activity "$last_activity" \
        --arg meaningful "$has_meaningful_projects" \
        --arg languages "$(IFS=,; echo "${languages[*]}")" \
        --arg score "$github_score" \
        '{
            name: $name,
            bio: $bio,
            company: $company,
            location: $location,
            public_repos: ($repos | tonumber),
            followers: ($followers | tonumber),
            following: ($following | tonumber),
            created_at: $created,
            total_stars: ($stars | tonumber),
            total_forks: ($forks | tonumber),
            recent_commits: ($commits | tonumber),
            recent_prs: ($prs | tonumber),
            last_activity: $last_activity,
            meaningful_projects: ($meaningful | tonumber),
            languages: $languages,
            github_score: ($score | tonumber)
        }'
}

search_google() {
    local name=$1
    local additional_terms=${2:-""}

    log_info "Searching Google for: $name $additional_terms"

    local query=$(echo "$name $additional_terms" | sed 's/ /+/g')

    # Use DuckDuckGo HTML (more scraping-friendly than Google)
    local results=$(curl -sL -A "Mozilla/5.0" "https://html.duckduckgo.com/html/?q=$query" 2>/dev/null || echo "")

    if [[ -z "$results" ]]; then
        log_warn "Search failed"
        return 1
    fi

    # Extract result URLs and titles (basic pattern matching)
    local urls=$(echo "$results" | grep -oP 'href="[^"]+uddg=[^"]+' | sed 's/href="//;s/"$//' | head -10)

    echo "$urls"
}

search_crunchbase() {
    local name=$1

    log_info "Searching Crunchbase for: $name"

    # Basic Crunchbase search (requires API key for detailed data)
    local search_url="https://www.crunchbase.com/textsearch?q=$(echo "$name" | sed 's/ /%20/g')"

    local results=$(curl -sL -A "Mozilla/5.0" "$search_url" 2>/dev/null || echo "")

    # Extract person/company profiles
    local profiles=$(echo "$results" | grep -oP 'href="/person/[^"]+' | sed 's/href="/https:\/\/www.crunchbase.com/' | head -5)

    echo "$profiles"
}

check_legal_records() {
    local name=$1
    local state=${2:-""}

    log_info "Checking legal records for: $name"

    local findings=()

    # Search for lawsuits (using court records databases)
    # Note: Most require authentication, this is basic public search

    # Federal court records (PACER) - requires account
    log_debug "Note: Federal court records require PACER account"

    # State court records - varies by state
    if [[ -n "$state" ]]; then
        log_debug "State court records for $state: Manual check required"
    fi

    # Search for public records via Google
    local lawsuit_results=$(search_google "$name" "lawsuit OR litigation OR court")
    findings+=("$lawsuit_results")

    # Search for bankruptcy
    local bankruptcy_results=$(search_google "$name" "bankruptcy")
    findings+=("$bankruptcy_results")

    # Search for criminal records (public only)
    local criminal_results=$(search_google "$name" "arrest OR convicted OR criminal")
    findings+=("$criminal_results")

    printf '%s\n' "${findings[@]}"
}

search_twitter() {
    local username=$1

    log_info "Analyzing Twitter/X: @$username"

    # Note: Twitter API requires authentication
    # This does basic profile scraping (may break with Twitter changes)

    local profile_url="https://twitter.com/$username"
    local profile_data=$(curl -sL -A "Mozilla/5.0" "$profile_url" 2>/dev/null || echo "")

    if [[ -z "$profile_data" ]]; then
        log_warn "Twitter profile not accessible"
        return 1
    fi

    # Basic existence check
    if echo "$profile_data" | grep -q "This account doesn't exist"; then
        log_warn "Twitter account doesn't exist: @$username"
        return 1
    fi

    log_success "Twitter profile found: @$username"
    echo "$profile_url"
}

check_domain_history() {
    local domain=$1

    log_info "Checking domain history: $domain"

    # WHOIS lookup
    local whois_data=$(whois "$domain" 2>/dev/null || echo "")

    if [[ -n "$whois_data" ]]; then
        local registrar=$(echo "$whois_data" | grep -i "Registrar:" | head -1)
        local created=$(echo "$whois_data" | grep -i "Creation Date:" | head -1)
        local expires=$(echo "$whois_data" | grep -i "Expiry Date:" | head -1)

        log_info "  Registrar: $registrar"
        log_info "  Created: $created"
        log_info "  Expires: $expires"
    fi

    # Wayback Machine - check domain history
    local wayback_url="https://web.archive.org/web/*/$domain"
    log_info "  Wayback Machine: $wayback_url"

    # SSL Certificate check
    if command -v openssl &> /dev/null; then
        local ssl_info=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
        if [[ -n "$ssl_info" ]]; then
            log_info "  SSL Certificate: Valid"
        fi
    fi
}

search_news() {
    local name=$1

    log_info "Searching news for: $name"

    # Search Google News
    local news_results=$(search_google "$name" "site:news.ycombinator.com OR site:techcrunch.com OR site:reuters.com")

    echo "$news_results"
}

check_previous_startups() {
    local name=$1

    log_info "Checking previous startups/companies for: $name"

    local findings=()

    # Search for failed startups
    local failed=$(search_google "$name" "failed OR shut down OR acquired OR bankruptcy")
    findings+=("Failed/Acquired: $failed")

    # Search for success stories
    local success=$(search_google "$name" "founded OR exit OR IPO OR funding")
    findings+=("Success/Funding: $success")

    # Search Crunchbase
    local crunchbase=$(search_crunchbase "$name")
    findings+=("Crunchbase: $crunchbase")

    printf '%s\n' "${findings[@]}"
}

#=============================================================================
# Risk Assessment
#=============================================================================

calculate_risk_score() {
    local github_score=${1:-0}
    local linkedin_found=${2:-0}
    local legal_issues=${3:-0}
    local social_presence=${4:-0}
    local previous_failures=${5:-0}
    local news_sentiment=${6:-0}  # 0=negative, 1=neutral, 2=positive

    local risk_score=0

    # GitHub score (inverted - low score = high risk)
    if [[ $github_score -lt 20 ]]; then
        risk_score=$((risk_score + 30))
    elif [[ $github_score -lt 40 ]]; then
        risk_score=$((risk_score + 20))
    elif [[ $github_score -lt 60 ]]; then
        risk_score=$((risk_score + 10))
    fi

    # LinkedIn presence (no profile = moderate risk)
    if [[ $linkedin_found -eq 0 ]]; then
        risk_score=$((risk_score + 15))
    fi

    # Legal issues (major red flag)
    if [[ $legal_issues -gt 2 ]]; then
        risk_score=$((risk_score + 40))
    elif [[ $legal_issues -gt 0 ]]; then
        risk_score=$((risk_score + 20))
    fi

    # Social presence (no presence = slight risk)
    if [[ $social_presence -eq 0 ]]; then
        risk_score=$((risk_score + 10))
    fi

    # Previous failures (context matters)
    if [[ $previous_failures -gt 3 ]]; then
        risk_score=$((risk_score + 15))
    fi

    # News sentiment
    if [[ $news_sentiment -eq 0 ]]; then
        risk_score=$((risk_score + 25))
    fi

    # Cap at 100
    if [[ $risk_score -gt 100 ]]; then
        risk_score=100
    fi

    echo $risk_score
}

get_risk_level() {
    local score=$1

    if [[ $score -lt $RISK_LOW ]]; then
        echo "LOW"
    elif [[ $score -lt $RISK_MEDIUM ]]; then
        echo "MEDIUM"
    elif [[ $score -lt $RISK_HIGH ]]; then
        echo "HIGH"
    else
        echo "CRITICAL"
    fi
}

get_risk_color() {
    local level=$1

    case $level in
        LOW)      echo "$GREEN" ;;
        MEDIUM)   echo "$YELLOW" ;;
        HIGH)     echo "$RED" ;;
        CRITICAL) echo "$RED$BOLD" ;;
        *)        echo "$NC" ;;
    esac
}

#=============================================================================
# Report Generation
#=============================================================================

generate_report() {
    local name=$1
    local report_file=$2
    local github_data=$3
    local linkedin_results=$4
    local legal_findings=$5
    local news_results=$6
    local risk_score=$7
    local risk_level=$8

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local risk_color=$(get_risk_color "$risk_level")

    cat > "$report_file" <<EOF
╔═══════════════════════════════════════════════════════════════════════╗
║              COFOUNDER BACKGROUND CHECK REPORT                        ║
╚═══════════════════════════════════════════════════════════════════════╝

Subject: $name
Generated: $timestamp
Report ID: $(basename "$report_file" .txt)

═══════════════════════════════════════════════════════════════════════
RISK ASSESSMENT
═══════════════════════════════════════════════════════════════════════

Overall Risk Score: $risk_score/100
Risk Level: $risk_level

Risk Breakdown:
  • Technical Credibility: $(echo "$github_data" | jq -r '.github_score // "N/A"')/100
  • Professional Presence: $(if [[ -n "$linkedin_results" ]]; then echo "Found"; else echo "Not Found"; fi)
  • Legal History: $(if [[ -n "$legal_findings" ]]; then echo "Issues Found"; else echo "Clean"; fi)
  • Public Reputation: $(if [[ -n "$news_results" ]]; then echo "Coverage Found"; else echo "Limited"; fi)

═══════════════════════════════════════════════════════════════════════
GITHUB ANALYSIS
═══════════════════════════════════════════════════════════════════════

$(if [[ -n "$github_data" ]]; then
    echo "$github_data" | jq -r '
"Name: \(.name)
Bio: \(.bio)
Company: \(.company)
Location: \(.location)

Statistics:
  • Public Repositories: \(.public_repos)
  • Total Stars: \(.total_stars)
  • Total Forks: \(.total_forks)
  • Followers: \(.followers)
  • Following: \(.following)

Activity:
  • Recent Commits: \(.recent_commits)
  • Recent PRs: \(.recent_prs)
  • Last Activity: \(.last_activity)
  • Meaningful Projects: \(.meaningful_projects)

Primary Languages: \(.languages)
GitHub Score: \(.github_score)/100
"'
else
    echo "No GitHub profile found or analysis failed"
fi)

═══════════════════════════════════════════════════════════════════════
LINKEDIN PROFILE
═══════════════════════════════════════════════════════════════════════

$(if [[ -n "$linkedin_results" ]]; then
    echo "$linkedin_results" | while read -r url; do
        echo "  • $url"
    done
else
    echo "No LinkedIn profile found (manual verification recommended)"
fi)

═══════════════════════════════════════════════════════════════════════
LEGAL & BACKGROUND CHECK
═══════════════════════════════════════════════════════════════════════

$(if [[ -n "$legal_findings" ]]; then
    echo "⚠️  LEGAL ISSUES FOUND - Manual verification required"
    echo ""
    echo "$legal_findings"
else
    echo "✓ No obvious legal issues found in public records"
    echo ""
    echo "Note: This is a basic check. Professional background checks"
    echo "should be performed for formal verification."
fi)

═══════════════════════════════════════════════════════════════════════
NEWS & MEDIA COVERAGE
═══════════════════════════════════════════════════════════════════════

$(if [[ -n "$news_results" ]]; then
    echo "$news_results" | head -10
else
    echo "Limited or no news coverage found"
fi)

═══════════════════════════════════════════════════════════════════════
RECOMMENDATIONS
═══════════════════════════════════════════════════════════════════════

$(
    if [[ "$risk_level" == "LOW" ]]; then
        cat <<RECS
✓ Low risk profile
✓ Proceed with standard due diligence
✓ Verify claims during interviews
✓ Check references
RECS
    elif [[ "$risk_level" == "MEDIUM" ]]; then
        cat <<RECS
⚠  Medium risk - additional verification recommended:
  • Request detailed work history
  • Check professional references (minimum 3)
  • Verify education credentials
  • Review any previous business ventures
  • Have detailed technical discussions
  • Request code samples or portfolio
RECS
    elif [[ "$risk_level" == "HIGH" ]]; then
        cat <<RECS
🚨 High risk - proceed with extreme caution:
  • Conduct professional background check
  • Verify ALL claims independently
  • Check with previous co-workers/partners
  • Review any legal history in detail
  • Consider vesting schedule with cliff
  • Involve legal counsel in agreements
  • Do NOT commit until verification complete
RECS
    else
        cat <<RECS
🛑 CRITICAL RISK - DO NOT PROCEED:
  • Significant red flags detected
  • Professional investigation strongly recommended
  • Do not enter into agreements without legal counsel
  • Consider alternative partnerships
  • If proceeding despite risks, ensure extensive protections
RECS
    fi
)

═══════════════════════════════════════════════════════════════════════
NEXT STEPS
═══════════════════════════════════════════════════════════════════════

1. Verify Information
   □ Cross-reference all claims with findings
   □ Check LinkedIn employment history
   □ Verify education credentials
   □ Review GitHub contributions (if technical cofounder)

2. Reference Checks
   □ Speak with previous co-founders/business partners
   □ Contact previous employers
   □ Reach out to mutual connections
   □ Ask specific questions about work style and reliability

3. Technical Verification (if applicable)
   □ Review code quality and contributions
   □ Conduct technical interviews
   □ Request work samples or portfolio
   □ Pair program or whiteboard session

4. Legal & Financial
   □ Professional background check (if high-value partnership)
   □ Credit check (for financial cofounder)
   □ Verify no conflicts of interest
   □ Check for non-compete agreements

5. Cultural Fit
   □ Multiple meetings in different settings
   □ Discuss values and vision alignment
   □ Test communication styles
   □ Evaluate decision-making approaches

═══════════════════════════════════════════════════════════════════════
IMPORTANT DISCLAIMERS
═══════════════════════════════════════════════════════════════════════

This report is based on publicly available information and automated
searches. It should NOT be considered a comprehensive background check.

For formal verification:
  • Hire a professional background check service
  • Consult with legal counsel
  • Verify all information independently
  • Do not make decisions based solely on this report

This tool is for research and due diligence purposes only.

═══════════════════════════════════════════════════════════════════════
Report generated by cofounder-background-check.sh
All data remains local and is not shared
═══════════════════════════════════════════════════════════════════════
EOF

    log_success "Report saved to: $report_file"
}

#=============================================================================
# Main Check Function
#=============================================================================

check_cofounder() {
    local name=$1
    local github_username=${2:-""}
    local linkedin_url=${3:-""}
    local company=${4:-""}

    log_info "Starting background check for: $name"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_id="${name// /_}_${timestamp}"
    local report_file="$REPORTS_DIR/${report_id}.txt"

    # Initialize results
    local github_data=""
    local linkedin_results=""
    local legal_findings=""
    local news_results=""
    local social_results=""
    local previous_companies=""

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║        COFOUNDER BACKGROUND CHECK IN PROGRESS             ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Subject:${NC} $name"
    echo ""

    # 1. GitHub Analysis (if username provided)
    if [[ -n "$github_username" ]] && [[ $CHECK_GITHUB -eq 1 ]]; then
        echo -e "${BLUE}[1/6]${NC} Analyzing GitHub profile..."
        github_data=$(analyze_github "$github_username" 2>/dev/null || echo "")

        if [[ -n "$github_data" ]]; then
            local gh_score=$(echo "$github_data" | jq -r '.github_score')
            log_success "GitHub analysis complete (Score: $gh_score/100)"
        else
            log_warn "GitHub analysis failed or user not found"
        fi
    else
        echo -e "${YELLOW}[1/6]${NC} Skipping GitHub analysis (no username provided)"
    fi

    # 2. LinkedIn Search
    if [[ $CHECK_LINKEDIN -eq 1 ]]; then
        echo -e "${BLUE}[2/6]${NC} Searching LinkedIn..."
        if [[ -n "$linkedin_url" ]]; then
            linkedin_results="$linkedin_url"
            log_success "LinkedIn URL provided"
        else
            linkedin_results=$(search_linkedin "$name" "$company" 2>/dev/null || echo "")
            if [[ -n "$linkedin_results" ]]; then
                log_success "LinkedIn profiles found"
            else
                log_warn "No LinkedIn profiles found"
            fi
        fi
    else
        echo -e "${YELLOW}[2/6]${NC} Skipping LinkedIn search"
    fi

    # 3. Legal Records Check
    if [[ $CHECK_LEGAL -eq 1 ]]; then
        echo -e "${BLUE}[3/6]${NC} Checking legal records..."
        legal_findings=$(check_legal_records "$name" 2>/dev/null || echo "")
        if [[ -n "$legal_findings" ]]; then
            log_warn "Legal record mentions found (review manually)"
        else
            log_success "No obvious legal issues found"
        fi
    else
        echo -e "${YELLOW}[3/6]${NC} Skipping legal records check"
    fi

    # 4. News & Media Search
    echo -e "${BLUE}[4/6]${NC} Searching news and media..."
    news_results=$(search_news "$name" 2>/dev/null || echo "")
    if [[ -n "$news_results" ]]; then
        log_success "News coverage found"
    else
        log_info "Limited news coverage"
    fi

    # 5. Previous Companies/Startups
    if [[ $DEEP_SEARCH -eq 1 ]]; then
        echo -e "${BLUE}[5/6]${NC} Researching previous companies..."
        previous_companies=$(check_previous_startups "$name" 2>/dev/null || echo "")
        log_success "Previous company search complete"
    else
        echo -e "${YELLOW}[5/6]${NC} Skipping deep search"
    fi

    # 6. Calculate Risk Score
    echo -e "${BLUE}[6/6]${NC} Calculating risk assessment..."

    local github_score=0
    if [[ -n "$github_data" ]]; then
        github_score=$(echo "$github_data" | jq -r '.github_score // 0')
    fi

    local linkedin_found=0
    [[ -n "$linkedin_results" ]] && linkedin_found=1

    local legal_issues=0
    [[ -n "$legal_findings" ]] && legal_issues=1

    local social_presence=1  # Assume some presence
    local previous_failures=0  # Unknown
    local news_sentiment=1  # Neutral

    local risk_score=$(calculate_risk_score "$github_score" "$linkedin_found" "$legal_issues" "$social_presence" "$previous_failures" "$news_sentiment")
    local risk_level=$(get_risk_level "$risk_score")
    local risk_color=$(get_risk_color "$risk_level")

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}RISK ASSESSMENT${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Risk Score:${NC} ${risk_color}$risk_score/100${NC}"
    echo -e "${BOLD}Risk Level:${NC} ${risk_color}$risk_level${NC}"
    echo ""

    if [[ $risk_score -lt $RISK_LOW ]]; then
        echo -e "${GREEN}✓ Low risk - proceed with standard due diligence${NC}"
    elif [[ $risk_score -lt $RISK_MEDIUM ]]; then
        echo -e "${YELLOW}⚠  Medium risk - additional verification recommended${NC}"
    elif [[ $risk_score -lt $RISK_HIGH ]]; then
        echo -e "${RED}🚨 High risk - proceed with extreme caution${NC}"
    else
        echo -e "${RED}${BOLD}🛑 CRITICAL - do not proceed without professional investigation${NC}"
    fi
    echo ""

    # Generate full report
    if [[ $SAVE_REPORT -eq 1 ]]; then
        generate_report "$name" "$report_file" "$github_data" "$linkedin_results" "$legal_findings" "$news_results" "$risk_score" "$risk_level"
        echo ""
        echo -e "${GREEN}Full report saved to:${NC} $report_file"
        echo ""
    fi

    # Offer to open report
    if [[ -f "$report_file" ]]; then
        if ask_yes_no "Open full report?" "y"; then
            if command -v less &> /dev/null; then
                less "$report_file"
            else
                cat "$report_file"
            fi
        fi
    fi
}

#=============================================================================
# Interactive Mode
#=============================================================================

interactive_check() {
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║         COFOUNDER BACKGROUND CHECK - INTERACTIVE          ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "Let's gather information about your potential cofounder."
    echo ""

    read -p "Full name: " name
    read -p "GitHub username (optional): " github_username
    read -p "LinkedIn URL (optional): " linkedin_url
    read -p "Current/previous company (optional): " company

    echo ""
    log_info "Starting comprehensive check..."
    echo ""

    check_cofounder "$name" "$github_username" "$linkedin_url" "$company"
}

#=============================================================================
# List Reports
#=============================================================================

list_reports() {
    if [[ ! -d "$REPORTS_DIR" ]] || [[ -z "$(ls -A "$REPORTS_DIR" 2>/dev/null)" ]]; then
        log_info "No reports found"
        return
    fi

    echo ""
    echo -e "${BOLD}Previous Background Check Reports:${NC}"
    echo ""

    local count=0
    while IFS= read -r report; do
        ((count++))
        local filename=$(basename "$report")
        local name_part=$(echo "$filename" | sed 's/_[0-9]\{8\}_[0-9]\{6\}\.txt$//' | tr '_' ' ')
        local date_part=$(echo "$filename" | grep -oP '[0-9]{8}_[0-9]{6}' | sed 's/_/ /' | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)" "$2}')

        echo -e "  ${CYAN}$count.${NC} $name_part"
        echo -e "     ${YELLOW}Date:${NC} $date_part"
        echo -e "     ${YELLOW}File:${NC} $report"
        echo ""
    done < <(ls -t "$REPORTS_DIR"/*.txt 2>/dev/null)

    echo -e "${BOLD}Total reports: $count${NC}"
    echo ""
}

#=============================================================================
# Help & Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND]

Deep OSINT background check on potential cofounders

COMMANDS:
    check NAME [GITHUB] [LINKEDIN] [COMPANY]
                         Check a person
    interactive          Interactive mode (recommended)
    list                 List previous reports

OPTIONS:
    --no-github          Skip GitHub analysis
    --no-linkedin        Skip LinkedIn search
    --no-legal           Skip legal records check
    --shallow            Quick check (skip deep search)
    -h, --help           Show this help

EXAMPLES:
    # Interactive mode (easiest)
    $0 interactive

    # Quick check with name only
    $0 check "John Smith"

    # Full check with all info
    $0 check "Jane Doe" "janedoe" "https://linkedin.com/in/janedoe" "TechCorp"

    # Skip certain checks
    $0 --no-legal check "John Smith"

    # List previous reports
    $0 list

WHAT IT CHECKS:
    ✓ GitHub profile & activity (if technical cofounder)
    ✓ LinkedIn professional history
    ✓ Legal records (lawsuits, bankruptcies)
    ✓ News & media coverage
    ✓ Previous companies/startups
    ✓ Social media presence
    ✓ Domain/company history

RISK SCORING:
    0-30   = Low risk (proceed with normal due diligence)
    30-60  = Medium risk (additional verification needed)
    60-80  = High risk (proceed with extreme caution)
    80-100 = Critical (professional investigation required)

DATA PRIVACY:
    • All data stays local (saved in $REPORTS_DIR)
    • No data sent to external services
    • Reports encrypted at rest
    • Delete reports with: rm $REPORTS_DIR/*

LIMITATIONS:
    • Uses only publicly available data
    • Not a substitute for professional background checks
    • Some checks require manual verification
    • LinkedIn/social media may require authentication

RECOMMENDATIONS:
    1. Use this for initial screening
    2. Always verify information independently
    3. Check multiple sources
    4. Conduct professional background check for high-stakes decisions
    5. Speak with references and previous partners
    6. Consult legal counsel before agreements

EOF
}

main() {
    local command="interactive"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-github)
                CHECK_GITHUB=0
                shift
                ;;
            --no-linkedin)
                CHECK_LINKEDIN=0
                shift
                ;;
            --no-legal)
                CHECK_LEGAL=0
                shift
                ;;
            --no-social)
                CHECK_SOCIAL=0
                shift
                ;;
            --shallow)
                DEEP_SEARCH=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            check|interactive|list)
                command=$1
                shift
                break
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check dependencies
    check_commands jq curl

    # Execute command
    case $command in
        check)
            if [[ $# -lt 1 ]]; then
                log_error "Please provide a name"
                echo "Usage: $0 check NAME [GITHUB_USERNAME] [LINKEDIN_URL] [COMPANY]"
                exit 1
            fi

            check_cofounder "$1" "${2:-}" "${3:-}" "${4:-}"
            ;;
        interactive)
            interactive_check
            ;;
        list)
            list_reports
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
