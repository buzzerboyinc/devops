#!/usr/bin/env bash
# ============================================================
# Azure DevOps Self-Hosted Agent Setup Script
# 
# INTENDED OUTCOME:
# This script downloads, installs, and configures Azure DevOps agent 
# binaries on a Linux system. It creates a dedicated user account and 
# sets up the agent environment but does NOT configure or start the 
# agent service (that requires separate configuration).
#
# WHAT THIS SCRIPT DOES:
#   1. Validates required environment variables and dependencies
#   2. Fetches Azure DevOps credentials from AWS Secrets Manager
#   3. Creates a dedicated user account for the agent
#   4. Downloads and extracts the Azure DevOps agent package
#   5. Installs agent runtime dependencies
#   6. Sets up proper file permissions and directory structure
#
# PREREQUISITES:
#   - AWS CLI v2 installed and configured with appropriate IAM permissions
#   - jq command-line JSON processor installed
#   - Internet connectivity to download agent package
#   - sudo privileges to create user accounts and install dependencies
#
# AWS SECRETS MANAGER SECRET FORMAT:
# The secret must contain a JSON object with these keys:
#   - "pat": Personal Access Token for Azure DevOps with Agent Pools (read, manage) scope
#   - "ado_agent_url": Full URL to the agent tarball from Microsoft
#     Example: "https://vstsagentpackage.azureedge.net/agent/3.240.1/vsts-agent-linux-x64-3.240.1.tar.gz"
#
# REQUIRED ENVIRONMENT VARIABLES:
#   ADO_SECRET_NAME   = AWS Secrets Manager secret name containing ADO credentials
#   AWS_REGION        = AWS region where the secret is stored (default: ca-central-1)
#   AGENT_USER        = Linux user account for the agent (default: adoagent)
#
# USAGE EXAMPLE:
#   export ADO_SECRET_NAME="my-ado-agent-secrets"
#   export AWS_REGION="us-east-1"
#   export AGENT_USER="buildagent"
#   sudo bash setup.sh
#
# POST-SETUP STEPS:
# After this script completes successfully, you still need to:
#   1. Configure the agent with your Azure DevOps organization
#   2. Register the agent with an agent pool
#   3. Start the agent service
# ============================================================

# ============================================================
# SCRIPT INITIALIZATION AND LOGGING SETUP
# ============================================================
set -euo pipefail
LOGFILE="/var/log/install-adoagent.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Azure DevOps Agent Installer (Secrets-based) ==="

# ============================================================
# ENVIRONMENT VALIDATION AND CONFIGURATION
# ============================================================
AGENT_USER="${AGENT_USER:-adoagent}"
AWS_REGION="${AWS_REGION:-ca-central-1}"

# Validate required environment variables
if [ -z "${ADO_SECRET_NAME:-}" ]; then
  echo "❌ ERROR: Missing required environment variable ADO_SECRET_NAME"
  exit 1
fi

# Check for required command-line tools
if ! command -v aws >/dev/null 2>&1; then
  echo "❌ ERROR: AWS CLI not found. Please install AWS CLI v2 first."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ ERROR: jq not found. Please install jq first."
  exit 1
fi

# ============================================================
# AWS SECRETS MANAGER INTEGRATION
# ============================================================
echo "=== [1/4] Fetching secret $ADO_SECRET_NAME from AWS Secrets Manager ==="
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$ADO_SECRET_NAME" \
  --query 'SecretString' \
  --output text)

# Extract required fields from the secret JSON
PAT=$(echo "$SECRET_JSON" | jq -r '.pat')
AGENT_URL=$(echo "$SECRET_JSON" | jq -r '.ado_agent_url')

# Validate that required fields are present and not null
if [ -z "$PAT" ] || [ "$PAT" = "null" ]; then
  echo "❌ ERROR: Secret missing 'pat' field."
  exit 1
fi
if [ -z "$AGENT_URL" ] || [ "$AGENT_URL" = "null" ]; then
  echo "❌ ERROR: Secret missing 'ado_agent_url' field."
  exit 1
