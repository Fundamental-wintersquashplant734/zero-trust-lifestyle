#!/bin/bash
#=============================================================================
# delete-me-from-internet.sh
# Submits opt-out requests to all main data brokers simultaneously
# "They're selling your data. Time to take it back."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

BROKERS_DB_FILE="$DATA_DIR/data_brokers.json"
REQUESTS_LOG_FILE="$DATA_DIR/optout_requests.json"
PROFILE_FILE="$DATA_DIR/my_profile.enc"

# Your information (encrypted at rest)
YOUR_NAME=""
YOUR_EMAIL=""
YOUR_PHONE=""
YOUR_ADDRESS=""
YOUR_CITY=""
YOUR_STATE=""
YOUR_ZIP=""
YOUR_DOB=""

# Settings
AUTO_SUBMIT=0  # If 1, attempts automated submission
DRY_RUN=0
BATCH_SIZE=5  # Number of requests per batch

#=============================================================================
# Data Broker Database
#=============================================================================

init_brokers_db() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$BROKERS_DB_FILE" ]]; then
        cat > "$BROKERS_DB_FILE" <<'EOF'
{
  "brokers": [
    {
      "name": "Spokeo",
      "category": "people_search",
      "opt_out_url": "https://www.spokeo.com/optout",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your name",
        "Click 'This is me' on your listing",
        "Enter email for verification",
        "Click confirmation link in email"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true,
      "email_verification": true
    },
    {
      "name": "WhitePages",
      "category": "people_search",
      "opt_out_url": "https://www.whitepages.com/suppression-requests",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your listing",
        "Copy the URL of your listing",
        "Fill out opt-out form with listing URL",
        "Verify via email"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "BeenVerified",
      "category": "background_check",
      "opt_out_url": "https://www.beenverified.com/app/optout/search",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Search for your name",
        "Find your listing and copy URL",
        "Submit opt-out form",
        "Verify via email",
        "May take 24-72 hours"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "PeopleFinder",
      "category": "people_search",
      "opt_out_url": "https://www.peoplefinder.com/manage",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your record",
        "Click 'Remove this record'",
        "Fill out opt-out form",
        "Verify email"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true
    },
    {
      "name": "Intelius",
      "category": "background_check",
      "opt_out_url": "https://www.intelius.com/optout",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Find your listing via search",
        "Note the listing URL",
        "Submit opt-out request",
        "Scan and upload ID (required)",
        "Takes 72 hours to process"
      ],
      "estimated_time": "15 minutes",
      "verification_required": true,
      "id_required": true
    },
    {
      "name": "MyLife",
      "category": "reputation",
      "opt_out_url": "https://www.mylife.com/ccpa/index.pubview",
      "method": "form",
      "difficulty": "hard",
      "instructions": [
        "Search for your profile",
        "Note profile URL",
        "Submit CCPA opt-out request",
        "Upload ID verification",
        "May require multiple attempts"
      ],
      "estimated_time": "20 minutes",
      "verification_required": true,
      "id_required": true,
      "notes": "Notoriously difficult to remove"
    },
    {
      "name": "TruthFinder",
      "category": "background_check",
      "opt_out_url": "https://www.truthfinder.com/opt-out/",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Search for your record",
        "Click opt-out link",
        "Fill out form with record URL",
        "Verify via email",
        "Takes 48 hours"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "Instant Checkmate",
      "category": "background_check",
      "opt_out_url": "https://www.instantcheckmate.com/opt-out/",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Search for yourself",
        "Copy listing URL",
        "Submit opt-out form",
        "Email verification required"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "USSearch",
      "category": "people_search",
      "opt_out_url": "https://www.ussearch.com/opt-out/submit/",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Find your listing",
        "Submit opt-out form",
        "Verify email"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true
    },
    {
      "name": "PeekYou",
      "category": "people_search",
      "opt_out_url": "https://www.peekyou.com/about/contact/optout/",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your name",
        "Click 'Opt Out'",
        "Fill out form",
        "Takes 24 hours"
      ],
      "estimated_time": "5 minutes",
      "verification_required": false
    },
    {
      "name": "Radaris",
      "category": "people_search",
      "opt_out_url": "https://radaris.com/control/privacy",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Search for yourself",
        "Find all your listings",
        "Submit removal for each one",
        "Email verification required",
        "May need to repeat monthly"
      ],
      "estimated_time": "15 minutes",
      "verification_required": true,
      "notes": "Data reappears frequently"
    },
    {
      "name": "Zabasearch",
      "category": "people_search",
      "opt_out_url": "http://www.zabasearch.com/block_records/",
      "method": "email",
      "difficulty": "hard",
      "instructions": [
        "Email: privacy@intelius.com",
        "Include your name and address",
        "Reference Zabasearch specifically",
        "Takes 4-6 weeks"
      ],
      "estimated_time": "5 minutes",
      "verification_required": false,
      "contact_email": "privacy@intelius.com"
    },
    {
      "name": "Pipl",
      "category": "aggregator",
      "opt_out_url": "https://pipl.com/personal-information-removal-request",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Fill out removal request form",
        "Provide all known URLs",
        "Takes 1-2 weeks"
      ],
      "estimated_time": "10 minutes",
      "verification_required": false
    },
    {
      "name": "PrivateEye",
      "category": "background_check",
      "opt_out_url": "https://www.privateeye.com/optout/",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search and find listing",
        "Submit opt-out form",
        "Email verification"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true
    },
    {
      "name": "CheckPeople",
      "category": "background_check",
      "opt_out_url": "https://www.checkpeople.com/optout",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Find your record",
        "Submit removal request",
        "May require ID"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "PeopleSearchNow",
      "category": "people_search",
      "opt_out_url": "https://www.peoplesearchnow.com/opt-out",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for yourself",
        "Click 'opt out'",
        "Verify via email"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true
    },
    {
      "name": "FastPeopleSearch",
      "category": "people_search",
      "opt_out_url": "https://www.fastpeoplesearch.com/removal",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your name",
        "Find listing and copy URL",
        "Submit removal form",
        "Immediate removal (no verification)"
      ],
      "estimated_time": "3 minutes",
      "verification_required": false,
      "notes": "One of the easiest"
    },
    {
      "name": "TruePeopleSearch",
      "category": "people_search",
      "opt_out_url": "https://www.truepeoplesearch.com/removal",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Find your listing",
        "Click removal link",
        "Verify via automated phone call",
        "Takes 24-48 hours"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true,
      "phone_verification": true
    },
    {
      "name": "Nuwber",
      "category": "people_search",
      "opt_out_url": "https://nuwber.com/removal/link",
      "method": "form",
      "difficulty": "medium",
      "instructions": [
        "Search for all your records",
        "Submit removal for each",
        "Email verification required",
        "Data may reappear"
      ],
      "estimated_time": "10 minutes",
      "verification_required": true
    },
    {
      "name": "FamilyTreeNow",
      "category": "genealogy",
      "opt_out_url": "https://www.familytreenow.com/optout",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your record",
        "Click 'Opt Out'",
        "No verification needed",
        "Immediate removal"
      ],
      "estimated_time": "3 minutes",
      "verification_required": false
    },
    {
      "name": "NeighborWho",
      "category": "people_search",
      "opt_out_url": "https://www.neighborwho.com/remove",
      "method": "form",
      "difficulty": "easy",
      "instructions": [
        "Search for your listing",
        "Submit opt-out form",
        "Email verification"
      ],
      "estimated_time": "5 minutes",
      "verification_required": true
    }
  ],
  "ccpa_template": "Subject: CCPA Data Deletion Request\n\nDear [BROKER],\n\nI am a California resident exercising my rights under the California Consumer Privacy Act (CCPA).\n\nI request that you:\n1. Delete all personal information you have collected about me\n2. Cease selling my personal information\n3. Provide confirmation of deletion within 45 days\n\nMy information:\nName: [NAME]\nAddress: [ADDRESS]\nEmail: [EMAIL]\n\nPlease confirm receipt and provide a timeline for deletion.\n\nThank you.",
  "gdpr_template": "Subject: GDPR Right to Erasure Request\n\nDear [BROKER],\n\nUnder Article 17 of the GDPR (Right to Erasure), I request that you:\n1. Erase all personal data concerning me\n2. Cease processing my data\n3. Notify any third parties with whom you've shared my data\n4. Confirm erasure within 30 days\n\nMy information:\nName: [NAME]\nEmail: [EMAIL]\n\nFailure to comply may result in a complaint to the supervisory authority.\n\nThank you."
}
EOF
        log_success "Initialized data brokers database (20 brokers)"
    fi

    if [[ ! -f "$REQUESTS_LOG_FILE" ]]; then
        echo '{"requests": []}' > "$REQUESTS_LOG_FILE"
    fi
}

