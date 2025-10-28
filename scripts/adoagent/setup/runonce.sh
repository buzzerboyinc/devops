#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
AZDO_ORG_URL="https://dev.azure.com/$ADO_ORG_NAME"
AZDO_POOL="$ADO_POOL_NAME"
AZDO_AGENT_NAME="$(hostname)"                  # resource name = hostname
AWS_REGION="ca-central-1"
SECRET_NAME="$ADO_POOL_NAME"    # Secrets Manager secret with PAT
AGENT_VERSION="3.240.1"                       # update when you want newer agent

# Install directory layout
AGENT_USER="adoagent"
AGENT_HOME="/home/${AGENT_USER}"
AGENT_ROOT="${AGENT_HOME}/azdo"
AGENT_DIR="${AGENT_ROOT}/agent"
SETUP_BIN="/usr/local/bin/adoagent-setup.sh"
# =========================

echo "[1/9] Create user & folders"
if ! id -u "${AGENT_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${AGENT_USER}"
  usermod -aG sudo "${AGENT_USER}"
fi
mkdir -p "${AGENT_DIR}"
chown -R "${AGENT_USER}:${AGENT_USER}" "${AGENT_ROOT}"

echo "[2/9] Apt base & build deps"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  ca-certificates apt-transport-https gnupg lsb-release \
  git curl tar wget jq awscli \
  python3 python3-venv python3-distutils \
  pkg-config default-libmysqlclient-dev build-essential libssl-dev libffi-dev libpq-dev gcc

# Python version note (3.9+): Ubuntu 22.04 ships 3.10; 20.04 is 3.8 (still fine if you only need >=3.9; upgrade if required)

echo "[3/9] Install .NET 8 SDK (auto-detect Ubuntu version)"
UBU_VER="$(lsb_release -rs)"
MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/${UBU_VER}/packages-microsoft-prod.deb"
# If URL for this Ubuntu isn't available, fall back to 20.04 as requested
if ! curl -fsI "$MS_DEB_URL" >/dev/null; then
  MS_DEB_URL="https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
fi
cd /tmp
curl -fsSL "$MS_DEB_URL" -o packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0

echo "[4/9] Install Terraform from HashiCorp APT"
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

echo "[5/9] Install nvm + Node 20 LTS for ${AGENT_USER}"
# Use login shell for user so nvm is available
sudo -iu "${AGENT_USER}" bash <<'EOSU'
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
# Load nvm in current shell
. "$HOME/.nvm/nvm.sh"
nvm install 20
nvm alias default 20
node -v
npm -v
EOSU

echo "[6/9] Install CDKTF globally for ${AGENT_USER}"
sudo -iu "${AGENT_USER}" bash <<'EOSU'
set -euo pipefail
. "$HOME/.nvm/nvm.sh"
npm i -g cdktf-cli
cdktf --version
EOSU

echo "[7/9] Clone awsIdentityTools"
sudo -iu "${AGENT_USER}" bash <<EOSU
set -euo pipefail
if [ ! -d "${AGENT_HOME}/awsIdentityTools" ]; then
  git clone https://github.com/fahadzainjawaid/awsIdentityTools "${AGENT_HOME}/awsIdentityTools"
fi
EOSU

echo "[8/9] Install Azure DevOps agent files"
sudo -iu "${AGENT_USER}" bash <<EOSU
set -euo pipefail
cd "${AGENT_DIR}"
# Download agent tarball if not present or version mismatch
NEED_DL=1
if [ -f "./.agent" ]; then
  NEED_DL=0
else
  if [ -f "vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz" ]; then
    NEED_DL=0
  fi
fi
if [ "\$NEED_DL" -eq 1 ]; then
  rm -rf ./* || true
  curl -fSLO "https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"
  tar -xzf "vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"
fi
./bin/installdependencies.sh || true
EOSU

echo "[9/9] Install setup/refresh script + systemd units"
cat > "${SETUP_BIN}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

AZDO_ORG_URL="${AZDO_ORG_URL}"
AZDO_POOL="${AZDO_POOL}"
AZDO_AGENT_NAME="${AZDO_AGENT_NAME}"
AWS_REGION="${AWS_REGION}"
SECRET_NAME="${SECRET_NAME}"
AGENT_DIR="${AGENT_DIR}"
AGENT_USER="${AGENT_USER}"
AGENT_HOME="${AGENT_HOME}"
AGENT_VERSION="${AGENT_VERSION}"

# Fetch PAT (plain string or JSON {"pat":"..."} supported)
PAT_RAW="\$(aws --region "\$AWS_REGION" secretsmanager get-secret-value --secret-id "\$SECRET_NAME" --query 'SecretString' --output text)"
if [[ "\$PAT_RAW" == \{* ]]; then
  # JSON secret with key "pat"
  if command -v jq >/dev/null 2>&1; then
    AZDO_PAT="\$(printf '%s' "\$PAT_RAW" | jq -r '.pat')"
  else
    echo "jq is required to parse PAT JSON" >&2
    exit 1
  fi
else
  AZDO_PAT="\$PAT_RAW"
fi

cd "\$AGENT_DIR"

# Stop & uninstall old service if present
sudo ./svc.sh stop || true
sudo ./svc.sh uninstall || true

# If agent already registered, remove cleanly
./config.sh remove --unattended --auth pat --token "\$AZDO_PAT" || true

# (Re)configure unattended
./config.sh --unattended --replace --acceptTeeEula \
  --url "\$AZDO_ORG_URL" \
  --auth pat \
  --token "\$AZDO_PAT" \
  --pool "\$AZDO_POOL" \
  --agent "\$AZDO_AGENT_NAME" \
  --work _work

# Install service under AGENT_USER and start
sudo ./svc.sh install "\$AGENT_USER"
sudo systemctl enable "vsts.agent.*"
sudo ./svc.sh start

# Add robust restart policy
sudo systemctl edit vsts.agent.* <<'EOS'
[Service]
Restart=always
RestartSec=5s
EOS

sudo systemctl daemon-reload
sudo systemctl restart vsts.agent.*
EOF

chmod +x "${SETUP_BIN}"

# One-shot systemd unit to (re)configure at every boot (safe to re-run)
cat > /etc/systemd/system/adoagent-setup.service <<EOF
[Unit]
Description=Prepare/Refresh Azure DevOps Agent before start
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${AGENT_USER}
ExecStart=${SETUP_BIN}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable adoagent-setup.service
systemctl start adoagent-setup.service

echo "Bootstrap complete."
echo "Check status:"
echo "  systemctl status adoagent-setup.service"
echo "  systemctl status vsts.agent.*"
