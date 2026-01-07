#!/usr/bin/env bash
# ===============================================================
# Development Environment Bootstrap Script (macOS)
#
# This script installs prerequisites for a development environment
# on macOS using Homebrew and NVM.
#
# Installation Components:
#   1. System Dependencies & Build Tools (including Graphviz & Chromium)
#   2. Python 3 Environment & Virtual Environment Tools
#   3. Python Diagram Libraries (diagrams, graphviz, pydot, pygraphviz)
#   4. AWS CLI v2
#   5. Microsoft Azure CLI
#   6. Azure DevOps Extension (Azure CLI)
#   7. AWS Lightsail Plugin (lightsailctl)
#   8. Microsoft .NET SDK
#   9. HashiCorp Terraform
#  10. Docker Desktop (container runtime)
#  11. Node Version Manager (nvm)
#  12. Node.js 20 LTS via nvm
#  13. NPM Package Manager (included with Node.js)
#  14. Shell profile configuration for nvm
#  15. CDK for Terraform (cdktf-cli) - Global NPM Package
#  16. Markdown to PDF Converter (mdpdf) - Global NPM Package
#
# Usage:
#   bash node_python.sh
# ===============================================================

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: This script is intended for macOS only."
  exit 1
fi

# Determine log file location based on permissions
if [ "${EUID}" -eq 0 ]; then
  LOG_FILE="/var/log/dev-environment-setup.log"
else
  LOG_FILE="./dev-environment-setup.log"
fi

exec > >(tee "$LOG_FILE") 2>&1

echo "Starting Development Environment Setup (macOS)..."
echo "Log File: $LOG_FILE"
echo ""

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is not installed."
  echo "Install Homebrew from https://brew.sh and rerun this script."
  exit 1
fi

BREW_PREFIX="$(brew --prefix)"

# ===============================================================
# 1. SYSTEM DEPENDENCIES & BUILD TOOLS
# ===============================================================
echo "[1/16] Installing System Dependencies & Build Tools..."
brew install git curl wget unzip jq shellcheck pkg-config graphviz openssl@3 libffi postgresql@16 mysql-client

# Install Chromium for PDF generation (Mermaid, md-to-pdf)
if ! command -v chromium >/dev/null 2>&1; then
  brew install --cask chromium
fi

echo "System dependencies installed."
echo ""

# ===============================================================
# 2. PYTHON 3 ENVIRONMENT & VIRTUAL ENVIRONMENT TOOLS
# ===============================================================
echo "[2/16] Installing Python 3 Environment..."
if ! command -v python3 >/dev/null 2>&1; then
  brew install python
fi

echo "Python detected: $(python3 --version)"
python3 -m pip install --upgrade pip setuptools wheel || echo "Warning: pip/setuptools upgrade failed."
echo "Python 3 environment setup completed."
echo ""

# ===============================================================
# 3. PYTHON DIAGRAM LIBRARIES
# ===============================================================
echo "[3/16] Installing Python Diagram Libraries..."
if python3 -c "import diagrams; import graphviz; import pydot" >/dev/null 2>&1; then
  echo "  Python diagram libraries already installed."
else
  python3 -m pip install diagrams graphviz pydot || true
  python3 -m pip install pygraphviz 2>/dev/null || echo "  pygraphviz could not be installed (optional)."
fi

echo "Python diagram libraries installation completed."
echo ""

# ===============================================================
# 4. AWS CLI v2
# ===============================================================
echo "[4/16] Installing AWS CLI v2..."
if command -v aws >/dev/null 2>&1; then
  echo "  AWS CLI already installed: $(aws --version)"
else
  brew install awscli
  echo "  AWS CLI installed: $(aws --version)"
fi

echo ""

# ===============================================================
# 5. MICROSOFT AZURE CLI
# ===============================================================
echo "[5/16] Installing Microsoft Azure CLI..."
if command -v az >/dev/null 2>&1; then
  echo "  Azure CLI already installed: $(az --version 2>/dev/null | head -n 1 || echo installed)"
else
  brew install azure-cli
  echo "  Azure CLI installed: $(az --version 2>/dev/null | head -n 1 || echo installed)"
fi

echo ""

# ===============================================================
# 6. AZURE DEVOPS EXTENSION (AZURE CLI)
# ===============================================================
echo "[6/16] Installing Azure DevOps Extension..."
if command -v az >/dev/null 2>&1; then
  if az extension show --name azure-devops >/dev/null 2>&1; then
    echo "  Azure DevOps extension already installed."
  else
    az extension add --name azure-devops
    echo "  Azure DevOps extension installed."
  fi
else
  echo "  Azure CLI not found, skipping Azure DevOps extension installation."
fi

echo ""

# ===============================================================
# 7. AWS LIGHTSAIL PLUGIN (LIGHTSAILCTL)
# ===============================================================
echo "[7/16] Installing AWS Lightsail Plugin..."
if command -v lightsailctl >/dev/null 2>&1; then
  echo "  lightsailctl already installed: $(lightsailctl --version 2>/dev/null || echo installed)"