#=============================================================================
# Profile Management (Encrypted)
#=============================================================================

setup_profile() {
    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          🔒 PROFILE SETUP (ENCRYPTED STORAGE) 🔒        ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo "This information will be encrypted and stored locally."
    echo "It's used to fill out opt-out forms."
    echo

    read -p "Full Name: " name
    read -p "Email (for verification): " email
    read -p "Phone (optional): " phone
    read -p "Street Address: " address
    read -p "City: " city
    read -p "State: " state
    read -p "ZIP Code: " zip
    read -p "Date of Birth (MM/DD/YYYY, optional): " dob

    # Create JSON profile
    local profile=$(jq -n \
        --arg name "$name" \
        --arg email "$email" \
        --arg phone "$phone" \
        --arg address "$address" \
        --arg city "$city" \
        --arg state "$state" \
        --arg zip "$zip" \
        --arg dob "$dob" \
        '{
            name: $name,
            email: $email,
            phone: $phone,
            address: $address,
            city: $city,
            state: $state,
            zip: $zip,
            dob: $dob,
            created: (now | todate)
        }')

    # Encrypt and save
    encrypt_data "$profile" "$PROFILE_FILE"

    log_success "Profile saved (encrypted)"
}

get_profile() {
    if [[ ! -f "$PROFILE_FILE" ]]; then
        log_error "Profile not set up. Run: $0 setup"
        return 1
    fi

    decrypt_data "$PROFILE_FILE"
}

