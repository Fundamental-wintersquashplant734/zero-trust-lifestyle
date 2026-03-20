#!/bin/bash
#=============================================================================
# random-skill-learner.sh
# Picks random skill, blocks distractions until you learn basics
# "You have 30 days. Twitter is blocked. Learn Rust or stay blocked."
#=============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

#=============================================================================
# Configuration
#=============================================================================

SKILLS_DB_FILE="$DATA_DIR/skills.json"
CURRENT_SKILL_FILE="$DATA_DIR/current_skill.json"
PROGRESS_LOG_FILE="$DATA_DIR/skill_progress.json"
BLOCKED_SITES_FILE="$DATA_DIR/skill_blocker_sites.txt"

# Learning settings
LEARNING_PERIOD=30  # Days to learn basics
DAILY_PRACTICE_MINUTES=30
ENABLE_BLOCKING=1
STRICT_MODE=0  # If 1, blocks EVERYTHING except learning resources

# Verification
REQUIRE_PROOF=1
MIN_CHECKPOINTS=3  # Minimum checkpoints to complete

#=============================================================================
# Skills Database
#=============================================================================

init_skills_db() {
    mkdir -p "$DATA_DIR"

    if [[ ! -f "$SKILLS_DB_FILE" ]]; then
        cat > "$SKILLS_DB_FILE" <<'EOF'
{
  "skills": [
    {
      "name": "Rust Programming",
      "category": "programming",
      "difficulty": 7,
      "time_estimate": "30 days",
      "why_useful": "Systems programming, performance, safety",
      "resources": [
        "https://doc.rust-lang.org/book/",
        "https://www.rust-lang.org/learn",
        "https://exercism.org/tracks/rust"
      ],
      "checkpoints": [
        "Install Rust and run 'Hello World'",
        "Understand ownership and borrowing",
        "Complete 5 Exercism exercises",
        "Build a CLI tool",
        "Understand lifetimes"
      ],
      "daily_practice": "Write 50 lines of Rust code",
      "projects": [
        "CLI todo app",
        "Web scraper",
        "Simple HTTP server"
      ]
    },
    {
      "name": "Touch Typing",
      "category": "productivity",
      "difficulty": 4,
      "time_estimate": "30 days",
      "why_useful": "60+ WPM increases productivity 20%",
      "resources": [
        "https://www.keybr.com/",
        "https://monkeytype.com/",
        "https://www.typingclub.com/"
      ],
      "checkpoints": [
        "Type 30 WPM without looking",
        "Type 40 WPM with 95% accuracy",
        "Type 50 WPM with 98% accuracy",
        "Type 60 WPM consistently"
      ],
      "daily_practice": "30 minutes typing practice",
      "projects": [
        "Reach 60 WPM",
        "Touch type code",
        "Take typing test"
      ]
    },
    {
      "name": "Docker & Containers",
      "category": "devops",
      "difficulty": 5,
      "time_estimate": "21 days",
      "why_useful": "Essential for modern development",
      "resources": [
        "https://docs.docker.com/get-started/",
        "https://www.docker.com/101-tutorial",
        "https://github.com/docker/awesome-compose"
      ],
      "checkpoints": [
        "Install Docker and run hello-world",
        "Build a custom Dockerfile",
        "Use docker-compose for multi-container app",
        "Push image to Docker Hub",
        "Understand volumes and networks"
      ],
      "daily_practice": "Containerize one project",
      "projects": [
        "Dockerize a web app",
        "Multi-container app with docker-compose",
        "CI/CD with Docker"
      ]
    },
    {
      "name": "Spanish (Conversational)",
      "category": "language",
      "difficulty": 8,
      "time_estimate": "90 days",
      "why_useful": "500M+ speakers worldwide",
      "resources": [
        "https://www.duolingo.com/course/es/en",
        "https://www.spanishdict.com/",
        "https://www.languagetransfer.org/"
      ],
      "checkpoints": [
        "Learn 100 common words",
        "Master present tense",
        "Hold 5-minute conversation",
        "Understand simple podcast",
        "Write 500-word essay"
      ],
      "daily_practice": "30 minutes Duolingo + 1 podcast",
      "projects": [
        "Write daily journal in Spanish",
        "Have conversation with native speaker",
        "Watch movie with Spanish subtitles"
      ]
    },
    {
      "name": "Vim/Neovim",
      "category": "productivity",
      "difficulty": 6,
      "time_estimate": "30 days",
      "why_useful": "Edit at the speed of thought",
      "resources": [
        "https://www.openvim.com/",
        "https://vim-adventures.com/",
        "vimtutor (built-in)"
      ],
      "checkpoints": [
        "Complete vimtutor",
        "Use vim for all editing (no VSCode)",
        "Master motions (w, b, f, t)",
        "Use vim in 10 coding sessions",
        "Configure custom vimrc"
      ],
      "daily_practice": "Use vim exclusively for 1 hour",
      "projects": [
        "Build custom vim config",
        "Learn 20 vim commands",
        "Edit code faster than before"
      ]
    },
    {
      "name": "SQL & Databases",
      "category": "data",
      "difficulty": 5,
      "time_estimate": "21 days",
      "why_useful": "Data is everywhere",
      "resources": [
        "https://sqlzoo.net/",
        "https://www.postgresqltutorial.com/",
        "https://www.db-fiddle.com/"
      ],
      "checkpoints": [
        "Understand SELECT, WHERE, JOIN",
        "Write complex queries with subqueries",
        "Design normalized database schema",
        "Use indexes effectively",
        "Understand transactions"
      ],
      "daily_practice": "Solve 5 SQL problems",
      "projects": [
        "Design database for personal project",
        "Optimize slow query",
        "Build reporting dashboard"
      ]
    },
    {
      "name": "Photography Basics",
      "category": "creative",
      "difficulty": 4,
      "time_estimate": "30 days",
      "why_useful": "Creative expression + marketable skill",
      "resources": [
        "https://www.r-photoclass.com/",
        "https://www.cambridgeincolour.com/",
        "YouTube: Photography basics"
      ],
      "checkpoints": [
        "Understand aperture, shutter, ISO",
        "Shoot in manual mode",
        "Compose using rule of thirds",
        "Edit photos in Lightroom/GIMP",
        "Take 100 photos"
      ],
      "daily_practice": "Take 10 photos in manual mode",
      "projects": [
        "Photo series (50 photos)",
        "Portrait session",
        "Landscape photography"
      ]
    },
    {
      "name": "Drawing/Sketching",
      "category": "creative",
      "difficulty": 6,
      "time_estimate": "60 days",
      "why_useful": "Visual thinking + creativity",
      "resources": [
        "https://drawabox.com/",
        "YouTube: Proko",
        "https://www.ctrlpaint.com/"
      ],
      "checkpoints": [
        "Complete Drawabox Lesson 1",
        "Draw 100 boxes",
        "Sketch from observation daily",
        "Understand perspective",
        "Draw recognizable portrait"
      ],
      "daily_practice": "Draw for 30 minutes",
      "projects": [
        "Sketch 365 challenge",
        "Portrait from reference",
        "Comic/storyboard"
      ]
    },
    {
      "name": "Machine Learning Basics",
      "category": "ai",
      "difficulty": 8,
      "time_estimate": "45 days",
      "why_useful": "Future of tech",
      "resources": [
        "https://www.coursera.org/learn/machine-learning",
        "https://www.kaggle.com/learn",
        "https://scikit-learn.org/stable/tutorial/index.html"
      ],
      "checkpoints": [
        "Understand supervised vs unsupervised",
        "Implement linear regression from scratch",
        "Build classification model",
        "Use scikit-learn effectively",
        "Complete Kaggle competition"
      ],
      "daily_practice": "1 hour ML course + coding",
      "projects": [
        "Predict housing prices",
        "Image classifier",
        "Kaggle competition entry"
      ]
    },
    {
      "name": "Public Speaking",
      "category": "soft_skills",
      "difficulty": 7,
      "time_estimate": "30 days",
      "why_useful": "Career advancement + influence",
      "resources": [
        "Toastmasters",
        "https://speaking.io/",
        "YouTube: TED Talk analysis"
      ],
      "checkpoints": [
        "Give 3-minute presentation to friend",
        "Speak at team meeting",
        "Give 10-minute presentation",
        "Speak at local meetup",
        "Handle Q&A confidently"
      ],
      "daily_practice": "Practice speaking for 15 minutes",
      "projects": [
        "Lightning talk at meetup",
        "YouTube video",
        "Teach something publicly"
      ]
    },
    {
      "name": "Cooking Fundamentals",
      "category": "life_skills",
      "difficulty": 4,
      "time_estimate": "30 days",
      "why_useful": "Save money, healthier, impress people",
      "resources": [
        "https://www.seriouseats.com/",
        "YouTube: Basics with Babish",
        "Salt Fat Acid Heat (book)"
      ],
      "checkpoints": [
        "Master knife skills",
        "Cook 5 basic proteins properly",
        "Make stock from scratch",
        "Cook 20 different recipes",
        "Understand flavor balancing"
      ],
      "daily_practice": "Cook one meal from scratch",
      "projects": [
        "Cook 30 meals in 30 days",
        "Host dinner party",
        "Master 5 cuisines"
      ]
    },
    {
      "name": "Linux Command Line",
      "category": "technical",
      "difficulty": 5,
      "time_estimate": "21 days",
      "why_useful": "Essential for developers",
      "resources": [
        "https://linuxjourney.com/",
        "https://overthewire.org/wargames/bandit/",
        "https://www.learnenough.com/command-line-tutorial"
      ],
      "checkpoints": [
        "Navigate filesystem confidently",
        "Use pipes and redirection",
        "Write bash scripts",
        "Understand permissions",
        "Use sed/awk/grep"
      ],
      "daily_practice": "Do everything in terminal for 1 hour",
      "projects": [
        "Automate daily task with script",
        "Complete Bandit wargame",
        "Build CLI tool"
      ]
    }
  ],
  "custom_skills": []
}
EOF
        log_success "Initialized skills database with 12 skills"
    fi

    if [[ ! -f "$PROGRESS_LOG_FILE" ]]; then
        echo '{"skills_learned": []}' > "$PROGRESS_LOG_FILE"
    fi

    if [[ ! -f "$BLOCKED_SITES_FILE" ]]; then
        cat > "$BLOCKED_SITES_FILE" <<'EOF'
# Distraction sites to block during learning
reddit.com
twitter.com
x.com
facebook.com
instagram.com
tiktok.com
youtube.com
netflix.com
twitch.tv
9gag.com
imgur.com
news.ycombinator.com
lobste.rs
linkedin.com
discord.com
EOF
    fi
}

