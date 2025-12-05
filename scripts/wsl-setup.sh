#!/bin/bash

################################################################################
# WSL Environment Setup Script
#
# Sets up the Macheveli Image Bot in WSL (Windows Subsystem for Linux)
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/jlucus/Macheveli-Image-bot/master/scripts/wsl-setup.sh | bash
#   OR
#   ./wsl-setup.sh
################################################################################

set -eo pipefail

# Configuration
PROJECT_NAME="Macheveli-Image-bot"
GITHUB_REPO="https://github.com/jlucus/Macheveli-Image-bot.git"
INSTALL_DIR="$HOME/projects/macheveli"
LOG_FILE="$HOME/macheveli-setup-$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $@" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $@" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $@" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

################################################################################
# System Checks
################################################################################

check_wsl() {
    print_header "Checking WSL Environment"

    if grep -qi microsoft /proc/version; then
        log_success "Running in WSL"
    else
        log_warning "May not be running in WSL"
    fi

    log_info "Distribution: $(lsb_release -d | cut -f2)"
    log_info "Kernel: $(uname -r)"
}

check_dependencies() {
    print_header "Checking System Dependencies"

    local missing_deps=()

    # Check for required tools
    for cmd in git python3 pip curl; do
        if command -v $cmd &>/dev/null; then
            log_success "$cmd is installed"
        else
            missing_deps+=("$cmd")
            log_error "$cmd is NOT installed"
        fi
    done

    # Check Python version
    if command -v python3 &>/dev/null; then
        local py_version=$(python3 --version | awk '{print $2}')
        log_info "Python version: $py_version"

        if python3 -c 'import sys; exit(0 if sys.version_info >= (3, 8) else 1)'; then
            log_success "Python version is sufficient (3.8+)"
        else
            log_error "Python 3.8+ required"
            return 1
        fi
    fi

    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_info "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update
        sudo apt-get install -y git python3 python3-pip python3-venv curl
    fi

    return 0
}

################################################################################
# Project Setup
################################################################################

clone_repository() {
    print_header "Cloning Repository"

    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Directory already exists: $INSTALL_DIR"

        read -p "Remove and re-clone? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing directory..."
            rm -rf "$INSTALL_DIR"
        else
            log_info "Using existing directory"
            cd "$INSTALL_DIR"
            git pull origin master
            return 0
        fi
    fi

    log_info "Creating directory: $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"

    log_info "Cloning from: $GITHUB_REPO"
    if git clone "$GITHUB_REPO" "$INSTALL_DIR"; then
        log_success "Repository cloned"
        cd "$INSTALL_DIR"
    else
        log_error "Failed to clone repository"
        return 1
    fi
}

setup_python_env() {
    print_header "Setting Up Python Environment"

    cd "$INSTALL_DIR"

    # Create virtual environment
    if [ -d "venv" ]; then
        log_info "Virtual environment already exists"
    else
        log_info "Creating virtual environment..."
        python3 -m venv venv
        log_success "Virtual environment created"
    fi

    # Activate virtual environment
    log_info "Activating virtual environment..."
    source venv/bin/activate

    # Upgrade pip
    log_info "Upgrading pip..."
    pip install --upgrade pip setuptools wheel

    # Install dependencies
    if [ -f "requirements.txt" ]; then
        log_info "Installing Python dependencies..."
        pip install -r requirements.txt
        log_success "Dependencies installed"
    else
        log_warning "requirements.txt not found"
    fi
}

setup_env_file() {
    print_header "Environment Configuration"

    cd "$INSTALL_DIR"

    if [ -f ".env" ]; then
        log_info ".env file already exists"
        read -p "Overwrite? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing .env file"
            return 0
        fi
    fi

    log_info "Creating .env file template..."

    cat > .env << 'EOF'
# Discord Configuration
DISCORD_APP_ID=
DISCORD_PUBLIC_KEY=
DISCORD_INSTALL_LINK=
DISCORD_BOT_TOKE=

# Modal Configuration
MODAL_SERVER=
EOF

    log_success ".env file created"
    log_warning "IMPORTANT: Edit .env file with your credentials:"
    log_info "  nano $INSTALL_DIR/.env"
}

