#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/agent-app/agent-app.log"

if pgrep -u agent-admin -x agent-app >/dev/null 2>&1; then
    printf '[INFO] agent-app is already running.\n'
    exit 0
fi

nohup bash /mission/scripts/start-agent.sh >> "$LOG_FILE" 2>&1 &
sleep 2

if pgrep -u agent-admin -x agent-app >/dev/null 2>&1; then
    printf '[OK] agent-app started in background. Log: %s\n' "$LOG_FILE"
else
    printf '[FAIL] agent-app did not start. Check: %s\n' "$LOG_FILE" >&2
    exit 1
fi
