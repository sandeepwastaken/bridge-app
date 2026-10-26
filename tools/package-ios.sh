#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null
version=$(/usr/libexec/PlistBuddy -c 'Print :objects:B1D0000000000000000000AF:buildSettings:MARKETING_VERSION' BridgeApp/Bridge.xcodeproj/project.pbxproj)
output="$PWD/.local/releases/$version"
mkdir -p "$PWD/.local/build" "$output"
staging=$(mktemp -d "$PWD/.local/build/ios.XXXXXX")
trap 'rm -rf "$staging"' EXIT
xcodebuild -quiet -project BridgeApp/Bridge.xcodeproj -scheme Bridge \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$staging/DerivedData" CODE_SIGNING_ALLOWED=NO build
mkdir -p "$staging/package/Payload"
ditto "$staging/DerivedData/Build/Products/Release-iphoneos/Bridge.app" "$staging/package/Payload/Bridge.app"
(cd "$staging/package" && COPYFILE_DISABLE=1 /usr/bin/zip -q -r "$staging/Bridge.ipa" Payload)
mv "$staging/Bridge.ipa" "$output/Bridge.ipa"
printf 'Unsigned IPA: %s/Bridge.ipa\n' "$output"
