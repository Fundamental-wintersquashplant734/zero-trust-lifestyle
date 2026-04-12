#!/bin/bash
#=============================================================================
# Installation script for zero-trust-lifestyle
# Sets up environment, dependencies, and configurations
#=============================================================================

set -euo pipefail

# Require Bash 4+ for associative arrays (macOS ships 3.2 by default)
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: Bash 4.0+ required. You have Bash ${BASH_VERSION}."
    echo "macOS users: brew install bash"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#=============================================================================
# Helper Functions
#=============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

check_dependency() {
    local cmd=$1
    local optional=${2:-0}

    if command -v "$cmd" &> /dev/null; then
        log_success "$cmd is installed"
        return 0
    else
        if [[ $optional -eq 1 ]]; then
            log_warn "$cmd is not installed (optional)"
            return 1
        else
            log_error "$cmd is required but not installed"
            return 1
        fi
    fi
}

#=============================================================================
# Banner
#=============================================================================

show_banner() {
    cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         Security Researcher Scripts                     ║
║         Installation & Setup                            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

EOF
}

#=============================================================================
# Dependency Check
#=============================================================================

check_dependencies() {
    log_info "Checking dependencies..."
    echo

    local missing_required=0
    local missing_optional=0

    # Required
    echo "Required dependencies:"
    check_dependency bash || missing_required=$((missing_required + 1))
    check_dependency jq || missing_required=$((missing_required + 1))
    check_dependency curl || missing_required=$((missing_required + 1))
    check_dependency grep || missing_required=$((missing_required + 1))
    check_dependency sed || missing_required=$((missing_required + 1))
    check_dependency awk || missing_required=$((missing_required + 1))
    check_dependency openssl || missing_required=$((missing_required + 1))
    echo

    # Optional (for specific features)
    echo "Optional dependencies:"
    check_dependency python3 1 || missing_optional=$((missing_optional + 1))
    check_dependency chromedriver 1 || missing_optional=$((missing_optional + 1))
    check_dependency exiftool 1 || missing_optional=$((missing_optional + 1))
    check_dependency nmcli 1 || missing_optional=$((missing_optional + 1))
    check_dependency iptables 1 || missing_optional=$((missing_optional + 1))
    check_dependency gcalcli 1 || missing_optional=$((missing_optional + 1))
    check_dependency notify-send 1 || missing_optional=$((missing_optional + 1))
    echo

    if [[ $missing_required -gt 0 ]]; then
        log_error "$missing_required required dependencies missing!"
        echo
        echo "Install required dependencies:"
        echo "  Ubuntu/Debian: sudo apt install jq curl openssl"
        echo "  Fedora/RHEL:   sudo dnf install jq curl openssl"
        echo "  macOS:         brew install jq curl openssl"
        echo
        return 1
    fi

    if [[ $missing_optional -gt 0 ]]; then
        log_warn "$missing_optional optional dependencies missing"
        echo "Some features may not work. See docs/SETUP.md for details."
        echo
    fi

    log_success "All required dependencies installed!"
    return 0
}

#=============================================================================
# Setup
#=============================================================================

setup_directories() {
    log_info "Setting up directories..."

    mkdir -p "$SCRIPT_DIR/data"
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/config"

    # Set permissions — logs may contain sensitive script output, keep user-only.
    chmod 700 "$SCRIPT_DIR/data"
    chmod 700 "$SCRIPT_DIR/logs"

    log_success "Directories created"
}

