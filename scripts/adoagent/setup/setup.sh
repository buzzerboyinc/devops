#!/usr/bin/env bash
# ============================================================
# Install Azure DevOps Agent Binaries (from AWS Secrets Manager)
#
# Reads the following keys from the secret identified by $ADO_SECRET_NAME:
#   - pat: Personal Access Token for Azure DevOps
#   - ado_agent_url: Full URL to the agent tarball (e.g.
#       https://vstsagentpackage.azureedge.net/agent/3.240.1/vsts-agent-linux-x64-3.240.1.tar.gz)
#
# Environment variables required:
#   ADO_SECRET_NAME   = AWS Secrets Manager secret name
#   AWS_REGION        = region for the secret
#   AGENT_USER        = user to install agent under (default: adoagent)
#
# Example:
#   export ADO_SECRET_NAME="aws-buzzerboy-pipeline-agent"
#   export AWS_REGION="ca-central-1"
#   sudo bash install-adoagent.sh
# ============================================================

set -euo pipefail
LOGFILE="/var/log/install-adoagent.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Azure DevOps Agent Installer (Secrets-based) ==="

# -----------------------------
# Config & validation
# -----------------------------
AGENT_USER="${AGENT_USER:-adoagent}"
AWS_REGION="${AWS_REGION:-ca-central-1}"

if [ -z "${ADO_SECRET_NAME:-}" ]; then
  echo "❌ ERROR: Missing required environment variable ADO_SECRET_NAME"
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "❌ ERROR: AWS CLI not found. Please install AWS CLI v2 first."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ ERROR: jq not found. Please install jq first."
  exit 1
fi

# -----------------------------
# Fetch secret JSON
# -----------------------------
echo "=== [1/4] Fetching secret $ADO_SECRET_NAME from AWS Secrets Manager ==="
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$ADO_SECRET_NAME" \
  --query 'SecretString' \
  --output text)

# Extract fields
PAT=$(echo "$SECRET_JSON" | jq -r '.pat')
AGENT_URL=$(echo "$SECRET_JSON" | jq -r '.ado_agent_url')

# Validate
if [ -z "$PAT" ] || [ "$PAT" = "null" ]; then
  echo "❌ ERROR: Secret missing 'pat' field."
  exit 1
fi
if [ -z "$AGENT_URL" ] || [ "$AGENT_URL" = "null" ]; then
  echo "❌ ERROR: Secret missing 'ado_agent_url' field."
  exit 1
fi
echo "✅ Secret retrieved successfully (PAT + Agent URL)"

# -----------------------------
# Setup directories
# -----------------------------
AGENT_ROOT="/home/${AGENT_USER}/azdo"
AGENT_DIR="${AGENT_ROOT}/agent"
sudo mkdir -p "$AGENT_DIR"
sudo chown -R "${AGENT_USER}:${AGENT_USER}" "$AGENT_ROOT"

# -----------------------------
# Download and extract agent
# -----------------------------
echo "=== [2/4] Downloading Azure DevOps agent package ==="
AGENT_TGZ="${AGENT_URL##*/}"  # extract filename
sudo -iu "$AGENT_USER" bash <<EOSU
set -euo pipefail
cd "$AGENT_DIR"
echo "Downloading agent from: ${AGENT_URL}"
curl -fSL "${AGENT_URL}" -o "${AGENT_DIR}/${AGENT_TGZ}"
echo "Extracting..."
tar -xzf "${AGENT_DIR}/${AGENT_TGZ}" -C "${AGENT_DIR}"
rm -f "${AGENT_DIR}/${AGENT_TGZ}"
EOSU

# -----------------------------
# Install runtime dependencies
# -----------------------------
echo "=== [3/4] Installing agent dependencies ==="
sudo -iu "$AGENT_USER" bash -c "${AGENT_DIR}/bin/installdependencies.sh || true"

# -----------------------------
# Verification
# -----------------------------
echo "=== [4/4] Verifying installation ==="
sudo -iu "$AGENT_USER" bash <<EOSU
set -e
ls -1 "${AGENT_DIR}"
echo
echo "✅ Azure DevOps agent binaries installed at ${AGENT_DIR}"
EOSU

# Optional: mask PAT in environment for downstream scripts
export ADO_AGENT_PAT_RETRIEVED="true"
echo "✅ PAT and agent URL loaded into environment for adoagent-setup.sh"
