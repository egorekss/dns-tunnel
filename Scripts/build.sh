#!/bin/bash
# Собирает DNS Tunnel.app — universal binary (arm64 + x86_64) с локализацией.
set -e

cd "$(dirname "$0")/.."

APP_NAME="DNS Tunnel"
EXECUTABLE_NAME="DNSTunnel"
APP_BUNDLE="Build/${APP_NAME}.app"
MIN_MACOS="13.0"

# Архитектуры. По умолчанию — universal. Можно сузить: BUILD_ARCH=arm64 ./build.sh
ARCHS="${BUILD_ARCH:-arm64 x86_64}"

echo "==>Очистка..."
rm -rf "$APP_BUNDLE"

echo "==>Создание структуры .app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==>Генерация app icon..."
if [ -x "Scripts/make-icon.sh" ]; then
    ./Scripts/make-icon.sh "$APP_BUNDLE/Contents/Resources/AppIcon.icns" || \
        echo "(make-icon.sh упал — app будет без иконки)"
fi

SWIFT_FILES=$(find Sources -name '*.swift' | tr '\n' ' ')

# Компилируем под каждую архитектуру отдельно, потом склеиваем lipo
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
ARCH_BINS=()

for arch in $ARCHS; do
    echo "==>Компиляция Swift для $arch..."
    OUT="$TMP_DIR/$EXECUTABLE_NAME-$arch"
    swiftc $SWIFT_FILES \
        -o "$OUT" \
        -framework Cocoa \
        -framework SwiftUI \
        -framework Combine \
        -O \
        -target ${arch}-apple-macos${MIN_MACOS}
    ARCH_BINS+=("$OUT")
done

if [ "${#ARCH_BINS[@]}" -gt 1 ]; then
    echo "==>Сборка universal binary через lipo..."
    lipo -create "${ARCH_BINS[@]}" -output "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
    echo "  Архитектуры:"
    lipo -archs "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | sed 's/^/    /'
else
    cp "${ARCH_BINS[0]}" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
    echo "  Single-arch: $ARCHS"
fi

echo "==>Копирование Info.plist..."
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "==>Копирование локализаций..."
for lproj in Resources/*.lproj; do
    if [ -d "$lproj" ]; then
        cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"
        echo "    $(basename "$lproj")"
    fi
done

echo "==>Подпись (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Done: $APP_BUNDLE"
echo ""
echo "Размер: $(du -sh "$APP_BUNDLE" | awk '{print $1}')"
echo ""
echo "Дальше:"
echo "  1. cp -R \"$APP_BUNDLE\" /Applications/"
echo "  2. ./Scripts/install-helper.sh   # один раз, потребуется sudo"
echo "  3. open /Applications/${APP_NAME}.app"
