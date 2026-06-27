#!/usr/bin/env bash
set -euo pipefail

LAUNCH_AGENT_LABEL="com.claude-notch.agent"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

launchctl bootout "gui/$(id -u)/${LAUNCH_AGENT_LABEL}" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PLIST"
rm -f "$HOME/Library/Application Support/ClaudeNotch/notch.sock"

printf '\033[1;32m✓\033[0m Background agent removed.\n'
echo "To finish, disable the plugin in Claude Code:"
echo "    /plugin uninstall claude-notch@claude-notch"
