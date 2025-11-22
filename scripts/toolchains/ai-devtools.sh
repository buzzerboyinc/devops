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
#    2. OpenAI Codex - AI code completion and generation
#    3. Anthropic Claude Code - AI coding assistant
#    4. GitHub Copilot CLI - AI pair programming from command line
#    5. Markdown to PDF Converter (mdpdf) - Convert markdown to PDF
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
# 2. OPENAI CODEX
# ===============================================================
echo "🧠 [2/5] Installing OpenAI Codex..."
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
# 3. ANTHROPIC CLAUDE CODE
# ===============================================================
echo "🎯 [3/5] Installing Anthropic Claude Code..."
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
# 4. GITHUB COPILOT CLI
# ===============================================================
echo "🤖 [4/5] Installing GitHub Copilot CLI..."
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
# 5. MARKDOWN TO PDF CONVERTER (MDPDF)
# ===============================================================
echo "📄 [5/5] Installing Markdown to PDF Converter (mdpdf)..."
echo "--------------------------------------------------------"
echo "  📝 Description: Convert Markdown files to PDF with styling"
echo "  🌐 Package: mdpdf"
echo "  💡 Use case: Documentation, reports, README exports"
echo ""

# Check if mdpdf is already installed
if command -v mdpdf &> /dev/null; then
  MDPDF_VERSION=$(mdpdf --version 2>&1 || echo "installed")
  echo "  ℹ️  Markdown to PDF converter already installed: $MDPDF_VERSION"
  echo "  ✅ Status: Found existing installation"
  echo "  → Skipping installation"
else
  echo "  🔍 Status: Not found, proceeding with installation..."
  echo "  → Installing mdpdf as global NPM package..."
  echo ""
  
  if npm install -g mdpdf 2>&1 | grep -E "(added|up to date|mdpdf@)"; then
    echo ""
    MDPDF_VERSION=$(mdpdf --version 2>&1 || echo "installed")
    echo "  ✅ Markdown to PDF converter successfully installed!"
    echo "     Version: $MDPDF_VERSION"
    echo "     Command: mdpdf"
    echo "     Usage: mdpdf <input.md> [output.pdf]"
    echo "     Example: mdpdf README.md documentation.pdf"
  else
    echo ""
    echo "  ❌ Error: mdpdf installation failed"
    echo "  💡 Possible solutions:"
    echo "     • Check npm permissions (may need sudo for global install)"
    echo "     • Verify network connectivity"
    echo "     • Try: npm install -g mdpdf --verbose"
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

MDPDF_STATUS="❌"
MDPDF_VER="Not installed"
MDPDF_CMD=""
MDPDF_LOCATION=""
if command -v mdpdf &> /dev/null; then
  MDPDF_STATUS="✅"
  MDPDF_VER="$(mdpdf --version 2>&1 | head -n 1 || echo 'Installed')"
  MDPDF_CMD="mdpdf"
  MDPDF_LOCATION="$(which mdpdf)"
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
echo "│  Status:   $MDPDF_STATUS $MDPDF_VER"
[ -n "$MDPDF_CMD" ] && echo "│  Command:  $MDPDF_CMD"
[ -n "$MDPDF_LOCATION" ] && echo "│  Location: $MDPDF_LOCATION"
[ "$MDPDF_STATUS" = "✅" ] && echo "│  Usage:    mdpdf <input.md> [output.pdf]"
[ "$MDPDF_STATUS" = "✅" ] && echo "│  Example:  mdpdf README.md documentation.pdf"
echo "└────────────────────────────────────────────────────────────────┘"
echo ""

# Count successful installations
SUCCESS_COUNT=0
TOTAL_COUNT=5
[ "$VSCODE_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$CODEX_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$CLAUDE_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
[ "$MDPDF_STATUS" = "✅" ] && ((SUCCESS_COUNT++))
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

if [ "$MDPDF_STATUS" = "✅" ]; then
  echo "  📄 Markdown to PDF:"
  echo "     • Basic conversion:    mdpdf README.md"
  echo "     • Custom output:       mdpdf input.md output.pdf"
  echo "     • With styling:        mdpdf --style custom.css doc.md"
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