#!/usr/bin/env bash
set -u

service cron start >/dev/null 2>&1 || true

trap 'service ssh stop >/dev/null 2>&1 || true; service cron stop >/dev/null 2>&1 || true; exit 0' TERM INT

while true; do
    sleep 3600 &
    wait $!
done
