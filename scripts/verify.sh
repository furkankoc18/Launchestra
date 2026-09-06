#!/bin/bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_root="${DESKMODE_BUILD_ROOT:-$project_root/.build/verify}"

export DEVELOPER_DIR="$developer_dir"

mkdir -p "$build_root/logs"

cd "$project_root"
xcodebuild -version | tee "$build_root/logs/xcode-version.txt"
swift --version | tee "$build_root/logs/swift-version.txt"

swift test --package-path Packages/DeskModeKit \
  -Xswiftc -gnone -Xswiftc -warnings-as-errors \
  2>&1 | tee "$build_root/logs/package-tests.log"

xcodebuild -project DeskMode.xcodeproj -scheme DeskMode \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$build_root/xcode" CODE_SIGNING_ALLOWED=NO build \
  2>&1 | tee "$build_root/logs/app-build.log"

echo "Verification completed: $build_root"