add_custom_skill() {
    local name=$1
    local category=$2
    local difficulty=$3
    shift 3
    local resources=("$@")

    init_skills_db

    local resources_json=$(printf '%s\n' "${resources[@]}" | jq -R . | jq -s .)
    local tmp_file=$(mktemp)

    jq --arg name "$name" \
       --arg category "$category" \
       --argjson difficulty "$difficulty" \
       --argjson resources "$resources_json" \
       '.custom_skills += [{
           name: $name,
           category: $category,
           difficulty: $difficulty,
           resources: $resources,
           checkpoints: [],
           daily_practice: "Practice for 30 minutes"
       }]' \
       "$SKILLS_DB_FILE" > "$tmp_file"

    mv "$tmp_file" "$SKILLS_DB_FILE"

    log_success "Added custom skill: $name"
}

list_skills() {
    init_skills_db

    echo -e "\n${BOLD}🎯 Available Skills to Learn${NC}\n"

    jq -r '.skills[] |
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
        "\u001b[1m\(.name)\u001b[0m\n" +
        "  Category: \(.category) | Difficulty: \(.difficulty)/10 | Time: \(.time_estimate)\n" +
        "  Why: \(.why_useful)\n" +
        "  Resources: \(.resources | length) links\n" +
        "  Checkpoints: \(.checkpoints | length) milestones\n"' \
        "$SKILLS_DB_FILE"

    local custom_count=$(jq '.custom_skills | length' "$SKILLS_DB_FILE")
    if [[ $custom_count -gt 0 ]]; then
        echo -e "${BOLD}Custom Skills:${NC}\n"
        jq -r '.custom_skills[] | "  • \(.name) (\(.category))"' "$SKILLS_DB_FILE"
        echo
    fi

    local total=$(jq '(.skills | length) + (.custom_skills | length)' "$SKILLS_DB_FILE")
    echo -e "${BOLD}Total skills available: $total${NC}\n"
}

