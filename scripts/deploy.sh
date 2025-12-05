#!/bin/bash

################################################################################
# Git Deploy Script - Fetch and Deploy from Remote Repository
#
# This script handles:
# - Git repository initialization and updates
# - Fetching latest changes from origin
# - Dependency installation
# - Discord bot restart
# - Error handling and logging
################################################################################

set -eo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d_%H%M%S).log"
VENV_DIR="${PROJECT_ROOT}/venv"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Logging Functions
################################################################################

init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    echo "Deployment started at $(date)" | tee "$LOG_FILE"
}

log() {
    local level="$1"
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $@" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗${NC} $@" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $@" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $@" | tee -a "$LOG_FILE"
}

print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Git Operations
################################################################################

check_git_repo() {
    print_section "Git Repository Check"

    cd "$PROJECT_ROOT"

    if [ ! -d ".git" ]; then
        log_warning "Not a git repository. Initializing..."

        read -p "Enter git remote URL (or press Enter to skip): " git_url

        if [ -n "$git_url" ]; then
            git init
            git remote add origin "$git_url"
            log_success "Git repository initialized with remote: $git_url"
        else
            log_warning "Skipping git initialization"
            return 1
        fi
    else
        log_success "Git repository found"
    fi

    return 0
}

fetch_from_origin() {
    print_section "Fetching from Remote"

    cd "$PROJECT_ROOT"

    if ! git remote get-url origin &>/dev/null; then
        log_error "No remote 'origin' configured"
        return 1
    fi

    local remote_url=$(git remote get-url origin)
    log_info "Remote URL: $remote_url"

    log_info "Fetching latest changes..."
    if git fetch origin; then
        log_success "Fetched from origin"
    else
        log_error "Failed to fetch from origin"
        return 1
    fi

    # Show status
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    log_info "Current branch: $current_branch"

    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null || echo "unknown")

    if [ "$local_commit" = "$remote_commit" ]; then
        log_success "Already up to date"
    else
        log_warning "Local branch is behind remote"
        log_info "Local:  $local_commit"
        log_info "Remote: $remote_commit"
    fi

    return 0
}

pull_changes() {
    print_section "Pulling Changes"

    cd "$PROJECT_ROOT"

    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "You have uncommitted changes"
        git status --short

        read -p "Stash changes and continue? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "Auto-stash before deploy $(date)"
            log_success "Changes stashed"
        else
            log_error "Deployment cancelled due to uncommitted changes"
            return 1
        fi
    fi

    log_info "Pulling from origin/$current_branch..."
    if git pull origin "$current_branch"; then
        log_success "Successfully pulled changes"
        git log -1 --oneline
    else
        log_error "Failed to pull changes"
        return 1
    fi

    return 0
}

################################################################################
# Dependency Management
################################################################################

update_dependencies() {
    print_section "Updating Dependencies"

    cd "$PROJECT_ROOT"

    if [ ! -f "requirements.txt" ]; then
        log_warning "No requirements.txt found"
        return 0
    fi

    # Activate virtual environment
    if [ -d "$VENV_DIR" ]; then
        log_info "Activating virtual environment..."
        source "$VENV_DIR/bin/activate"
    else
        log_warning "Virtual environment not found at: $VENV_DIR"
        log_info "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
    fi

    log_info "Installing/updating dependencies..."
    if pip install -r requirements.txt --upgrade; then
        log_success "Dependencies updated"
    else
        log_error "Failed to update dependencies"
        return 1
    fi

    return 0
}

################################################################################
# Service Management
################################################################################

restart_bot() {
    print_section "Discord Bot Management"

    cd "$PROJECT_ROOT"

    # Check if bot is running
    local bot_pid=$(pgrep -f "discord_logo_bot.py" || echo "")

    if [ -n "$bot_pid" ]; then
        log_info "Stopping running bot (PID: $bot_pid)..."
        kill "$bot_pid"
        sleep 2

        # Force kill if still running
        if ps -p "$bot_pid" > /dev/null 2>&1; then
            log_warning "Force killing bot..."
            kill -9 "$bot_pid"
        fi

        log_success "Bot stopped"
    else
        log_info "Bot is not currently running"
    fi

    # Optional: restart bot
    read -p "Start Discord bot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting Discord bot..."

        if [ -f "$VENV_DIR/bin/activate" ]; then
            source "$VENV_DIR/bin/activate"
        fi

        nohup python3 discord_logo_bot.py > logs/bot.log 2>&1 &
        local new_pid=$!

        sleep 2

        if ps -p "$new_pid" > /dev/null 2>&1; then
            log_success "Bot started successfully (PID: $new_pid)"
            log_info "Logs: tail -f logs/bot.log"
        else
            log_error "Bot failed to start. Check logs/bot.log"
            return 1
        fi
    fi

    return 0
}

################################################################################
# Deployment Summary
################################################################################

print_summary() {
    print_section "Deployment Summary"

    echo ""
    echo "Project Root: $PROJECT_ROOT"
    echo "Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
    echo "Latest Commit: $(git log -1 --oneline 2>/dev/null || echo 'N/A')"
    echo "Log File: $LOG_FILE"
    echo ""

    log_success "Deployment completed successfully"
}

################################################################################
# Main Execution
################################################################################

main() {
    init_logging

    print_section "Modal Logo Bot - Git Deployment"
    log_info "Starting deployment process"
    log_info "Project root: $PROJECT_ROOT"

    # Git operations
    if check_git_repo; then
        fetch_from_origin || log_warning "Fetch failed, continuing anyway..."

        read -p "Pull latest changes? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pull_changes || exit 1
        fi
    fi

    # Update dependencies
    read -p "Update Python dependencies? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_dependencies || log_warning "Dependency update failed"
    fi

    # Restart services
    restart_bot || log_warning "Bot restart failed"

    # Summary
    print_summary

    return 0
}

# Run main function
main
exit_code=$?

exit $exit_code
