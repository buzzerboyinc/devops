#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /var/log/adoagent-part1.log) 2>&1

echo "=== [1/9] Update apt & install core build deps ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release software-properties-common \
  git curl tar wget unzip jq \
  python3 python3-venv pkg-config build-essential gcc \
  default-libmysqlclient-dev libssl-dev libffi-dev libpq-dev

# ---------------------------------------------------------------------
# Ensure python3-distutils or equivalent
# ---------------------------------------------------------------------
echo "=== [2/9] Ensure python3-distutils present ==="
if ! python3 -c "import distutils" >/dev/null 2>&1; then
  PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  apt-get install -y "python${PY_VER}-distutils" || true
  if ! python3 -c "import distutils" >/dev/null 2>&1; then
    echo "Installing setuptools via pip bootstrap"
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3
    python3 -m pip install setuptools
  fi
fi

# ---------------------------------------------------------------------
# AWS CLI v2
# ---------------------------------------------------------------------
echo "=== [3/9] Install AWS CLI v2 ==="
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q -o awscliv2.zip
sudo ./aws/install --update
aws --version

# ---------------------------------------------------------------------
# .NET 8 SDK
# ---------------------------------------------------------------------
echo "=== [4/9] Install .NET 8 SDK ==="
UBU_VER="$(lsb_release -rs)"
MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/${UBU_VER}/packages-microsoft-prod.deb"
if ! curl -fsI "$MS_DEB_URL" >/dev/null; then
  MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
fi
curl -fsSL "$MS_DEB_URL" -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0
dotnet --list-sdks

# ---------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------
echo "=== [5/9] Install Terraform ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform
terraform -version

# ---------------------------------------------------------------------
# Create adoagent user
# ---------------------------------------------------------------------
echo "=== [6/9] Create adoagent user ==="
if ! id -u adoagent >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" adoagent
  usermod -aG sudo adoagent
fi

# ---------------------------------------------------------------------
# nvm + Node.js 20
# ---------------------------------------------------------------------
echo "=== [7/9] Install nvm & Node.js 20 for adoagent ==="
sudo -iu adoagent bash <<'EOSU'
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
. "$HOME/.nvm/nvm.sh"
nvm install 20
nvm alias default 20
node -v
npm -v
EOSU

# ---------------------------------------------------------------------
# CDKTF CLI
# ---------------------------------------------------------------------
echo "=== [8/9] Install CDKTF CLI ==="
sudo -iu adoagent bash <<'EOSU'
set -euo pipefail
. "$HOME/.nvm/nvm.sh"
npm i -g cdktf-cli
cdktf --version
EOSU

# ---------------------------------------------------------------------
# awsIdentityTools repo
# ---------------------------------------------------------------------
echo "=== [9/9] Clone awsIdentityTools ==="
sudo -iu adoagent bash <<'EOSU'
set -euo pipefail
EOSU

echo "✅  Part 1 complete: all development tools installed."
echo "Verify with:"
echo "  python3 --version"
echo "  aws --version"
echo "  dotnet --list-sdks"
echo "  terraform -version"
echo "  node -v"
echo "  cdktf --version"