#=============================================================================
# Skill Selection
#=============================================================================

pick_random_skill() {
    local category=${1:-""}

    init_skills_db

    local filter="."
    if [[ -n "$category" ]]; then
        filter="select(.category == \"$category\")"
    fi

    # Get all skills
    local skills=$(jq -r "[.skills[] | $filter | .name] | unique | .[]" "$SKILLS_DB_FILE")

    local count=$(echo "$skills" | wc -l)
    if [[ $count -eq 0 ]]; then
        log_error "No skills found"
        return 1
    fi

    local random_index=$(( RANDOM % count ))
    echo "$skills" | sed -n "$((random_index + 1))p"
}

get_skill_details() {
    local skill_name=$1

    init_skills_db

    jq --arg name "$skill_name" '.skills[] | select(.name == $name)' "$SKILLS_DB_FILE"
}

#=============================================================================
# The Algorithm - Pick and Start
#=============================================================================

the_algorithm() {
    local category=${1:-""}

    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                                                            ║${NC}"
    echo -e "${BOLD}${CYAN}║          📚 THE ALGORITHM PICKS YOUR SKILL 📚           ║${NC}"
    echo -e "${BOLD}${CYAN}║                                                            ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    # Pick skill
    local skill_name=$(pick_random_skill "$category")

    if [[ -z "$skill_name" ]]; then
        log_error "Failed to pick skill"
        return 1
    fi

    local skill=$(get_skill_details "$skill_name")

    # Display skill
    echo -e "${BOLD}${GREEN}You will learn:${NC}\n"
    echo -e "${YELLOW}${BOLD}    $skill_name${NC}\n"

    echo -e "${BOLD}Why this matters:${NC}"
    echo "$skill" | jq -r '"  " + .why_useful'
    echo

    echo -e "${BOLD}Time commitment:${NC}"
    echo "$skill" | jq -r '"  • Total: " + .time_estimate'
    echo "$skill" | jq -r '"  • Daily: " + .daily_practice'
    echo

    echo -e "${BOLD}Learning resources:${NC}"
    echo "$skill" | jq -r '.resources[] | "  • \(.)"'
    echo

    echo -e "${BOLD}Checkpoints (must complete all):${NC}"
    echo "$skill" | jq -r '.checkpoints[] | "  [ ] \(.)"'
    echo

    # Ask for confirmation
    read -p "Ready to commit to learning this? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Skill rejected. Pick again or face the same one."
        return 0
    fi

    # Save current skill
    start_learning "$skill_name"

    # Enable blocking
    if [[ $ENABLE_BLOCKING -eq 1 ]]; then
        enable_distraction_blocking
    fi
}

