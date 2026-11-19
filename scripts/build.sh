#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/stroke-data build/zip
site="$(mktemp -d "$PWD/build/site.XXXXXX")"
trap 'rm -rf "$site"' EXIT
archive="build/hanzi-writer-data-2.0.1.tgz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --silent --show-error --retry 2 \
    https://registry.npmjs.org/hanzi-writer-data/-/hanzi-writer-data-2.0.1.tgz \
    --output "$archive.part"
  mv "$archive.part" "$archive"
fi
python3 scripts/hanzi.py "$archive" build/stroke-data
package="build/zip/GPT Welcome"
app="$package/GPT Welcome.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Sources/Info.plist "$app/Contents/"
cp LICENSE Sources/Welcome.html web/greeting.css web/greeting.js web/letter-strokes.js build/stroke-data/hanzi-strokes.js build/stroke-data/ARPHICPL.TXT "$app/Contents/Resources/"
for arch in arm64 x86_64; do
  swiftc -O -target "${arch}-apple-macos13.0" -module-cache-path build/swift-cache \
    Sources/GreetingSettings.swift Sources/main.swift -o "build/GPTWelcome-$arch"
done
lipo -create build/GPTWelcome-arm64 build/GPTWelcome-x86_64 -output "$app/Contents/MacOS/GPTWelcome"
chmod 755 "$app/Contents/MacOS/GPTWelcome"
xattr -cr "$app"
codesign --force --sign "${SIGNING_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
ditto -c -k --norsrc --keepParent "$package" "$site/GPT-Welcome.zip"
cp web/index.html web/greeting.css web/greeting.js web/letter-strokes.js "$site/"
rm -rf build/site
mv "$site" build/site
