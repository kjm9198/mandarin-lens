#!/bin/zsh
set -eu
cd "$(dirname "$0")"
./build.sh
mkdir -p build/dmg-staging
ditto 'build/Mandarin Lens.app' 'build/dmg-staging/Mandarin Lens.app'
if [ ! -L build/dmg-staging/Applications ]; then ln -s /Applications build/dmg-staging/Applications; fi
hdiutil create -volname 'Mandarin Lens' -srcfolder build/dmg-staging -ov -format UDZO build/MandarinLens-dev.dmg
(cd build && shasum -a 256 MandarinLens-dev.dmg > MandarinLens-dev.dmg.sha256)