make_executable() {
    log_info "Making scripts executable..."

    chmod +x "$SCRIPT_DIR"/scripts/*.sh
    chmod +x "$SCRIPT_DIR"/lib/*.sh

    log_success "Scripts are now executable"
}

setup_config() {
    log_info "Setting up configuration..."

    if [[ ! -f "$SCRIPT_DIR/config/config.sh" ]]; then
        cp "$SCRIPT_DIR/config/config.example.sh" "$SCRIPT_DIR/config/config.sh"
        log_success "Created config.sh from example"
        log_warn "Please edit config/config.sh with your settings"
    else
        log_info "config.sh already exists, skipping"
    fi
}

install_python_deps() {
    if ! command -v python3 &> /dev/null; then
        log_warn "Python3 not found, skipping Python dependencies"
        return 0
    fi

    log_info "Installing Python dependencies..."

    # Check if pip is available
    if ! command -v pip3 &> /dev/null; then
        log_warn "pip3 not found, skipping Python dependencies"
        return 0
    fi

    # Install Selenium for sockpuppet automation
    if pip3 show selenium &> /dev/null; then
        log_info "selenium already installed"
    else
        read -p "Install selenium for sockpuppet automation? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pip3 install selenium
            log_success "Installed selenium"
        fi
    fi

    # Install transformers for sentiment analysis
    if pip3 show transformers &> /dev/null; then
        log_info "transformers already installed"
    else
        read -p "Install transformers for email sentiment analysis? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pip3 install transformers torch
            log_success "Installed transformers"
        fi
    fi
}

#=============================================================================
# Cron Setup
#=============================================================================

setup_cron() {
    log_info "Setting up cron jobs..."

    cat <<EOF

Recommended cron jobs:

# OPSEC check every 15 minutes
*/15 * * * * $SCRIPT_DIR/scripts/opsec-paranoia-check.sh --quick

# Sockpuppet maintenance daily at 3am
0 3 * * * $SCRIPT_DIR/scripts/automated-sock-maintenance.sh maintain-all

# Relationship score reminder daily at 9am
0 9 * * * $SCRIPT_DIR/scripts/wife-happy-score.sh --dashboard

# Meeting prep runs continuously (start on boot)
@reboot $SCRIPT_DIR/scripts/meeting-prep-assassin.sh --continuous &

Would you like to add these to your crontab? [y/N]
EOF

    read -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; cat <<EOF
# Security Researcher Scripts
*/15 * * * * $SCRIPT_DIR/scripts/opsec-paranoia-check.sh --quick
0 3 * * * $SCRIPT_DIR/scripts/automated-sock-maintenance.sh maintain-all
0 9 * * * $SCRIPT_DIR/scripts/wife-happy-score.sh --dashboard
@reboot $SCRIPT_DIR/scripts/meeting-prep-assassin.sh --continuous &
EOF
        ) | crontab -

        log_success "Cron jobs added!"
    else
        log_info "Skipped cron setup"
    fi
}

#=============================================================================
# Systemd Service
#=============================================================================

setup_systemd() {
    if ! command -v systemctl &> /dev/null; then
        log_warn "systemd not available, skipping"
        return 0
    fi

    log_info "Setting up systemd services..."

    cat <<EOF

Create systemd service for coffee-shop-lockdown? [y/N]
This will monitor your network and auto-lockdown on untrusted WiFi.
EOF

    read -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local service_file="/etc/systemd/system/coffee-shop-lockdown.service"

        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Coffee Shop Network Lockdown Monitor
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$SCRIPT_DIR/scripts/coffee-shop-lockdown.sh monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable coffee-shop-lockdown.service
        sudo systemctl start coffee-shop-lockdown.service

        log_success "Systemd service created and started!"
    else
        log_info "Skipped systemd setup"
    fi
}

#=============================================================================
# Shell Integration
#=============================================================================

