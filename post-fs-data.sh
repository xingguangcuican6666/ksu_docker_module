#!/system/bin/sh
MODDIR=${0%/*}

if [ ! -d "/dev/docker" ]; then
    mkdir -p /dev/docker
    chmod 777 /dev/docker
fi
ln -sf /dev/docker /tmp

"$MODDIR/scripts/dockerctl.sh" init >/dev/null 2>&1
