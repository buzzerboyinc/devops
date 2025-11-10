#!/bin/bash

#
# (c) Buzzerboy Inc. (www.buzzerboy.com) 2025
#
# CDKTF Terraform Diff Script
# 
# This script sets up a Python virtual environment, installs CDKTF (Cloud Development Kit for Terraform),
# and runs terraform diff operations to compare the current infrastructure state with the desired state.
#
# REQUIRED ENVIRONMENT VARIABLES:
# --------------------------------
# product            - The product name (e.g., "myapp")
# app                - The application name (e.g., "frontend") 
# tier               - The deployment tier/environment (e.g., "dev", "staging", "prod")
# architectureFolder - The folder containing the architecture/infrastructure code
#
# OPTIONAL ENVIRONMENT VARIABLES:
# --------------------------------
# repoName           - Custom repository name (defaults to "${product}-${app}" if not provided)
#
# USAGE:
# ------
# export product="myapp"
# export app="frontend"
# export tier="dev"
# export architectureFolder="infrastructure"
# bash td-diff.sh
#

# Enable strict error handling
set -euo pipefail

# Color codes for better output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_separator() {
    echo "============================================"
}

# Validate required environment variables
validate_environment() {
    log_info "Validating environment variables..."
    local missing_vars=()
    
    [[ -z "${product:-}" ]] && missing_vars+=("product")
    [[ -z "${app:-}" ]] && missing_vars+=("app")
    [[ -z "${tier:-}" ]] && missing_vars+=("tier")
    [[ -z "${architectureFolder:-}" ]] && missing_vars+=("architectureFolder")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set all required variables before running this script."
        exit 1
    fi
    
    log_success "All required environment variables are set"
}

# Main execution
main() {
    print_separator
    log_info "Starting CDKTF Terraform Diff Script"
    print_separator
    
    # Validate environment
    validate_environment
    
    # Set repository name
    readonly REPO_NAME="${repoName:-${product}-${app}}"
    
    log_info "Configuration:"
    echo "  Product: ${product}"
    echo "  App: ${app}"
    echo "  Tier: ${tier}"
    echo "  Repository: ${REPO_NAME}"
    echo "  Architecture Folder: ${architectureFolder}"
    print_separator

    
    # Navigate to architecture folder
    log_info "Navigating to architecture folder: ${architectureFolder}"
    if [[ ! -d "${architectureFolder}" ]]; then
        log_error "Architecture folder '${architectureFolder}' does not exist"
        exit 1
    fi
    cd "${architectureFolder}"
    log_success "Successfully navigated to $(pwd)"
    
    # Show disk usage
    log_info "Current disk usage:"
    df -h
    print_separator

    # Setup Python virtual environment
    log_info "Setting up Python virtual environment..."
    if [[ -d "venv" ]]; then
        log_warning "Virtual environment already exists, removing old one"
        rm -rf venv
    fi
    
    python3 -m venv venv
    # shellcheck source=/dev/null
    source venv/bin/activate
    log_success "Python virtual environment activated"
    
    log_info "Installing Python dependencies..."
    if [[ ! -f "requirements.txt" ]]; then
        log_warning "requirements.txt not found, skipping pip install"
    else
        pip install -r requirements.txt
        log_success "Python dependencies installed"
    fi
    print_separator


    # Navigate to tier folder
    log_info "Navigating to tier folder: ${tier}"
    if [[ ! -d "${tier}" ]]; then
        log_error "Tier folder '${tier}' does not exist"
        exit 1
    fi
    cd "${tier}"
    log_success "Successfully navigated to $(pwd)"
    print_separator

    # Check Terraform version
    log_info "Checking Terraform installation..."
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    terraform --version
    print_separator

    # Install CDKTF
    log_info "Installing CDKTF CLI..."
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed or not in PATH"
        exit 1
    fi
    
    npm install --global cdktf-cli@latest
    log_success "CDKTF CLI installed"
    
    log_info "CDKTF version:"
    cdktf --version
    
    log_info "Current disk usage after CDKTF install:"
    df -h
    print_separator

    # System cleanup and optimization
    log_info "Performing system cleanup to free up space..."
    
    log_info "Memory usage before cleanup:"
    free -h
    
    log_info "Cleaning up unnecessary files..."
    sudo rm -rf /usr/local/lib/android 2>/dev/null || true
    sudo rm -rf /usr/share/dotnet 2>/dev/null || true
    sudo rm -rf /opt/ghc 2>/dev/null || true
    sudo apt-get clean 2>/dev/null || true
    
    log_info "Memory usage after cleanup:"
    free -h
    
    log_info "Disk usage after cleanup:"
    df -h
    print_separator

    # AWS configuration verification
    log_info "Verifying AWS configuration..."
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    log_info "AWS caller identity:"
    aws sts get-caller-identity
    
    log_info "AWS configuration:"
    aws configure list
    
    log_info "AWS credentials file:"
    if [[ -f ~/.aws/credentials ]]; then
        cat ~/.aws/credentials
    else
        log_warning "AWS credentials file not found"
    fi
    print_separator

    # Node.js version check
    log_info "Checking Node.js installation..."
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed or not in PATH"
        exit 1
    fi
    log_info "Node.js version: $(node -v)"
    print_separator

    # CDKTF operations
    log_info "Running CDKTF get (downloading providers)..."
    export NODE_OPTIONS="--max-old-space-size=4096"
    PIPENV_VERBOSITY=-1 cdktf get --no-synth
    log_success "CDKTF get completed"
    print_separator

    log_info "Running CDKTF synth (generating Terraform code)..."
    export NODE_OPTIONS="--max-old-space-size=4096"
    PIPENV_VERBOSITY=-1 cdktf synth
    log_success "CDKTF synth completed"
    print_separator

    # Final diff operation
    readonly STACK_NAME="${product}-${app}-${tier}-stack"
    log_info "Running CDKTF diff for stack: ${STACK_NAME}"
    PIPENV_VERBOSITY=-1 cdktf diff "${STACK_NAME}"
    log_success "CDKTF diff completed successfully"
    print_separator
    
    log_success "Script execution completed successfully!"
}

# Error handling
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

# Execute main function
main "$@"