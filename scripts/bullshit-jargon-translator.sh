#!/bin/bash
#=============================================================================
# bullshit-jargon-translator.sh
# Converts startup/corporate speak to actual English
# "Because 'we're pivoting' just means 'we failed'"
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

TRANSLATION_DB="$DATA_DIR/jargon_translations.json"
DETECTION_HISTORY="$DATA_DIR/jargon_detections.json"

# Feature flags
SHOW_SEVERITY=${SHOW_SEVERITY:-1}
SHOW_CATEGORY=${SHOW_CATEGORY:-1}
COLORIZE_OUTPUT=${COLORIZE_OUTPUT:-1}

#=============================================================================
# Jargon Translation Database
#=============================================================================

# Severity levels: buzzword, warning, red_flag, run_away
# Categories: failure, lying, meaningless, sales, tech, finance, hr

declare -A JARGON_MAP

init_jargon_database() {
    # Failure disguises
    JARGON_MAP["we're pivoting"]="we failed|red_flag|failure"
    JARGON_MAP["pivoting"]="changing direction because the first idea failed|red_flag|failure"
    JARGON_MAP["course correction"]="we were wrong|warning|failure"
    JARGON_MAP["strategic shift"]="we're panicking and changing everything|red_flag|failure"
    JARGON_MAP["refocusing our efforts"]="we wasted time on the wrong thing|warning|failure"
    JARGON_MAP["rightsizing"]="layoffs|red_flag|hr"
    JARGON_MAP["restructuring"]="layoffs but we're trying to sound smart|red_flag|hr"
    JARGON_MAP["optimizing headcount"]="firing people|red_flag|hr"
    JARGON_MAP["letting you go"]="firing you|red_flag|hr"
    JARGON_MAP["transitioning"]="firing|warning|hr"
    JARGON_MAP["parting ways"]="firing you but pretending it's mutual|warning|hr"

    # Lying/Misleading
    JARGON_MAP["pre-revenue"]="making zero dollars|warning|finance"
    JARGON_MAP["pre-profit"]="losing money|warning|finance"
    JARGON_MAP["growth stage"]="burning cash faster than we make it|warning|finance"
    JARGON_MAP["aggressive growth"]="spending money we don't have|red_flag|finance"
    JARGON_MAP["runway"]="months until bankruptcy|red_flag|finance"
    JARGON_MAP["extending runway"]="desperately trying not to die|red_flag|finance"
    JARGON_MAP["seeking funding"]="we're running out of money|warning|finance"
    JARGON_MAP["cash flow negative"]="losing money every month|warning|finance"
    JARGON_MAP["investment opportunity"]="give us money before we die|red_flag|finance"
    JARGON_MAP["equity compensation"]="we can't afford to pay you real money|warning|hr"
    JARGON_MAP["competitive salary"]="below market rate|warning|hr"

    # Meaningless buzzwords
    JARGON_MAP["synergy"]="meaningless buzzword|buzzword|meaningless"
    JARGON_MAP["synergize"]="work together (why not just say that?)|buzzword|meaningless"
    JARGON_MAP["leverage"]="use|buzzword|meaningless"
    JARGON_MAP["utilize"]="use|buzzword|meaningless"
    JARGON_MAP["circle back"]="talk about it later (probably never)|buzzword|meaningless"
    JARGON_MAP["touch base"]="have a pointless meeting|buzzword|meaningless"
    JARGON_MAP["reach out"]="email or call|buzzword|meaningless"
    JARGON_MAP["move the needle"]="make any impact at all|buzzword|meaningless"
    JARGON_MAP["low-hanging fruit"]="easy tasks we should've done already|buzzword|meaningless"
    JARGON_MAP["think outside the box"]="have a normal idea|buzzword|meaningless"
    JARGON_MAP["paradigm shift"]="change|buzzword|meaningless"
    JARGON_MAP["game changer"]="probably not a game changer|buzzword|meaningless"
    JARGON_MAP["disruptive"]="new (maybe)|buzzword|tech"
    JARGON_MAP["innovative"]="slightly different|buzzword|tech"
    JARGON_MAP["cutting edge"]="probably outdated in 6 months|buzzword|tech"
    JARGON_MAP["bleeding edge"]="unstable and will break|warning|tech"
    JARGON_MAP["best in class"]="mediocre|buzzword|sales"
    JARGON_MAP["world class"]="average|buzzword|sales"
    JARGON_MAP["industry leading"]="one of many competitors|buzzword|sales"
    JARGON_MAP["next generation"]="the current version with minor changes|buzzword|tech"

    # Sales speak
    JARGON_MAP["solution"]="product (just say product)|buzzword|sales"
    JARGON_MAP["ecosystem"]="several products we want you to buy|buzzword|sales"
    JARGON_MAP["platform"]="website or app|buzzword|tech"
    JARGON_MAP["end-to-end solution"]="we do everything (probably poorly)|buzzword|sales"
    JARGON_MAP["turnkey solution"]="off-the-shelf product|buzzword|sales"
    JARGON_MAP["white glove service"]="basic customer support|buzzword|sales"
    JARGON_MAP["value add"]="thing we're trying to upsell|buzzword|sales"
    JARGON_MAP["premium experience"]="expensive|buzzword|sales"
    JARGON_MAP["enterprise grade"]="expensive and complicated|warning|sales"

    # Tech buzzwords
    JARGON_MAP["ai-powered"]="has a simple algorithm|buzzword|tech"
    JARGON_MAP["machine learning"]="pattern matching|buzzword|tech"
    JARGON_MAP["blockchain"]="slow database|buzzword|tech"
    JARGON_MAP["web3"]="blockchain scam|red_flag|tech"
    JARGON_MAP["metaverse"]="VR chat room|buzzword|tech"
    JARGON_MAP["cloud-based"]="runs on someone else's computer|buzzword|tech"
    JARGON_MAP["serverless"]="still has servers, you just don't see them|buzzword|tech"
    JARGON_MAP["microservices"]="we split one app into 47 apps|warning|tech"
    JARGON_MAP["scalable"]="works on more than one computer|buzzword|tech"
    JARGON_MAP["full stack"]="knows some frontend and some backend|buzzword|tech"

    # Work culture BS
    JARGON_MAP["work hard play hard"]="unpaid overtime disguised as fun|red_flag|hr"
    JARGON_MAP["fast-paced environment"]="chaotic and disorganized|warning|hr"
    JARGON_MAP["wear many hats"]="do 3 jobs for the price of 1|red_flag|hr"
    JARGON_MAP["self-starter"]="you'll get zero training or support|warning|hr"
    JARGON_MAP["rockstar"]="we want to underpay someone talented|warning|hr"
    JARGON_MAP["ninja"]="we want to underpay someone talented|warning|hr"
    JARGON_MAP["guru"]="we want to underpay someone talented|warning|hr"
    JARGON_MAP["family"]="we'll guilt trip you into overtime|red_flag|hr"
    JARGON_MAP["like a family"]="toxic workplace pretending to care|red_flag|hr"
    JARGON_MAP["unlimited pto"]="you'll be guilted into taking none|warning|hr"
    JARGON_MAP["results-oriented"]="we measure everything and trust nothing|warning|hr"
    JARGON_MAP["agile"]="meetings about meetings|buzzword|tech"
    JARGON_MAP["scrum"]="daily status report meetings|buzzword|tech"

    # Time wasting
    JARGON_MAP["let's take this offline"]="stop talking, you're embarrassing me|buzzword|meaningless"
    JARGON_MAP["run it up the flagpole"]="ask someone else to decide|buzzword|meaningless"
    JARGON_MAP["deep dive"]="actually look at something|buzzword|meaningless"
    JARGON_MAP["drill down"]="look at details|buzzword|meaningless"
    JARGON_MAP["boil the ocean"]="waste time on impossible tasks|warning|meaningless"
    JARGON_MAP["move forward"]="do anything|buzzword|meaningless"
    JARGON_MAP["action items"]="tasks|buzzword|meaningless"
    JARGON_MAP["bandwidth"]="time|buzzword|meaningless"
    JARGON_MAP["capacity"]="time|buzzword|meaningless"
    JARGON_MAP["on my radar"]="I'm aware but won't do anything|buzzword|meaningless"

    # Misc corporate speak
    JARGON_MAP["double-click"]="look closer|buzzword|meaningless"
    JARGON_MAP["take it to the next level"]="improve it|buzzword|meaningless"
    JARGON_MAP["empower"]="allow|buzzword|meaningless"
    JARGON_MAP["proactive"]="doing your job|buzzword|meaningless"
    JARGON_MAP["ownership"]="blame if it fails|warning|hr"
    JARGON_MAP["accountability"]="someone to blame|warning|hr"
    JARGON_MAP["transparency"]="we're watching you|warning|hr"
    JARGON_MAP["alignment"]="everyone agree with management|warning|hr"
    JARGON_MAP["buy-in"]="agree with our decision|buzzword|meaningless"
    JARGON_MAP["stakeholders"]="people who have opinions|buzzword|meaningless"
    JARGON_MAP["key stakeholders"]="people whose opinions matter|buzzword|meaningless"
}

