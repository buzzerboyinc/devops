#!/usr/bin/env bash
# ===============================================================
#  Development Environment Bootstrap Script
#  Target OS: Ubuntu 22.04 / 24.04 (EC2 or any x86_64 Linux)
#
#  This script installs all prerequisites for a complete
#  development environment with global tool installations.
#
#  Installation Components:
#    1. System Dependencies & Build Tools (including Graphviz & Chromium)
#    2. Python 3 Environment & Virtual Environment Tools
#    3. Python Diagram Libraries (diagrams, graphviz, pydot, pygraphviz)
#    4. AWS CLI v2 (Official Package)
#    5. Microsoft Azure CLI
#    6. Azure DevOps Extension (Azure CLI)
#    7. AWS Lightsail Plugin (lightsailctl)
#    8. Microsoft .NET 8 SDK
#    9. HashiCorp Terraform (Latest Stable)
#   10. Docker & Docker CE (Container Runtime)
#   11. Node Version Manager (nvm) - Global Installation
#   12. Node.js 20 LTS - Global Installation via nvm
#   13. NPM Package Manager - Included with Node.js
#   14. Global Environment Configuration
#   15. CDK for Terraform (cdktf-cli) - Global NPM Package
#   16. Markdown to PDF Converter (mdpdf) - Global NPM Package
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
# HELPER FUNCTIONS
# ===============================================================

# Wait for apt/dpkg locks to be released
wait_for_apt_lock() {
  local max_wait=300  # Maximum wait time in seconds (5 minutes)
  local wait_time=0
  local check_interval=2
  
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
        fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    
    if [ $wait_time -eq 0 ]; then
      echo "  ⏳ Waiting for other package managers to finish..."
    fi
    
    if [ $wait_time -ge $max_wait ]; then
      echo "  ⚠️  Warning: Timeout waiting for package manager locks"
      echo "  → You may need to manually kill blocking processes or remove stale locks"
      return 1
    fi
    
    sleep $check_interval
    wait_time=$((wait_time + check_interval))
  done
  
  if [ $wait_time -gt 0 ]; then
    echo "  ✓ Package manager is now available"
  fi
  
  return 0
}

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
echo "📦 [1/16] Installing System Dependencies & Build Tools..."
echo "-------------------------------------------------------"
export DEBIAN_FRONTEND=noninteractive

# Wait for any existing package manager operations to complete
wait_for_apt_lock

# Fix any broken or partially installed packages
echo "  → Checking for broken packages..."
dpkg --configure -a 2>/dev/null || true

# Update package index
echo "  → Updating package index..."
apt-get update -y

# Install essential system packages and build dependencies
echo "  → Installing core system packages..."
apt-get update -y

# Skip upgrade to avoid issues with partially installed packages
# Users can run 'apt-get upgrade' manually if needed

apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release software-properties-common \
  git curl tar wget unzip jq shellcheck
apt-get install -y pkg-config default-libmysqlclient-dev build-essential libssl-dev libffi-dev libpq-dev gcc git wget

echo "  → Installing build tools and development libraries..."
apt-get install -y \
  pkg-config build-essential gcc \
  default-libmysqlclient-dev libssl-dev libffi-dev libpq-dev

echo "  → Installing Graphviz for diagram generation..."
apt-get install -y graphviz
# Try to install libgraphviz-dev, but don't fail if there are dependency issues
apt-get install -y libgraphviz-dev || echo "  ⚠️  Warning: libgraphviz-dev has dependency conflicts, skipping (graphviz core installed)"

echo "  → Installing Chromium and dependencies for PDF generation..."
# Try chromium-browser first, fall back to chromium, or skip if neither works
if ! command -v chromium-browser &> /dev/null && ! command -v chromium &> /dev/null; then
  # Install core Chromium dependencies (excluding audio libs that may fail on WSL)
  apt-get install -y \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils
  
  # Try to install audio library (may fail on WSL, which is OK)
  echo "  → Installing audio dependencies (optional for WSL)..."
  apt-get install -y libasound2t64 2>/dev/null || apt-get install -y libasound2 2>/dev/null || echo "  ⚠️  Warning: libasound2/libasound2t64 not available (common on WSL, chromium will work without audio)"
  
  # Try to install chromium (don't fail if snap is unavailable or slow)
  timeout 60 apt-get install -y chromium || echo "  ⚠️  Warning: Chromium installation timed out or failed, skipping"
