#!/usr/bin/env bash
# Demonstrate the required exit 1 behavior when the app is stopped.

set -u

MONITOR="/home/agent-admin/agent-app/bin/monitor.sh"

if pgrep -u agent-admin -x agent-app >/dev/null 2>&1; then
    printf '[ERROR] Stop agent-app before running this negative test.\n' >&2
    exit 2
fi

set +e
runuser -u agent-admin -- "$MONITOR"
status=$?
set -e

if [[ "$status" -eq 1 ]]; then
    printf '[PASS] monitor.sh returned exit 1 for a stopped process.\n'
    exit 0
fi

printf '[FAIL] Expected exit 1, got exit %s.\n' "$status" >&2
exit 1