setup_shell_integration() {
    log_info "Setting up shell integration..."

    local shell_rc=""
    if [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    fi

    if [[ -z "$shell_rc" ]]; then
        log_warn "Unknown shell, skipping shell integration"
        return 0
    fi

    cat <<EOF

Add scripts to PATH? [y/N]
This will add $SCRIPT_DIR/scripts to your PATH
EOF

    read -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! grep -q "zero-trust-lifestyle" "$shell_rc"; then
            cat >> "$shell_rc" <<EOF

# Security Researcher Scripts
export PATH="\$PATH:$SCRIPT_DIR/scripts"
EOF
            log_success "Added to $shell_rc"
            log_warn "Run: source $shell_rc"
        else
            log_info "Already in PATH"
        fi
    fi
}

#=============================================================================
# Final Setup
#=============================================================================

show_next_steps() {
    cat <<EOF

${GREEN}╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         Installation Complete! 🎉                       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝${NC}

${YELLOW}Next Steps:${NC}

1. Edit configuration:
   ${BLUE}nano $SCRIPT_DIR/config/config.sh${NC}

2. Set up API keys (see docs/SETUP.md)

3. Try out the scripts:
   ${BLUE}$SCRIPT_DIR/scripts/opsec-paranoia-check.sh${NC}
   ${BLUE}$SCRIPT_DIR/scripts/wife-happy-score.sh --setup${NC}
   ${BLUE}$SCRIPT_DIR/scripts/meeting-prep-assassin.sh --list${NC}

4. Read the documentation:
   ${BLUE}cat README.md${NC}
   ${BLUE}cat docs/SETUP.md${NC}

${YELLOW}Quick Test:${NC}
   ${BLUE}$SCRIPT_DIR/scripts/opsec-paranoia-check.sh --quick${NC}

${YELLOW}Get Help:${NC}
   ${BLUE}$SCRIPT_DIR/scripts/[script-name].sh --help${NC}

EOF
}

#=============================================================================
# Pack Definitions
#=============================================================================

declare -A PACK_SCRIPTS
PACK_SCRIPTS["paranoid-dev"]="opsec-paranoia-check.sh coffee-shop-lockdown.sh git-secret-scanner.sh browser-history-cleanser.sh"
PACK_SCRIPTS["corporate-survival"]="slack-auto-responder.sh passive-aggressive-emailer.sh meeting-prep-assassin.sh meeting-excuse-generator.sh standup-bot.sh meeting-cost-calculator.sh"
PACK_SCRIPTS["osint-hunter"]="meeting-prep-assassin.sh automated-sock-maintenance.sh paste-site-monitor.sh data-breach-stalker.sh"
PACK_SCRIPTS["deep-work"]="focus-mode-nuclear.sh slack-auto-responder.sh coffee-shop-lockdown.sh meeting-excuse-generator.sh pomodoro-enforcer.sh"
PACK_SCRIPTS["personal-life"]="wife-happy-score.sh expense-shame-dashboard.sh health-nag-bot.sh birthday-reminder-pro.sh"

declare -A PACK_DESCRIPTIONS
PACK_DESCRIPTIONS["paranoid-dev"]="Because one mistake can burn everything"
PACK_DESCRIPTIONS["corporate-survival"]="Automating corporate bullshit since 2025"
PACK_DESCRIPTIONS["osint-hunter"]="Professional stalking, automated"
PACK_DESCRIPTIONS["deep-work"]="Protect your focus like your life depends on it"
PACK_DESCRIPTIONS["personal-life"]="Optimizing life so you can focus on work... wait"

#=============================================================================
# Pack Install Functions
#=============================================================================

list_packs() {
    show_banner
    echo -e "${BLUE}Available packs:${NC}"
    echo
    for pack in paranoid-dev corporate-survival osint-hunter deep-work personal-life; do
        echo -e "${GREEN}  --pack ${pack}${NC}"
        echo -e "    ${PACK_DESCRIPTIONS[$pack]}"
        echo "    Scripts:"
        for script in ${PACK_SCRIPTS[$pack]}; do
            echo "      - $script"
        done
        echo
    done
}

list_scripts() {
    show_banner
    echo -e "${BLUE}Available scripts:${NC}"
    echo
    for f in "$SCRIPT_DIR"/scripts/*.sh; do
        local name=$(basename "$f" .sh)
        echo -e "  ${GREEN}$name${NC}"
    done
    echo
    echo "Install a single script:"
    echo -e "  ${BLUE}./install.sh --script <name>${NC}"
    echo
}

install_pack() {
    local pack=$1

    if [[ -z "${PACK_SCRIPTS[$pack]+_}" ]]; then
        log_error "Unknown pack: $pack"
        echo
        echo "Available packs: paranoid-dev, corporate-survival, osint-hunter, deep-work, personal-life"
        echo "Run './install.sh --list-packs' to see all packs and their scripts."
        exit 1
    fi

    show_banner
    log_info "Installing pack: $pack"
    echo -e "  ${PACK_DESCRIPTIONS[$pack]}"
    echo

    # Check if running from correct directory
    if [[ ! -f "$SCRIPT_DIR/README.md" ]]; then
        log_error "Please run this script from the repository root"
        exit 1
    fi

    setup_directories

    log_info "Making pack scripts executable..."
    chmod +x "$SCRIPT_DIR/lib/common.sh"
    local installed=()
    local missing=()
    for script in ${PACK_SCRIPTS[$pack]}; do
        local path="$SCRIPT_DIR/scripts/$script"
        if [[ -f "$path" ]]; then
            chmod +x "$path"
            installed+=("$script")
        else
            missing+=("$script")
        fi
    done

    for script in "${installed[@]}"; do
        log_success "$script"
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo
        for script in "${missing[@]}"; do
            log_warn "$script (not found, skipping)"
        done
    fi
    echo

    setup_config
    echo

    log_success "Pack '$pack' installed (${#installed[@]} scripts)"
    echo
    echo -e "${YELLOW}Run scripts from:${NC} ${BLUE}$SCRIPT_DIR/scripts/${NC}"
    echo
}

install_script() {
    local name=$1

    # Strip .sh suffix if provided
    name="${name%.sh}"

    local path="$SCRIPT_DIR/scripts/${name}.sh"
    if [[ ! -f "$path" ]]; then
        log_error "Script not found: $name"
        echo
        echo "Run './install.sh --list-scripts' to see available scripts."
        exit 1
    fi

    show_banner
    log_info "Installing script: $name"
    echo

    if [[ ! -f "$SCRIPT_DIR/README.md" ]]; then
        log_error "Please run this script from the repository root"
        exit 1
    fi

    setup_directories
    chmod +x "$SCRIPT_DIR/lib/common.sh"
    chmod +x "$path"
    setup_config
    echo

    log_success "Installed: $name"
    echo
    echo -e "${YELLOW}Run it:${NC} ${BLUE}$path --help${NC}"
    echo
}

#=============================================================================
# Main Installation
#=============================================================================

main() {
    local pack=""
    local script=""
    local list_packs_flag=0
    local list_scripts_flag=0

    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pack)
                if [[ -z "${2:-}" ]]; then
                    log_error "--pack requires an argument"
                    exit 1
                fi
                pack="$2"
                shift 2
                ;;
            --script)
                if [[ -z "${2:-}" ]]; then
                    log_error "--script requires an argument"
                    exit 1
                fi
                script="$2"
                shift 2
                ;;
            --list-packs)
                list_packs_flag=1
                shift
                ;;
            --list-scripts)
                list_scripts_flag=1
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                echo "Usage: $0 [--pack PACK_NAME] [--script SCRIPT_NAME] [--list-packs] [--list-scripts]"
                exit 1
                ;;
        esac
    done

    if [[ $list_scripts_flag -eq 1 ]]; then
        list_scripts
        exit 0
    fi

    if [[ $list_packs_flag -eq 1 ]]; then
        list_packs
        exit 0
    fi

    if [[ -n "$script" ]]; then
        install_script "$script"
        exit 0
    fi

    if [[ -n "$pack" ]]; then
        install_pack "$pack"
        exit 0
    fi

    # Full install (existing behavior)
    show_banner

    # Check if running from correct directory
    if [[ ! -f "$SCRIPT_DIR/README.md" ]]; then
        log_error "Please run this script from the repository root"
        exit 1
    fi

    # Run installation steps
    check_dependencies || exit 1
    echo

    setup_directories
    make_executable
    setup_config
    echo

    # Optional steps
    install_python_deps
    echo

    setup_cron
    echo

    setup_systemd
    echo

    setup_shell_integration
    echo

    show_next_steps
}

# Run installation
main "$@"
