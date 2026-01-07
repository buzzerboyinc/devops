#!/usr/bin/env bash
# ===============================================================
# AI Development Tools Installation Script (macOS)
#
# This script installs AI-powered development tools and utilities
# as global NPM packages and Homebrew packages.
#
# Installation Components:
#   1. Visual Studio Code - Latest stable version (Homebrew cask)
#   2. Chromium Browser - Required for Mermaid CLI rendering (cask)
#   3. MkDocs - Documentation site generator
#   4. Mermaid CLI - Diagram generation from text
#   5. OpenAI Codex - AI code completion and generation
#   6. Anthropic Claude Code - AI coding assistant
#   7. GitHub Copilot CLI - AI pair programming from command line
#   8. ngrok - Secure tunnels to localhost
#   9. cloudflared - Cloudflare Tunnel client
#  10. Markdown to PDF Converter (md-to-pdf)
#
# Prerequisites:
#   - macOS
#   - Homebrew installed
#   - Node.js 16+ and NPM installed
#
# Usage:
#   bash ai-devtools.sh
# ===============================================================

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: This script is intended for macOS only."
  exit 1
fi

# Determine log file location based on permissions
if [ "${EUID}" -eq 0 ]; then
  LOG_FILE="/var/log/ai-devtools-setup.log"
else
  LOG_FILE="./ai-devtools-setup.log"
fi

exec > >(tee "$LOG_FILE") 2>&1

echo "Starting AI Development Tools Installation (macOS)..."
echo "Log File: $LOG_FILE"
echo "====================================================="
echo ""

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is not installed."
  echo "Install Homebrew from https://brew.sh and rerun this script."
  exit 1
fi

# Check if Node.js is installed
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is not installed."
  echo "Please install Node.js first (run node_python.sh) or install via Homebrew."
  exit 1
fi

# Check if NPM is installed
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: NPM is not installed. Please reinstall Node.js."
  exit 1
fi

echo "Node.js detected: $(node -v)"
echo "NPM detected: v$(npm -v)"
echo ""

# ===============================================================
# 1. VISUAL STUDIO CODE - LATEST STABLE
# ===============================================================
echo "[1/10] Installing Visual Studio Code..."
if [ -d "/Applications/Visual Studio Code.app" ] || brew list --cask visual-studio-code >/dev/null 2>&1; then
  echo "  Visual Studio Code already installed."
else
  brew install --cask visual-studio-code
  echo "  Visual Studio Code installed."
fi
echo ""

# ===============================================================
# 2. CHROMIUM BROWSER - REQUIRED FOR MERMAID CLI
# ===============================================================
echo "[2/10] Installing Chromium Browser..."
if command -v chromium >/dev/null 2>&1 || brew list --cask chromium >/dev/null 2>&1; then
  echo "  Chromium already installed."
else
  brew install --cask chromium
  echo "  Chromium installed."
fi
echo ""

# ===============================================================
# 3. MKDOCS - DOCUMENTATION SITE GENERATOR
# ===============================================================
echo "[3/10] Installing MkDocs..."
if command -v mkdocs >/dev/null 2>&1; then
  echo "  MkDocs already installed: $(mkdocs --version 2>/dev/null | head -n 1 || echo installed)"
else
  brew install mkdocs
  echo "  MkDocs installed: $(mkdocs --version 2>/dev/null | head -n 1 || echo installed)"
fi
echo ""

# ===============================================================
# 4. MERMAID CLI - DIAGRAM GENERATION FROM TEXT
# ===============================================================
echo "[4/10] Installing Mermaid CLI..."
if command -v mmdc >/dev/null 2>&1; then
  echo "  Mermaid CLI already installed: $(mmdc --version 2>/dev/null || echo installed)"
else
  npm install -g @mermaid-js/mermaid-cli
  echo "  Mermaid CLI installed: $(mmdc --version 2>/dev/null || echo installed)"
fi
echo ""

# ===============================================================
# 5. OPENAI CODEX
# ===============================================================
echo "[5/10] Installing OpenAI Codex..."
if command -v codex >/dev/null 2>&1; then
  echo "  OpenAI Codex already installed: $(codex --version 2>/dev/null || echo installed)"
else
  npm install -g @openai/codex
  echo "  OpenAI Codex installed: $(codex --version 2>/dev/null || echo installed)"
fi
echo ""

# ===============================================================
# 6. ANTHROPIC CLAUDE CODE
# ===============================================================
echo "[6/10] Installing Anthropic Claude Code..."
if command -v claude >/dev/null 2>&1; then
  echo "  Claude Code already installed: $(claude --version 2>/dev/null || echo installed)"
else
  npm install -g @anthropic-ai/claude-code
  echo "  Claude Code installed: $(claude --version 2>/dev/null || echo installed)"
fi
echo ""

# ===============================================================
# 7. GITHUB COPILOT CLI
# ===============================================================
echo "[7/10] Installing GitHub Copilot CLI..."
if command -v copilot >/dev/null 2>&1 || command -v github-copilot-cli >/dev/null 2>&1; then
  if command -v copilot >/dev/null 2>&1; then
    echo "  GitHub Copilot CLI already installed: $(copilot --version 2>/dev/null || echo installed)"
  else
    echo "  GitHub Copilot CLI already installed: $(github-copilot-cli --version 2>/dev/null || echo installed)"
  fi
else
  npm install -g @githubnext/github-copilot-cli
  if command -v copilot >/dev/null 2>&1; then
    echo "  GitHub Copilot CLI installed: $(copilot --version 2>/dev/null || echo installed)"
  else
    echo "  GitHub Copilot CLI installed."
  fi
fi
echo ""

# ===============================================================
# 8. NGROK - SECURE TUNNELS TO LOCALHOST
# ===============================================================
echo "[8/10] Installing ngrok..."
if command -v ngrok >/dev/null 2>&1; then
  echo "  ngrok already installed: $(ngrok version 2>/dev/null | head -n 1 || echo installed)"
else
  brew install ngrok/ngrok/ngrok
  echo "  ngrok installed: $(ngrok version 2>/dev/null | head -n 1 || echo installed)"
fi
echo ""

# ===============================================================
# 9. CLOUDFLARED - CLOUDFLARE TUNNEL CLIENT
# ===============================================================
echo "[9/10] Installing cloudflared..."
if command -v cloudflared >/dev/null 2>&1; then
  echo "  cloudflared already installed: $(cloudflared --version 2>/dev/null | head -n 1 || echo installed)"
else
  brew install cloudflared
  echo "  cloudflared installed: $(cloudflared --version 2>/dev/null | head -n 1 || echo installed)"
fi
echo ""

# ===============================================================
# 10. MARKDOWN TO PDF CONVERTER (MD-TO-PDF)
# ===============================================================
echo "[10/10] Installing md-to-pdf..."
if command -v md-to-pdf >/dev/null 2>&1; then
  echo "  md-to-pdf already installed: $(md-to-pdf --version 2>/dev/null || echo installed)"
else
  npm install -g md-to-pdf
  echo "  md-to-pdf installed: $(md-to-pdf --version 2>/dev/null || echo installed)"
fi
echo ""

echo "Installation complete."
echo "Log File: $LOG_FILE"

exit 0
