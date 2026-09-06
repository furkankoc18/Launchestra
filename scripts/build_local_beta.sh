#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
version="0.1.0-beta.1"
build_root="${DESKMODE_RELEASE_BUILD_ROOT:-$project_root/.build/release-$version}"
dist_root="${DESKMODE_DIST_ROOT:-$project_root/dist/$version}"
archive_path="$build_root/Launchestra.xcarchive"
package_root="$build_root/package"
app_path="$archive_path/Products/Applications/Launchestra.app"

if [[ -e "$dist_root" ]]; then
  echo "Distribution directory already exists: $dist_root" >&2
  exit 2
fi

mkdir -p "$build_root" "$package_root"
export DEVELOPER_DIR="$developer_dir"

xcodebuild archive \
  -project "$project_root/DeskMode.xcodeproj" \
  -scheme DeskMode \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  2>&1 | tee "$build_root/archive.log"

codesign --verify --deep --strict --verbose=2 "$app_path" \
  2>&1 | tee "$build_root/codesign-verify.log"
codesign -d --verbose=4 "$app_path" 2> "$build_root/codesign-details.log"
codesign -d --entitlements :- "$app_path" > "$build_root/entitlements.plist" 2>&1 || true

mkdir -p "$dist_root"
cp -R "$app_path" "$package_root/Launchestra.app"
cp "$project_root/LICENSE" "$package_root/LICENSE"
cp "$project_root/THIRD_PARTY_NOTICES.md" "$package_root/THIRD_PARTY_NOTICES.md"
cp "$project_root/docs/releases/0.1.0-beta.1.md" "$package_root/RELEASE_NOTES.md"
source_commit="$(git -C "$project_root" rev-parse HEAD 2>/dev/null || printf 'uncommitted')"
printf '%s\n' "$source_commit" > "$package_root/SOURCE_COMMIT.txt"

ditto -c -k --sequesterRsrc \
  "$package_root" "$dist_root/Launchestra-$version-arm64.zip"
hdiutil create -volname "Launchestra 0.1.0 Beta" \
  -srcfolder "$package_root" -format UDZO \
  "$dist_root/Launchestra-$version-arm64.dmg" \
  > "$build_root/hdiutil.log"

(cd "$dist_root" && shasum -a 256 \
  "Launchestra-$version-arm64.zip" \
  "Launchestra-$version-arm64.dmg" > SHA256SUMS.txt)

plutil -extract CFBundleIdentifier raw "$app_path/Contents/Info.plist" > "$build_root/bundle-identifier.txt"
plutil -extract CFBundleShortVersionString raw "$app_path/Contents/Info.plist" > "$build_root/version.txt"
plutil -extract CFBundleVersion raw "$app_path/Contents/Info.plist" > "$build_root/build.txt"

echo "Created local ad-hoc beta artifacts in $dist_root"