setup_modal() {
    print_header "Modal Setup"

    cd "$INSTALL_DIR"
    source venv/bin/activate

    # Check if Modal is installed
    if ! python3 -c "import modal" &>/dev/null; then
        log_info "Installing Modal SDK..."
        pip install modal
    fi

    # Check Modal authentication
    if [ -f "$HOME/.modal/token" ]; then
        log_success "Modal token found"
    else
        log_warning "No Modal token found"
        log_info "Authenticate with Modal:"
        log_info "  modal token new"
        log_info ""

        read -p "Authenticate now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            modal token new
        else
            log_warning "Skipping Modal authentication"
            log_info "Run 'modal token new' later to authenticate"
        fi
    fi
}

fix_modal_api() {
    print_header "Fixing Modal API Compatibility"

    cd "$INSTALL_DIR"

    # Check if modal_project exists
    if [ -d "modal_project/src" ]; then
        local logo_gen="modal_project/src/logo_generator.py"

        if [ -f "$logo_gen" ]; then
            log_info "Checking $logo_gen for old Modal API..."

            if grep -q "modal.Stub" "$logo_gen"; then
                log_info "Fixing Modal API (Stub -> App)..."
                sed -i.bak 's/modal\.Stub/modal.App/g' "$logo_gen"
                sed -i 's/@stub\.function/@app.function/g' "$logo_gen"
                sed -i 's/^stub =/app =/g' "$logo_gen"
                log_success "Modal API updated"
            else
                log_success "Modal API already up to date"
            fi
        fi
    else
        log_info "modal_project not found (will be created by stat.sh)"
    fi
}

################################################################################
# Final Setup
################################################################################

print_summary() {
    print_header "Setup Summary"

    echo ""
    echo "Installation Directory: $INSTALL_DIR"
    echo "Log File: $LOG_FILE"
    echo ""

    log_success "WSL environment setup complete!"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Configure environment variables:"
    echo "   cd $INSTALL_DIR"
    echo "   nano .env"
    echo ""
    echo "2. Activate Python environment:"
    echo "   source $INSTALL_DIR/venv/bin/activate"
    echo ""
    echo "3. Run setup script (optional):"
    echo "   cd $INSTALL_DIR"
    echo "   ./scripts/stat.sh"
    echo ""
    echo "4. Deploy Modal app:"
    echo "   cd $INSTALL_DIR/modal_project/src"
    echo "   modal deploy logo_generator.py"
    echo ""
    echo "5. Start Discord bot:"
    echo "   cd $INSTALL_DIR"
    echo "   python discord_logo_bot.py"
    echo ""
}

create_activation_script() {
    print_header "Creating Activation Script"

    cat > "$INSTALL_DIR/activate.sh" << 'EOF'
#!/bin/bash
# Quick activation script for Macheveli Image Bot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Activating Macheveli Image Bot environment..."
cd "$SCRIPT_DIR"
source venv/bin/activate

echo "✓ Environment activated"
echo "  Directory: $SCRIPT_DIR"
echo "  Python: $(which python)"
echo ""
echo "Available commands:"
echo "  python discord_logo_bot.py    - Start Discord bot"
echo "  ./scripts/stat.sh             - Run setup script"
echo "  ./scripts/deploy.sh           - Deploy updates"
echo ""
EOF

    chmod +x "$INSTALL_DIR/activate.sh"
    log_success "Created activation script: $INSTALL_DIR/activate.sh"
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Macheveli Image Bot - WSL Setup"

    log_info "Starting WSL environment setup..."
    log_info "Log file: $LOG_FILE"

    # System checks
    check_wsl || exit 1
    check_dependencies || exit 1

    # Project setup
    clone_repository || exit 1
    setup_python_env || exit 1
    setup_env_file || exit 1
    setup_modal || exit 1
    fix_modal_api || exit 1

    # Final touches
    create_activation_script || exit 1

    # Summary
    print_summary

    return 0
}

# Run main function
main
exit_code=$?

exit $exit_code
