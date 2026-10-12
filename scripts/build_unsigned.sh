#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/create_project.py
mkdir -p build
swiftc -O App/Game.swift Tests/main.swift -o build/core-tests
build/core-tests
xcodebuild -project PocketFront.xcodeproj -scheme PocketFront -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
APP="build/DerivedData/Build/Products/Release-iphoneos/PocketFront.app"
test -f "$APP/PocketFront"
file "$APP/PocketFront" | tee build/binary-info.txt
file "$APP/PocketFront" | grep -q arm64
if codesign -dv "$APP" 2>/dev/null; then
  echo 'Expected an unsigned app; found signature' >&2
  exit 1
fi
rm -rf build/Payload
mkdir -p build/Payload
ditto "$APP" build/Payload/PocketFront.app
(cd build && zip -qry PocketFront-unsigned.ipa Payload)
python3 scripts/verify_ipa.py build/PocketFront-unsigned.ipa
