#!/bin/bash
# render-icon.sh - generate /tmp/Display.icns from the SF Symbol "display".
#
# This is what the menu bar item uses at runtime, and it's also baked into
# the .app's Finder icon (Contents/Resources/applet.icns) by build.sh.
#
# Run once after cloning, or any time you want to change the icon.

set -euo pipefail

cat > /tmp/_render_icon.swift <<'SWIFT'
import Cocoa

guard let img = NSImage(systemSymbolName: "display", accessibilityDescription: "Display") else {
    FileHandle.standardError.write("SF Symbol not found\n".data(using: .utf8)!)
    exit(1)
}

let outSize = NSSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(outSize.width),
    pixelsHigh: Int(outSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
)!

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 760, weight: .regular)
let configured = img.withSymbolConfiguration(symbolConfig) ?? img

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(origin: .zero, size: outSize).fill()
configured.draw(in: NSRect(x: 132, y: 132, width: 760, height: 760),
                from: NSRect(origin: .zero, size: configured.size),
                operation: .sourceOver,
                fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: "/tmp/display-icon-1024.png"))
SWIFT

swift /tmp/_render_icon.swift

ICONSET=/tmp/icon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in "16 16" "32 32:16x16@2x" "32 32" "64 64:32x32@2x" "128 128" "256 256:128x128@2x" "256 256" "512 512:256x256@2x" "512 512" "1024 1024:512x512@2x"; do
    sz="${spec%:*}"
    name="${spec##*:}"
    [ "$name" = "$spec" ] && name="${sz// /x}"
    sips -z "${sz% *}" "${sz#* }" /tmp/display-icon-1024.png --out "$ICONSET/icon_${name}.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o /tmp/Display.icns
echo "Wrote /tmp/Display.icns"