#=============================================================================
# Translation Functions
#=============================================================================

translate_text() {
    local input_text=$1
    local translated_text="$input_text"
    local detections=0
    local severity_count_buzzword=0
    local severity_count_warning=0
    local severity_count_red_flag=0
    local severity_count_run_away=0

    local detection_log=""

    # Sort jargon by length (longest first) to avoid partial matches
    local sorted_jargon=()
    while IFS= read -r jargon; do
        sorted_jargon+=("$jargon")
    done < <(printf '%s\n' "${!JARGON_MAP[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

    # Detect and replace jargon
    for jargon in "${sorted_jargon[@]}"; do
        IFS='|' read -r translation severity category <<< "${JARGON_MAP[$jargon]}"

        # Case-insensitive search
        if echo "$input_text" | grep -qi "$jargon"; then
            ((detections++))

            case $severity in
                buzzword) ((severity_count_buzzword++)) ;;
                warning) ((severity_count_warning++)) ;;
                red_flag) ((severity_count_red_flag++)) ;;
                run_away) ((severity_count_run_away++)) ;;
            esac

            # Build replacement with color/markers
            local replacement=""
            if [[ $COLORIZE_OUTPUT -eq 1 ]]; then
                case $severity in
                    buzzword)
                        replacement="${YELLOW}${translation}${NC}"
                        ;;
                    warning)
                        replacement="${YELLOW}${BOLD}${translation}${NC}"
                        ;;
                    red_flag)
                        replacement="${RED}${BOLD}${translation}${NC}"
                        ;;
                    run_away)
                        replacement="${RED}${BOLD}🚩 ${translation} 🚩${NC}"
                        ;;
                esac
            else
                replacement="$translation"
            fi

            # Add annotation if enabled
            if [[ $SHOW_SEVERITY -eq 1 ]] || [[ $SHOW_CATEGORY -eq 1 ]]; then
                local annotation=" ["
                [[ $SHOW_SEVERITY -eq 1 ]] && annotation+="$severity"
                [[ $SHOW_SEVERITY -eq 1 ]] && [[ $SHOW_CATEGORY -eq 1 ]] && annotation+=":"
                [[ $SHOW_CATEGORY -eq 1 ]] && annotation+="$category"
                annotation+="]"
                replacement+="$annotation"
            fi

            # Replace in text (case-insensitive)
            translated_text=$(echo "$translated_text" | sed "s/$jargon/$replacement/gi" 2>/dev/null || \
                              echo "$translated_text" | awk -v find="$jargon" -v replace="$replacement" 'BEGIN{IGNORECASE=1} {gsub(find,replace); print}')

            # Log detection
            detection_log+="  ${CYAN}•${NC} \"$jargon\" → \"$translation\" [$severity:$category]\n"
        fi
    done

    # Output results
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           BULLSHIT JARGON TRANSLATOR v1.0                 ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ $detections -eq 0 ]]; then
        echo -e "${GREEN}✅ No corporate BS detected! This text is surprisingly honest.${NC}"
        echo ""
        echo "$input_text"
    else
        echo -e "${RED}🚨 BS DETECTED: $detections instances of corporate jargon found${NC}"
        echo ""

        # Show severity breakdown
        echo -e "${BOLD}Severity Breakdown:${NC}"
        [[ $severity_count_buzzword -gt 0 ]] && echo -e "  ${YELLOW}●${NC} Buzzwords: $severity_count_buzzword"
        [[ $severity_count_warning -gt 0 ]] && echo -e "  ${YELLOW}⚠${NC}  Warnings: $severity_count_warning"
        [[ $severity_count_red_flag -gt 0 ]] && echo -e "  ${RED}🚩${NC} Red Flags: $severity_count_red_flag"
        [[ $severity_count_run_away -gt 0 ]] && echo -e "  ${RED}🏃${NC} RUN AWAY: $severity_count_run_away"
        echo ""

        # Show detections
        echo -e "${BOLD}Detected Jargon:${NC}"
        echo -e "$detection_log"

        # Show translated text
        echo -e "${BOLD}Translated Text:${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "$translated_text"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Overall assessment
        local bs_score=$((detections * 10))
        if [[ $severity_count_run_away -gt 0 ]] || [[ $severity_count_red_flag -ge 3 ]]; then
            echo -e "${RED}${BOLD}🚨 CRITICAL BS LEVEL 🚨${NC}"
            echo -e "${RED}Assessment: This communication is 95%+ corporate bullshit. RUN.${NC}"
        elif [[ $severity_count_red_flag -gt 0 ]] || [[ $severity_count_warning -ge 3 ]]; then
            echo -e "${YELLOW}${BOLD}⚠️  HIGH BS LEVEL ⚠️${NC}"
            echo -e "${YELLOW}Assessment: Major red flags detected. Proceed with extreme caution.${NC}"
        elif [[ $detections -ge 5 ]]; then
            echo -e "${YELLOW}MODERATE BS LEVEL${NC}"
            echo -e "Assessment: Typical corporate speak. Translate before taking seriously."
        else
            echo -e "${BLUE}LOW BS LEVEL${NC}"
            echo -e "Assessment: Some buzzwords but mostly harmless."
        fi
        echo ""

        # Record detection
        record_detection "$detections" "$severity_count_red_flag"
    fi
}

