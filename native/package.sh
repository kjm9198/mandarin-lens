#!/bin/zsh
set -eu
cd "$(dirname "$0")"
if [ "${LENS_SKIP_BUILD:-0}" != "1" ]; then ./build.sh; fi
mkdir -p build/dmg-staging-v37
ditto 'build/Mandarin Lens 3.7.app' 'build/dmg-staging-v37/Mandarin Lens 3.7.app'
if [ ! -L build/dmg-staging-v37/Applications ]; then ln -s /Applications build/dmg-staging-v37/Applications; fi
hdiutil create -volname 'Mandarin Lens 3.7' -srcfolder build/dmg-staging-v37 -ov -format UDZO build/MandarinLens-3.7-private.dmg
(cd build && shasum -a 256 MandarinLens-3.7-private.dmg > MandarinLens-3.7-private.dmg.sha256)
