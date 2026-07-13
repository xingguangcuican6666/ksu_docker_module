#!/system/bin/sh
MODDIR=${0%/*}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
done

exec "$MODDIR/scripts/dockerctl.sh" boot-start