#=============================================================================
# Learning Session Management
#=============================================================================

start_learning() {
    local skill_name=$1

    local skill=$(get_skill_details "$skill_name")
    local end_date=$(date -d "+${LEARNING_PERIOD} days" +%Y-%m-%d 2>/dev/null || date -v+${LEARNING_PERIOD}d +%Y-%m-%d 2>/dev/null)

    # Save to current skill file
    echo "$skill" | jq --arg start "$(date -Iseconds)" \
                        --arg end "$end_date" \
                        '. + {
                            started_at: $start,
                            end_date: $end,
                            checkpoints_completed: [],
                            days_practiced: 0,
                            total_minutes: 0
                        }' > "$CURRENT_SKILL_FILE"

    log_success "Started learning: $skill_name"
    log_info "You have $LEARNING_PERIOD days to complete the basics"
    log_info "Deadline: $end_date"

    echo
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}  Distractions are now blocked. Learn or stay blocked.${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

#=============================================================================
# Distraction Blocking
#=============================================================================

enable_distraction_blocking() {
    if ! is_root && [[ $ENABLE_BLOCKING -eq 1 ]]; then
        log_warn "Need sudo to enable website blocking"
        log_info "Run with sudo or manually add to /etc/hosts:"
        cat "$BLOCKED_SITES_FILE"
        return 1
    fi

    if ! is_root; then
        return 0
    fi

    log_info "Blocking distraction websites..."

    # Backup hosts file
    if [[ ! -f /etc/hosts.backup.skill-learner ]]; then
        cp /etc/hosts /etc/hosts.backup.skill-learner
    fi

    # Add blocked sites
    while IFS= read -r site; do
        [[ "$site" =~ ^# ]] && continue
        [[ -z "$site" ]] && continue

        if ! grep -q "127.0.0.1 $site" /etc/hosts; then
            echo "127.0.0.1 $site" >> /etc/hosts
            echo "127.0.0.1 www.$site" >> /etc/hosts
        fi
    done < "$BLOCKED_SITES_FILE"

    # Flush DNS
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
    fi

    log_success "Distraction blocking enabled!"
    echo
    echo -e "${YELLOW}Blocked sites:${NC}"
    cat "$BLOCKED_SITES_FILE" | grep -v "^#" | sed 's/^/  • /'
    echo
}

disable_distraction_blocking() {
    if ! is_root; then
        log_warn "Need sudo to disable blocking"
        return 1
    fi

    log_info "Removing distraction blocks..."

    if [[ -f /etc/hosts.backup.skill-learner ]]; then
        cp /etc/hosts.backup.skill-learner /etc/hosts
        rm /etc/hosts.backup.skill-learner
    fi

    # Flush DNS
    if command -v systemd-resolve &> /dev/null; then
        systemd-resolve --flush-caches 2>/dev/null || true
    elif command -v dscacheutil &> /dev/null; then
        dscacheutil -flushcache 2>/dev/null || true
    fi

    log_success "Blocking disabled"
}

#=============================================================================
# Progress Tracking
#=============================================================================

log_practice_session() {
    local minutes=${1:-30}

    if [[ ! -f "$CURRENT_SKILL_FILE" ]]; then
        log_error "No active learning session"
        return 1
    fi

    local tmp_file=$(mktemp)

    jq --argjson minutes "$minutes" \
       --arg date "$(date +%Y-%m-%d)" \
       '.days_practiced += 1 |
        .total_minutes += $minutes |
        .last_practice = $date' \
       "$CURRENT_SKILL_FILE" > "$tmp_file"

    mv "$tmp_file" "$CURRENT_SKILL_FILE"

    log_success "Logged $minutes minutes of practice"

    # Show progress
    show_progress
}

complete_checkpoint() {
    local checkpoint=$1

    if [[ ! -f "$CURRENT_SKILL_FILE" ]]; then
        log_error "No active learning session"
        return 1
    fi

    # Ask for evidence
    if [[ $REQUIRE_PROOF -eq 1 ]]; then
        echo "Provide evidence (description, screenshot path, URL):"
        read -r evidence
    else
        evidence="Completed"
    fi

    local tmp_file=$(mktemp)

    jq --arg checkpoint "$checkpoint" \
       --arg evidence "$evidence" \
       --arg timestamp "$(date -Iseconds)" \
       '.checkpoints_completed += [{
           checkpoint: $checkpoint,
           evidence: $evidence,
           completed_at: $timestamp
       }]' \
       "$CURRENT_SKILL_FILE" > "$tmp_file"

    mv "$tmp_file" "$CURRENT_SKILL_FILE"

    log_success "Checkpoint completed: $checkpoint"

    # Check if all checkpoints done
    local total=$(jq '.checkpoints | length' "$CURRENT_SKILL_FILE")
    local completed=$(jq '.checkpoints_completed | length' "$CURRENT_SKILL_FILE")

    echo
    echo -e "${BOLD}Progress: $completed/$total checkpoints${NC}"

    if [[ $completed -ge $total ]]; then
        echo
        echo -e "${GREEN}${BOLD}🎉 ALL CHECKPOINTS COMPLETE! 🎉${NC}"
        echo
        read -p "Mark skill as learned? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            complete_skill
        fi
    fi
}

complete_skill() {
    if [[ ! -f "$CURRENT_SKILL_FILE" ]]; then
        log_error "No active learning session"
        return 1
    fi

    local skill_name=$(jq -r '.name' "$CURRENT_SKILL_FILE")

    # Move to completed
    local tmp_file=$(mktemp)

    local current_skill=$(cat "$CURRENT_SKILL_FILE")

    jq --argjson skill "$current_skill" \
       '.skills_learned += [$skill]' \
       "$PROGRESS_LOG_FILE" > "$tmp_file"

    mv "$tmp_file" "$PROGRESS_LOG_FILE"

    # Clear current skill
    rm "$CURRENT_SKILL_FILE"

    # Disable blocking
    if [[ $ENABLE_BLOCKING -eq 1 ]]; then
        disable_distraction_blocking
    fi

    echo
    echo -e "${GREEN}${BOLD}"
    cat <<'EOF'
    ███████╗██╗  ██╗██╗██╗     ██╗         ██╗     ███████╗ █████╗ ██████╗ ███╗   ██╗███████╗██████╗ ██╗
    ██╔════╝██║ ██╔╝██║██║     ██║         ██║     ██╔════╝██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔══██╗██║
    ███████╗█████╔╝ ██║██║     ██║         ██║     █████╗  ███████║██████╔╝██╔██╗ ██║█████╗  ██║  ██║██║
    ╚════██║██╔═██╗ ██║██║     ██║         ██║     ██╔══╝  ██╔══██║██╔══██╗██║╚██╗██║██╔══╝  ██║  ██║╚═╝
    ███████║██║  ██╗██║███████╗███████╗    ███████╗███████╗██║  ██║██║  ██║██║ ╚████║███████╗██████╔╝██╗
    ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝    ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═════╝ ╚═╝
EOF
    echo -e "${NC}\n"

    log_success "Congratulations! You learned: $skill_name"

    # Show stats
    show_stats

    echo
    read -p "Pick next skill now? (yes/no): " next
    if [[ "$next" == "yes" ]]; then
        the_algorithm
    fi
}

#=============================================================================
# Status & Statistics
#=============================================================================

show_current() {
    if [[ ! -f "$CURRENT_SKILL_FILE" ]]; then
        echo -e "\n${YELLOW}No active learning session${NC}"
        echo "  Run: $0 pick"
        echo
        return 0
    fi

    local skill=$(cat "$CURRENT_SKILL_FILE")

    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          📖 CURRENT LEARNING SESSION 📖                 ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}Skill:${NC}"
    echo "$skill" | jq -r '"  " + .name'
    echo

    echo -e "${BOLD}Started:${NC}"
    echo "$skill" | jq -r '"  " + .started_at'
    echo

    echo -e "${BOLD}Deadline:${NC}"
    echo "$skill" | jq -r '"  " + .end_date'

    # Calculate days remaining
    local end_date=$(echo "$skill" | jq -r '.end_date')
    local end_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$end_date" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( (end_epoch - now_epoch) / 86400 ))

    if [[ $days_left -gt 0 ]]; then
        echo "  ($days_left days remaining)"
    else
        echo -e "  ${RED}(OVERDUE!)${NC}"
    fi
    echo

    echo -e "${BOLD}Progress:${NC}"
    local total=$(echo "$skill" | jq '.checkpoints | length')
    local completed=$(echo "$skill" | jq '.checkpoints_completed | length')
    echo "  Checkpoints: $completed/$total"
    echo "$skill" | jq -r '"  Days practiced: " + (.days_practiced | tostring)'
    echo "$skill" | jq -r '"  Total time: " + (.total_minutes | tostring) + " minutes"'
    echo

    echo -e "${BOLD}Remaining checkpoints:${NC}"
    local completed_list=$(echo "$skill" | jq -r '.checkpoints_completed[].checkpoint')

    echo "$skill" | jq -r '.checkpoints[]' | while read -r checkpoint; do
        if echo "$completed_list" | grep -qF "$checkpoint"; then
            echo -e "  ${GREEN}[✓]${NC} $checkpoint"
        else
            echo -e "  ${YELLOW}[ ]${NC} $checkpoint"
        fi
    done

    echo
}

