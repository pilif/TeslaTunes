#!/bin/bash
# Uses only Xcode and macOS tools. Optional argument: existing DerivedData path.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
derived_data="${1:-$repo/build}"
/usr/bin/xcodebuild -project TeslaTunes.xcodeproj -scheme TeslaTunes \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" build
# Resolve a relative DerivedData argument after xcodebuild has created it.
derived_data="$(cd "$derived_data" && pwd)"
test_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/teslatunes-test.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
includes=(-I "$repo/TeslaTunes" -I "$repo/Vendor/flac-1.5.0/include" -I "$repo/Vendor/config/taglib")
while IFS= read -r directory; do
    includes+=(-I "$directory")
done < <(/usr/bin/find "$repo/Vendor/taglib-1.13.1/taglib" -type d)
architecture="${TEST_ARCH:-$(/usr/bin/uname -m)}"
/usr/bin/xcrun clang++ -std=c++14 -fobjc-arc -arch "$architecture" \
    -mmacosx-version-min=14.6 -DFLAC__NO_DLL -DTAGLIB_STATIC \
    "${includes[@]}" "$repo/Tests/conversion-smoke.mm" "$repo/TeslaTunes/flac_utils.mm" \
    "$derived_data/Build/Products/Release/libFLAC.a" \
    "$derived_data/Build/Products/Release/libTagLib.a" \
    -framework Cocoa -framework AudioToolbox -framework AVFoundation -lz \
    -o "$test_dir/conversion-smoke"
/usr/bin/arch "-$architecture" "$test_dir/conversion-smoke" "$test_dir"
