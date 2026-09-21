# Bundled audio libraries

The `FLAC` and `TagLib` static-library targets in `TeslaTunes.xcodeproj` compile
these sources directly with the selected Xcode SDK, for arm64 and x86_64. No
package manager, network access, CMake, configure step, or prebuilt binary is
used at build time. The app links macOS's system zlib and Apple frameworks.

| Library | Upstream release | Source archive SHA-256 |
| --- | --- | --- |
| FLAC / FLAC++ 1.5.0 | https://downloads.xiph.org/releases/flac/flac-1.5.0.tar.xz | `f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920` |
| TagLib 1.13.1 | https://taglib.org/releases/taglib-1.13.1.tar.gz | `c8da2b10f1bfec2cd7dbfcd33f4a2338db0765d851a50583d410bacf055cfd0b` |

TagLib 1.13.1 retains the 1.x API used by this app. Its bundled UTF8-CPP headers
are included too. FLAC is licensed under the BSD license in `COPYING.Xiph`;
TagLib is used under its MPL 1.1 license option (`COPYING.MPL`). Upstream license
files and copyright notices are retained, and `TeslaTunes/ThirdPartyNotices.txt`
is copied into the app's Resources directory.

These are source subsets, not complete upstream build distributions:

- FLAC: `include`, `src/libFLAC`, and `src/libFLAC++`, plus upstream notices and
  configuration templates. No command-line programs, tests, or documentation.
- TagLib: `taglib`, `3rdparty`, and upstream notices/configuration templates.
- Upstream implementation files are unchanged. `config/flac/config.h` and
  `config/taglib/{config.h,taglib_config.h}` are the local macOS configurations.
  Architecture macros are evaluated by the compiler separately for each slice.
- FLAC includes NEON on arm64 and runtime-dispatched x86 SIMD implementations.
  Ogg-wrapped FLAC encoding/decoding is disabled; TeslaTunes produces native
  `.flac` files. TagLib's Ogg metadata support remains enabled.
- TagLib uses compiler atomic operations and macOS system zlib. Some old
  compatibility headers still produce deprecation warnings on current SDKs.

To update a dependency, download and verify the upstream release, replace its
source subset, review the platform configuration and upstream source lists,
and update the Xcode target's sources/header paths. Update this document and
the bundled notices, then run `scripts/test-conversion.sh` and build both
Debug and Release for both architectures. The upstream build files retained
here are references; they are not invoked by Xcode.