show_progress() {
    if [[ ! -f "$CURRENT_SKILL_FILE" ]]; then
        return 0
    fi

    local skill=$(cat "$CURRENT_SKILL_FILE")
    local total=$(echo "$skill" | jq '.checkpoints | length')
    local completed=$(echo "$skill" | jq '.checkpoints_completed | length')
    local days=$(echo "$skill" | jq '.days_practiced')
    local minutes=$(echo "$skill" | jq '.total_minutes')

    echo
    echo -e "${BOLD}Current Progress:${NC}"
    echo "  Checkpoints: $completed/$total ($(echo "scale=0; $completed * 100 / $total" | bc)%)"
    echo "  Days practiced: $days"
    echo "  Total time: $minutes minutes ($(echo "scale=1; $minutes / 60" | bc) hours)"
    echo
}

show_stats() {
    if [[ ! -f "$PROGRESS_LOG_FILE" ]]; then
        log_info "No skills learned yet"
        return 0
    fi

    echo -e "\n${BOLD}📊 Learning Statistics${NC}\n"

    local total=$(jq '.skills_learned | length' "$PROGRESS_LOG_FILE")
    echo "Skills mastered: ${BOLD}$total${NC}"
    echo

    if [[ $total -gt 0 ]]; then
        echo -e "${BOLD}Skills learned:${NC}"
        jq -r '.skills_learned[] |
            "  • \(.name) (\(.total_minutes) minutes, \(.checkpoints_completed | length) checkpoints)"' \
            "$PROGRESS_LOG_FILE"
        echo

        local total_minutes=$(jq '[.skills_learned[].total_minutes] | add' "$PROGRESS_LOG_FILE")
        local total_hours=$(echo "scale=1; $total_minutes / 60" | bc)

        echo "Total learning time: $total_hours hours"
        echo
    fi
}

