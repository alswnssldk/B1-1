#!/usr/bin/env bash
# Read-only requirement verification. Run as root inside the configured container.

set -u

pass=0
fail=0

ok() {
    printf '[PASS] %s\n' "$*"
    pass=$((pass + 1))
}

no() {
    printf '[FAIL] %s\n' "$*"
    fail=$((fail + 1))
}

check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then ok "$description"; else no "$description"; fi
}

check 'agent-admin account exists' id agent-admin
check 'agent-dev account exists' id agent-dev
check 'agent-test account exists' id agent-test
check 'agent-common group exists' getent group agent-common
check 'agent-core group exists' getent group agent-core

if id -nG agent-admin | tr ' ' '\n' | grep -qx agent-core; then ok 'agent-admin belongs to agent-core'; else no 'agent-admin belongs to agent-core'; fi
if id -nG agent-test | tr ' ' '\n' | grep -qx agent-core; then no 'agent-test must not belong to agent-core'; else ok 'agent-test is excluded from agent-core'; fi

if sshd -T 2>/dev/null | grep -q '^port 20022$'; then ok 'SSH port is 20022'; else no 'SSH port is 20022'; fi
if sshd -T 2>/dev/null | grep -q '^permitrootlogin no$'; then ok 'Root SSH login is disabled'; else no 'Root SSH login is disabled'; fi
if ss -ltnH | awk '$4 ~ /:20022$/ {found=1} END {exit !found}'; then ok 'sshd listens on 20022'; else no 'sshd listens on 20022'; fi

if ufw status 2>/dev/null | grep -q '^Status: active'; then ok 'UFW is active'; else no 'UFW is active'; fi
if ufw status 2>/dev/null | grep -q '20022/tcp'; then ok 'UFW allows 20022/tcp'; else no 'UFW allows 20022/tcp'; fi
if ufw status 2>/dev/null | grep -q '15034/tcp'; then ok 'UFW allows 15034/tcp'; else no 'UFW allows 15034/tcp'; fi

check 'monitor.sh mode is 750' bash -c '[[ "$(stat -c %a /home/agent-admin/agent-app/bin/monitor.sh)" == 750 ]]'
check 'monitor.sh owner/group is agent-dev:agent-core' bash -c '[[ "$(stat -c %U:%G /home/agent-admin/agent-app/bin/monitor.sh)" == agent-dev:agent-core ]]'
check 'mission key t_secret.key exists' test -f /home/agent-admin/agent-app/api_keys/t_secret.key
check 'binary key secret.key exists' test -f /home/agent-admin/agent-app/api_keys/secret.key
check 'logrotate policy exists' test -f /etc/logrotate.d/agent-app
check 'agent-admin cron is registered' bash -c "crontab -u agent-admin -l | grep -Fq '/home/agent-admin/agent-app/bin/monitor.sh'"

if pgrep -u agent-admin -x agent-app >/dev/null 2>&1; then ok 'agent-app process is running'; else no 'agent-app process is running'; fi
if ss -ltnH | awk '$4 ~ /:15034$/ {found=1} END {exit !found}'; then ok 'agent-app listens on 15034'; else no 'agent-app listens on 15034'; fi

printf '\nSummary: PASS=%d FAIL=%d\n' "$pass" "$fail"
(( fail == 0 ))
