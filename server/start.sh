#!/bin/sh
set -eu
umask 077
cd -P "$(dirname "$0")"
start_lock="/tmp/littlelearning-sync-start-$(id -u).lock"
if ! mkdir "$start_lock" 2>/dev/null; then echo 'Another start is in progress'; exit 1; fi
trap 'rmdir "$start_lock"' EXIT
if [ -f service.pid ]; then
    pid=$(cat service.pid)
    if kill -0 "$pid" 2>/dev/null && [ "$(readlink "/proc/$pid/exe" 2>/dev/null)" = "$PWD/learning-server" ]; then
        echo "Already running (PID $pid)"; exit 0
    fi
fi
# QNAP has no nohup here. The detached child inherits ignored SIGHUP.
sh -c 'trap "" HUP; exec ./learning-server -config config.json' </dev/null >>service.log 2>&1 &
pid=$!
echo "$pid" > service.pid
sleep 1
if ! kill -0 "$pid" 2>/dev/null; then echo 'Start failed; inspect service.log'; exit 1; fi
echo "Started (PID $pid)"
