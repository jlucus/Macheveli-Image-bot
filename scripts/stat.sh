#!/bin/bash

################################################################################
# Modal Logo Generator - Automated Setup and Execution Script
# 
# This script handles:
# - Environment validation
# - Dependency installation
# - Modal project setup
# - Error handling and recovery
# - Logging and reporting
################################################################################

set -o pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/modal-logo-gen-$(date +%Y%m%d_%H%M%S).log"
VENV_DIR="${SCRIPT_DIR}/venv"
MODAL_PROJECT_DIR="${SCRIPT_DIR}/modal_project"
ERRORS_FILE="${LOG_DIR}/errors.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tracking variables
ERRORS_ENCOUNTERED=0
WARNINGS_ENCOUNTERED=0

################################################################################
# Utility Functions
################################################################################

# Create log directory if it doesn't exist
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    touch "$ERRORS_FILE"
    echo "Logging initialized at $LOG_FILE" >> "$LOG_FILE"
}

# Log function with timestamp
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Log only to file
log_silent() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Error logging
log_error() {
    local message="$@"
    echo -e "${RED}✗ ERROR:${NC} $message"
    log "ERROR" "$message"
    echo "$message" >> "$ERRORS_FILE"
    ((ERRORS_ENCOUNTERED++))
}

# Warning logging
log_warning() {
    local message="$@"
    echo -e "${YELLOW}⚠ WARNING:${NC} $message"
    log "WARNING" "$message"
    ((WARNINGS_ENCOUNTERED++))
}

# Success logging
log_success() {
    local message="$@"
    echo -e "${GREEN}✓ SUCCESS:${NC} $message"
    log "INFO" "$message"
}

# Info logging
log_info() {
    local message="$@"
    echo -e "${BLUE}ℹ INFO:${NC} $message"
    log "INFO" "$message"
}

