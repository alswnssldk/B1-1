#!/usr/bin/env bash
# Optional bonus: summarize CPU/MEM/DISK values in monitor.log.

set -u

LOG_FILE="${1:-/var/log/agent-app/monitor.log}"

if [[ ! -f "$LOG_FILE" ]]; then
    printf '[ERROR] Log file not found: %s\n' "$LOG_FILE" >&2
    exit 1
fi

if [[ ! -s "$LOG_FILE" ]]; then
    printf '[WARNING] No samples in: %s\n' "$LOG_FILE"
    exit 0
fi

awk '
function value_after(prefix,    i, item) {
    for (i = 1; i <= NF; i++) {
        if (index($i, prefix) == 1) {
            item = $i
            sub(prefix, "", item)
            sub(/%$/, "", item)
            return item + 0
        }
    }
    return ""
}
{
    timestamp = substr($0, 2, 19)
    cpu = value_after("CPU:")
    mem = value_after("MEM:")
    disk = value_after("DISK_USED:")
    if (cpu == "" || mem == "" || disk == "") next

    count++
    cpu_sum += cpu; mem_sum += mem; disk_sum += disk

    if (count == 1 || cpu > cpu_max) { cpu_max=cpu; cpu_max_time=timestamp }
    if (count == 1 || cpu < cpu_min) { cpu_min=cpu; cpu_min_time=timestamp }
    if (count == 1 || mem > mem_max) { mem_max=mem; mem_max_time=timestamp }
    if (count == 1 || mem < mem_min) { mem_min=mem; mem_min_time=timestamp }
    if (count == 1 || disk > disk_max) { disk_max=disk; disk_max_time=timestamp }
    if (count == 1 || disk < disk_min) { disk_min=disk; disk_min_time=timestamp }
}
END {
    if (count == 0) {
        print "[WARNING] No valid samples found."
        exit 0
    }

    print "====== STATISTICS REPORT ======"
    printf "[CPU]\nAverage : %.1f%%\nMaximum : %.1f%% at %s\nMinimum : %.1f%% at %s\n", cpu_sum/count, cpu_max, cpu_max_time, cpu_min, cpu_min_time
    printf "[Memory]\nAverage : %.1f%%\nMaximum : %.1f%% at %s\nMinimum : %.1f%% at %s\n", mem_sum/count, mem_max, mem_max_time, mem_min, mem_min_time
    printf "[Disk]\nAverage : %.1f%%\nMaximum : %.1f%% at %s\nMinimum : %.1f%% at %s\n", disk_sum/count, disk_max, disk_max_time, disk_min, disk_min_time
    printf "[Samples]\nData Points: %d samples\n", count
}
' "$LOG_FILE"