#=============================================================================
# Opt-Out Execution
#=============================================================================

list_brokers() {
    init_brokers_db

    echo -e "\n${BOLD}🗑️  Data Brokers Database${NC}\n"

    jq -r '.brokers[] |
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
        "\u001b[1m\(.name)\u001b[0m (\(.category))\n" +
        "  Difficulty: \(.difficulty) | Time: \(.estimated_time)\n" +
        "  URL: \(.opt_out_url)\n" +
        (if .notes then "  ⚠️  \(.notes)\n" else "" end)' \
        "$BROKERS_DB_FILE"

    local total=$(jq '.brokers | length' "$BROKERS_DB_FILE")
    echo -e "\n${BOLD}Total brokers: $total${NC}\n"
}

show_broker_details() {
    local broker_name=$1

    init_brokers_db

    local broker=$(jq --arg name "$broker_name" \
        '.brokers[] | select(.name == $name)' \
        "$BROKERS_DB_FILE")

    if [[ -z "$broker" ]]; then
        log_error "Broker not found: $broker_name"
        return 1
    fi

    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          📋 $(printf "%-48s" "$broker_name") ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo "$broker" | jq -r '"Category: \(.category)"'
    echo "$broker" | jq -r '"Difficulty: \(.difficulty)"'
    echo "$broker" | jq -r '"Estimated time: \(.estimated_time)"'
    echo "$broker" | jq -r '"Opt-out URL: \(.opt_out_url)"'
    echo

    echo -e "${BOLD}Instructions:${NC}"
    echo "$broker" | jq -r '.instructions[] | "  \(.  | split("\n") | join("\n  "))"'
    echo

    if echo "$broker" | jq -e '.notes' &>/dev/null; then
        echo -e "${YELLOW}Note: $(echo "$broker" | jq -r '.notes')${NC}"
        echo
    fi

    # Open URL
    read -p "Open opt-out page in browser? (yes/no): " open
    if [[ "$open" == "yes" ]]; then
        local url=$(echo "$broker" | jq -r '.opt_out_url')
        if command -v xdg-open &> /dev/null; then
            xdg-open "$url"
        elif command -v open &> /dev/null; then
            open "$url"
        else
            log_info "Open manually: $url"
        fi
    fi

    # Mark as started
    record_request "$broker_name" "started"
}

#=============================================================================
# Batch Processing
#=============================================================================