#=============================================================================
# Input Handling
#=============================================================================

translate_from_stdin() {
    log_info "Reading from stdin (Ctrl+D when done)..."
    local input_text=$(cat)
    translate_text "$input_text"
}

translate_from_file() {
    local file_path=$1

    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi

    log_info "Translating file: $file_path"
    local input_text=$(cat "$file_path")
    translate_text "$input_text"
}

translate_interactive() {
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║       INTERACTIVE BULLSHIT JARGON TRANSLATOR              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Paste your corporate speak below (empty line to translate):"
    echo ""

    local input_text=""
    local line=""
    local empty_count=0

    while true; do
        read -r line

        if [[ -z "$line" ]]; then
            ((empty_count++))
            if [[ $empty_count -ge 1 ]] && [[ -n "$input_text" ]]; then
                break
            fi
        else
            empty_count=0
            input_text+="$line"$'\n'
        fi
    done

    if [[ -n "$input_text" ]]; then
        translate_text "$input_text"
    else
        log_warn "No input provided"
    fi
}

#=============================================================================
# Common Phrases (Quick Reference)
#=============================================================================

show_common_phrases() {
    cat <<'EOF'

╔═══════════════════════════════════════════════════════════╗
║          COMMON STARTUP/CORPORATE JARGON                  ║
╚═══════════════════════════════════════════════════════════╝

💸 FINANCE RED FLAGS:
  "Pre-revenue"               → Making zero dollars
  "Extending runway"          → Desperately trying not to die
  "Investment opportunity"    → Give us money before we die
  "Aggressive growth"         → Spending money we don't have

🚩 HR RED FLAGS:
  "We're like a family"       → Toxic workplace pretending to care
  "Wear many hats"            → Do 3 jobs for the price of 1
  "Work hard, play hard"      → Unpaid overtime disguised as fun
  "Unlimited PTO"             → You'll be guilted into taking none
  "Rockstar/Ninja/Guru"       → We want to underpay someone talented

💔 FAILURE DISGUISES:
  "We're pivoting"            → We failed
  "Strategic shift"           → We're panicking and changing everything
  "Rightsizing"               → Layoffs
  "Letting you go"            → Firing you

🤡 MEANINGLESS BUZZWORDS:
  "Synergy"                   → Meaningless buzzword
  "Leverage"                  → Use
  "Circle back"               → Talk about it later (probably never)
  "Low-hanging fruit"         → Easy tasks we should've done already
  "Think outside the box"     → Have a normal idea

💻 TECH BUZZWORDS:
  "AI-powered"                → Has a simple algorithm
  "Blockchain"                → Slow database
  "Cloud-based"               → Runs on someone else's computer
  "Disruptive"                → New (maybe)

EOF
}