else
  echo "  ℹ️  Chromium already installed, skipping"
fi

echo "✅ System dependencies and build tools installed successfully"
echo ""

# ===============================================================
# 2. PYTHON 3 ENVIRONMENT & VIRTUAL ENVIRONMENT TOOLS
# ===============================================================
echo "🐍 [2/16] Installing Python 3 Environment..."
echo "---------------------------------------------"

# Install Python 3 and virtual environment tools
echo "  → Installing Python 3 and venv module..."
apt-get install -y python3 python3-venv python3-full
apt-get install -y python3-pip || echo "  ⚠️  python3-pip may have issues, will use alternative method"

# Verify Python installation
PYTHON_VERSION=$(python3 --version)
echo "  → Python installed: ${PYTHON_VERSION}"

# Try to upgrade pip, but don't fail if system pip is broken
echo "  → Ensuring pip is available..."
if ! python3 -m pip --version >/dev/null 2>&1; then
  echo "  → System pip not working, installing pip via get-pip.py..."
  curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
  python3 /tmp/get-pip.py
  rm /tmp/get-pip.py
fi

python3 -m pip --version
echo "  → Upgrading pip/setuptools/wheel for Python 3.12 compatibility..."
python3 -m pip install --upgrade pip setuptools wheel || echo "  ⚠️  Warning: pip/setuptools upgrade failed, continuing"
echo "✅ Python 3 environment setup completed"
echo ""

# ===============================================================
# 3. PYTHON DIAGRAM LIBRARIES
# ===============================================================
echo "🎨 [3/16] Installing Python Diagram Libraries..."
echo "------------------------------------------------"

# Check if diagram libraries are already installed
if python3 -c "import diagrams; import graphviz; import pydot" 2>/dev/null; then
  echo "  ℹ️  Python diagram libraries already installed"
  echo "  → Skipping installation"
else
  # Install Python diagram and visualization packages
  echo "  → Installing diagrams, graphviz, and pydot..."
  python3 -m pip install --break-system-packages diagrams graphviz pydot || \
  python3 -m pip install diagrams graphviz pydot
  
  # Try to install pygraphviz separately (may fail without libgraphviz-dev)
  echo "  → Attempting to install pygraphviz (optional)..."
  python3 -m pip install --break-system-packages pygraphviz 2>/dev/null || \
  python3 -m pip install pygraphviz 2>/dev/null || \
  echo "  ⚠️  pygraphviz could not be installed (requires libgraphviz-dev), continuing without it"

  echo "  → Verifying core diagram libraries installation..."
  python3 -c "import diagrams; import graphviz; import pydot; print('Core diagram libraries installed successfully')" || \
  echo "  ⚠️  Some diagram libraries may not have installed correctly"
fi
echo "✅ Python diagram libraries installation completed"
echo ""

# ===============================================================
# 4. AWS CLI v2 (OFFICIAL PACKAGE)
# ===============================================================
echo "☁️  [4/16] Installing AWS CLI v2..."
echo "----------------------------------"

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
  AWS_VERSION=$(aws --version)
  echo "  ℹ️  AWS CLI already installed: ${AWS_VERSION}"
  echo "  → Skipping installation"
else
  # Install AWS CLI v2 - try snap first, fall back to direct download
  echo "  → Installing AWS CLI v2..."
  if command -v snap &> /dev/null; then
    echo "  → Using snap package manager..."
    snap install aws-cli --classic
  else
    echo "  → Using direct download (snap not available)..."
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
  fi

  # Verify AWS CLI installation
  AWS_VERSION=$(aws --version)
  echo "  → AWS CLI installed: ${AWS_VERSION}"
fi
echo "✅ AWS CLI v2 installation completed"
echo ""

# ===============================================================
# 5. MICROSOFT AZURE CLI
# ===============================================================
echo "☁️  [5/16] Installing Microsoft Azure CLI..."
echo "--------------------------------------------"

# Check if Azure CLI is already installed
if command -v az &> /dev/null; then
  AZ_VERSION=$(az --version 2>/dev/null | head -n 1 || echo "installed")
  echo "  ℹ️  Azure CLI already installed: ${AZ_VERSION}"
  echo "  → Skipping installation"
