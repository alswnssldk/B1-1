#!/usr/bin/env bash
set -euo pipefail

AGENT_HOME="/home/agent-admin/agent-app"
AGENT_PORT="15034"
AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
# Supplied binary behavior: this must be the directory containing secret.key.
AGENT_KEY_PATH="$AGENT_HOME/api_keys"
AGENT_LOG_DIR="/var/log/agent-app"
APP="$AGENT_HOME/agent-app"

if pgrep -u agent-admin -x agent-app >/dev/null 2>&1; then
    printf '[ERROR] agent-app is already running.\n' >&2
    exit 1
fi

run_agent() {
    exec env \
        AGENT_HOME="$AGENT_HOME" \
        AGENT_PORT="$AGENT_PORT" \
        AGENT_UPLOAD_DIR="$AGENT_UPLOAD_DIR" \
        AGENT_KEY_PATH="$AGENT_KEY_PATH" \
        AGENT_LOG_DIR="$AGENT_LOG_DIR" \
        "$APP"
}

if [[ "$(id -u)" -eq 0 ]]; then
    exec runuser -u agent-admin -- env \
        AGENT_HOME="$AGENT_HOME" \
        AGENT_PORT="$AGENT_PORT" \
        AGENT_UPLOAD_DIR="$AGENT_UPLOAD_DIR" \
        AGENT_KEY_PATH="$AGENT_KEY_PATH" \
        AGENT_LOG_DIR="$AGENT_LOG_DIR" \
        "$APP"
fi

if [[ "$(id -un)" != "agent-admin" ]]; then
    printf '[ERROR] Run as root or agent-admin.\n' >&2
    exit 1
fi

run_agent
