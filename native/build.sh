#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p 'build/Mandarin Lens 3.7.app/Contents/MacOS'
xcrun swiftc -O -target arm64-apple-macos15.0 -parse-as-library Sources/MandarinLens/*.swift -o 'build/Mandarin Lens 3.7.app/Contents/MacOS/MandarinLens' -framework SwiftUI -framework Translation -framework AppKit -framework NaturalLanguage -framework ApplicationServices -framework Vision -framework Security -framework AVFoundation -framework Carbon -framework Speech
mkdir -p 'build/Mandarin Lens 3.7.app/Contents/Resources'
cp Resources/*.py 'build/Mandarin Lens 3.7.app/Contents/Resources/'
cp Info.plist 'build/Mandarin Lens 3.7.app/Contents/Info.plist'
# A stable local development signature lets macOS retain permission grants across rebuilds.
signing_identity="${LENS_SIGNING_IDENTITY:-}"
if [ -z "$signing_identity" ]; then
  signing_identity="$(security find-identity -v -p codesigning | sed -nE 's/.* ([A-F0-9]{40}) "Apple Development:.*$/\1/p' | head -n 1)"
fi
codesign --force --sign "${signing_identity:--}" --timestamp=none 'build/Mandarin Lens 3.7.app'
codesign --verify --strict 'build/Mandarin Lens 3.7.app'
