# Agent Zero — Kali Linux Setup (No Docker)
### Default model: OpenRouter openrouter/free (embeddings: HuggingFace)

---

## Quick Start

```bash
# 1. Download the installer
chmod +x install_kali.sh

# 2. Run it (one command, sets everything up)
./install_kali.sh

# 3. Start Agent Zero (manual test)
cd ~/zero && ./start.sh

# 4. Open browser
http://localhost:5000
```

That's it. Nothing else to configure.

---

## What the installer does

| Step | Action |
|------|--------|
| 1 | Installs system deps (`git`, `chromium`, `build-essential`, etc.) |
| 2 | Clones Agent Zero from GitHub into ~/zero |
| 3 | Uses system python3 and installs Python packages to the user site (~/.local) — does NOT create/manage a virtualenv |
| 4 | Installs Python requirements via `python3 -m pip install --user -r requirements.txt` |
| 5 | Prompts for an OpenRouter API key (stored in `~/zero/.env`) and writes OpenRouter defaults |
| 6 | Injects `initialize_claude_patch.py` to set default providers/models (OpenRouter for chat/utility; HuggingFace for embeddings) |
| 7 | Writes `start.sh` that runs the UI using system python |
| 8 | Creates a systemd service to start the server at boot (runs as the installing user) and enables it |
| 9 | Creates a desktop autostart entry that opens the UI in a browser on graphical login |
| 10 | Optionally installs Tailscale for remote access |

---

## Files included

| File | Purpose |
|------|---------|
| `install_kali.sh` | Main installer — run this |
| `example.env` | Pre-filled `.env` template (installer auto-generates the real one at `~/zero/.env`) |
| `initialize_claude_patch.py` | Auto-injected by the installer — sets OpenRouter defaults (chat/utility) and HuggingFace for embeddings |

---

## Manual setup (if you prefer not to run the installer)

```bash
# Clone
git clone https://github.com/agent0ai/agent-zero.git ~/zero
cd ~/zero

# Install dependencies manually, then install Python packages to user site:
python3 -m pip install --user -r requirements.txt

# Copy example env and edit:
cp example.env .env
nano .env   # add your API keys (OpenRouter key is optional)

# Add the initialize_claude_patch.py file if you want the OpenRouter defaults:
cp /path/to/initialize_claude_patch.py .
# Add this line to the TOP of initialize.py:
# import initialize_claude_patch

# Run
python run_ui.py --port 5000 --host 127.0.0.1
```

---

## Managing the system service

The installer writes a system-level systemd unit at `/etc/systemd/system/agent-zero.service` that runs the server as the installing user.

Commands:

```bash
# Reload units, enable & start the service (requires sudo)
sudo systemctl daemon-reload
sudo systemctl enable --now agent-zero.service

# Check status & logs
sudo systemctl status agent-zero.service
sudo journalctl -u agent-zero.service -f

# To disable and remove:
sudo systemctl disable --now agent-zero.service
sudo rm /etc/systemd/system/agent-zero.service
```

Note: enabling the systemd unit and writing `/etc/systemd/system` require sudo. The installer will attempt to run these steps but will warn if it cannot.

If you prefer a per-user service (systemctl --user) instead of a system-level unit, I can switch the installer to create/enable a user unit.

---

## Changing the model or embeddings

Edit `~/zero/.env` to change providers/models. Example:

```bash
# Use a different chat model/provider
A0_CHAT_MODEL_PROVIDER=openrouter
A0_CHAT_MODEL_NAME=openrouter/free

# Use a HuggingFace embedding model (default)
A0_EMBED_MODEL_PROVIDER=huggingface
A0_EMBED_MODEL_NAME=sentence-transformers/all-MiniLM-L6-v2
```

After editing `.env`, restart the service:

```bash
sudo systemctl restart agent-zero.service
```

---

## Notes & caveats

- The installer uses the system python3 and installs Python packages to the user site (`~/.local`) — it does not create or manage virtual environments.
- Browser autolaunch only runs in graphical desktop sessions (the installer creates a `~/.config/autostart` entry). Headless systems can still be accessed via Tailscale or by port-forwarding.
- Playwright/browser binaries may require additional system libraries on some systems; the installer attempts to install them but may warn if manual steps are required.
- The installer currently checks for 32-bit architecture and exits on non-32-bit systems. If you want 64-bit support, I can update/remove that check.
