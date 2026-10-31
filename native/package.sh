#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [ "${LENS_SKIP_BUILD:-0}" != "1" ]; then ./build.sh; fi
mkdir -p build/dmg-staging-v38
ditto 'build/Kamihi Lens.app' 'build/dmg-staging-v38/Kamihi Lens.app'
if [ ! -L build/dmg-staging-v38/Applications ]; then ln -s /Applications build/dmg-staging-v38/Applications; fi
hdiutil create -volname 'Kamihi Lens' -srcfolder build/dmg-staging-v38 -ov -format UDZO build/KamihiLens-3.8-private.dmg
(cd build && shasum -a 256 KamihiLens-3.8-private.dmg > KamihiLens-3.8-private.dmg.sha256)
