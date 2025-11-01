#!/usr/bin/env bash
# ===============================================================
#  Development Environment Bootstrap Script
#  Target OS: Ubuntu 22.04 / 24.04 (EC2 or any x86_64 Linux)
#
#  This script installs all prerequisites for a complete
#  development environment with global tool installations.
#
#  Installation Components:
#    1. System Dependencies & Build Tools
#    2. Python 3 Environment & Virtual Environment Tools
#    3. AWS CLI v2 (Official Package)
#    4. Microsoft .NET 8 SDK
#    5. HashiCorp Terraform (Latest Stable)
#    6. Node Version Manager (nvm) - Global Installation
#    7. Node.js 20 LTS - Global Installation via nvm
#    8. NPM Package Manager - Included with Node.js
#    9. CDK for Terraform (cdktf-cli) - Global NPM Package
#   10. Global Environment Configuration & Tool Verification
#
#  Usage:
#    sudo bash node_python.sh
#
#  Log file:
#    /var/log/dev-environment-setup.log
# ===============================================================

set -euo pipefail
exec > >(tee /var/log/dev-environment-setup.log) 2>&1

# ===============================================================
# CONFIGURATION VARIABLES
# ===============================================================
NVM_VERSION="v0.39.7"      # Node Version Manager installer version

echo "🚀 Starting Development Environment Setup..."
echo "Log File: /var/log/dev-environment-setup.log"
echo ""

# ===============================================================
# 1. SYSTEM DEPENDENCIES & BUILD TOOLS
# ===============================================================
echo "📦 [1/11] Installing System Dependencies & Build Tools..."
echo "-------------------------------------------------------"
export DEBIAN_FRONTEND=noninteractive

# Update package index
echo "  → Updating package index..."
apt-get update -y

# Install essential system packages and build dependencies
echo "  → Installing core system packages..."
apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release software-properties-common \
  git curl tar wget unzip jq

echo "  → Installing build tools and development libraries..."
apt-get install -y \
  pkg-config build-essential gcc \
  default-libmysqlclient-dev libssl-dev libffi-dev libpq-dev

echo "✅ System dependencies and build tools installed successfully"
echo ""

# ===============================================================
# 2. PYTHON 3 ENVIRONMENT & VIRTUAL ENVIRONMENT TOOLS
# ===============================================================
echo "🐍 [2/11] Installing Python 3 Environment..."
echo "---------------------------------------------"

# Install Python 3 and virtual environment tools
echo "  → Installing Python 3 and venv module..."
apt-get install -y python3 python3-venv
apt-get install -y python3-pip

# Verify Python installation
PYTHON_VERSION=$(python3 --version)
echo "  → Python installed: ${PYTHON_VERSION}"
echo "✅ Python 3 environment setup completed"
echo ""

# ===============================================================
# 3. AWS CLI v2 (OFFICIAL PACKAGE)
# ===============================================================
echo "☁️  [3/11] Installing AWS CLI v2..."
echo "----------------------------------"

# Install AWS CLI v2 using snap (official package manager approach)
echo "  → Installing AWS CLI v2 via snap..."
snap install aws-cli --classic

# Verify AWS CLI installation
AWS_VERSION=$(aws --version)
echo "  → AWS CLI installed: ${AWS_VERSION}"
echo "✅ AWS CLI v2 installation completed"
echo ""

# ===============================================================
# 4. MICROSOFT .NET 8 SDK
# ===============================================================
echo "⚡ [4/11] Installing Microsoft .NET 8 SDK..."
echo "--------------------------------------------"

# Determine Ubuntu version and set up Microsoft package repository
echo "  → Configuring Microsoft package repository..."
UBU_VER="$(lsb_release -rs)"
MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/${UBU_VER}/packages-microsoft-prod.deb"

# Fall back to Ubuntu 20.04 configuration if specific version not available
if ! curl -fsI "$MS_DEB_URL" >/dev/null; then
  echo "  → Falling back to Ubuntu 20.04 package configuration..."
  MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
fi

# Download and install Microsoft package repository configuration
curl -fsSL "$MS_DEB_URL" -o /tmp/packages-microsoft-prod.deb
dpkg -i --force-confdef --force-confold /tmp/packages-microsoft-prod.deb

# Update package index and install .NET SDK
echo "  → Installing .NET 8 SDK..."
apt-get update -y
apt-get install -y dotnet-sdk-8.0

# Verify .NET SDK installation
echo "  → Installed .NET SDKs:"
dotnet --list-sdks
echo "✅ Microsoft .NET 8 SDK installation completed"
echo ""

# ===============================================================
# 5. HASHICORP TERRAFORM (LATEST STABLE)
# ===============================================================
echo "🏗️  [5/11] Installing HashiCorp Terraform..."
echo "-------------------------------------------"

# Set up HashiCorp package repository
echo "  → Configuring HashiCorp package repository..."
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg

# Add HashiCorp repository to sources list
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
echo "  → Installing Terraform..."
apt-get update -y
apt-get install -y terraform

# Verify Terraform installation
TERRAFORM_VERSION=$(terraform -version | head -n 1)
echo "  → ${TERRAFORM_VERSION}"
echo "✅ HashiCorp Terraform installation completed"
echo ""

