#!/usr/bin/env bash
# ============================================================
# Install Azure DevOps Agent Binaries
# ============================================================

set -euo pipefail
AGENT_USER="adoagent"
AGENT_VERSION="3.240.1"
AGENT_DIR="/home/${AGENT_USER}/azdo/agent"

echo "=== Downloading Azure DevOps agent v${AGENT_VERSION} ==="
sudo -iu "$AGENT_USER" bash <<EOSU
set -e
mkdir -p "${AGENT_DIR}"
cd "${AGENT_DIR}"
curl -fSL "https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz" -o agent.tar.gz
tar -xzf agent.tar.gz
rm -f agent.tar.gz
./bin/installdependencies.sh || true
EOSU

echo "✅ Azure DevOps agent binaries installed in ${AGENT_DIR}"
