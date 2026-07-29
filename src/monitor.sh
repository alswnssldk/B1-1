#!/usr/bin/env bash
# Linux Agent health/resource monitor
# Required runtime owner/group/mode: agent-dev:agent-core 750

set -u

APP_USER="${AGENT_APP_USER:-agent-admin}"
PROCESS_NAME="${AGENT_PROCESS_NAME:-agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="${MONITOR_LOG_FILE:-${AGENT_LOG_DIR}/monitor.log}"
CPU_THRESHOLD="${CPU_THRESHOLD:-20}"
MEM_THRESHOLD="${MEM_THRESHOLD:-10}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"

warning_count=0

warn() {
    printf '[WARNING] %s\n' "$*"
    warning_count=$((warning_count + 1))
}

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

is_greater_than() {
    awk -v value="$1" -v threshold="$2" 'BEGIN { exit !(value > threshold) }'
}

read_cpu_snapshot() {
    local cpu user nice system idle iowait irq softirq steal guest guest_nice
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    CPU_IDLE=$((idle + iowait))
    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

get_cpu_usage() {
    local first_idle first_total second_idle second_total idle_delta total_delta

    read_cpu_snapshot
    first_idle=$CPU_IDLE
    first_total=$CPU_TOTAL
    sleep 1
    read_cpu_snapshot
    second_idle=$CPU_IDLE
    second_total=$CPU_TOTAL

    idle_delta=$((second_idle - first_idle))
    total_delta=$((second_total - first_total))

    if (( total_delta <= 0 )); then
        printf '0.0'
        return
    fi

    awk -v idle="$idle_delta" -v total="$total_delta" \
        'BEGIN { printf "%.1f", (total - idle) * 100 / total }'
}

get_memory_usage() {
    awk '
        /^MemTotal:/ { total=$2 }
        /^MemAvailable:/ { available=$2 }
        END {
            if (total > 0) printf "%.1f", (total - available) * 100 / total
            else printf "0.0"
        }
    ' /proc/meminfo
}

get_disk_usage() {
    df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }'
}

printf '====== SYSTEM MONITOR RESULT ======\n\n'
printf '[HEALTH CHECK]\n'

PID="$(pgrep -o -u "$APP_USER" -x "$PROCESS_NAME" 2>/dev/null || true)"
if [[ -z "$PID" ]]; then
    fail "Process '${PROCESS_NAME}' is not running as ${APP_USER}."
fi
printf "Checking process '%s'... [OK] (PID: %s)\n" "$PROCESS_NAME" "$PID"

if ! ss -ltnH | awk -v port="$AGENT_PORT" '$4 ~ (":" port "$" ) { found=1 } END { exit !found }'; then
    fail "TCP port ${AGENT_PORT} is not in LISTEN state."
fi
printf 'Checking port %s... [OK]\n' "$AGENT_PORT"

if command -v ufw >/dev/null 2>&1; then
    if sudo -n /usr/sbin/ufw status 2>/dev/null | grep -q '^Status: active'; then
        printf 'Checking UFW... [OK] (active)\n'
    else
        warn 'UFW is inactive or its status could not be read.'
    fi
else
    warn 'UFW command is unavailable.'
fi

[[ -d "$AGENT_LOG_DIR" ]] || fail "Log directory does not exist: ${AGENT_LOG_DIR}"
[[ -w "$AGENT_LOG_DIR" ]] || fail "Log directory is not writable: ${AGENT_LOG_DIR}"

printf '\n[RESOURCE MONITORING]\n'
CPU_USAGE="$(get_cpu_usage)"
MEM_USAGE="$(get_memory_usage)"
DISK_USAGE="$(get_disk_usage)"

printf 'CPU Usage : %s%%\n' "$CPU_USAGE"
printf 'MEM Usage : %s%%\n' "$MEM_USAGE"
printf 'DISK Used : %s%%\n' "$DISK_USAGE"

if is_greater_than "$CPU_USAGE" "$CPU_THRESHOLD"; then
    warn "CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)."
fi
if is_greater_than "$MEM_USAGE" "$MEM_THRESHOLD"; then
    warn "Memory threshold exceeded (${MEM_USAGE}% > ${MEM_THRESHOLD}%)."
fi
if is_greater_than "$DISK_USAGE" "$DISK_THRESHOLD"; then
    warn "Disk threshold exceeded (${DISK_USAGE}% > ${DISK_THRESHOLD}%)."
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
LOG_LINE="[${TIMESTAMP}] PID:${PID} CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}%"
printf '%s\n' "$LOG_LINE" >> "$LOG_FILE" || fail "Could not append to ${LOG_FILE}."

printf '\n[INFO] Log appended: %s\n' "$LOG_FILE"
printf '[INFO] Warning count: %d\n' "$warning_count"
exit 0
