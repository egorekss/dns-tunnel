#!/bin/bash
# Устанавливает helper-скрипт в /usr/local/bin.
# Helper нужен для управления роутами и iodine с правами root.
set -e

cd "$(dirname "$0")/.."

HELPER_DST="/usr/local/bin/proxy-tunnel.sh"
HELPER_SRC="Resources/proxy-tunnel.sh"

if [ ! -f "$HELPER_SRC" ]; then
    echo "❌ Не найден $HELPER_SRC" >&2
    exit 1
fi

echo "▶ Установка $HELPER_SRC → $HELPER_DST"
echo "  (потребуется пароль администратора)"

# TCC иногда блокирует sudo на файлы из ~/Desktop. Стейджим в /tmp.
TMP=/tmp/proxy-tunnel-installer.sh
cp "$HELPER_SRC" "$TMP"
chmod 755 "$TMP"

osascript -e "do shell script \"install -m 755 -o root -g wheel $TMP $HELPER_DST && rm $TMP && echo OK\" with administrator privileges"

echo "✅ Helper установлен."
echo ""
echo "Проверка:"
"$HELPER_DST" status || echo "(статус: остановлен — это норма для свежей установки)"
