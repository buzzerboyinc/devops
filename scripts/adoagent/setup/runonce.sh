#!/usr/bin/env bash
# ===============================================================
#  Azure DevOps Self-Hosted Agent Setup (Public-safe version)
#
#  This script securely installs and registers an Azure DevOps
#  self-hosted agent. It expects AWS Secrets Manager to store
#  the PAT token in JSON format: {"pat":"<token>"}.
#
#  SAFE FOR PUBLIC DISTRIBUTION:
#   - No secrets or org names are hardcoded.
#   - Requires explicit environment variables for sensitive values.
#   - Includes validation and logging.
#
#  USAGE:
#    curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/adoagent-setup.sh | bash
#
#  REQUIRED ENVIRONMENT VARIABLES:
#    ADO_ORG_NAME        Azure DevOps org name (e.g. "buzzerboyinc")
#    ADO_POOL_NAME       Azure DevOps agent pool name
#    AWS_REGION          AWS region for Secrets Manager
#    ADO_SECRET_NAME     AWS Secrets Manager secret with PAT JSON
#    AGENT_USER          (optional) default: adoagent
#
#  OPTIONAL:
#    AGENT_DIR           Path to agent (default: /home/adoagent/azdo/agent)
#
# ===============================================================

set -euo pipefail
LOGFILE="/var/log/adoagent-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Azure DevOps Agent Setup Started ==="

# -----------------------------
# Validate required environment variables
# -----------------------------
REQUIRED_VARS=(ADO_ORG_NAME ADO_POOL_NAME AWS_REGION ADO_SECRET_NAME)
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR:-}" ]; then
    echo "❌ ERROR: Missing required environment variable: $VAR"
    echo "Please export it before running this script."
    echo "Example:"
    echo "  export ADO_ORG_NAME=\"myorg\""
    echo "  export ADO_POOL_NAME=\"my-pool\""
    echo "  export AWS_REGION=\"ca-central-1\""
    echo "  export ADO_SECRET_NAME=\"my-secret\""
    exit 1
  fi
done

# -----------------------------
# Defaults & Derived Values
# -----------------------------
AGENT_USER="${AGENT_USER:-adoagent}"
AGENT_DIR="${AGENT_DIR:-/home/${AGENT_USER}/azdo/agent}"
ADO_URL="https://dev.azure.com/${ADO_ORG_NAME}"
AGENT_NAME="$(hostname)"

# -----------------------------
# 1. Fetch PAT from AWS Secrets Manager
# -----------------------------
echo "=== [1/6] Fetching PAT from AWS Secrets Manager (${AWS_REGION}) ==="
if ! command -v aws >/dev/null 2>&1; then
  echo "❌ ERROR: AWS CLI not installed. Please install awscli v2 first."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ ERROR: jq not installed. Please install jq first."
  exit 1
fi

TOKEN=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$ADO_SECRET_NAME" \
  --query 'SecretString' \
  --output text | jq -r '.pat' || true)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "❌ ERROR: Could not retrieve a valid PAT from AWS Secrets Manager ($ADO_SECRET_NAME)"
  exit 1
fi
echo "✅ PAT retrieved successfully"

# -----------------------------
# 2. Stop and remove existing agent
# -----------------------------
echo "=== [2/6] Cleaning up old agent if exists ==="
sudo -iu "$AGENT_USER" bash <<EOSU
set -e
cd "$AGENT_DIR" 2>/dev/null || exit 0
if [ -f "./svc.sh" ]; then
  sudo ./svc.sh stop || true
  sudo ./svc.sh uninstall || true
fi
EOSU

# -----------------------------
# 3. Configure new Azure DevOps agent
# -----------------------------
echo "=== [3/6] Registering agent with Azure DevOps org: $ADO_ORG_NAME ==="
sudo -iu "$AGENT_USER" bash <<EOSU
set -e
mkdir -p "$AGENT_DIR"
cd "$AGENT_DIR"
if [ ! -f "./config.sh" ]; then
  echo "❌ ERROR: Azure DevOps agent binaries not found in $AGENT_DIR"
  echo "Please install the agent before running this setup script."
  exit 1
fi
./config.sh --unattended \
  --url "$ADO_URL" \
  --auth pat \
  --token "$TOKEN" \
  --pool "$ADO_POOL_NAME" \
  --agent "$AGENT_NAME" \
  --replace \
  --acceptTeeEula \
  --runasservice \
  --work _work
EOSU

# -----------------------------
# 4. Install and start the service
# -----------------------------
echo "=== [4/6] Starting agent service ==="
sudo -iu "$AGENT_USER" bash <<EOSU
cd "$AGENT_DIR"
sudo ./svc.sh install adoagent
sudo ./svc.sh start
EOSU

# -----------------------------
# 5. Enable restart on failure
# -----------------------------
echo "=== [5/6] Enabling auto-restart on failure ==="
SERVICE_FILE=$(systemctl list-units --type=service | grep vsts.agent | awk '{print $1}' | head -n1)
if [ -n "$SERVICE_FILE" ]; then
  sudo systemctl edit "$SERVICE_FILE" <<'EOF'
[Service]
Restart=always
RestartSec=5s
EOF
  sudo systemctl daemon-reload
  sudo