#=============================================================================
# Main
#=============================================================================

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Random skill picker with enforced learning

COMMANDS:
    pick [CATEGORY]              Pick random skill to learn
    list                         List all available skills
    add NAME CAT DIFF URL...     Add custom skill
    current                      Show current learning session
    practice MINUTES             Log practice session
    checkpoint "TEXT"            Complete a checkpoint
    complete                     Mark skill as learned
    stats                        Show learning statistics
    unblock                      Disable distraction blocking

CATEGORIES:
    programming, devops, language, productivity, data,
    creative, ai, soft_skills, life_skills, technical

OPTIONS:
    --strict                     Block EVERYTHING except learning
    --no-blocking                Don't block distractions

EXAMPLES:
    # Let the algorithm decide
    $0 pick

    # Pick programming skill
    $0 pick programming

    # Add custom skill
    $0 add "Go Programming" programming 6 https://go.dev/learn

    # Log practice
    $0 practice 45

    # Complete checkpoint
    $0 checkpoint "Completed Rust Book Chapter 1"

    # View current progress
    $0 current

    # View statistics
    $0 stats

WORKFLOW:
    1. Pick skill: $0 pick
    2. Distractions get blocked automatically
    3. Learn daily (track with: $0 practice 30)
    4. Complete checkpoints as you go
    5. Mark complete when done: $0 complete
    6. Repeat with new skill

