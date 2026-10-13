#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -quiet -project PocketFront.xcodeproj -scheme PocketFront -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/SimulatorData \
  ARCHS="$(uname -m)" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcrun simctl list devices available -j > build/simulator-devices.json
DEVICE=$(python3 - <<'PY'
import json
p=json.load(open('build/simulator-devices.json'))
phones=[d for key,ds in p['devices'].items() if 'iOS' in key for d in ds if d['isAvailable'] and 'iPhone' in d['name']]
if not phones:raise SystemExit('No installed iPhone simulator runtime')
print(next((d for d in phones if 'iPhone 16 Pro'==d['name']),phones[0])['udid'])
PY
)
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" build/SimulatorData/Build/Products/Release-iphonesimulator/PocketFront.app
for page in menu wardrobe abilities gameplay; do
  xcrun simctl terminate "$DEVICE" com.pocketfront.game || true
  xcrun simctl launch "$DEVICE" com.pocketfront.game "--qa-$page"
  sleep 12
  xcrun simctl io "$DEVICE" screenshot "build/original-$page-native.png"
done
build/asset-python/bin/python - <<'PY'
from PIL import Image
import io,base64
for page in ('menu','wardrobe','abilities','gameplay'):
 im=Image.open(f'build/original-{page}-native.png');im.thumbnail((1400,900));b=io.BytesIO();im.convert('RGB').save(b,format='JPEG',quality=85)
 print(page.upper()+'_UI_VISUAL='+base64.b64encode(b.getvalue()).decode())
PY
