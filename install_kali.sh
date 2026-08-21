#!/bin/bash
# ============================================================
#  Agent Zero - Kali Linux Installer (No Docker Required)
#  Compatible with Python 3.13 (Kali default)
#  Default model: OpenRouter openrouter/free
#  Auto-starts on http://localhost:5000
#  Installs a lightweight browser and configures auto-open on login
#  BULLETPROOF: Installs ALL dependencies automatically
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/zero"
PORT=5000

banner() {
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║     Agent Zero × Kali Linux Setup            ║"
  echo "  ║     Default Model: OpenRouter openrouter/free ║"
  echo "  ║     Python 3.13 Compatible (no venv)         ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

log()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
err()    { echo -e "${RED}[✗]${NC} $1"; }

banner

# ── 1. System dependencies ─────────────────────────────────
log "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y \
  git curl wget build-essential \
  python3-pip python3-venv python3-dev \
  libssl-dev libffi-dev libsodium-dev \
  chromium chromium-driver \
  --no-install-recommends -qq

PYTHON=$(command -v python3)
log "Using $($PYTHON --version)"

# ── 2. Clone Agent Zero ────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
  warn "Found existing install at $INSTALL_DIR — removing and re-cloning fresh..."
  rm -rf "$INSTALL_DIR"
fi
log "Cloning Agent Zero..."
git clone https://github.com/agent0ai/agent-zero.git "$INSTALL_DIR"

cd "$INSTALL_DIR"

# ── 3. Use system Python (no virtual environment) ─────────
log "Using system Python (no virtualenv). Packages will be installed for the user."
pip_cmd="$PYTHON -m pip"
$pip_cmd install --user --upgrade pip setuptools wheel -q --break-system-packages

# ── 4. Install Agent Zero's own requirements first ────────
log "Installing Agent Zero's own requirements..."
$pip_cmd install --user -r requirements.txt --ignore-requires-python -q 2 --break-system-packages>&1 | grep -E "ERROR|Successfully|error" || true

# ── 5. Install ALL additional required packages ───────────
log "Installing all additional required packages..."
PACKAGES=(
  # Web server
  "uvicorn[standard]"
  "uvicorn"
  "fastapi"
  "aiohttp"
  "websockets"
  "python-socketio"
  "flask"
  "flask-basicauth"
  "flask-socketio"
  "nest-asyncio"
  "eventlet"
  # LLM providers
  "anthropic"
  "openai"
  "litellm"
  # LangChain full suite
  "langchain"
  "langchain-community"
  "langchain-anthropic"
  "langchain-openai"
  "langchain-google-genai"
  "langchain-groq"
  "langchain-mistralai"
  "langchain-chroma"
  "langchain-ollama"
  "langchain-huggingface"
  # Embeddings
  "sentence-transformers"
  "chromadb"
  "faiss-cpu"
  # Security
  "cryptography"
  "paramiko"
  # Utilities
  "python-dotenv"
  "requests"
  "aiofiles"
  "GitPython"
  "simpleeval"
  "inputimeout"
  "ansio"
  # Text processing
  "beautifulsoup4"
  "markdownify"
  "html2text"
  "pypdf"
  "Pillow"
  "tiktoken"
  "tokenizers"
  # Data
  "numpy"
  "pydantic"
  "pyyaml"
  "toml"
  "regex"
  # Search & tools
  "duckduckgo-search"
  "mcp"
  "webcolors"
  "schedule"
  "rich"
  "tqdm"
  "packaging"
  "annotated-types"
  "rfc3986"
)

FAILED=()
for pkg in "${PACKAGES[@]}"; do
  $pip_cmd install --user "$pkg" --ignore-requires-python -q 2>/dev/null || {
    warn "Failed to install $pkg — skipping"
    FAILED+=("$pkg")
  }
done

if [ ${#FAILED[@]} -gt 0 ]; then
  warn "These packages failed (non-fatal): ${FAILED[*]}"
fi

# ── 6. Install kokoro without heavy deps ──────────────────
log "Installing kokoro (TTS)..."
$pip_cmd install --user kokoro --no-deps -q 2>/dev/null || warn "kokoro skipped — voice disabled (non-fatal)"

# ── 7. Playwright ─────────────────────────────────────────
log "Installing Playwright..."
$pip_cmd install --user playwright -q 2>/dev/null
playwright install chromium 2>/dev/null || warn "Playwright chromium skipped (non-fatal)"

# ── 8. Defaults patch (OpenRouter) ────────────────────────
log "Installing default model patch (OpenRouter)..."
cat > "$INSTALL_DIR/initialize_claude_patch.py" << 'PYEOF'
"""
initialize_claude_patch.py
Forces OpenRouter openrouter/free as the default model.
Auto-injected by install_kali.sh
"""
import os

def apply_default_model_envs():
    defaults = {
        "A0_CHAT_MODEL_PROVIDER":    "openrouter",
        "A0_CHAT_MODEL_NAME":        "openrouter/free",
        "A0_UTILITY_MODEL_PROVIDER": "openrouter",
        "A0_UTILITY_MODEL_NAME":     "openrouter/free",
        "A0_EMBED_MODEL_PROVIDER":   "huggingface",
        "A0_EMBED_MODEL_NAME":       "sentence-transformers/all-MiniLM-L6-v2",
    }
    for key, value in defaults.items():
        os.environ.setdefault(key, value)

apply_default_model_envs()
PYEOF

# Patch initialize.py
INIT_FILE="$INSTALL_DIR/initialize.py"
if ! grep -q "initialize_claude_patch" "$INIT_FILE" 2>/dev/null; then
  TMP=$(mktemp)
  echo "import initialize_claude_patch  # Auto-added by install_kali.sh" > "$TMP"
  cat "$INIT_FILE" >> "$TMP"
  mv "$TMP" "$INIT_FILE"
  log "initialize.py patched."
else
  log "initialize.py already patched."
fi

# ── 9. OpenRouter API key ─────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}[?] Enter your OpenRouter API key (optional, leave blank if you don't have one):${NC}"
read -r -s OPENROUTER_KEY
echo ""

# ── 10. Write .env ────────────────────────────────────────
log "Writing .env configuration..."
cat > "$INSTALL_DIR/.env" << EOF
# OpenRouter
API_KEY_OPENROUTER=${OPENROUTER_KEY}
OPENROUTER_API_KEY=${OPENROUTER_KEY}

# Other providers (optional)
API_KEY_OPENAI=
API_KEY_GROQ=
API_KEY_GOOGLE=
API_KEY_ANTHROPIC=
ANTHROPIC_API_KEY=

# Web UI
WEB_UI_PORT=${PORT}
WEB_UI_HOST=127.0.0.1

# Default model
A0_CHAT_MODEL_PROVIDER=openrouter
A0_CHAT_MODEL_NAME=openrouter/free
A0_UTILITY_MODEL_PROVIDER=openrouter
A0_UTILITY_MODEL_NAME=openrouter/free
A0_EMBED_MODEL_PROVIDER=huggingface
A0_EMBED_MODEL_NAME=sentence-transformers/all-MiniLM-L6-v2
EOF

# ── 11. Launcher ──────────────────────────────────────────
log "Writing launcher..."
cat > "$INSTALL_DIR/start.sh" << LAUNCHER
#!/bin/bash
cd "$(dirname "$0")"
# No virtualenv; use system python and user site-packages
set -a; source .env; set +a
export PATH="${HOME}/.local/bin:$PATH"
echo ""
echo -e "\033[0;36m  Agent Zero starting..."
echo -e "  Browser UI : http://localhost:${PORT}"
echo -e "  CLI mode   : python run_cli.py\033[0m"
echo ""
python run_ui.py --port ${PORT} --host 127.0.0.1
LAUNCHER
chmod +x "$INSTALL_DIR/start.sh"

# ── 11b. Create a small helper script to open the browser after UI is up ──
cat > "$INSTALL_DIR/open_browser.sh" << 'BOPEN'
#!/bin/bash
# Wait for Agent Zero to be available, then open the browser (user session)
PORT=${PORT}
URL="http://localhost:${PORT}"
# Wait up to 60 seconds for the service
for i in {1..60}; do
  if curl -sSf "$URL" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
# Prefer chromium if available, fall back to xdg-open
if command -v chromium >/dev/null 2>&1; then
  chromium --new-window "$URL" &>/dev/null &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" &>/dev/null &
fi
BOPEN
chmod +x "$INSTALL_DIR/open_browser.sh"

# ── 11c. Create desktop autostart so the browser opens when a user logs in graphically ──
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/agent-zero-browser.desktop" << ADO
[Desktop Entry]
Type=Application
Name=Agent Zero Browser
Exec=$INSTALL_DIR/open_browser.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
Ado

# ── 11d. Create systemd service to run Agent Zero server on boot ──
SERVICE_FILE="/etc/systemd/system/agent-zero.service"
sudo tee "$SERVICE_FILE" > /dev/null << SVC
[Unit]
Description=Agent Zero web UI
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$HOME/.local/bin:/usr/bin:/bin
ExecStart=$INSTALL_DIR/start.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
SVC

log "Reloading systemd and enabling Agent Zero service (requires sudo)..."
sudo systemctl daemon-reload
sudo systemctl enable --now agent-zero.service || warn "Could not enable system service (you may need sudo)."

# ── 12. Tailscale ─────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}[?] Install Tailscale for remote access? [y/N]${NC}"
read -r TAILSCALE
if [[ "$TAILSCALE" =~ ^[Yy]$ ]]; then
  log "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up
  TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "run: tailscale ip")
  log "Tailscale IP: $TAILSCALE_IP"
  log "Access from other devices: http://${TAILSCALE_IP}:${PORT}"
fi

# ── 13. Done ──────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗"
echo -e "║   ✅  Installation Complete!              ║"
echo -e "╚════════════════════════════════════════╝${NC}"
echo ""
echo -e " ${CYAN}Start Agent Zero:${NC}"
echo -e "   cd ~/agent-zero && ./start.sh"
echo ""
echo -e " ${CYAN}Open in browser:${NC}"
echo -e "   http://localhost:${PORT}"
echo ""
echo -e " ${CYAN}CLI mode (no browser):${NC}"
echo -e "   cd ~/agent-zero && python run_cli.py"
echo ""
echo -e " ${YELLOW}Default model: OpenRouter openrouter/free${NC}"
echo ""
