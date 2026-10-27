#!/bin/sh
set -eu
CONF=/etc/config/qpkg.conf
NAME=LittleLearningSync
PACKAGE=$(/sbin/getcfg "$NAME" Install_Path -f "$CONF")
SERVICE=/share/CACHEDEV2_DATA/homes/yangyao/littlelearning-sync
run_as_owner() { /usr/bin/sudo -u yangyao -- /bin/sh "$SERVICE/$1"; }
case "${1:-}" in
 start)
    [ "$(/sbin/getcfg "$NAME" Enable -u -d FALSE -f "$CONF")" = TRUE ] || exit 1
    touch "$PACKAGE/.start-enabled"
    if run_as_owner start.sh; then exit 0; fi
    # Network/storage may not be ready when QTS starts applications.
    # Only the fixed command below runs, and always as the unprivileged owner.
    (
      trap '' HUP
      attempts=0
      while [ "$attempts" -lt 60 ] && [ -f "$PACKAGE/.start-enabled" ]; do
        sleep 5
        [ -f "$PACKAGE/.start-enabled" ] || exit 0
        if run_as_owner start.sh; then exit 0; fi
        attempts=$((attempts+1))
      done
    ) </dev/null >>"$PACKAGE/startup.log" 2>&1 &
    ;;
 stop|remove)
    rm -f "$PACKAGE/.start-enabled"
    run_as_owner stop.sh
    ;;
 restart)
    "$0" stop
    "$0" start
    ;;
 *) echo "Usage: $0 {start|stop|restart|remove}"; exit 1 ;;
esac
