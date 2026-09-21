/* TeslaTunes macOS configuration for FLAC 1.5.0.
 * Checked in so Xcode can compile both architectures without configure/CMake.
 * Native FLAC only (no Ogg container); retain architecture-specific SIMD.
 */
#pragma once
#define PACKAGE_VERSION "1.5.0"
#define CPU_IS_BIG_ENDIAN 0
#define WORDS_BIGENDIAN 0
#define ENABLE_64_BIT_WORDS 1
#define FLAC__SYS_DARWIN 1
#define FLAC__HAS_OGG 0
#define HAVE_BSWAP16 1
#define HAVE_BSWAP32 1
#define HAVE_FSEEKO 1
#define HAVE_INTTYPES_H 1
#define HAVE_LROUND 1
#define HAVE_PTHREAD 1
#define HAVE_STDINT_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_UNISTD_H 1
#define SIZEOF_OFF_T 8
#define SIZEOF_VOIDP 8
#if defined(__arm64__)
#define FLAC__CPU_ARM64 1
#define FLAC__HAS_A64NEONINTRIN 1
#define FLAC__HAS_NEONINTRIN 1
#define FLAC__HAS_X86INTRIN 0
#elif defined(__x86_64__)
#define FLAC__CPU_X86_64 1
#define FLAC__ALIGN_MALLOC_DATA 1
#define FLAC__HAS_X86INTRIN 1
#define HAVE_CPUID_H 1
#define FLAC__USE_AVX 1
#define FLAC__HAS_A64NEONINTRIN 0
#define FLAC__HAS_NEONINTRIN 0
#else
#error TeslaTunes supports arm64 and x86_64 macOS only
#endif
