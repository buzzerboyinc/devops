#!/usr/bin/env bash
set -euo pipefail

echo "=== Buzzerboy System Toolchain: System & build prerequisites ==="
apt-get update
apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release software-properties-common \
  git curl tar wget unzip jq awscli \
  python3 python3-venv python3-distutils \
  pkg-config default-libmysqlclient-dev build-essential libssl-dev libffi-dev libpq-dev gcc

echo "=== Step 1: Install .NET 8 SDK ==="

# ---- Fix for distutils missing on newer Ubuntu ----
echo "=== Installing python3-distutils manually if missing ==="
if ! python3 -c "import distutils" >/dev/null 2>&1; then
  PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  apt-get install -y "python${PY_VER}-distutils" || true
  if ! python3 -c "import distutils" >/dev/null 2>&1; then
    echo "Falling back to pip-based installation of distutils"
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3
    python3 -m pip install setuptools
  fi
fi

# ---- AWS CLI v2 install (official bundle, replaces apt) ----
echo "=== Installing AWS CLI v2 ==="
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
aws --version

echo "=== Step 2: Install .NET 8 SDK ==="
UBU_VER="$(lsb_release -rs)"
MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/${UBU_VER}/packages-microsoft-prod.deb"
if ! curl -fsI "$MS_DEB_URL" >/dev/null; then
  # Fallback for non-standard version
  MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
fi
cd /tmp
curl -fsSL "$MS_DEB_URL" -o packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0

echo "=== Step 3: Install Terraform ==="
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

echo "=== Step 4: Create adoagent user (if missing) ==="
if ! id -u adoagent >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" adoagent
  usermod -aG sudo adoagent
fi

echo "=== Step 5: Install nvm + Node 20 LTS for adoagent ==="
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

echo "=== Step 6: Install CDKTF globally for adoagent ==="
sudo -iu adoagent bash <<'EOSU'
set -euo pipefail
. "$HOME/.nvm/nvm.sh"
npm i -g cdktf-cli
cdktf --version
EOSU

echo "=== Step 7: Clone awsIdentityTools repo ==="
sudo -iu adoagent bash <<'EOSU'
set -euo pipefail
EOSU

echo "=== Part 1 complete: toolchain verified ==="