else
  # Install Azure CLI using the official installer
  echo "  → Installing Azure CLI..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

  # Verify Azure CLI installation
  AZ_VERSION=$(az --version 2>/dev/null | head -n 1 || echo "installed")
  echo "  → Azure CLI installed: ${AZ_VERSION}"
fi
echo "✅ Microsoft Azure CLI installation completed"
echo ""

# ===============================================================
# 6. AZURE DEVOPS EXTENSION (AZURE CLI)
# ===============================================================
echo "☁️  [6/16] Installing Azure DevOps Extension..."
echo "----------------------------------------------"

# Install Azure DevOps extension if Azure CLI is available
if command -v az &> /dev/null; then
  if az extension show --name azure-devops >/dev/null 2>&1; then
    echo "  ℹ️  Azure DevOps extension already installed"
    echo "  → Skipping installation"
  else
    echo "  → Installing Azure DevOps extension..."
    az extension add --name azure-devops
    echo "  → Azure DevOps extension installed"
  fi
else
  echo "  ⚠️  Azure CLI not found, skipping Azure DevOps extension installation"
fi
echo "✅ Azure DevOps extension installation completed"
echo ""

# ===============================================================
# 7. AWS LIGHTSAIL PLUGIN (LIGHTSAILCTL)
# ===============================================================
echo "☁️  [7/16] Installing AWS Lightsail Plugin..."
echo "--------------------------------------------"

# Check if lightsailctl is already installed
if command -v lightsailctl &> /dev/null; then
  LIGHTSAIL_VERSION=$(lightsailctl --version 2>&1 || echo "installed")
  echo "  ℹ️  Lightsail plugin already installed: ${LIGHTSAIL_VERSION}"
  echo "  → Skipping installation"
else
  # Download and install lightsailctl
  echo "  → Downloading lightsailctl from S3..."
  curl -fsSL "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-amd64/lightsailctl" -o /tmp/lightsailctl

  echo "  → Installing lightsailctl to /usr/local/bin/..."
  chmod +x /tmp/lightsailctl
  mv /tmp/lightsailctl /usr/local/bin/

  # Verify Lightsail plugin installation
  LIGHTSAIL_VERSION=$(lightsailctl --version 2>&1 || echo "installed")
  echo "  → Lightsail plugin installed: ${LIGHTSAIL_VERSION}"
fi
echo "✅ AWS Lightsail Plugin installation completed"
echo ""

# ===============================================================
# 8. MICROSOFT .NET 8 SDK
# ===============================================================
echo "⚡ [8/16] Installing Microsoft .NET 8 SDK..."
echo "--------------------------------------------"

# Check if .NET SDK is already installed
if command -v dotnet &> /dev/null; then
  echo "  ℹ️  .NET SDK already installed:"
  dotnet --list-sdks
  echo "  → Skipping installation"
else
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
fi
echo "✅ Microsoft .NET 8 SDK installation completed"
echo ""

# ===============================================================
# 9. HASHICORP TERRAFORM (LATEST STABLE)
# ===============================================================
echo "🏗️  [9/16] Installing HashiCorp Terraform..."
echo "-------------------------------------------"

# Check if Terraform is already installed
if command -v terraform &> /dev/null; then
  TERRAFORM_VERSION=$(terraform -version | head -n 1)
  echo "  ℹ️  Terraform already installed: ${TERRAFORM_VERSION}"
  echo "  → Skipping installation"
else
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
fi
echo "✅ HashiCorp Terraform installation completed"
echo ""

# ===============================================================
# 10. DOCKER & DOCKER CE (CONTAINER RUNTIME)
# ===============================================================
echo "🐳 [10/16] Installing Docker & Docker CE..."
echo "-----------------------------------------"

# Check if Docker is already installed
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version)
  echo "  ℹ️  Docker already installed: ${DOCKER_VERSION}"
  echo "  → Skipping installation"