# Print section header
print_section() {
    local title="$1"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Cleanup on exit
cleanup() {
    local exit_code=$?
    
    print_section "Cleanup"
    
    if [ $exit_code -eq 0 ]; then
        log_success "Script completed successfully"
    else
        log_error "Script exited with code $exit_code"
    fi
    
    log_info "Total errors: $ERRORS_ENCOUNTERED"
    log_info "Total warnings: $WARNINGS_ENCOUNTERED"
    log_info "Log file: $LOG_FILE"
    
    if [ $ERRORS_ENCOUNTERED -gt 0 ]; then
        log_info "Error details saved to: $ERRORS_FILE"
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Retry mechanism for network operations
retry_command() {
    local max_attempts=3
    local attempt=1
    local command="$@"
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt of $max_attempts: $command"

        if bash -c "$command"; then
            return 0
        fi
        
        local exit_code=$?

        log_warning "Command failed with exit code $exit_code"
        
        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((attempt * 5))
            log_info "Waiting ${wait_time}s before retry..."
            sleep $wait_time
        fi
        
        ((attempt++))
    done
    
    log_error "Command failed after $max_attempts attempts: $command"
    return 1
}

################################################################################
# Pre-flight Checks
################################################################################

check_system_requirements() {
    print_section "System Requirements Check"
    
    local missing_tools=()
    
    # Check for required tools
    for tool in python3 pip git curl; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
            log_error "Missing required tool: $tool"
        else
            log_success "Found: $tool"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing tools: ${missing_tools[*]}"
        log_error "Please install missing tools and try again"
        return 1
    fi
    
    # Check Python version
    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "Python version: $python_version"
    
    if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'; then
        log_error "Python 3.8+ required, found: $python_version"
        return 1
    fi
    
    log_success "System requirements met"
    return 0
}

check_disk_space() {
    print_section "Disk Space Check"
    
    local available_space=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
    local min_required=$((5 * 1024 * 1024)) # 5GB in KB
    
    log_info "Available space: $((available_space / 1024 / 1024))GB"
    
    if [ "$available_space" -lt "$min_required" ]; then
        log_error "Insufficient disk space. Required: 5GB, Available: $((available_space / 1024 / 1024))GB"
        return 1
    fi
    
    log_success "Sufficient disk space available"
    return 0
}

check_internet_connectivity() {
    print_section "Internet Connectivity Check"
    
    if retry_command "curl -s --connect-timeout 5 https://api.github.com > /dev/null"; then
        log_success "Internet connectivity verified"
        return 0
    else
        log_error "No internet connectivity detected"
        return 1
    fi
}

################################################################################
# Virtual Environment Setup
################################################################################

setup_virtual_environment() {
    print_section "Virtual Environment Setup"
    
    if [ -d "$VENV_DIR" ]; then
        log_warning "Virtual environment already exists: $VENV_DIR"
        log_info "Reusing existing virtual environment"
    else
        log_info "Creating virtual environment at: $VENV_DIR"
        
        if ! python3 -m venv "$VENV_DIR"; then
            log_error "Failed to create virtual environment"
            return 1
        fi
        
        log_success "Virtual environment created"
    fi
    
    # Activate virtual environment
    # shellcheck source=/dev/null
    if ! source "$VENV_DIR/bin/activate"; then
        log_error "Failed to activate virtual environment"
        return 1
    fi
    
    log_success "Virtual environment activated"
    return 0
}

################################################################################
# Dependency Installation
################################################################################

install_dependencies() {
    print_section "Dependency Installation"
    
    # Upgrade pip
    log_info "Upgrading pip..."
    if ! retry_command "pip install --upgrade pip setuptools wheel"; then
        log_error "Failed to upgrade pip"
        return 1
    fi
    
    log_success "Pip upgraded"
    
    # Install Modal SDK
    log_info "Installing Modal SDK..."
    if ! retry_command "pip install modal"; then
        log_error "Failed to install Modal SDK"
        return 1
    fi
    
    log_success "Modal SDK installed"
    
    # Install additional dependencies
    local dependencies=(
        "pillow>=10.0.0"
        "svgwrite>=1.4.3"
        "torch>=2.4.0"
        "huggingface-hub>=0.36.0"
    )
    
    for dep in "${dependencies[@]}"; do
        log_info "Installing: $dep"
        if ! retry_command "pip install '$dep'"; then
            log_warning "Non-critical dependency installation failed: $dep"
        else
            log_success "Installed: $dep"
        fi
    done
    
    log_success "Dependencies installed"
    return 0
}

################################################################################
# Modal Authentication
################################################################################

setup_modal_authentication() {
    print_section "Modal Authentication"
    
    local modal_token_dir="${HOME}/.modal"
    local modal_token_file="${modal_token_dir}/token"
    
    if [ -f "$modal_token_file" ]; then
        log_success "Modal token found at: $modal_token_file"
        return 0
    fi

    log_warning "No Modal token found locally"
    log_info "Skipping authentication check (assuming running in Modal shell)"
    log_info "If this fails, authenticate with: modal token new"

    return 0
}

################################################################################
# Project Setup
################################################################################

create_project_structure() {
    print_section "Project Structure Setup"
    
    mkdir -p "$MODAL_PROJECT_DIR/src"
    mkdir -p "$MODAL_PROJECT_DIR/output"
    
    log_success "Project directories created"
    return 0
}

create_modal_app() {
    print_section "Creating Modal Application"
    
    local app_file="$MODAL_PROJECT_DIR/src/logo_generator.py"
    
    cat > "$app_file" << 'EOF'
"""
Modal Logo Generator Application
Generates SVG and PNG logos using a language model
"""

import modal
from typing import Optional
import os

# Container image with GPU support
image = (
    modal.Image.from_registry("nvidia/cuda:12.8.0-devel-ubuntu22.04", add_python="3.12")
    .entrypoint([])
    .uv_pip_install(
        "vllm==0.11.2",
        "huggingface-hub==0.36.0",
        "flashinfer-python==0.5.2",
        "pillow>=10.0.0",
        "svgwrite>=1.4.3",
        "torch>=2.4.0",
    )
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1"})
)

app = modal.App("logo-generator")

# Cache model weights
hf_cache_vol = modal.Volume.from_name("huggingface-cache", create_if_missing=True)

@app.function(
    image=image,
    gpu="H100",
    volumes={"/root/.cache/huggingface": hf_cache_vol},
    timeout=600,
)
def generate_logo_svg(prompt: str) -> str:
    """Generate SVG logo from text prompt"""
    try:
        from vllm import LLM, SamplingParams
        
        print(f"Loading model...")
        llm = LLM(model="Qwen/Qwen3-8B-FP8")
        
        full_prompt = f"""Generate only valid SVG code for a logo based on this description: {prompt}
Output ONLY the SVG code, no explanations. Start with <svg and end with </svg>."""
        
        print(f"Generating SVG...")
        result = llm.generate(
            full_prompt,
            SamplingParams(temperature=0.7, max_tokens=2048)
        )
        
        svg_code = result[0].outputs[0].text
        
        # Clean up the output
        if svg_code.startswith("```"):
            svg_code = svg_code.split("```")[1]
            if svg_code.startswith("svg"):
                svg_code = svg_code[3:]
        
        return svg_code.strip()
    
    except Exception as e:
        raise RuntimeError(f"Logo generation failed: {str(e)}")


@app.function(image=image)
def save_svg_logo(svg_code: str, filename: str, output_dir: str = "/tmp") -> str:
    """Save SVG logo to file"""
    try:
        filepath = os.path.join(output_dir, filename)
        os.makedirs(output_dir, exist_ok=True)
        
        with open(filepath, "w") as f:
            f.write(svg_code)
        
        return filepath
    
    except Exception as e:
        raise RuntimeError(f"Failed to save SVG: {str(e)}")


if __name__ == "__main__":
    prompt = "A minimalist tech startup logo with circuit board patterns and neon blue"
    
    try:
        print(f"Generating logo for prompt: {prompt}")
        svg = generate_logo_svg.remote(prompt=prompt)
        print("Logo generated successfully!")
        print(svg)
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
EOF
    
    if [ -f "$app_file" ]; then
        log_success "Modal app created: $app_file"
        return 0
    else
        log_error "Failed to create Modal app"
        return 1
    fi
}

create_client_script() {
    print_section "Creating Client Script"
    
    local client_file="$MODAL_PROJECT_DIR/run_logo_generator.py"
    
    cat > "$client_file" << 'EOF'
"""
Client script to run the logo generator
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from logo_generator import generate_logo_svg, save_svg_logo
import modal

def main():
    prompts = [
        "A cyberpunk NFT card logo with neon circuit board patterns and glowing purple",
        "Minimalist tech startup logo with geometric shapes and gradient blue",
        "Gaming logo with bold typography and flame effects",
    ]
    
    output_dir = os.path.join(os.path.dirname(__file__), "output")
    os.makedirs(output_dir, exist_ok=True)
    
    for idx, prompt in enumerate(prompts, 1):
        try:
            print(f"\n[{idx}/{len(prompts)}] Generating logo for: {prompt}")
            
            # Generate SVG
            svg_code = generate_logo_svg.remote(prompt=prompt)
            
            # Save to file
            filename = f"logo_{idx}.svg"
            filepath = save_svg_logo.remote(svg_code, filename, output_dir)
            
            print(f"✓ Logo saved to: {filepath}")
            
        except Exception as e:
            print(f"✗ Error generating logo {idx}: {e}")
            continue
    
    print("\nDone!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)
EOF
    
    if [ -f "$client_file" ]; then
        chmod +x "$client_file"
        log_success "Client script created: $client_file"
        return 0
    else
        log_error "Failed to create client script"
        return 1
    fi
}

################################################################################
# Validation
################################################################################

validate_installation() {
    print_section "Installation Validation"
    
    # Check Modal installation
    if python3 -c "import modal; print(f'Modal version: {modal.__version__}')" >> "$LOG_FILE" 2>&1; then
        log_success "Modal SDK verified"
    else
        log_error "Modal SDK verification failed"
        return 1
    fi
    
    # Check project files
    if [ -f "$MODAL_PROJECT_DIR/src/logo_generator.py" ] && [ -f "$MODAL_PROJECT_DIR/run_logo_generator.py" ]; then
        log_success "Project files verified"
    else
        log_error "Project files missing"
        return 1
    fi
    
    log_success "Installation validation passed"
    return 0
}

################################################################################
# Execution
################################################################################

run_logo_generator() {
    print_section "Running Logo Generator"
    
    if [ ! -f "$MODAL_PROJECT_DIR/run_logo_generator.py" ]; then
        log_error "Client script not found"
        return 1
    fi
    
    log_info "Executing logo generator..."
    
    if cd "$MODAL_PROJECT_DIR" && python3 run_logo_generator.py; then
        log_success "Logo generator executed successfully"
        log_info "Output saved to: $MODAL_PROJECT_DIR/output"
        return 0
    else
        log_error "Logo generator execution failed"
        return 1
    fi
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    print_section "Execution Summary"
    
    echo ""
    echo "Project Directory: $MODAL_PROJECT_DIR"
    echo "Output Directory: $MODAL_PROJECT_DIR/output"
    echo "Log File: $LOG_FILE"
    echo ""
    echo "Errors: $ERRORS_ENCOUNTERED"
    echo "Warnings: $WARNINGS_ENCOUNTERED"
    echo ""
    
    if [ $ERRORS_ENCOUNTERED -eq 0 ]; then
        echo -e "${GREEN}✓ Execution completed successfully${NC}"
    else
        echo -e "${RED}✗ Execution completed with errors${NC}"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    init_logging
    
    print_section "Modal Logo Generator - Setup & Execution"
    log_info "Starting automated setup and execution"
    log_info "Script directory: $SCRIPT_DIR"
    
    # Pre-flight checks
    check_system_requirements || return 1
    check_disk_space || return 1
    check_internet_connectivity || return 1
    
    # Setup
    setup_virtual_environment || return 1
    install_dependencies || return 1
    setup_modal_authentication || return 1
    create_project_structure || return 1
    create_modal_app || return 1
    create_client_script || return 1
    
    # Validation
    validate_installation || return 1

    # Execution (non-fatal - requires Modal deployment)
    log_info "Skipping logo generator execution (requires Modal deployment)"
    log_info "To run the logo generator later:"
    log_info "  1. Deploy Modal app: cd modal_project/src && modal deploy logo_generator.py"
    log_info "  2. Run generator: python modal_project/run_logo_generator.py"

    # Summary
    print_summary

    return 0
}

# Run main function
main
exit_code=$?

exit $exit_code