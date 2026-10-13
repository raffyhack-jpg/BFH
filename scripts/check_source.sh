#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/create_project.py
mkdir -p build
swiftc -O App/Game.swift Tests/main.swift -o build/core-tests
build/core-tests
swiftc -typecheck App/Game.swift App/Animation.swift App/OriginalWorld.swift -framework SceneKit
xcodebuild -quiet -project PocketFront.xcodeproj -scheme PocketFront -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
