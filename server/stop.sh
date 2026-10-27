#!/bin/sh
set -eu
cd -P "$(dirname "$0")"
[ -f service.pid ] || exit 0
pid=$(cat service.pid)
if kill -0 "$pid" 2>/dev/null && [ "$(readlink "/proc/$pid/exe" 2>/dev/null)" = "$PWD/learning-server" ]; then
    kill -TERM "$pid"
    echo "Stopping (PID $pid)"
fi