else
  # Check if running in a container (Docker-in-Docker detection)
  if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "  ⚠️  Running inside a container - Docker-in-Docker setup detected"
    echo "  → Installing Docker CLI only (daemon will use host Docker)"
  fi

  # Remove any old Docker packages
  echo "  → Removing old Docker packages (if any)..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg 2>/dev/null || true
  done

  # Set up Docker's official GPG key and repository
  echo "  → Configuring Docker's official repository..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker repository to sources list
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  # Install Docker Engine, CLI, containerd, and plugins
  echo "  → Installing Docker Engine and components..."
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Start and enable Docker service (skip if in container)
  if [ ! -f /.dockerenv ] && ! grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "  → Starting Docker service..."
    systemctl start docker
    systemctl enable docker
  else
    echo "  → Skipping Docker daemon start (running in container)"
  fi

  # Verify Docker installation
  DOCKER_VERSION=$(docker --version)
  echo "  → Docker installed: ${DOCKER_VERSION}"
  if command -v docker compose &> /dev/null; then
    echo "  → Docker Compose installed: $(docker compose version)"
  fi

  # Add docker group for non-root access (users will need to be added manually)
  echo "  → Docker group configured for non-root access"
  echo "  → Note: Add users to docker group with: sudo usermod -aG docker <username>"
fi
echo "✅ Docker & Docker CE installation completed"
echo ""

# ===============================================================
# 11. NODE VERSION MANAGER (NVM) - GLOBAL INSTALLATION
# ===============================================================
echo "📦 [11/16] Installing Node Version Manager (nvm)..."
echo "-------------------------------------------------"

# Set up global nvm directory (accessible to all users)
export NVM_DIR="/opt/nvm"

