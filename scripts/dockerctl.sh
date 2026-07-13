#!/system/bin/sh

SELF="$0"
case "$SELF" in
    */scripts/*)
        MODDIR=${SELF%/scripts/*}
        ;;
    *)
        MODDIR=$(CDPATH= cd -- "$(dirname -- "$SELF")/.." 2>/dev/null && pwd)
        ;;
esac

STATE_DIR="/data/docker/ksu"
DAEMON_FILE="$STATE_DIR/daemon.json"
SETTINGS_FILE="$STATE_DIR/settings.json"
CLIENT_HOST_FILE="$STATE_DIR/client_host"
DEFAULT_DAEMON_FILE="$MODDIR/system/etc/docker/daemon.json"
LOG_FILE="/data/docker/dockerd_boot.log"

export PATH="$MODDIR/system/bin:/system/bin:$PATH"
export HOME=/data/docker
export TMPDIR=/dev/docker

die() {
    echo "$1" >&2
    exit 1
}

ensure_state() {
    mkdir -p /data/docker "$STATE_DIR" /dev/docker
    chmod 777 /dev/docker 2>/dev/null
    ln -sf /dev/docker /tmp

    if [ ! -f "$DAEMON_FILE" ]; then
        cp "$DEFAULT_DAEMON_FILE" "$DAEMON_FILE" || die "failed to create daemon config"
    fi

    if [ ! -f "$SETTINGS_FILE" ]; then
        write_default_settings >"$SETTINGS_FILE" || die "failed to create settings"
    fi

    sync_client_host_file
}

write_default_settings() {
    cat <<'EOF'
{
  "autostart": true,
  "clientHost": "unix:///dev/docker/docker.sock"
}
EOF
}

json_compact() {
    tr -d '\r\n' <"$1"
}

json_string() {
    local compact key
    compact=$(json_compact "$1")
    key=$2
    printf '%s' "$compact" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

json_bool() {
    local compact key
    compact=$(json_compact "$1")
    key=$2
    printf '%s' "$compact" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\\(true\\|false\\).*/\\1/p" | head -n 1
}

decode_b64_to_file() {
    local target
    target=$1

    if command -v base64 >/dev/null 2>&1; then
        printf '%s' "$PAYLOAD_B64" | base64 -d >"$target" 2>/dev/null && return 0
    fi

    if command -v busybox >/dev/null 2>&1; then
        printf '%s' "$PAYLOAD_B64" | busybox base64 -d >"$target" 2>/dev/null && return 0
    fi

    return 1
}

sync_client_host_file() {
    local host
    host=$(json_string "$SETTINGS_FILE" "clientHost")
    [ -n "$host" ] || host="unix:///dev/docker/docker.sock"
    printf '%s\n' "$host" >"$CLIENT_HOST_FILE"
    chmod 600 "$CLIENT_HOST_FILE" 2>/dev/null
}

client_host() {
    ensure_state
    if [ -f "$CLIENT_HOST_FILE" ]; then
        cat "$CLIENT_HOST_FILE"
    else
        printf '%s\n' "unix:///dev/docker/docker.sock"
    fi
}

