#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/teslatunes-platform.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
architecture="${TEST_ARCH:-$(/usr/bin/uname -m)}"
/usr/bin/xcrun clang -fobjc-arc -arch "$architecture" -mmacosx-version-min=14.6 \
    -Wall -Wextra -Werror -c TeslaTunes/SavedFolderDefaults.m -o "$test_dir/defaults.o"
/usr/bin/xcrun clang++ -std=c++14 -fobjc-arc -arch "$architecture" \
    -mmacosx-version-min=14.6 -Wall -Wextra -Werror -DTAGLIB_STATIC \
    -I TeslaTunes -I Vendor/config/taglib -I Vendor/taglib-1.13.1/taglib \
    -I Vendor/taglib-1.13.1/taglib/toolkit \
    Tests/platform-compatibility.mm "$test_dir/defaults.o" -framework Foundation \
    -o "$test_dir/platform-compatibility"
/usr/bin/arch "-$architecture" "$test_dir/platform-compatibility"
