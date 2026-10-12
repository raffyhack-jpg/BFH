#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/asset-check
cp scripts/check_assets.swift build/asset-check/main.swift
swiftc -O App/Game.swift App/Animation.swift build/asset-check/main.swift \
  -framework SceneKit -o build/asset-check/check
build/asset-check/check
