#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
marker="$project_root/.build/performance/run-menu-measurement"
mkdir -p "$project_root/.build/performance/menu"
touch "$marker"
trap 'rm -f "$marker"' EXIT

DEVELOPER_DIR="$developer_dir" xcodebuild \
  -project "$project_root/DeskMode.xcodeproj" \
  -scheme DeskMode \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$project_root/.build/performance-ui" \
  -parallel-testing-enabled NO \
  -only-testing:DeskModeUITests/DeskModeUITests/testWarmedProfileListPresentationPerformance \
  test 2>&1 | tee "$project_root/.build/performance/menu/xcodebuild.log"

xcresult="$(find "$project_root/.build/performance-ui/Logs/Test" -name '*.xcresult' -type d -print | sort | tail -n 1)"
attachment_root="$(mktemp -d "${TMPDIR:-/tmp}/launchestra-perf-attachments.XXXXXX")"
xcrun xcresulttool export attachments --path "$xcresult" --output-path "$attachment_root"
result_attachment="$(find "$attachment_root" -name '*.json' ! -name manifest.json -type f -print | head -n 1)"
cp "$result_attachment" "$project_root/.build/performance/menu/result.json"