#=============================================================================
# Detection History & Stats
#=============================================================================

init_detection_history() {
    if [[ ! -f "$DETECTION_HISTORY" ]]; then
        echo '{"detections": [], "total_jargon_found": 0, "total_translations": 0}' > "$DETECTION_HISTORY"
    fi
}

record_detection() {
    local count=$1
    local red_flags=$2

    init_detection_history

    local tmp_file=$(mktemp)

    jq --arg count "$count" \
       --arg red_flags "$red_flags" \
       --arg timestamp "$(date -Iseconds)" \
       '.detections += [{count: ($count | tonumber), red_flags: ($red_flags | tonumber), timestamp: $timestamp}] |
        .total_jargon_found += ($count | tonumber) |
        .total_translations += 1' \
       "$DETECTION_HISTORY" > "$tmp_file"

    mv "$tmp_file" "$DETECTION_HISTORY"

    # Keep last 100 detections
    jq '.detections = .detections[-100:]' "$DETECTION_HISTORY" > "$tmp_file"
    mv "$tmp_file" "$DETECTION_HISTORY"
}

show_stats() {
    init_detection_history

    local total_translations=$(jq -r '.total_translations' "$DETECTION_HISTORY")
    local total_jargon=$(jq -r '.total_jargon_found' "$DETECTION_HISTORY")
    local avg_per_translation=$((total_jargon / (total_translations > 0 ? total_translations : 1)))

    cat <<EOF

╔═══════════════════════════════════════════════════════════╗
║              JARGON DETECTION STATISTICS                  ║
╚═══════════════════════════════════════════════════════════╝

Total texts analyzed: $total_translations
Total jargon detected: $total_jargon
Average BS per text: $avg_per_translation instances

Recent translations:
EOF

    jq -r '.detections[-10:] | .[] | "  \(.timestamp | split("T")[0]) - \(.count) instances (\(.red_flags) red flags)"' \
        "$DETECTION_HISTORY" 2>/dev/null || echo "  None yet"

    echo ""
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [COMMAND] [FILE]

Translate startup/corporate jargon into actual English

COMMANDS:
    translate [FILE]     Translate text from file or stdin
    interactive          Interactive translation mode
    phrases              Show common jargon phrases
    stats                Show detection statistics
    test                 Run test translation

OPTIONS:
    --no-color           Disable colored output
    --no-severity        Don't show severity levels
    --no-category        Don't show jargon categories
    -h, --help           Show this help

EXAMPLES:
    # Interactive mode
    $0 interactive

    # Translate from file
    $0 translate job_description.txt

    # Translate from stdin
    echo "We're pivoting to a blockchain solution" | $0 translate

    # Translate email
    cat startup_email.txt | $0 translate

    # Show common phrases
    $0 phrases

    # View stats
    $0 stats

SAMPLE INPUT:
    "We're seeking a rockstar ninja to join our fast-paced,
    pre-revenue startup. We're pivoting to a blockchain-based
    AI solution with synergistic leverage of our ecosystem."

TRANSLATED OUTPUT:
    "We're seeking someone talented we want to underpay to join
    our chaotic and disorganized, making zero dollars startup.
    We're changing direction because the first idea failed to a
    slow database-based has a simple algorithm product with
    meaningless buzzword use of our several products we want you
    to buy."

SEVERITY LEVELS:
    buzzword   - Harmless but annoying
    warning    - Concerning, investigate further
    red_flag   - Major warning sign
    run_away   - Critical, avoid immediately

EOF
}

