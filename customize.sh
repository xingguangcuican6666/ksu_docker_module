#!/sbin/sh

check_kernel_configs() {
    if [ ! -f /proc/config.gz ]; then
        abort "  [✘] 错误: 未检测到 /proc/config.gz，内核未开启 IKCONFIG_PROC，无法验证，安装终止。"
    fi

    local REQ_CONFIGS="CONFIG_SYSVIPC CONFIG_POSIX_MQUEUE CONFIG_IPC_NS CONFIG_PID_NS CONFIG_DEVTMPFS CONFIG_USER_NS"
    local OPT_CONFIGS="CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_NETFILTER_XT_TARGET_REJECT CONFIG_NETFILTER_XT_TARGET_LOG CONFIG_NETFILTER_XT_MATCH_RECENT CONFIG_IP_SET CONFIG_IP_SET_HASH_IP CONFIG_IP_SET_HASH_NET CONFIG_NETFILTER_XT_SET CONFIG_TMPFS_POSIX_ACL CONFIG_TMPFS_XATTR"
    local ANY_REQ_FAIL=0

    ui_print "- 检查 必备 (Required) 内核参数:"
    for cfg in $REQ_CONFIGS; do
        if zcat /proc/config.gz | grep -q "^${cfg}=y"; then
            ui_print "  [✔] $cfg = y"
        else
            ui_print "  [✘] $cfg (缺失)"
            ANY_REQ_FAIL=1
        fi
    done

    ui_print "- 检查 可选 (Optional) 功能参数:"
    for cfg in $OPT_CONFIGS; do
        if zcat /proc/config.gz | grep -q "^${cfg}=y"; then
            ui_print "  [✔] $cfg = y"
        else
            ui_print "  [!] $cfg (未开启)"
        fi
    done

    if [ "$ANY_REQ_FAIL" -eq 1 ]; then
        abort "  [✘] 错误: 当前内核不满足 Docker 运行必备的硬性条件，安装终止。"
    fi
}

check_kernel_configs

if [ -f "$MODPATH/symlinks.txt" ]; then
    ui_print "- 正在恢复符号链接..."
    while IFS='|' read -r link_path target; do
        FULL_LINK_PATH="$MODPATH/$link_path"
        mkdir -p "$(dirname "$FULL_LINK_PATH")"
        ln -sf "$target" "$FULL_LINK_PATH"
    done < "$MODPATH/symlinks.txt"
    rm "$MODPATH/symlinks.txt"
fi

chmod -R 755 "$MODPATH/system/bin/"
chmod -R 755 "$MODPATH/system/"
chmod -R 755 "$MODPATH/scripts/"
