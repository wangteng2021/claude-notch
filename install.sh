#!/usr/bin/env bash
#
# claude-notch installer
#   1. builds the native overlay binary
#   2. installs a LaunchAgent so it runs in the background and at login
#   3. points you at the Claude Code plugin to enable the hooks
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_DIR/app"
PLUGIN_BIN_DIR="$REPO_DIR/plugin/bin"
BINARY_NAME="claude-notch"
LAUNCH_AGENT_LABEL="com.claude-notch.agent"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

say()  { printf '\033[1;35m▶\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$1"; }

# --- 0. sanity checks --------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "claude-notch only runs on macOS." >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift toolchain not found. Install Xcode command line tools:" >&2
  echo "    xcode-select --install" >&2
  exit 1
fi

# --- 0b. language choice -----------------------------------------------------
CONFIG_DIR="$HOME/Library/Application Support/ClaudeNotch"
DEFAULT_LANG=zh
LANG_CHOICE="$DEFAULT_LANG"
if [ -t 0 ]; then
  echo "Card language / 卡片语言:"
  echo "  1) 中文 (默认)"
  echo "  2) English"
  printf 'Choose 1 or 2 [default: 中文]: '
  read -r choice || choice=""
  case "$choice" in
    1) LANG_CHOICE=zh ;;
    2) LANG_CHOICE=en ;;
  esac
fi
mkdir -p "$CONFIG_DIR"

# Optional phone push via ntfy.sh
NTFY_TOPIC=""
NTFY_SERVER="https://ntfy.sh"
if [ -t 0 ]; then
  SUGGESTED="claude-notch-$(openssl rand -hex 5 2>/dev/null || echo $RANDOM$RANDOM)"
  echo
  echo "Phone push via ntfy.sh (optional) / 手机推送（可选）:"
  echo "  Install the free 'ntfy' app (iOS/Android) and subscribe to a topic to"
  echo "  get a push when Claude needs you. Leave blank to skip."
  printf 'ntfy topic [suggested: %s]: ' "$SUGGESTED"
  read -r NTFY_TOPIC || NTFY_TOPIC=""
fi

if [ -n "$NTFY_TOPIC" ]; then
  cat > "$CONFIG_DIR/config.json" <<JSON
{
  "lang": "$LANG_CHOICE",
  "ntfy": {
    "server": "$NTFY_SERVER",
    "topic": "$NTFY_TOPIC"
  }
}
JSON
  ok "Language '$LANG_CHOICE'; phone push → topic '$NTFY_TOPIC'"
  warn "Subscribe to topic '$NTFY_TOPIC' in the ntfy app to receive pushes."
else
  cat > "$CONFIG_DIR/config.json" <<JSON
{
  "lang": "$LANG_CHOICE"
}
JSON
  ok "Language set to '$LANG_CHOICE' (no phone push)"
fi
echo "Edit $CONFIG_DIR/config.json anytime to change."

# --- 1. build ----------------------------------------------------------------
say "Building the overlay (swift build -c release)…"
( cd "$APP_DIR" && swift build -c release )
BUILT="$APP_DIR/.build/release/$BINARY_NAME"
mkdir -p "$PLUGIN_BIN_DIR"
cp "$BUILT" "$PLUGIN_BIN_DIR/$BINARY_NAME"
ok "Binary installed at plugin/bin/$BINARY_NAME"

# --- 2. LaunchAgent ----------------------------------------------------------
say "Installing the background agent…"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${PLUGIN_BIN_DIR}/${BINARY_NAME}</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST

# reload if already present
launchctl bootout "gui/$(id -u)/${LAUNCH_AGENT_LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
launchctl kickstart -k "gui/$(id -u)/${LAUNCH_AGENT_LABEL}" 2>/dev/null || true
ok "Background agent running (and will start at login)"

# --- 3. test card ------------------------------------------------------------
# launchd may take a moment to spin up the overlay; retry the test card briefly.
for _ in 1 2 3 4 5 6 7 8; do
  if "$PLUGIN_BIN_DIR/$BINARY_NAME" ping 2>/dev/null; then
    PINGED=1; break
  fi
  sleep 0.5
done
[[ "${PINGED:-}" == 1 ]] || warn "Could not reach the agent — check Console for ${LAUNCH_AGENT_LABEL}"

# --- 4. enable the plugin ----------------------------------------------------
cat <<EOF

$(ok "Native side installed.")

Last step — enable the Claude Code plugin so events get forwarded.
Inside Claude Code run:

    /plugin marketplace add $REPO_DIR
    /plugin install claude-notch@claude-notch

Then restart Claude Code. A card should appear on your notch whenever Claude
needs your input or finishes a turn.

Optional: show every tool step too —
    export CLAUDE_NOTCH_STEPS=1     (before launching Claude Code)

Uninstall:  ./uninstall.sh
EOF
