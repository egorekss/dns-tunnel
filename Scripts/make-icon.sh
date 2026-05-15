#!/bin/bash
# Генерирует AppIcon.icns для DNS Tunnel.
# Рисует SF Symbol "shield.checkered" на градиентном фоне в нескольких размерах,
# затем упаковывает в .icns через iconutil.
set -e

OUT="${1:-AppIcon.icns}"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# Swift-скрипт рисует одну PNG нужного размера
GEN="$TMP/gen.swift"
cat > "$GEN" <<'SWIFT'
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let size = Int(args[1]) else {
    print("usage: gen <size> <outpath>")
    exit(1)
}
let outPath = args[2]

let s = CGFloat(size)
let img = NSImage(size: NSSize(width: s, height: s))
img.lockFocus()

// Скруглённый фон с градиентом
let rect = NSRect(x: 0, y: 0, width: s, height: s)
let radius = s * 0.22
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.36, blue: 0.85, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.55, alpha: 1.0),
])!
gradient.draw(in: rect, angle: -90)

// SF Symbol shield
let conf = NSImage.SymbolConfiguration(pointSize: s * 0.62, weight: .semibold)
if let shield = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: nil)?
    .withSymbolConfiguration(conf) {
    let shieldSize = shield.size
    let drawRect = NSRect(
        x: (s - shieldSize.width) / 2,
        y: (s - shieldSize.height) / 2 - s * 0.02,
        width: shieldSize.width,
        height: shieldSize.height
    )
    NSColor.white.set()
    shield.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 0.95)
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("png conversion failed"); exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
SWIFT

swiftc "$GEN" -o "$TMP/gen" 2>/dev/null

declare -a sizes=(16 32 64 128 256 512 1024)
for size in "${sizes[@]}"; do
    "$TMP/gen" "$size" "$ICONSET/icon_${size}x${size}.png"
    if [ "$size" -lt 1024 ]; then
        next=$((size * 2))
        "$TMP/gen" "$next" "$ICONSET/icon_${size}x${size}@2x.png"
    fi
done

iconutil -c icns "$ICONSET" -o "$OUT"
echo "✅ Готово: $OUT"
