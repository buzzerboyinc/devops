#!/usr/bin/env bash
# ===============================================================
#  Azure DevOps Agent – Environment Bootstrap (Part 1)
#  Target OS: Ubuntu 22.04 / 24.04 (EC2 or any x86_64 Linux)
#
#  This script installs the complete developer toolchain required
#  for building and running an Azure DevOps self-hosted agent.
#
#  It performs the following tasks:
#    1. Installs system packages and build libraries
#    2. Installs Python 3 + venv
#    3. Installs AWS CLI v2 (official bundle)
#    4. Installs Microsoft .NET 8 SDK
#    5. Installs Terraform (from HashiCorp repo)
#    6. Creates a dedicated "adoagent" user
#    7. Installs Node.js 20 LTS via nvm for adoagent
#    8. Installs the CDK for Terraform (cdktf-cli)
#    9. Clones the awsIdentityTools GitHub repository
#
#  Usage:
#    sudo bash adoagent-part1.sh
#
#  Log output is written to: /var/log/adoagent-part1.log
# ===============================================================

set -euo pipefail
exec > >(tee /var/log/adoagent-part1.log) 2>&1

# -------------------------------
# Configuration
# -------------------------------
AGENT_USER="adoagent"             # dedicated user account
NVM_VERSION="v0.39.7"             # nvm installer version

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
# 2. Install AWS CLI v2 (official snap package)
# -------------------------------------------------------------------
sudo snap install aws-cli --classic




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
dpkg -i /tmp/packages-microsoft-prod.deb
apt-get update -y
apt-get install -y dotnet-sdk-8.0
dotnet --list-sdks



# -------------------------------------------------------------------
# 4. Install Terraform (latest stable from HashiCorp)
# -------------------------------------------------------------------
echo "=== [4/9] Installing Terraform ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform
terraform -version






# -------------------------------------------------------------------
# 6. Install Node.js 20 LTS via nvm (for adoagent user)
# -------------------------------------------------------------------
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion