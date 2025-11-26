#!/usr/bin/env bash
# ===============================================================
#  AI Development Tools Installation Script
#  Target OS: Ubuntu 22.04 / 24.04 (or any Linux with Node.js)
#
#  This script installs AI-powered development tools and utilities
#  as global NPM packages. Requires Node.js and NPM to be installed.
#
#  Installation Components:
#    1. Visual Studio Code - Latest stable version
#    2. Chromium Browser - Required for Mermaid CLI rendering
#    3. MkDocs - Documentation site generator
#    4. Mermaid CLI - Diagram generation from text
#    5. OpenAI Codex - AI code completion and generation
#    6. Anthropic Claude Code - AI coding assistant
#    7. GitHub Copilot CLI - AI pair programming from command line
#    8. Markdown to PDF Converter (md-to-pdf) - Convert markdown to PDF with image support
#
#  Note: AI packages may require authentication or special access.
#
#  Prerequisites:
#    - Node.js 16+ and NPM installed
#    - Internet connection
#    - Appropriate access/authentication for AI tools
#    - sudo access for VS Code installation
#
#  Usage:
#    sudo bash ai-devtools.sh
#
#  Log file:
#    /var/log/ai-devtools-setup.log (if run with sudo)
#    ./ai-devtools-setup.log (if run as regular user)
# ===============================================================

set -euo pipefail

# Determine log file location based on permissions
if [ "$EUID" -eq 0 ]; then
  LOG_FILE="/var/log/ai-devtools-setup.log"
else
  LOG_FILE="./ai-devtools-setup.log"
fi

# Set up logging to both console and file
exec > >(tee "$LOG_FILE") 2>&1

echo "🤖 Starting AI Development Tools Installation..."
echo "Log File: $LOG_FILE"
echo "================================================"
echo ""

# ===============================================================
# PREREQUISITE CHECKS
# ===============================================================
echo "🔍 Checking Prerequisites..."
echo "----------------------------"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
  echo "❌ ERROR: Node.js is not installed"
  echo ""
  echo "Please install Node.js first:"
  echo "  - Run node_python.sh script, or"
  echo "  - Visit https://nodejs.org for installation instructions"
  exit 1
fi

NODE_VERSION=$(node -v)
echo "  ✓ Node.js detected: $NODE_VERSION"

# Check if NPM is installed
if ! command -v npm &> /dev/null; then
  echo "❌ ERROR: NPM is not installed"
  echo ""
  echo "NPM should be installed with Node.js. Please reinstall Node.js."
  exit 1
fi

NPM_VERSION=$(npm -v)
echo "  ✓ NPM detected: v$NPM_VERSION"

# Load NVM if available (for global installations)
if [ -s "/opt/nvm/nvm.sh" ]; then
  echo "  ✓ Loading NVM environment..."
  export NVM_DIR="/opt/nvm"
  . "$NVM_DIR/nvm.sh"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
  echo "  ✓ Loading NVM environment (user installation)..."
  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
fi

echo "✅ All prerequisites satisfied"
echo ""

# ===============================================================
# 1. VISUAL STUDIO CODE - LATEST STABLE
# ===============================================================
echo "💻 [1/3] Installing Visual Studio Code..."
echo "-----------------------------------------"
echo "  📝 Description: Microsoft's powerful, free code editor"
echo "  🌐 Website: https://code.visualstudio.com"
echo ""

# Check if VS Code is already installed
if command -v code &> /dev/null; then
  VSCODE_VERSION=$(code --version | head -n 1)
  echo "  ℹ️  Visual Studio Code already installed: $VSCODE_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Configuring Microsoft package repository..."
  
  # Check if we have sudo access for system installation
  if [ "$EUID" -ne 0 ]; then
    echo "  ⚠️  Warning: VS Code installation requires sudo privileges"
    echo "  💡 Solution: Please run this script with sudo to install VS Code"
    echo "  → Skipping VS Code installation..."
  else
    # Install dependencies
    echo "  → Step 1/5: Installing dependencies (wget, gpg, apt-transport-https)..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget gpg apt-transport-https > /dev/null 2>&1
    echo "     ✓ Dependencies installed"
    
    # Add Microsoft GPG key
    echo "  → Step 2/5: Adding Microsoft GPG key for package verification..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    rm /tmp/packages.microsoft.gpg
    echo "     ✓ GPG key configured"
    
    # Add VS Code repository
    echo "  → Step 3/5: Adding VS Code repository to apt sources..."
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    echo "     ✓ Repository added"
    
    # Update package index
    echo "  → Step 4/5: Updating package index..."
    apt-get update -y > /dev/null 2>&1
    echo "     ✓ Package index updated"
    
    # Install VS Code
    echo "  → Step 5/5: Installing Visual Studio Code package..."
    apt-get install -y code
    
    # Verify installation
    if command -v code &> /dev/null; then
      VSCODE_VERSION=$(code --version | head -n 1)
      echo ""
      echo "  ✅ Visual Studio Code successfully installed!"
      echo "     Version: $VSCODE_VERSION"
      echo "     Command: code"
      echo "     Launch: Run 'code' or 'code .' in terminal"
    else
      echo ""
      echo "  ❌ Error: VS Code installation failed"
      echo "     Check package manager logs for details"
    fi
  fi
fi
echo ""

# ===============================================================
# 2. CHROMIUM BROWSER - REQUIRED FOR MERMAID CLI
# ===============================================================
echo "🌐 [2/8] Installing Chromium Browser..."
echo "----------------------------------------"
echo "  📝 Description: Headless browser required for Mermaid CLI diagram rendering"
echo "  🌐 Website: https://www.chromium.org"
echo ""

# Check if Chromium is already installed
if command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
  CHROMIUM_VERSION=$(chromium-browser --version 2>/dev/null || chromium --version 2>/dev/null || echo "Chromium")
  echo "  ℹ️  Chromium already installed: $CHROMIUM_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  
  # Check if we have sudo access for system installation
  if [ "$EUID" -ne 0 ]; then
    echo "  ⚠️  Warning: Chromium installation requires sudo privileges"
    echo "  💡 Solution: Please run this script with sudo to install Chromium"
    echo "  → Skipping Chromium installation..."
  else
    echo "  → Installing Chromium and dependencies from apt repository..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y chromium-browser \
      ca-certificates \
      fonts-liberation \
      libasound2 \
      libatk-bridge2.0-0 \
      libatk1.0-0 \
      libcairo2 \
      libcups2 \
      libdbus-1-3 \
      libexpat1 \
      libfontconfig1 \
      libgbm1 \
      libglib2.0-0 \
      libgtk-3-0 \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      libx11-6 \
      libx11-xcb1 \
      libxcb1 \
      libxcomposite1 \
      libxcursor1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxrandr2 \
      libxrender1 \
      libxss1 \
      libxtst6 \
      lsb-release \
      wget \
      xdg-utils
    
    # Verify installation
    if command -v chromium-browser &> /dev/null || command -v chromium &> /dev/null; then
      CHROMIUM_VERSION=$(chromium-browser --version 2>/dev/null || chromium --version 2>/dev/null)
      echo ""
      echo "  ✅ Chromium successfully installed!"
      echo "     Version: $CHROMIUM_VERSION"
      echo "     Command: chromium-browser or chromium"
      echo "     Purpose: Required for Mermaid CLI diagram rendering"
    else
      echo ""
      echo "  ❌ Error: Chromium installation failed"
      echo "     Check package manager logs for details"
    fi
  fi
fi
echo ""

# ===============================================================
# 3. MKDOCS - DOCUMENTATION SITE GENERATOR
# ===============================================================
echo "📚 [3/8] Installing MkDocs..."
echo "-----------------------------"
echo "  📝 Description: Static site generator for project documentation"
echo "  🌐 Website: https://www.mkdocs.org"
echo ""

# Check if MkDocs is already installed
if command -v mkdocs &> /dev/null; then
  MKDOCS_VERSION=$(mkdocs --version | head -n 1)
  echo "  ℹ️  MkDocs already installed: $MKDOCS_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  
  # Check if we have sudo access for system installation
  if [ "$EUID" -ne 0 ]; then
    echo "  ⚠️  Warning: MkDocs installation requires sudo privileges"
    echo "  💡 Solution: Please run this script with sudo to install MkDocs"
    echo "  → Skipping MkDocs installation..."
  else
    echo "  → Installing MkDocs from apt repository..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y mkdocs
    
    # Verify installation
    if command -v mkdocs &> /dev/null; then
      MKDOCS_VERSION=$(mkdocs --version | head -n 1)
      echo ""
      echo "  ✅ MkDocs successfully installed!"
      echo "     Version: $MKDOCS_VERSION"
      echo "     Command: mkdocs"
      echo "     Usage: mkdocs new [project-name]"
      echo "     Serve: mkdocs serve"
      echo "     Build: mkdocs build"
    else
      echo ""
      echo "  ❌ Error: MkDocs installation failed"
      echo "     Check package manager logs for details"
    fi
  fi
fi
echo ""

# ===============================================================
# 4. MERMAID CLI - DIAGRAM GENERATION FROM TEXT
# ===============================================================
echo "📊 [4/8] Installing Mermaid CLI..."
echo "----------------------------------"
echo "  📝 Description: Generate diagrams and flowcharts from text definitions"
echo "  🌐 Website: https://mermaid.js.org"
echo "  📦 Package: @mermaid-js/mermaid-cli"
echo ""

# Check if Mermaid CLI is already installed
if command -v mmdc &> /dev/null; then
  MERMAID_VERSION=$(mmdc --version 2>&1 || echo "installed")
  echo "  ℹ️  Mermaid CLI already installed: $MERMAID_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing @mermaid-js/mermaid-cli as global NPM package..."
  echo ""
  
  if npm install -g @mermaid-js/mermaid-cli 2>&1 | grep -E "(added|up to date|mermaid-cli@)"; then
    echo ""
    if command -v mmdc &> /dev/null; then
      MERMAID_VERSION=$(mmdc --version 2>&1 || echo "installed")
      echo "  ✅ Mermaid CLI successfully installed!"
      echo "     Version: $MERMAID_VERSION"
      echo "     Command: mmdc"
      echo "     Usage: mmdc -i input.mmd -o output.png"
      echo "     Formats: PNG, SVG, PDF supported"
      echo "     Note: Requires Chromium browser (installed above)"
    else
      echo "  ⚠️  Installation completed but 'mmdc' command not found"
      echo "     Package may have been installed with different command name"
    fi
  else
    echo ""
    echo "  ❌ Error: Mermaid CLI installation failed"
    echo "  💡 Possible solutions:"
    echo "     • Ensure Chromium is installed (required dependency)"
    echo "     • Check npm permissions (may need sudo for global install)"
    echo "     • Verify network connectivity"
    echo "     • Try: npm install -g @mermaid-js/mermaid-cli --verbose"
  fi
fi
echo ""

# ===============================================================
# 5. OPENAI CODEX
# ===============================================================
echo "🧠 [5/8] Installing OpenAI Codex..."
echo "-----------------------------------"
echo "  📝 Description: OpenAI's AI code completion and generation tool"
echo "  🌐 Website: https://openai.com/blog/openai-codex"
echo "  📦 Package: @openai/codex"
echo ""

# Check if OpenAI Codex is already installed
if command -v codex &> /dev/null; then
  CODEX_VERSION=$(codex --version 2>&1 || echo "installed")
  echo "  ℹ️  OpenAI Codex already installed: $CODEX_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing @openai/codex as global NPM package..."
  echo ""
  
  # Try to install
  if npm install -g @openai/codex 2>&1 | tee /tmp/codex-install.log; then
    echo ""
    if command -v codex &> /dev/null; then
      CODEX_VERSION=$(codex --version 2>&1 || echo "installed")
      echo "  ✅ OpenAI Codex successfully installed!"
      echo "     Version: $CODEX_VERSION"
      echo "     Command: codex"
      echo "     Note: May require OpenAI API key for usage"
      echo "     Setup: Configure OPENAI_API_KEY environment variable"
    else
      echo "  ⚠️  Installation completed but 'codex' command not found"
      echo "     Package may have been installed with different command name"
    fi
  else
    echo ""
    echo "  ⚠️  Warning: OpenAI Codex installation failed"
    echo "  💡 Possible reasons:"
    echo "     • Package may require OpenAI authentication or access"
    echo "     • Package may not be publicly available"
    echo "     • API key or credentials may be required"
    echo "  🔗 More info: https://openai.com/api"
    echo "  → Continuing with remaining installations..."
  fi
  rm -f /tmp/codex-install.log
fi
echo ""

# ===============================================================
# 6. ANTHROPIC CLAUDE CODE
# ===============================================================
echo "🎯 [6/8] Installing Anthropic Claude Code..."
echo "--------------------------------------------"
echo "  📝 Description: Anthropic's Claude AI coding assistant"
echo "  🌐 Website: https://www.anthropic.com"
echo "  📦 Package: @anthropic-ai/claude-code"
echo ""

# Check if Claude Code is already installed
if command -v claude &> /dev/null; then
  CLAUDE_VERSION=$(claude --version 2>&1 || echo "installed")
  echo "  ℹ️  Anthropic Claude Code already installed: $CLAUDE_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing @anthropic-ai/claude-code as global NPM package..."
  echo ""
  
  # Try to install
  if npm install -g @anthropic-ai/claude-code 2>&1 | tee /tmp/claude-install.log; then
    echo ""
    if command -v claude &> /dev/null; then
      CLAUDE_VERSION=$(claude --version 2>&1 || echo "installed")
      echo "  ✅ Anthropic Claude Code successfully installed!"
      echo "     Version: $CLAUDE_VERSION"
      echo "     Command: claude"
      echo "     Note: May require Anthropic API key for usage"
      echo "     Setup: Configure ANTHROPIC_API_KEY environment variable"
    else
      echo "  ⚠️  Installation completed but 'claude' command not found"
      echo "     Package may have been installed with different command name"
    fi
  else
    echo ""
    echo "  ⚠️  Warning: Anthropic Claude Code installation failed"
    echo "  💡 Possible reasons:"
    echo "     • Package may require Anthropic authentication or access"
    echo "     • Package may not be publicly available"
    echo "     • API key or credentials may be required"
    echo "  🔗 More info: https://www.anthropic.com"
    echo "  → Continuing with remaining installations..."
  fi
  rm -f /tmp/claude-install.log
fi
echo ""

# ===============================================================
# 7. GITHUB COPILOT CLI
# ===============================================================
echo "🤖 [7/8] Installing GitHub Copilot CLI..."
echo "-----------------------------------------"
echo "  📝 Description: AI-powered command line assistant from GitHub"
echo "  🌐 Website: https://githubnext.com/projects/copilot-cli"
echo "  📦 Package: @githubnext/github-copilot-cli"
echo ""

# Check if GitHub Copilot CLI is already installed
if command -v copilot &> /dev/null; then
  COPILOT_VERSION=$(copilot --version 2>&1 || echo "installed")
  echo "  ℹ️  GitHub Copilot CLI already installed: $COPILOT_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
elif command -v github-copilot-cli &> /dev/null; then
  COPILOT_VERSION=$(github-copilot-cli --version 2>&1 || echo "installed")
  echo "  ℹ️  GitHub Copilot CLI already installed: $COPILOT_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing @githubnext/github-copilot-cli as global NPM package..."
  echo ""
  
  # Try to install, but handle gracefully if package is not available or requires auth
  if npm install -g @githubnext/github-copilot-cli 2>&1 | tee /tmp/copilot-install.log; then
    echo ""
    if command -v copilot &> /dev/null; then
      COPILOT_VERSION=$(copilot --version 2>&1 || echo "installed")
      echo "  ✅ GitHub Copilot CLI successfully installed!"
      echo "     Version: $COPILOT_VERSION"
      echo "     Command: copilot"
      echo "     Aliases: ?? (explain), git? (git commands), gh? (GitHub CLI)"
      echo "     Auth required: Run 'copilot auth' to authenticate"
    elif command -v github-copilot-cli &> /dev/null; then
      COPILOT_VERSION=$(github-copilot-cli --version 2>&1 || echo "installed")
      echo "  ✅ GitHub Copilot CLI successfully installed!"
      echo "     Version: $COPILOT_VERSION"
      echo "     Command: github-copilot-cli"
      echo "     Aliases: ?? (explain), git? (git commands), gh? (GitHub CLI)"
      echo "     Auth required: Run 'github-copilot-cli auth' to authenticate"
    else
      echo "  ⚠️  Installation completed but 'copilot' command not found"
      echo "     Package may have been installed with different command name"
    fi
  else
    echo ""
    echo "  ⚠️  Warning: GitHub Copilot CLI installation failed"
    echo "  💡 Possible reasons:"
    echo "     • Package may require GitHub authentication or special access"
    echo "     • Package name may have changed or be unavailable"
    echo "     • Network connectivity issues"
    echo "  🔗 More info: https://github.com/github/copilot-cli"
    echo "  → Continuing with remaining installations..."
  fi
  rm -f /tmp/copilot-install.log
fi
echo ""

# ===============================================================
# 8. MARKDOWN TO PDF CONVERTER (MD-TO-PDF)
# ===============================================================
echo "📄 [8/8] Installing Markdown to PDF Converter (md-to-pdf)..."
echo "------------------------------------------------------------"
echo "  📝 Description: Convert Markdown files to PDF with proper image handling"
echo "  🌐 Package: md-to-pdf"
echo "  💡 Use case: Documentation, reports, README exports with embedded images"
echo ""

# Check if md-to-pdf is already installed
if command -v md-to-pdf &> /dev/null; then
  MDTOPDF_VERSION=$(md-to-pdf --version 2>&1 || echo "installed")
  echo "  ℹ️  md-to-pdf already installed: $MDTOPDF_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing md-to-pdf as global NPM package..."
  echo ""
  
  if npm install -g md-to-pdf 2>&1 | grep -E "(added|up to date|md-to-pdf@)"; then
    echo ""
    MDTOPDF_VERSION=$(md-to-pdf --version 2>&1 || echo "installed")
    echo "  ✅ md-to-pdf successfully installed!"
    echo "     Version: $MDTOPDF_VERSION"
    echo "     Command: md-to-pdf"
    echo "     Usage: md-to-pdf input.md [--output output.pdf]"
    echo "     Features: Supports images, code blocks, tables, and custom CSS"
    echo "     Example: md-to-pdf README.md --output documentation.pdf"
  else
    echo ""
    echo "  ❌ Error: md-to-pdf installation failed"
    echo "  💡 Possible solutions:"
    echo "     • Check npm permissions (may need sudo for global install)"
    echo "     • Verify network connectivity"
    echo "     • Try: npm install -g md-to-pdf --verbose"
  fi
fi
echo ""

# ===============================================================
# INSTALLATION VERIFICATION & SUMMARY
# ===============================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  INSTALLATION VERIFICATION                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check each tool and report detailed status
VSCODE_STATUS="❌"
VSCODE_VER="Not installed"
VSCODE_CMD=""
VSCODE_LOCATION=""
if command -v code &> /dev/null; then
  VSCODE_STATUS="✅"
  VSCODE_VER="$(code --version | head -n 1)"
  VSCODE_CMD="code"
  VSCODE_LOCATION="$(which code)"
fi

CHROMIUM_STATUS="❌"
CHROMIUM_VER="Not installed"
CHROMIUM_CMD=""
CHROMIUM_LOCATION=""
if command -v chromium-browser &> /dev/null; then
  CHROMIUM_STATUS="✅"
  CHROMIUM_VER="$(chromium-browser --version)"
  CHROMIUM_CMD="chromium-browser"
  CHROMIUM_LOCATION="$(which chromium-browser)"
elif command -v chromium &> /dev/null; then
  CHROMIUM_STATUS="✅"
  CHROMIUM_VER="$(chromium --version)"
  CHROMIUM_CMD="chromium"
  CHROMIUM_LOCATION="$(which chromium)"
fi

MKDOCS_STATUS="❌"
MKDOCS_VER="Not installed"
MKDOCS_CMD=""
MKDOCS_LOCATION=""
if command -v mkdocs &> /dev/null; then
  MKDOCS_STATUS="✅"
  MKDOCS_VER="$(mkdocs --version | head -n 1)"
  MKDOCS_CMD="mkdocs"
  MKDOCS_LOCATION="$(which mkdocs)"
fi

MERMAID_STATUS="❌"
MERMAID_VER="Not installed"
MERMAID_CMD=""
MERMAID_LOCATION=""
if command -v mmdc &> /dev/null; then
  MERMAID_STATUS="✅"
  MERMAID_VER="$(mmdc --version 2>&1 | head -n 1 || echo 'Installed')"
  MERMAID_CMD="mmdc"
  MERMAID_LOCATION="$(which mmdc)"
fi

CODEX_STATUS="❌"
CODEX_VER="Not installed"
CODEX_CMD=""
CODEX_LOCATION=""
if command -v codex &> /dev/null; then
  CODEX_STATUS="✅"
  CODEX_VER="$(codex --version 2>&1 | head -n 1 || echo 'Installed')"
  CODEX_CMD="codex"
  CODEX_LOCATION="$(which codex)"
fi

CLAUDE_STATUS="❌"
CLAUDE_VER="Not installed"
CLAUDE_CMD=""
CLAUDE_LOCATION=""
if command -v claude &> /dev/null; then
  CLAUDE_STATUS="✅"
  CLAUDE_VER="$(claude --version 2>&1 | head -n 1 || echo 'Installed')"
  CLAUDE_CMD="claude"
  CLAUDE_LOCATION="$(which claude)"
fi

COPILOT_STATUS="❌"
COPILOT_VER="Not installed"
COPILOT_CMD=""
COPILOT_LOCATION=""
if command -v copilot &> /dev/null; then
  COPILOT_STATUS="✅"
  COPILOT_VER="$(copilot --version 2>&1 | head -n 1 || echo 'Installed')"
  COPILOT_CMD="copilot"
  COPILOT_LOCATION="$(which copilot)"
elif command -v github-copilot-cli &> /dev/null; then
  COPILOT_STATUS="✅"
  COPILOT_VER="$(github-copilot-cli --version 2>&1 | head -n 1 || echo 'Installed')"
  COPILOT_CMD="github-copilot-cli"
  COPILOT_LOCATION="$(which github-copilot-cli)"
fi

MDTOPDF_STATUS="❌"
MDTOPDF_VER="Not installed"
MDTOPDF_CMD=""
MDTOPDF_LOCATION=""
if command -v md-to-pdf &> /dev/null; then
  MDTOPDF_STATUS="✅"
  MDTOPDF_VER="$(md-to-pdf --version 2>&1 | head -n 1 || echo 'Installed')"
  MDTOPDF_CMD="md-to-pdf"
  MDTOPDF_LOCATION="$(which md-to-pdf)"
fi

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  💻  VISUAL STUDIO CODE                                        │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $VSCODE_STATUS $VSCODE_VER"
[ -n "$VSCODE_CMD" ] && echo "│  Command:  $VSCODE_CMD"
[ -n "$VSCODE_LOCATION" ] && echo "│  Location: $VSCODE_LOCATION"
[ "$VSCODE_STATUS" = "✅" ] && echo "│  Features: Code editing, debugging, extensions, Git integration"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  🌐  CHROMIUM BROWSER                                          │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $CHROMIUM_STATUS $CHROMIUM_VER"
[ -n "$CHROMIUM_CMD" ] && echo "│  Command:  $CHROMIUM_CMD"
[ -n "$CHROMIUM_LOCATION" ] && echo "│  Location: $CHROMIUM_LOCATION"
[ "$CHROMIUM_STATUS" = "✅" ] && echo "│  Purpose:  Required dependency for Mermaid CLI diagram rendering"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  📚  MKDOCS                                                    │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $MKDOCS_STATUS $MKDOCS_VER"
[ -n "$MKDOCS_CMD" ] && echo "│  Command:  $MKDOCS_CMD"
[ -n "$MKDOCS_LOCATION" ] && echo "│  Location: $MKDOCS_LOCATION"
[ "$MKDOCS_STATUS" = "✅" ] && echo "│  Features: Documentation site generator, Material theme support"
[ "$MKDOCS_STATUS" = "✅" ] && echo "│  Usage:    mkdocs new [project] | mkdocs serve | mkdocs build"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  📊  MERMAID CLI                                               │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $MERMAID_STATUS $MERMAID_VER"
[ -n "$MERMAID_CMD" ] && echo "│  Command:  $MERMAID_CMD"
[ -n "$MERMAID_LOCATION" ] && echo "│  Location: $MERMAID_LOCATION"
[ "$MERMAID_STATUS" = "✅" ] && echo "│  Features: Generate diagrams from text (flowcharts, sequences, etc.)"
[ "$MERMAID_STATUS" = "✅" ] && echo "│  Usage:    mmdc -i diagram.mmd -o diagram.png"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  🧠  OPENAI CODEX                                              │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $CODEX_STATUS $CODEX_VER"
[ -n "$CODEX_CMD" ] && echo "│  Command:  $CODEX_CMD"
[ -n "$CODEX_LOCATION" ] && echo "│  Location: $CODEX_LOCATION"
[ "$CODEX_STATUS" = "✅" ] && echo "│  Features: AI code completion, generation, and suggestions"
[ "$CODEX_STATUS" = "✅" ] && echo "│  Setup:    Set OPENAI_API_KEY environment variable"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  🎯  ANTHROPIC CLAUDE CODE                                     │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $CLAUDE_STATUS $CLAUDE_VER"
[ -n "$CLAUDE_CMD" ] && echo "│  Command:  $CLAUDE_CMD"
[ -n "$CLAUDE_LOCATION" ] && echo "│  Location: $CLAUDE_LOCATION"
[ "$CLAUDE_STATUS" = "✅" ] && echo "│  Features: AI coding assistant with Claude capabilities"
[ "$CLAUDE_STATUS" = "✅" ] && echo "│  Setup:    Set ANTHROPIC_API_KEY environment variable"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  🤖  GITHUB COPILOT CLI                                        │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $COPILOT_STATUS $COPILOT_VER"
[ -n "$COPILOT_CMD" ] && echo "│  Command:  $COPILOT_CMD"
[ -n "$COPILOT_LOCATION" ] && echo "│  Location: $COPILOT_LOCATION"
[ "$COPILOT_STATUS" = "✅" ] && echo "│  Features: AI command suggestions, git help, shell assistance"
[ "$COPILOT_STATUS" = "✅" ] && echo "│  Auth:     Run '$COPILOT_CMD auth' to authenticate"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│  📄  MARKDOWN TO PDF CONVERTER                                 │"
echo "├────────────────────────────────────────────────────────────────┤"
echo "│  Status:   $MDTOPDF_STATUS $MDTOPDF_VER"
[ -n "$MDTOPDF_CMD" ] && echo "│  Command:  $MDTOPDF_CMD"
[ -n "$MDTOPDF_LOCATION" ] && echo "│  Location: $MDTOPDF_LOCATION"
[ "$MDTOPDF_STATUS" = "✅" ] && echo "│  Usage:    md-to-pdf input.md --output output.pdf"
[ "$MDTOPDF_STATUS" = "✅" ] && echo "│  Features: Supports images, code blocks, tables, custom CSS"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

# Count successful installations
SUCCESS_COUNT=0
TOTAL_COUNT=8
[ "$VSCODE_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$CHROMIUM_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$MKDOCS_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$MERMAID_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$CODEX_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$CLAUDE_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$MDTOPDF_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$COPILOT_STATUS" = "✅" ] && ((SUCCESS_COUNT++))

echo "╔════════════════════════════════════════════════════════════════╗"
if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
  echo "║              ✅ 🎉  INSTALLATION SUCCESSFUL! 🎉 ✅              ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  🎊 All $TOTAL_COUNT tools have been successfully installed!"
  echo ""
  echo "  📊 Installation Summary:"
  echo "     • Visual Studio Code .......... ✅ Ready"
  echo "     • Chromium Browser ............ ✅ Ready"
  echo "     • MkDocs ...................... ✅ Ready"
  echo "     • Mermaid CLI ................. ✅ Ready"
  echo "     • OpenAI Codex ................ ✅ Ready"
  echo "     • Anthropic Claude Code ....... ✅ Ready"
  echo "     • GitHub Copilot CLI .......... ✅ Ready"
  echo "     • Markdown to PDF ............. ✅ Ready"
  echo ""
elif [ $SUCCESS_COUNT -gt 0 ]; then
  echo "║          ⚠️   INSTALLATION PARTIALLY COMPLETED ⚠️              ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  📊 Summary: $SUCCESS_COUNT out of $TOTAL_COUNT tools installed successfully"
  echo ""
  echo "  ⚠️  Please review the warnings above for tools that failed."
  echo ""
