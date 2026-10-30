#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p 'build/Mandarin Lens.app/Contents/MacOS'
xcrun swiftc -target arm64-apple-macos15.0 -parse-as-library Sources/MandarinLens/*.swift -o 'build/Mandarin Lens.app/Contents/MacOS/MandarinLens' -framework SwiftUI -framework Translation -framework AppKit -framework NaturalLanguage -framework ApplicationServices -framework Vision
cp Info.plist 'build/Mandarin Lens.app/Contents/Info.plist'
codesign --force --sign - 'build/Mandarin Lens.app'
