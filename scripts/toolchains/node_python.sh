#!/usr/bin/env bash
# ===============================================================
#  Azure DevOps Agent – Environment Bootstrap (Part 1)
#  Target OS: Ubuntu 22.04 / 24.04 (EC2 or any x86_64 Linux)
#
#  This script installs all prerequisites for running an
#  Azure DevOps self-hosted agent as user "adoagent".
#
#  Major Steps:
#    1. Install system build dependencies
#    2. Install Python 3 + venv
#    3. Install AWS CLI v2 (snap)
#    4. Install Microsoft .NET 8 SDK
#    5. Install Terraform
#    6. Create "adoagent" user
#    7. Install Node.js 20 LTS via nvm for adoagent
#    8. Install CDKTF CLI for adoagent
#    9. Verify tool versions
#
#  Usage:
#    sudo bash adoagent-part1.sh
#
#  Log file:
#    /var/log/adoagent-part1.log
# ===============================================================

set -euo pipefail
exec > >(tee /var/log/adoagent-part1.log) 2>&1

# -------------------------------
# Configuration
# -------------------------------
AGENT_USER="adoagent"      # dedicated user account
NVM_VERSION="v0.39.7"      # nvm installer version

echo "=== [1/9] Update apt and install base build tools ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release software-properties-common \
  git curl tar wget unzip jq \
  python3 python3-venv \
  pkg-config build-essential gcc \
  default-libmysqlclient-dev libssl-dev libffi-dev libpq-dev

# -------------------------------------------------------------------
# 2. Install AWS CLI v2 using snap (official package)
# -------------------------------------------------------------------
echo "=== [2/9] Installing AWS CLI v2 ==="
snap install aws-cli --classic
aws --version

# -------------------------------------------------------------------
# 3. Install Microsoft .NET 8 SDK
# -------------------------------------------------------------------
echo "=== [3/9] Installing Microsoft .NET 8 SDK ==="
UBU_VER="$(lsb_release -rs)"
MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/${UBU_VER}/packages-microsoft-prod.deb"
# Fall back to 20.04 configuration if specific version not available
if ! curl -fsI "$MS_DEB_URL" >/dev/null; then
  MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
fi
curl -fsSL "$MS_DEB_URL" -o /tmp/packages-microsoft-prod.deb
dpkg -i --force-confdef --force-confold /tmp/packages-microsoft-prod.deb
apt-get update -y
apt-get install -y dotnet-sdk-8.0
dotnet --list-sdks

# -------------------------------------------------------------------
# 4. Install Terraform (latest stable from HashiCorp)
# -------------------------------------------------------------------
echo "=== [4/9] Installing Terraform ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform
terraform -version

# -------------------------------------------------------------------
# 5. Create adoagent user (if not already present)
# -------------------------------------------------------------------
echo "=== [5/9] Creating adoagent user account ==="
if ! id -u "${AGENT_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${AGENT_USER}"
  usermod -aG sudo "${AGENT_USER}"
fi

# -------------------------------------------------------------------
# 6. Install nvm + Node.js 20 LTS for adoagent user
# -------------------------------------------------------------------
echo "=== [6/9] Installing nvm and Node.js 20 LTS for ${AGENT_USER} ==="
sudo -iu "${AGENT_USER}" bash <<EOSU
set -euo pipefail
export NVM_DIR="\$HOME/.nvm"
mkdir -p "\$NVM_DIR"

# Download and install nvm into adoagent’s home directory
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

# Load nvm in current shell
. "\$NVM_DIR/nvm.sh"

# Install Node.js 20 LTS and set as default
nvm install 20
nvm alias default 20

# Append nvm auto-load to bashrc for future logins
echo 'export NVM_DIR="\$HOME/.nvm"' >> "\$HOME/.bashrc"
echo '[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"' >> "\$HOME/.bashrc"

# Show installed versions
node -v
npm -v
EOSU

# -------------------------------------------------------------------
# 7. Install CDK for Terraform (cdktf-cli) under adoagent
# -------------------------------------------------------------------
echo "=== [7/9] Installing CDK for Terraform (cdktf-cli) ==="
sudo -iu "${AGENT_USER}" bash <<'EOSU'
set -euo pipefail
. "$HOME/.nvm/nvm.sh"
npm install -g cdktf-cli
cdktf --version
EOSU

# -------------------------------------------------------------------
# 8. Clone the awsIdentityTools repository
# -------------------------------------------------------------------
echo "=== [8/9] Cloning awsIdentityTools repository ==="
sudo -iu "${AGENT_USER}" bash <<'EOSU'
set -euo pipefail
REPO_DIR="$HOME/awsIdentityTools"
if [ -d "$REPO_DIR" ]; then
  echo "Repository already exists at $REPO_DIR"
else
  git clone https://github.com/fahadzainjawaid/awsIdentityTools "$REPO_DIR"
fi
EOSU

# -------------------------------------------------------------------
# 9. Verify installations
# -------------------------------------------------------------------
echo "=== [9/9] Verifying installations ==="
echo
echo "Installed tool versions:"
echo "-------------------------"
echo "NODE:       $(sudo -iu ${AGENT_USER} bash -c '. $HOME/.nvm/nvm.sh && node -v')"
echo "NPM:        $(sudo -iu ${AGENT_USER} bash -c '. $HOME/.nvm/nvm.sh && npm -v')"
echo "CDKTF:      $(sudo -iu ${AGENT_USER} bash -c '. $HOME/.nvm/nvm.sh && cdktf --version')"
echo "PYTHON:     $(python3 --version)"
echo "AWS CLI:    $(aws --version)"
echo "DOTNET:     $(dotnet --list-sdks)"
echo "TERRAFORM:  $(terraform -version | head -n 1)"
echo
echo "✅  Part 1 completed successfully — all tools installed for adoagent."
echo "Next step: proceed to Part 2 (download and register the Azure DevOps agent)."