# ===============================================================
# 6. NODE VERSION MANAGER (NVM) - GLOBAL INSTALLATION
# ===============================================================
echo "📦 [6/11] Installing Node Version Manager (nvm)..."
echo "-------------------------------------------------"

# Set up global nvm directory (accessible to all users)
echo "  → Setting up global nvm directory: /opt/nvm"
export NVM_DIR="/opt/nvm"
mkdir -p "$NVM_DIR"

# Download and install nvm globally
echo "  → Downloading and installing nvm ${NVM_VERSION}..."
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

# Load nvm in current shell session
echo "  → Loading nvm in current shell..."
. "$NVM_DIR/nvm.sh"

echo "✅ Node Version Manager (nvm) installation completed"
echo ""

# ===============================================================
# 7. NODE.JS 20 LTS - GLOBAL INSTALLATION VIA NVM
# ===============================================================
echo "🟢 [7/11] Installing Node.js 20 LTS..."
echo "-------------------------------------"

# Install Node.js 20 LTS and set as default
echo "  → Installing Node.js 20 LTS via nvm..."
nvm install 20
nvm alias default 20

# Verify Node.js installation
NODE_VERSION=$(node -v)
echo "  → Node.js installed: ${NODE_VERSION}"
echo "✅ Node.js 20 LTS installation completed"
echo ""

# ===============================================================
# 8. NPM PACKAGE MANAGER - INCLUDED WITH NODE.JS
# ===============================================================
echo "📦 [8/11] Configuring NPM Package Manager..."
echo "--------------------------------------------"

# NPM is automatically installed with Node.js, just verify and show version
NPM_VERSION=$(npm -v)
echo "  → NPM version: ${NPM_VERSION}"

# Configure global npm permissions (already handled by nvm global setup)
echo "  → NPM is ready for global package installations"
echo "✅ NPM Package Manager configuration completed"
echo ""

# ===============================================================
# 9. GLOBAL ENVIRONMENT CONFIGURATION
# ===============================================================
echo "🌍 [9/10] Configuring Global Environment Access..."
echo "------------------------------------------------"

# Make nvm and Node.js globally available to all users via profile.d
echo "  → Creating global environment configuration..."
cat > /etc/profile.d/nvm.sh << 'EOF'
# Global Node Version Manager (nvm) configuration
# This file makes nvm, Node.js, and npm available to all users

export NVM_DIR="/opt/nvm"

# Load nvm if available
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

# Load nvm bash completion if available
if [ -s "$NVM_DIR/bash_completion" ]; then
    . "$NVM_DIR/bash_completion"
fi
EOF

# Set proper permissions for global access
echo "  → Setting proper permissions..."
chmod 755 /etc/profile.d/nvm.sh
chown -R root:root "$NVM_DIR"
chmod -R 755 "$NVM_DIR"

echo "✅ Global environment configuration completed"
echo ""

# ===============================================================
# 10. CDK FOR TERRAFORM (CDKTF-CLI) - GLOBAL NPM PACKAGE
# ===============================================================
echo "🏗️  [10/10] Installing CDK for Terraform (cdktf-cli)..."
echo "-----------------------------------------------------"

# Load global nvm environment and install cdktf globally
echo "  → Installing cdktf-cli as global NPM package..."
. "/opt/nvm/nvm.sh"
npm install -g cdktf-cli

# Verify cdktf installation
CDKTF_VERSION=$(cdktf --version)
echo "  → CDK for Terraform installed: ${CDKTF_VERSION}"
echo "✅ CDK for Terraform (cdktf-cli) installation completed"
echo ""

# ===============================================================
# INSTALLATION VERIFICATION & SUMMARY
# ===============================================================
echo "🔍 Verifying All Installations..."
echo "================================"
echo ""
echo "📋 Installed Software Versions:"
echo "------------------------------"

# Load nvm environment for version checks
. /opt/nvm/nvm.sh

echo "🐍 PYTHON:     $(python3 --version)"
echo "☁️  AWS CLI:    $(aws --version | cut -d' ' -f1-2)"
echo "⚡ .NET SDK:    $(dotnet --version) ($(dotnet --list-sdks | wc -l) SDK(s) installed)"
echo "🏗️  TERRAFORM:  $(terraform -version | head -n 1)"
echo "📦 NVM:        $(nvm --version)"
echo "🟢 NODE.JS:    $(node -v)"
echo "📦 NPM:        $(npm -v)"
echo "🏗️  CDKTF:      $(cdktf --version)"
echo ""

echo "🌍 Global Environment:"
echo "---------------------"
echo "NVM Directory: ${NVM_DIR}"
echo "Profile Script: /etc/profile.d/nvm.sh"
echo "Log File: /var/log/dev-environment-setup.log"
echo ""

echo "✅ 🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉"
echo "============================================="
echo ""
echo "All development tools have been installed and configured globally."
echo "The environment is ready for development work."
echo ""
echo "Next Steps:"
echo "  1. Logout/login or run 'source /etc/profile.d/nvm.sh' to load Node.js environment"
echo "  2. All tools are now available globally for all users"
echo ""
echo "For support: Check logs at /var/log/dev-environment-setup.log"