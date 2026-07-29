#!/usr/bin/env bash
set -euo pipefail

if pkill -u agent-admin -x agent-app; then
    printf '[OK] agent-app stopped.\n'
else
    printf '[INFO] agent-app was not running.\n'
fi