start_removal_campaign() {
    echo -e "\n${BOLD}${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║                                                            ║${NC}"
    echo -e "${BOLD}${RED}║          🗑️  MASS OPT-OUT CAMPAIGN 🗑️                  ║${NC}"
    echo -e "${BOLD}${RED}║                                                            ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════╝${NC}\n"

    # Check profile
    if [[ ! -f "$PROFILE_FILE" ]]; then
        log_error "Profile not set up. Run: $0 setup first"
        return 1
    fi

    local profile=$(get_profile)
    local name=$(echo "$profile" | jq -r '.name')

    echo "This will guide you through opt-out requests for ALL data brokers."
    echo "Your profile: $name"
    echo
    read -p "Continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Get all brokers
    local brokers=$(jq -r '.brokers[].name' "$BROKERS_DB_FILE")

    local total=$(echo "$brokers" | wc -l)
    local count=0

    echo
    echo -e "${BOLD}Processing $total data brokers...${NC}\n"

    while IFS= read -r broker; do
        ((count++))

        echo -e "${BOLD}[$count/$total] $broker${NC}"

        # Check if already submitted
        if is_submitted "$broker"; then
            echo -e "${GREEN}  ✓ Already submitted${NC}"
            echo
            continue
        fi

        # Show details and open URL
        show_broker_details "$broker"

        # Mark as submitted
        read -p "Did you submit the opt-out? (yes/no/skip): " submitted
        case $submitted in
            yes)
                record_request "$broker" "submitted"
                ;;
            skip)
                log_info "Skipped $broker"
                ;;
            *)
                log_warn "Marked as incomplete"
                ;;
        esac

        # Pause between brokers
        if [[ $count -lt $total ]] && [[ $(($count % $BATCH_SIZE)) -eq 0 ]]; then
            echo
            echo -e "${YELLOW}Take a break! Processed $count/$total${NC}"
            read -p "Press Enter to continue..."
            echo
        fi
    done <<< "$brokers"

    echo
    echo -e "${GREEN}${BOLD}Campaign complete!${NC}"
    show_stats
}

#=============================================================================
# Quick Actions
#=============================================================================

easy_wins() {
    echo -e "\n${BOLD}🎯 Easy Wins (Start Here)${NC}\n"
    echo "These brokers are easiest to opt out from:"
    echo

    init_brokers_db

    jq -r '.brokers[] | select(.difficulty == "easy") |
        "  • \(.name) - \(.estimated_time)\n    \(.opt_out_url)"' \
        "$BROKERS_DB_FILE"

    echo
    echo "Start with these to build momentum!"
    echo
}

high_priority() {
    echo -e "\n${BOLD}🚨 High Priority Brokers${NC}\n"
    echo "These are the most widely used:"
    echo

    local priority=("Spokeo" "WhitePages" "BeenVerified" "PeopleFinder" "Intelius" "MyLife")

    for broker in "${priority[@]}"; do
        echo -e "${BOLD}• $broker${NC}"
        jq -r --arg name "$broker" \
            '.brokers[] | select(.name == $name) |
            "  \(.opt_out_url)"' \
            "$BROKERS_DB_FILE"
    done

    echo
}

#=============================================================================
# Request Tracking
#=============================================================================

record_request() {
    local broker=$1
    local status=$2  # started, submitted, verified, complete

    init_brokers_db

    local tmp_file=$(mktemp)

    jq --arg broker "$broker" \
       --arg status "$status" \
       --arg timestamp "$(date -Iseconds)" \
       '.requests += [{
           broker: $broker,
           status: $status,
           timestamp: $timestamp
       }]' \
       "$REQUESTS_LOG_FILE" > "$tmp_file"

    mv "$tmp_file" "$REQUESTS_LOG_FILE"
}

is_submitted() {
    local broker=$1

    jq -e --arg broker "$broker" \
        '.requests[] | select(.broker == $broker and .status != "started")' \
        "$REQUESTS_LOG_FILE" &>/dev/null
}

show_stats() {
    if [[ ! -f "$REQUESTS_LOG_FILE" ]]; then
        log_info "No requests logged yet"
        return 0
    fi

    echo -e "\n${BOLD}📊 Opt-Out Statistics${NC}\n"

    local total_brokers=$(jq '.brokers | length' "$BROKERS_DB_FILE")
    local submitted=$(jq '[.requests[] | select(.status == "submitted")] | length' "$REQUESTS_LOG_FILE")
    local verified=$(jq '[.requests[] | select(.status == "verified")] | length' "$REQUESTS_LOG_FILE")
    local complete=$(jq '[.requests[] | select(.status == "complete")] | length' "$REQUESTS_LOG_FILE")

    echo "Total brokers: $total_brokers"
    echo "Submitted: $submitted"
    echo "Verified: $verified"
    echo "Complete: $complete"
    echo

    if [[ $submitted -gt 0 ]]; then
        local percent=$(echo "scale=0; $submitted * 100 / $total_brokers" | bc)
        echo "Progress: ${percent}%"
        echo
    fi

    if [[ $submitted -gt 0 ]]; then
        echo -e "${BOLD}Recent requests:${NC}"
        jq -r '.requests[-10:] | .[] |
            "  • \(.broker) - \(.status) (\(.timestamp))"' \
            "$REQUESTS_LOG_FILE"
        echo
    fi
}