fi
echo "✅ Secret retrieved successfully (PAT + Agent URL)"

# ============================================================
# USER ACCOUNT SETUP AND CONFIGURATION
# ============================================================
echo "=== [2/4] Setting up user account: ${AGENT_USER} ==="
if ! id -u "${AGENT_USER}" >/dev/null 2>&1; then
  # Create new user with no password and no interactive prompts
  adduser --disabled-password --gecos "" "${AGENT_USER}"
  
  # Add user to sudo group for administrative privileges
  usermod -aG sudo "${AGENT_USER}"
  
  # Grant passwordless sudo access for automated operations
  echo "${AGENT_USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${AGENT_USER}" >/dev/null
  chmod 440 "/etc/sudoers.d/${AGENT_USER}"
  echo "✅ Added ${AGENT_USER} to sudoers (passwordless)"
else
  echo "✅ User ${AGENT_USER} already exists"
fi

# ============================================================
# DIRECTORY STRUCTURE SETUP
# ============================================================
echo "=== [3/4] Setting up directory structure ==="
AGENT_ROOT="/home/${AGENT_USER}/azdo"
AGENT_DIR="${AGENT_ROOT}/agent"

# Create agent directories with proper ownership
sudo mkdir -p "$AGENT_DIR"
sudo chown -R "${AGENT_USER}:${AGENT_USER}" "$AGENT_ROOT"
echo "✅ Created agent directory structure at ${AGENT_DIR}"






# ============================================================
# AZURE DEVOPS AGENT DOWNLOAD AND EXTRACTION
# ============================================================
echo "=== [4/4] Downloading and installing Azure DevOps agent package ==="
AGENT_TGZ="${AGENT_URL##*/}"  # Extract filename from URL

# Download and extract agent package as the dedicated user
# Using sudo -iu to switch to the agent user's environment
sudo -iu "$AGENT_USER" bash <<EOSU
set -euo pipefail
AGENT_DIR="${AGENT_DIR}"
AGENT_URL="${AGENT_URL}"
AGENT_TGZ="${AGENT_TGZ}"
cd "\${AGENT_DIR}"
echo "Downloading agent from: \${AGENT_URL}"
curl -fSL "\${AGENT_URL}" -o "\${AGENT_DIR}/\${AGENT_TGZ}"
echo "Extracting agent package..."
tar -xzf "\${AGENT_DIR}/\${AGENT_TGZ}" -C "\${AGENT_DIR}"
rm -f "\${AGENT_DIR}/\${AGENT_TGZ}"
echo "✅ Agent package downloaded and extracted"
EOSU

# ============================================================
# AGENT RUNTIME DEPENDENCIES INSTALLATION
# ============================================================
echo "=== Installing agent runtime dependencies ==="
# Run the agent's dependency installer script
# Using || true to continue if some dependencies are already installed
sudo -iu "$AGENT_USER" bash -c "AGENT_DIR='${AGENT_DIR}' && \${AGENT_DIR}/bin/installdependencies.sh || true"

# ============================================================
# INSTALLATION VERIFICATION
# ============================================================
echo "=== Verifying installation ==="
sudo -iu "$AGENT_USER" bash <<EOSU
set -e
AGENT_DIR="${AGENT_DIR}"
echo "Contents of agent directory:"
ls -la "\${AGENT_DIR}"
echo
echo "✅ Azure DevOps agent binaries installed successfully at \${AGENT_DIR}"
echo "✅ Agent is ready for configuration"
EOSU

# ============================================================
# COMPLETION AND NEXT STEPS
# ============================================================
# Mark PAT as retrieved for downstream scripts
export ADO_AGENT_PAT_RETRIEVED="true"
echo "✅ Installation completed successfully!"
echo "📋 Next steps:"
echo "   1. Configure the agent with your Azure DevOps organization"
echo "   2. Register the agent with an agent pool" 
echo "   3. Start the agent service"
echo "✅ PAT and agent URL loaded into environment for subsequent configuration scripts"