ensure_runtime_paths() {
    local data_root exec_root pid_file pid_dir
    data_root=$(json_string "$DAEMON_FILE" "data-root")
    exec_root=$(json_string "$DAEMON_FILE" "exec-root")
    pid_file=$(json_string "$DAEMON_FILE" "pidfile")

    [ -n "$data_root" ] && mkdir -p "$data_root"
    [ -n "$exec_root" ] && mkdir -p "$exec_root"
    if [ -n "$pid_file" ]; then
        pid_dir=${pid_file%/*}
        [ "$pid_dir" != "$pid_file" ] && mkdir -p "$pid_dir"
    fi

    [ -n "$data_root" ] && chmod 711 "$data_root" 2>/dev/null
}

find_dockerd_pids() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -x dockerd 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//'
        return
    fi

    ps -A 2>/dev/null | awk '/[d]ockerd/ { print $2 }' | tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

has_running_dockerd() {
    [ -n "$(find_dockerd_pids)" ]
}

socket_state() {
    local host socket_path
    host=$(client_host)
    case "$host" in
        unix://*)
            socket_path=${host#unix://}
            [ -S "$socket_path" ] && return 0
            ;;
    esac
    return 1
}

print_status() {
    local pids state autostart host
    ensure_state

    pids=$(find_dockerd_pids)
    if [ -n "$pids" ]; then
        if socket_state; then
            state="running"
        else
            state="starting"
        fi
    else
        state="stopped"
    fi

    autostart=$(json_bool "$SETTINGS_FILE" "autostart")
    [ -n "$autostart" ] || autostart="true"
    host=$(client_host)

    printf 'state=%s\n' "$state"
    printf 'pids=%s\n' "$pids"
    printf 'autostart=%s\n' "$autostart"
    printf 'client_host=%s\n' "$host"
    printf 'log_file=%s\n' "$LOG_FILE"
}

start_docker() {
    ensure_state
    ensure_runtime_paths

    if has_running_dockerd; then
        echo "Docker is already running."
        return 0
    fi

    "$MODDIR/system/bin/dockerd" --config-file "$DAEMON_FILE" >"$LOG_FILE" 2>&1 &
    echo "Docker start command dispatched."
}

stop_docker() {
    local pid_file
    ensure_state

    if command -v pkill >/dev/null 2>&1; then
        pkill -x dockerd 2>/dev/null
        pkill -f "/data/adb/modules/native_docker/system/libexec/dockerd" 2>/dev/null
    else
        local pids
        pids=$(find_dockerd_pids)
        [ -n "$pids" ] && kill $pids 2>/dev/null
    fi

    pid_file=$(json_string "$DAEMON_FILE" "pidfile")
    [ -n "$pid_file" ] && rm -f "$pid_file" 2>/dev/null
    echo "Docker stop command dispatched."
}

restart_docker() {
    stop_docker >/dev/null 2>&1
    sleep 1
    start_docker
}

show_log() {
    ensure_state
    if [ -f "$LOG_FILE" ]; then
        tail -n 120 "$LOG_FILE"
    else
        echo "No docker log yet."
    fi
}

save_state() {
    local daemon_tmp settings_tmp
    ensure_state
    [ -n "$CONFIG_B64" ] || die "CONFIG_B64 is required"
    [ -n "$SETTINGS_B64" ] || die "SETTINGS_B64 is required"

    daemon_tmp=$(mktemp /tmp/docker-config.XXXXXX) || die "failed to create temp file"
    settings_tmp=$(mktemp /tmp/docker-settings.XXXXXX) || die "failed to create temp file"

    PAYLOAD_B64=$CONFIG_B64
    decode_b64_to_file "$daemon_tmp" || die "failed to decode daemon config"
    PAYLOAD_B64=$SETTINGS_B64
    decode_b64_to_file "$settings_tmp" || die "failed to decode ui settings"

    mv "$daemon_tmp" "$DAEMON_FILE" || die "failed to store daemon config"
    mv "$settings_tmp" "$SETTINGS_FILE" || die "failed to store settings"
    chmod 600 "$DAEMON_FILE" "$SETTINGS_FILE" 2>/dev/null
    sync_client_host_file

    echo "Saved configuration."
}

reset_state() {
    ensure_state
    cp "$DEFAULT_DAEMON_FILE" "$DAEMON_FILE" || die "failed to reset daemon config"
    write_default_settings >"$SETTINGS_FILE" || die "failed to reset settings"
    chmod 600 "$DAEMON_FILE" "$SETTINGS_FILE" 2>/dev/null
    sync_client_host_file
    echo "Reset to defaults."
}

boot_start() {
    local autostart
    ensure_state
    autostart=$(json_bool "$SETTINGS_FILE" "autostart")
    [ -n "$autostart" ] || autostart="true"
    if [ "$autostart" = "true" ]; then
        start_docker
    fi
}

usage() {
    cat <<'EOF'
Usage: dockerctl.sh <command>
  init
  status
  start
  stop
  restart
  get-config
  get-settings
  get-log
  save-state
  reset
  boot-start
  client-host
EOF
}

cmd=$1

case "$cmd" in
    init)
        ensure_state
        ;;
    status)
        print_status
        ;;
    start)
        start_docker
        ;;
    stop)
        stop_docker
        ;;
    restart)
        restart_docker
        ;;
    get-config)
        ensure_state
        cat "$DAEMON_FILE"
        ;;
    get-settings)
        ensure_state
        cat "$SETTINGS_FILE"
        ;;
    get-log)
        show_log
        ;;
    save-state)
        save_state
        ;;
    reset)
        reset_state
        ;;
    boot-start)
        boot_start
        ;;
    client-host)
        client_host
        ;;
    ""|-h|--help|help)
        usage
        ;;
    *)
        usage
        die "unknown command: $cmd"
        ;;
esac
