#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEST=${1:-"$ROOT/build/Clipboard Archive.app"}
CONTENTS="$DEST/Contents"

case "$(uname -s)" in
  Darwin) ;;
  *) printf '%s\n' "Clipboard Archive can only be built on macOS." >&2; exit 1 ;;
esac

swift build --package-path "$ROOT" --configuration release
mkdir -p "$CONTENTS/MacOS"
cp "$ROOT/.build/release/ClipboardArchive" "$CONTENTS/MacOS/ClipboardArchive"
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ClipboardArchive</string>
  <key>CFBundleIdentifier</key><string>dev.toricreate.ClipboardArchive</string>
  <key>CFBundleName</key><string>Clipboard Archive</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
printf 'Created %s\n' "$DEST"
