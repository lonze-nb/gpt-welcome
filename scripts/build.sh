#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/site build/zip
app="build/zip/GPT Welcome.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Sources/Info.plist "$app/Contents/"
cp LICENSE Sources/Welcome.html web/greeting.css web/greeting.js "$app/Contents/Resources/"
for arch in arm64 x86_64; do
  swiftc -O -target "${arch}-apple-macos13.0" -module-cache-path build/swift-cache \
    Sources/main.swift -o "build/GPTWelcome-$arch"
done
lipo -create build/GPTWelcome-arm64 build/GPTWelcome-x86_64 -output "$app/Contents/MacOS/GPTWelcome"
chmod 755 "$app/Contents/MacOS/GPTWelcome"
xattr -cr "$app"
codesign --force --sign "${SIGNING_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
rm -f build/site/app-template.zip
ditto -c -k --norsrc --keepParent "$app" build/site/app-template.zip
cp web/index.html web/greeting.css web/greeting.js web/configurator.js web/zip.js build/site/
python3 scripts/offline.py
