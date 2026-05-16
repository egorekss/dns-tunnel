#!/bin/bash
# Helper script для DNS Tunnel App. Универсальный — параметры приходят с CLI.
# Должен лежать в /usr/local/bin/proxy-tunnel.sh с правами root.
# Вызывается приложением через osascript "do shell script ... with administrator privileges".
#
# Использование:
#   proxy-tunnel.sh connect <domain> <password> <server_ip>
#   proxy-tunnel.sh disconnect
#   proxy-tunnel.sh status
#   proxy-tunnel.sh kill-vpns <proc_name> [<proc_name>...]

set -u

TUNNEL_GW="10.0.66.1"
PID_FILE="/tmp/proxy-tunnel.pid"
LOG_FILE="/tmp/proxy-tunnel.log"
STATE_FILE="/tmp/proxy-tunnel.state"

IODINE_BIN=""
for candidate in /opt/homebrew/sbin/iodine /opt/homebrew/bin/iodine /usr/local/sbin/iodine /usr/local/bin/iodine; do
    if [ -x "$candidate" ]; then
        IODINE_BIN="$candidate"
        break
    fi
done
if [ -z "$IODINE_BIN" ] && [ "${1:-}" = "connect" ]; then
    echo "iodine binary not found (brew install iodine)" >&2
    exit 1
fi

active_service() {
    local dev
    dev=$(/sbin/route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    [ -z "$dev" ] && return 1
    /usr/sbin/networksetup -listnetworkserviceorder | awk -v dev="$dev" '
        /^\([0-9]+\)/ { name=$0; sub(/^\([0-9]+\) /, "", name) }
        $0 ~ "Device: " dev "\\)" { print name; exit }
    '
}

cmd_connect() {
    local domain="${1:-}"
    local password="${2:-}"
    local server_ip="${3:-}"
    if [ -z "$domain" ] || [ -z "$password" ] || [ -z "$server_ip" ]; then
        echo "Usage: $0 connect <domain> <password> <server_ip>" >&2
        exit 2
    fi

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Туннель уже запущен (PID $(cat "$PID_FILE"))"
        exit 0
    fi

    local orig_gw orig_dev orig_service orig_dns
    orig_gw=$(/sbin/route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')
    orig_dev=$(/sbin/route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    if [ -z "$orig_gw" ]; then
        echo "Нет default route — нет интернета?" >&2
        exit 1
    fi
    orig_service=$(active_service)
    if [ -z "$orig_service" ]; then
        echo "Не удалось определить активный network service" >&2
        exit 1
    fi
    orig_dns=$(/usr/sbin/networksetup -getdnsservers "$orig_service" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

    cat > "$STATE_FILE" <<EOF
ORIG_GW=$orig_gw
ORIG_DEV=$orig_dev
ORIG_SERVICE=$orig_service
ORIG_DNS=$orig_dns
SERVER_IP=$server_ip
EOF
    chmod 600 "$STATE_FILE"

    # 1. Pin route к серверу через оригинальный gateway, чтобы туннель не съел сам себя
    /sbin/route -n add -host "$server_ip" "$orig_gw" >/dev/null 2>&1 || \
        /sbin/route -n change -host "$server_ip" "$orig_gw" >/dev/null 2>&1

    # 2. Стартуем iodine в фоне (без nohup — он не работает без TTY в osascript)
    : > "$LOG_FILE"
    "$IODINE_BIN" -f -r -P "$password" "$domain" </dev/null >>"$LOG_FILE" 2>&1 &
    local iodine_pid=$!
    disown "$iodine_pid" 2>/dev/null || true
    echo "$iodine_pid" > "$PID_FILE"

    # 3. Ждём появления utun интерфейса с IP 10.0.66.x (до 15 сек)
    local tunnel_iface=""
    for i in $(seq 1 30); do
        sleep 0.5
        if ! kill -0 "$iodine_pid" 2>/dev/null; then
            echo "iodine упал. См. $LOG_FILE" >&2
            rm -f "$PID_FILE"
            cmd_disconnect_internal
            exit 1
        fi
        tunnel_iface=$(/sbin/ifconfig | awk '/^utun/ {iface=$1; sub(":","",iface)} /inet 10\.0\.66\./ {print iface; exit}')
        [ -n "$tunnel_iface" ] && break
    done

    if [ -z "$tunnel_iface" ]; then
        echo "Туннель не поднялся за 15 сек. См. $LOG_FILE" >&2
        kill "$iodine_pid" 2>/dev/null
        rm -f "$PID_FILE"
        cmd_disconnect_internal
        exit 1
    fi

    # 4. Меняем default route
    /sbin/route -n delete default >/dev/null 2>&1
    /sbin/route -n add default "$TUNNEL_GW" >/dev/null 2>&1

    # 5. DNS — НЕ через туннель (иначе зацикл). Ставим публичные.
    /usr/sbin/networksetup -setdnsservers "$orig_service" 1.1.1.1 8.8.8.8

    echo "Туннель активен через $tunnel_iface (gw $TUNNEL_GW). PID iodine: $iodine_pid"
}

cmd_disconnect_internal() {
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        . "$STATE_FILE"
        /sbin/route -n delete default >/dev/null 2>&1
        if [ -n "${ORIG_GW:-}" ]; then
            /sbin/route -n add default "$ORIG_GW" >/dev/null 2>&1
        fi
        if [ -n "${SERVER_IP:-}" ]; then
            /sbin/route -n delete -host "$SERVER_IP" >/dev/null 2>&1
        fi
        if [ -n "${ORIG_SERVICE:-}" ]; then
            if [ -z "${ORIG_DNS:-}" ] || echo "$ORIG_DNS" | grep -qi "aren't"; then
                /usr/sbin/networksetup -setdnsservers "$ORIG_SERVICE" Empty
            else
                # shellcheck disable=SC2086
                /usr/sbin/networksetup -setdnsservers "$ORIG_SERVICE" $(echo "$ORIG_DNS" | tr ',' ' ')
            fi
        fi
        rm -f "$STATE_FILE"
    fi
}

cmd_disconnect() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            for i in $(seq 1 10); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.3
            done
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    cmd_disconnect_internal
    echo "Туннель остановлен, маршруты восстановлены"
}

cmd_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "running PID=$(cat "$PID_FILE")"
        exit 0
    fi
    echo "stopped"
    exit 1
}

cmd_kill_vpns() {
    for proc in "$@"; do
        pkill -x "$proc" 2>/dev/null || true
        pkill -f "$proc" 2>/dev/null || true
    done
    echo "killed: $*"
}

case "${1:-}" in
    connect) shift; cmd_connect "$@" ;;
    disconnect) cmd_disconnect ;;
    status) cmd_status ;;
    kill-vpns) shift; cmd_kill_vpns "$@" ;;
    *) echo "Usage: $0 {connect <domain> <pass> <ip> | disconnect | status | kill-vpns <name>...}"; exit 2 ;;
esac
