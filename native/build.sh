#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p 'build/Kamihi Lens.app/Contents/MacOS'
xcrun swiftc -O -target arm64-apple-macos15.0 -parse-as-library Sources/MandarinLens/*.swift -o 'build/Kamihi Lens.app/Contents/MacOS/MandarinLens' -framework SwiftUI -framework Translation -framework AppKit -framework NaturalLanguage -framework ApplicationServices -framework Vision -framework Security -framework AVFoundation -framework Carbon -framework Speech -framework ScreenCaptureKit
mkdir -p 'build/Kamihi Lens.app/Contents/Resources'
cp Resources/*.py 'build/Kamihi Lens.app/Contents/Resources/'
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns 'build/Kamihi Lens.app/Contents/Resources/'; fi
cp Info.plist 'build/Kamihi Lens.app/Contents/Info.plist'
# A stable local development signature lets macOS retain permission grants across rebuilds.
signing_identity="${LENS_SIGNING_IDENTITY:-}"
if [ -z "$signing_identity" ]; then
  signing_identity="$(security find-identity -v -p codesigning | sed -nE 's/.* ([A-F0-9]{40}) "Apple Development:.*$/\1/p' | head -n 1)"
fi
codesign --force --sign "${signing_identity:--}" --timestamp=none 'build/Kamihi Lens.app'
codesign --verify --strict 'build/Kamihi Lens.app'