main() {
    local command="interactive"
    local input_file=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-color)
                COLORIZE_OUTPUT=0
                shift
                ;;
            --no-severity)
                SHOW_SEVERITY=0
                shift
                ;;
            --no-category)
                SHOW_CATEGORY=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            translate|interactive|phrases|stats|test)
                command=$1
                shift
                ;;
            *)
                input_file=$1
                shift
                ;;
        esac
    done

    # Initialize jargon database
    init_jargon_database

    # Check dependencies
    check_commands jq sed awk

    # Execute command
    case $command in
        translate)
            if [[ -n "$input_file" ]]; then
                translate_from_file "$input_file"
            else
                translate_from_stdin
            fi
            ;;
        interactive)
            translate_interactive
            ;;
        phrases)
            show_common_phrases
            ;;
        stats)
            show_stats
            ;;
        test)
            log_info "Running test translation..."
            local test_text="We're seeking a rockstar to join our fast-paced, pre-revenue startup. We're pivoting to leverage blockchain synergies in our AI-powered ecosystem. This is a game-changing opportunity for a self-starter who can wear many hats. We're like a family with unlimited PTO and work hard, play hard culture."
            echo ""
            echo -e "${BOLD}TEST INPUT:${NC}"
            echo "$test_text"
            echo ""
            translate_text "$test_text"
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
