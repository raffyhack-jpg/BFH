#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/original-client
if ! command -v innoextract >/dev/null; then brew install innoextract; fi
python3 -m venv build/asset-python
build/asset-python/bin/pip -q install numpy Pillow
source_archive="build/original-client/client.rar"
curl --fail --location --retry 3 \
  'https://archive.org/download/battlefield-heroes-setup/Battlefield%20Heroes%20Setup.rar' \
  --output "$source_archive"
python3 tools/original/recover_installer.py "$source_archive" build/original-client
innoextract --silent --output-dir build/original-client/extracted \
  --include app/mods/bfheroes/Levels/heat \
  --include app/mods/bfheroes/Objects/StaticObjects_client.zip \
  --include app/mods/bfheroes/Objects/StaticObjects_server.zip \
  --include app/mods/bfheroes/Objects/Vegitation_client.zip \
  --include app/mods/bfheroes/Objects/Weapons_client.zip \
  --include app/mods/bfheroes/Objects/Vehicles_client.zip \
  --include app/mods/bfheroes/Objects/Common_client.zip \
  --include app/mods/bfheroes/Common_client.zip \
  build/original-client/setup.exe
build/asset-python/bin/python tools/original/convert_world.py \
  build/original-client/extracted/app/mods/bfheroes Assets/OriginalWorld
build/asset-python/bin/python tools/original/verify_world.py Assets/OriginalWorld