else
  ARCH="$(uname -m)"
  LIGHTSAIL_ARCH=""
  case "$ARCH" in
    x86_64|amd64) LIGHTSAIL_ARCH="darwin-amd64" ;;
    arm64) LIGHTSAIL_ARCH="darwin-arm64" ;;
  esac

  if [ -z "$LIGHTSAIL_ARCH" ]; then
    echo "  Unsupported architecture for lightsailctl: $ARCH"
  else
    INSTALL_DIR="$BREW_PREFIX/bin"
    TMP_FILE="$(mktemp)"
    curl -fsSL "https://s3.us-west-2.amazonaws.com/lightsailctl/latest/${LIGHTSAIL_ARCH}/lightsailctl" -o "$TMP_FILE"
    install -m 755 "$TMP_FILE" "$INSTALL_DIR/lightsailctl"
    rm -f "$TMP_FILE"
    echo "  lightsailctl installed to $INSTALL_DIR/lightsailctl"
  fi
fi

echo ""

# ===============================================================
# 8. MICROSOFT .NET SDK
# ===============================================================
echo "[8/16] Installing Microsoft .NET SDK..."
if command -v dotnet >/dev/null 2>&1; then
  echo "  .NET SDK already installed:"
  dotnet --list-sdks || true
else
  brew install --cask dotnet-sdk
  dotnet --list-sdks || true
fi

echo ""

# ===============================================================
# 9. HASHICORP TERRAFORM
# ===============================================================
echo "[9/16] Installing HashiCorp Terraform..."
if command -v terraform >/dev/null 2>&1; then
  echo "  Terraform already installed: $(terraform -version | head -n 1)"
else
  brew install terraform
  echo "  Terraform installed: $(terraform -version | head -n 1)"
fi

echo ""

# ===============================================================
# 10. DOCKER DESKTOP
# ===============================================================
echo "[10/16] Installing Docker Desktop..."
if [ -d "/Applications/Docker.app" ] || brew list --cask docker >/dev/null 2>&1; then
  echo "  Docker Desktop already installed."
else
  brew install --cask docker
  echo "  Docker Desktop installed. Launch it once to finish setup."
fi

echo ""

# ===============================================================
# 11. NODE VERSION MANAGER (NVM)
# ===============================================================
echo "[11/16] Installing Node Version Manager (nvm)..."
if brew list nvm >/dev/null 2>&1; then
  echo "  nvm already installed."
else
  brew install nvm
fi

NVM_DIR_TARGET="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo ~"${NVM_DIR_TARGET}")"
export NVM_DIR="$TARGET_HOME/.nvm"
mkdir -p "$NVM_DIR"

NVM_SH="$BREW_PREFIX/opt/nvm/nvm.sh"
if [ -s "$NVM_SH" ]; then
  # Add nvm to shell profiles if not present
  for profile in ".zshrc" ".bash_profile" ".bashrc"; do
    PROFILE_PATH="$TARGET_HOME/$profile"
    if [ -f "$PROFILE_PATH" ] && grep -q "nvm.sh" "$PROFILE_PATH"; then
      continue
    fi
    if [ ! -f "$PROFILE_PATH" ]; then
      touch "$PROFILE_PATH"
    fi
    {
      echo ""
      echo "# NVM configuration"
      echo "export NVM_DIR=\"$NVM_DIR\""
      echo "[ -s \"$NVM_SH\" ] && \\. \"$NVM_SH\""
    } >> "$PROFILE_PATH"
  done

  # Load nvm for this session
  # shellcheck disable=SC1090
  . "$NVM_SH"
fi

echo ""

# ===============================================================
# 12. NODE.JS 20 LTS
# ===============================================================
echo "[12/16] Installing Node.js 20 LTS..."
if command -v nvm >/dev/null 2>&1; then
  nvm install 20
  nvm alias default 20
  echo "  Node.js installed: $(node -v)"
else
  echo "  nvm not available; install it and rerun this step."
fi

echo ""

# ===============================================================
# 13. NPM PACKAGE MANAGER
# ===============================================================
echo "[13/16] Configuring NPM..."
if command -v npm >/dev/null 2>&1; then
  echo "  NPM version: $(npm -v)"
fi

echo ""

# ===============================================================
# 14. SHELL PROFILE CONFIGURATION
# ===============================================================
echo "[14/16] Shell profile configuration complete."
echo "  Reload your shell or run: source \"$NVM_SH\""

echo ""

# ===============================================================
# 15. CDK FOR TERRAFORM (CDKTF-CLI)
# ===============================================================
echo "[15/16] Installing CDK for Terraform (cdktf-cli)..."
if command -v cdktf >/dev/null 2>&1; then
  echo "  CDKTF already installed: $(cdktf --version)"
else
  npm install -g cdktf-cli
  echo "  CDKTF installed: $(cdktf --version)"
fi

echo ""

# ===============================================================
# 16. MARKDOWN TO PDF CONVERTER (MDPDF)
# ===============================================================
echo "[16/16] Installing Markdown to PDF Converter (mdpdf)..."
if command -v mdpdf >/dev/null 2>&1; then
  echo "  mdpdf already installed: $(mdpdf --version 2>/dev/null || echo installed)"
else
  npm install -g mdpdf
  echo "  mdpdf installed: $(mdpdf --version 2>/dev/null || echo installed)"
fi

echo ""

echo "Installation complete."
echo "Log File: $LOG_FILE"

exit 0