else
  echo "║              ❌  INSTALLATION FAILED  ❌                        ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  ❌ No tools were installed successfully."
  echo ""
  echo "  🔧 Troubleshooting checklist:"
  echo "     □ Check internet connectivity"
  echo "     □ Verify npm permissions for global installs"
  echo "     □ Ensure sudo access for VS Code installation"
  echo "     □ Check firewall/proxy settings"
  echo "     □ Review authentication requirements for AI tools"
  echo ""
  exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      QUICK START GUIDE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
if [ "$VSCODE_STATUS" = "✅" ]; then
  echo "  💻 Visual Studio Code:"
  echo "     • Launch editor:       code"
  echo "     • Open current folder: code ."
  echo "     • Open specific file:  code myfile.txt"
  echo "     • Install extensions:  code --install-extension <ext-id>"
  echo ""
fi

if [ "$MKDOCS_STATUS" = "✅" ]; then
  echo "  📚 MkDocs:"
  echo "     • Create new project:  mkdocs new my-project"
  echo "     • Start dev server:    mkdocs serve"
  echo "     • Build static site:   mkdocs build"
  echo "     • Deploy to GitHub:    mkdocs gh-deploy"
  echo "     • Config file:         mkdocs.yml"
  echo ""
fi

if [ "$MERMAID_STATUS" = "✅" ]; then
  echo "  📊 Mermaid CLI:"
  echo "     • Generate diagram:    mmdc -i diagram.mmd -o output.png"
  echo "     • SVG output:          mmdc -i diagram.mmd -o output.svg"
  echo "     • PDF output:          mmdc -i diagram.mmd -o output.pdf"
  echo "     • Multiple files:      mmdc -i folder/*.mmd"
  echo "     • Documentation:       https://mermaid.js.org"
  echo ""
fi

if [ "$CODEX_STATUS" = "✅" ]; then
  echo "  🧠 OpenAI Codex:"
  echo "     • Check version:       codex --version"
  echo "     • Set API key:         export OPENAI_API_KEY='your-key-here'"
  echo "     • Documentation:       Check package documentation for usage"
  echo "     • API access:          https://platform.openai.com/api-keys"
  echo ""
fi

if [ "$CLAUDE_STATUS" = "✅" ]; then
  echo "  🎯 Anthropic Claude Code:"
  echo "     • Check version:       claude --version"
  echo "     • Set API key:         export ANTHROPIC_API_KEY='your-key-here'"
  echo "     • Documentation:       Check package documentation for usage"
  echo "     • API access:          https://console.anthropic.com"
  echo ""
fi

if [ "$COPILOT_STATUS" = "✅" ]; then
  echo "  🤖 GitHub Copilot CLI:"
  echo "     • Check version:       $COPILOT_CMD --version"
  echo "     • Authenticate:        $COPILOT_CMD auth"
  echo "     • Explain command:     ?? <what you want to do>"
  echo "     • Git assistance:      git? <what you want to do>"
  echo "     • GitHub CLI help:     gh? <what you want to do>"
  echo ""
fi

if [ "$MDTOPDF_STATUS" = "✅" ]; then
  echo "  📄 Markdown to PDF:"
  echo "     • Basic conversion:    md-to-pdf README.md"
  echo "     • Custom output:       md-to-pdf input.md --output output.pdf"
  echo "     • With CSS:            md-to-pdf doc.md --stylesheet custom.css"
  echo "     • Config file:         md-to-pdf --config-file config.json input.md"
  echo "     • Documentation:       https://github.com/simonhaenisch/md-to-pdf"
  echo ""
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      ADDITIONAL INFO                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  📝 Log file:        $LOG_FILE"
echo "  🌐 Node.js version: $(node -v 2>/dev/null || echo 'Not found')"
echo "  📦 NPM version:     v$(npm -v 2>/dev/null || echo 'Not found')"
echo "  🖥️  System:          $(uname -s) $(uname -m)"
echo "  👤 User:            $(whoami)"
echo "  📅 Date:            $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   INSTALLATION COMPLETE                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""