PHILOSOPHY:
    • Random selection removes choice paralysis
    • Blocking forces focus
    • Checkpoints ensure actual learning
    • Evidence prevents self-deception
    • Time-boxing creates urgency
    • Can't unlock until you learn

EOF
}

main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --strict)
                STRICT_MODE=1
                shift
                ;;
            --no-blocking)
                ENABLE_BLOCKING=0
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            pick|list|add|current|practice|checkpoint|complete|stats|unblock)
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
    check_commands jq

    # Initialize
    init_skills_db

    # Execute command
    case $command in
        pick)
            the_algorithm "$@"
            ;;
        list)
            list_skills
            ;;
        add)
            if [[ $# -lt 4 ]]; then
                log_error "Usage: add NAME CATEGORY DIFFICULTY URL..."
                exit 1
            fi
            local name=$1
            local cat=$2
            local diff=$3
            shift 3
            add_custom_skill "$name" "$cat" "$diff" "$@"
            ;;
        current)
            show_current
            ;;
        practice)
            log_practice_session "${1:-30}"
            ;;
        checkpoint)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: checkpoint \"CHECKPOINT_TEXT\""
                exit 1
            fi
            complete_checkpoint "$1"
            ;;
        complete)
            complete_skill
            ;;
        stats)
            show_stats
            ;;
        unblock)
            disable_distraction_blocking
            ;;
        "")
            show_current
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
