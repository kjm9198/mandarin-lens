#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [ "${LENS_SKIP_BUILD:-0}" != "1" ]; then ./build.sh; fi
stage="$(mktemp -d build/dmg-staging-v43.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
ditto 'build/Kamihi Lens.app' "$stage/Kamihi Lens.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname 'Kamihi Lens' -srcfolder "$stage" -ov -format UDZO build/KamihiLens-4.3.0-macOS-arm64.dmg
(cd build && shasum -a 256 KamihiLens-4.3.0-macOS-arm64.dmg > KamihiLens-4.3.0-macOS-arm64.dmg.sha256)