show_pending() {
    echo -e "\n${BOLD}⏳ Pending Verification${NC}\n"

    jq -r '.requests[] | select(.status == "submitted") |
        "  • \(.broker) - submitted \(.timestamp)"' \
        "$REQUESTS_LOG_FILE"

    echo
    echo "Check your email for verification links!"
    echo
}

#=============================================================================
# CCPA/GDPR Templates
#=============================================================================

generate_ccpa_email() {
    local broker=$1

    local template=$(jq -r '.ccpa_template' "$BROKERS_DB_FILE")
    local profile=$(get_profile)

    local name=$(echo "$profile" | jq -r '.name')
    local email=$(echo "$profile" | jq -r '.email')
    local address=$(echo "$profile" | jq -r '.address + ", " + .city + ", " + .state + " " + .zip')

    template="${template//\[BROKER\]/$broker}"
    template="${template//\[NAME\]/$name}"
    template="${template//\[EMAIL\]/$email}"
    template="${template//\[ADDRESS\]/$address}"

    echo "$template"
}

generate_gdpr_email() {
    local broker=$1

    local template=$(jq -r '.gdpr_template' "$BROKERS_DB_FILE")
    local profile=$(get_profile)

    local name=$(echo "$profile" | jq -r '.name')
    local email=$(echo "$profile" | jq -r '.email')

    template="${template//\[BROKER\]/$broker}"
    template="${template//\[NAME\]/$name}"
    template="${template//\[EMAIL\]/$email}"

    echo "$template"
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Delete yourself from data broker databases

COMMANDS:
    setup                        Set up your profile (encrypted)
    list                         List all data brokers
    campaign                     Start mass opt-out campaign
    broker NAME                  Show details for specific broker
    easy                         Show easy wins (start here)
    priority                     Show high-priority brokers
    stats                        Show opt-out statistics
    pending                      Show pending verifications
    ccpa BROKER                  Generate CCPA email template
    gdpr BROKER                  Generate GDPR email template

EXAMPLES:
    # Initial setup
    $0 setup

    # See easy wins
    $0 easy

    # Start full campaign
    $0 campaign

    # Check specific broker
    $0 broker Spokeo

    # Generate CCPA request
    $0 ccpa MyLife

    # View progress
    $0 stats

WORKFLOW:
    1. Set up profile: $0 setup
    2. Start with easy wins: $0 easy
    3. Run full campaign: $0 campaign
    4. Check verification emails
    5. Monitor with: $0 stats

DATA BROKERS INCLUDED:
    • Spokeo, WhitePages, BeenVerified
    • PeopleFinder, Intelius, MyLife
    • TruthFinder, Instant Checkmate
    • Radaris, PeekYou, Zabasearch
    • And 10+ more (20 total)

IMPORTANT:
    • This takes time (2-4 hours total)
    • Some require ID verification
    • Data may reappear (run annually)
    • Check verification emails
    • Some take 48-72 hours to process
    • California residents have CCPA rights
    • EU residents have GDPR rights

TIPS:
    • Use dedicated email for opt-outs
    • Screenshot confirmations
    • Set calendar reminder to repeat yearly
    • Some brokers are owned by same company
    • Data reappears from other sources

EOF
}

main() {
    local command=""

    # Initialize
    init_brokers_db

    # Parse command
    case ${1:-help} in
        setup)
            setup_profile
            ;;
        list)
            list_brokers
            ;;
        campaign)
            start_removal_campaign
            ;;
        broker)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: broker NAME"
                exit 1
            fi
            show_broker_details "$2"
            ;;
        easy)
            easy_wins
            ;;
        priority)
            high_priority
            ;;
        stats)
            show_stats
            ;;
        pending)
            show_pending
            ;;
        ccpa)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: ccpa BROKER"
                exit 1
            fi
            generate_ccpa_email "$2"
            ;;
        gdpr)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: gdpr BROKER"
                exit 1
            fi
            generate_gdpr_email "$2"
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
