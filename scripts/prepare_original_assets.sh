#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/original-client
if ! command -v innoextract >/dev/null; then brew install innoextract; fi
python3 -m venv build/asset-python
build/asset-python/bin/pip -q install numpy Pillow
source_archive="build/original-client/client.rar"
if [ ! -f "$source_archive" ]; then
  python3 tools/original/fetch_original.py "$source_archive"
fi
python3 tools/original/recover_installer.py "$source_archive" build/original-client
innoextract --silent --output-dir build/original-client/extracted \
  --include app/mods/bfheroes/Levels/heat \
  --include app/mods/bfheroes/Objects/StaticObjects_client.zip \
  --include app/mods/bfheroes/Objects/StaticObjects_server.zip \
  --include app/mods/bfheroes/Objects/Vegitation_client.zip \
  --include app/mods/bfheroes/Objects/Weapons_client.zip \
  --include app/mods/bfheroes/Objects/Vehicles_client.zip \
  --include app/mods/bfheroes/Objects/Common_client.zip \
  --include app/mods/bfheroes/Objects/Items_client.zip \
  --include app/mods/bfheroes/Common_client.zip \
  --include app/mods/bfheroes/Menu_client.zip \
  build/original-client/setup.exe
build/asset-python/bin/python tools/original/convert_world.py \
  build/original-client/extracted/app/mods/bfheroes Assets/OriginalWorld
build/asset-python/bin/python tools/original/verify_world.py Assets/OriginalWorld