# Check if nvm is already installed
if [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "  ℹ️  NVM already installed in ${NVM_DIR}"
  echo "  → Skipping installation"
  # Load nvm in current shell session
  . "$NVM_DIR/nvm.sh"
else
  echo "  → Setting up global nvm directory: /opt/nvm"
  mkdir -p "$NVM_DIR"

  # Download and install nvm globally
  echo "  → Downloading and installing nvm ${NVM_VERSION}..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

  # Load nvm in current shell session
  echo "  → Loading nvm in current shell..."
  . "$NVM_DIR/nvm.sh"
fi

echo "✅ Node Version Manager (nvm) installation completed"
echo ""

# ===============================================================
# 12. NODE.JS 20 LTS - GLOBAL INSTALLATION VIA NVM
# ===============================================================
echo "🟢 [12/16] Installing Node.js 20 LTS..."
echo "-------------------------------------"

# Check if Node.js 20 is already installed
if command -v node &> /dev/null; then
  NODE_VERSION=$(node -v)
  echo "  ℹ️  Node.js already installed: ${NODE_VERSION}"
  # Check if it's version 20
  if [[ "$NODE_VERSION" == v20* ]]; then
    echo "  → Node.js 20 LTS already installed, skipping"
  else
    echo "  → Installing Node.js 20 LTS via nvm..."
    nvm install 20
    nvm alias default 20
    NODE_VERSION=$(node -v)
    echo "  → Node.js installed: ${NODE_VERSION}"
  fi
else
  # Install Node.js 20 LTS and set as default
  echo "  → Installing Node.js 20 LTS via nvm..."
  nvm install 20
  nvm alias default 20

  # Verify Node.js installation
  NODE_VERSION=$(node -v)
  echo "  → Node.js installed: ${NODE_VERSION}"
fi
echo "✅ Node.js 20 LTS installation completed"
echo ""

# ===============================================================
# 13. NPM PACKAGE MANAGER - INCLUDED WITH NODE.JS
# ===============================================================
echo "📦 [13/16] Configuring NPM Package Manager..."
echo "--------------------------------------------"

# NPM is automatically installed with Node.js, just verify and show version
NPM_VERSION=$(npm -v)
echo "  → NPM version: ${NPM_VERSION}"

# Configure global npm permissions (already handled by nvm global setup)
echo "  → NPM is ready for global package installations"
echo "✅ NPM Package Manager configuration completed"
echo ""

# ===============================================================
# 14. GLOBAL ENVIRONMENT CONFIGURATION
# ===============================================================
echo "🌍 [14/16] Configuring Global Environment Access..."
echo "--------------------------------------------------"

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
# 15. CDK FOR TERRAFORM (CDKTF-CLI) - GLOBAL NPM PACKAGE
# ===============================================================
echo "🏗️  [15/16] Installing CDK for Terraform (cdktf-cli)..."
echo "-------------------------------------------------------"

# Load global nvm environment
. "/opt/nvm/nvm.sh"

# Check if cdktf is already installed
if command -v cdktf &> /dev/null; then
  CDKTF_VERSION=$(cdktf --version)
  echo "  ℹ️  CDK for Terraform already installed: ${CDKTF_VERSION}"
  echo "  → Skipping installation"
else
  # Install cdktf globally
  echo "  → Installing cdktf-cli as global NPM package..."
  npm install -g cdktf-cli

  # Verify cdktf installation
  CDKTF_VERSION=$(cdktf --version)
  echo "  → CDK for Terraform installed: ${CDKTF_VERSION}"
fi
echo "✅ CDK for Terraform (cdktf-cli) installation completed"
echo ""

# ===============================================================
# 16. MARKDOWN TO PDF CONVERTER (MDPDF) - GLOBAL NPM PACKAGE
# ===============================================================
echo "📄 [16/16] Installing Markdown to PDF Converter (mdpdf)..."
echo "---------------------------------------------------------"

# Load global nvm environment
. "/opt/nvm/nvm.sh"

# Check if mdpdf is already installed
if command -v mdpdf &> /dev/null; then
  MDPDF_VERSION=$(mdpdf --version 2>&1 || echo "installed")
  echo "  ℹ️  Markdown to PDF converter already installed: ${MDPDF_VERSION}"
  echo "  → Skipping installation"
else
  # Install mdpdf globally
  echo "  → Installing mdpdf as global NPM package..."
  npm install -g mdpdf

  # Verify mdpdf installation
  MDPDF_VERSION=$(mdpdf --version 2>&1 || echo "installed")
  echo "  → Markdown to PDF converter installed: ${MDPDF_VERSION}"
fi
echo "✅ Markdown to PDF converter (mdpdf) installation completed"
echo ""

# ===============================================================
# INSTALLATION VERIFICATION & SUMMARY
# ===============================================================
echo "🔍 Verifying All Installations..."
echo "================================"
echo ""
echo "🧪 Running Smoke Tests..."
echo "------------------------"
if command -v shellcheck &> /dev/null; then
  echo "  ✅ ShellCheck installed: $(shellcheck --version | head -n 1)"
else
  echo "  ⚠️  ShellCheck not found (smoke test skipped)"
fi
if command -v az &> /dev/null; then
  if az --version >/dev/null 2>&1; then
    echo "  ✅ Azure CLI responds to --version"
  else
    echo "  ⚠️  Azure CLI installed but version check failed"
  fi
else
  echo "  ⚠️  Azure CLI not found (smoke test skipped)"
fi
echo ""
echo "📋 Installed Software Versions:"
echo "------------------------------"

# Load nvm environment for version checks
. /opt/nvm/nvm.sh

echo "🐍 PYTHON:     $(python3 --version)"
echo "🎨 DIAGRAMS:   $(python3 -c 'import diagrams; print("installed")' 2>&1 || echo 'not installed')"
echo "📊 GRAPHVIZ:   $(dot -V 2>&1 | head -n 1)"
echo "☁️  AWS CLI:    $(aws --version | cut -d' ' -f1-2)"
echo "☁️  AZ CLI:     $(az --version 2>/dev/null | head -n 1 || echo 'not installed')"
echo "☁️  LIGHTSAIL:  $(lightsailctl --version 2>&1 | head -n 1 || echo 'installed (version check may not work)')"
echo "⚡ .NET SDK:    $(dotnet --version) ($(dotnet --list-sdks | wc -l) SDK(s) installed)"
echo "🏗️  TERRAFORM:  $(terraform -version | head -n 1)"
echo "🐳 DOCKER:     $(docker --version)"
echo "🐳 COMPOSE:    $(docker compose version)"
echo "🌐 CHROMIUM:   $(chromium-browser --version 2>&1 || chromium --version 2>&1 | head -n 1)"
echo "📦 NVM:        $(nvm --version)"
echo "🟢 NODE.JS:    $(node -v)"
echo "📦 NPM:        $(npm -v)"
echo "🏗️  CDKTF:      $(cdktf --version)"
echo "📄 MDPDF:      $(mdpdf --version 2>&1 || echo 'installed')"
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
