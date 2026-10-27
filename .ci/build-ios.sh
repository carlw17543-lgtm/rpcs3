#!/bin/bash -ex
set -o pipefail

# Configures RPCS3 for iOS arm64 without the Qt UI, builds the iOS app (rpcs3_ios) around the
# emulator core, and packages it as an unsigned .ipa.
# Like RPCS3's macOS builds, this compiles with upstream clang instead of Apple clang,
# but against the iOS SDK's own libc++ so the result links against the system C++ library.

IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG_DIR="$(brew --prefix llvm)/bin"
DEPS_DIR="${RUNNER_TEMP:-/tmp}/ios-deps"
BUILD_DIR="$PWD/build-ios"
mkdir -p "$DEPS_DIR" "$BUILD_DIR"

"$CLANG_DIR/clang" --version

# Vulkan headers matching the Vulkan SDK version RPCS3's Windows builds use
if [ ! -d "$DEPS_DIR/Vulkan-Headers" ]; then
    git clone --depth=1 --branch "v$VULKAN_HEADERS_VER" https://github.com/KhronosGroup/Vulkan-Headers.git "$DEPS_DIR/Vulkan-Headers"
fi

# MoltenVK (Vulkan on top of Metal), prebuilt for iOS
if [ ! -d "$DEPS_DIR/MoltenVK" ]; then
    mkdir -p "$DEPS_DIR/MoltenVK"
    gh release download --repo KhronosGroup/MoltenVK --pattern 'MoltenVK-ios.tar' --dir "$DEPS_DIR" ||
        gh release download --repo KhronosGroup/MoltenVK --pattern 'MoltenVK-all.tar' --dir "$DEPS_DIR"
    tar -xf "$DEPS_DIR"/MoltenVK-*.tar -C "$DEPS_DIR/MoltenVK"
fi
MOLTENVK_LIB="$(find "$DEPS_DIR/MoltenVK" -path '*ios-arm64/*' -not -path '*simulator*' -name 'libMoltenVK.a' | head -n 1)"
if [ -z "$MOLTENVK_LIB" ]; then
    find "$DEPS_DIR/MoltenVK" -maxdepth 5
    echo "libMoltenVK.a for iOS arm64 not found"
    exit 1
fi

# RPCS3 includes <MoltenVK/mvk_vulkan.h>. Expose only MoltenVK's own headers, so the Vulkan headers still come from Vulkan-Headers.
MVK_HEADER="$(find "$DEPS_DIR/MoltenVK" -name 'mvk_vulkan.h' | head -n 1)"
if [ -z "$MVK_HEADER" ]; then
    echo "MoltenVK headers not found"
    exit 1
fi
rm -rf "$DEPS_DIR/moltenvk-include"
mkdir -p "$DEPS_DIR/moltenvk-include/MoltenVK"
cp "$(dirname "$MVK_HEADER")"/*.h "$DEPS_DIR/moltenvk-include/MoltenVK/"

IOS_CXX_FLAGS="-nostdinc++ -isystem $IOS_SDK/usr/include/c++/v1 -isystem $DEPS_DIR/moltenvk-include"

# Homebrew's clang ships no iOS compiler runtime, which provides __isPlatformVersionAtLeast for @available checks
CLANG_RT_IOS="$(find "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang" -name libclang_rt.ios.a | head -n 1)"
if [ -z "$CLANG_RT_IOS" ]; then
    echo "libclang_rt.ios.a not found in Xcode"
    exit 1
fi

# Keep Homebrew's macOS libraries out of the iOS build
export PKG_CONFIG_LIBDIR="$DEPS_DIR/no-pkgconfig"
export PKG_CONFIG_PATH=""
mkdir -p "$PKG_CONFIG_LIBDIR"

# RPCS3 doesn't use C++20 modules, and with module scanning on, one file that fails to scan blocks its whole target.
# cubeb's AudioUnit backend uses macOS-only CoreAudio APIs, so it stays off on iOS for now.
# CMAKE_SYSTEM_PROCESSOR is the target CPU; otherwise CMake uses the build machine's, and RPCS3 picks its CPU backend from it.
cmake -S . -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
    -DCMAKE_MACOSX_BUNDLE=OFF \
    -DCMAKE_C_COMPILER="$CLANG_DIR/clang" \
    -DCMAKE_CXX_COMPILER="$CLANG_DIR/clang++" \
    -DCMAKE_CXX_FLAGS="$IOS_CXX_FLAGS" \
    -DCMAKE_OBJCXX_FLAGS="$IOS_CXX_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$CLANG_RT_IOS" \
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF \
    -DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local" \
    -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=OFF \
    -DLLVM_DIR="$LLVM_IOS_PREFIX/lib/cmake/llvm" \
    -DSTATIC_LINK_LLVM=ON \
    -DUSE_LTO=OFF \
    -DUSE_NATIVE_INSTRUCTIONS=OFF \
    -DUSE_PRECOMPILED_HEADERS=OFF \
    -DUSE_SDL=OFF \
    -DUSE_FAUDIO=OFF \
    -DUSE_LIBEVDEV=OFF \
    -DUSE_DISCORD_RPC=OFF \
    -DUSE_GAMEMODE=OFF \
    -DUSE_SYSTEM_CURL=OFF \
    -DUSE_SYSTEM_ZLIB=OFF \
    -DUSE_SYSTEM_FFMPEG=ON \
    -DFFMPEG_INCLUDE_DIR="$FFMPEG_IOS_PREFIX/include" \
    -DFFMPEG_LIBRARIES="$FFMPEG_IOS_PREFIX/lib/libavformat.a;$FFMPEG_IOS_PREFIX/lib/libavcodec.a;$FFMPEG_IOS_PREFIX/lib/libswscale.a;$FFMPEG_IOS_PREFIX/lib/libswresample.a;$FFMPEG_IOS_PREFIX/lib/libavutil.a" \
    -DUSE_SYSTEM_MVK=ON \
    -DUSE_AUDIOUNIT=OFF \
    -DVulkan_INCLUDE_DIR="$DEPS_DIR/Vulkan-Headers/include" \
    -DVulkan_LIBRARY="$MOLTENVK_LIB" \
    2>&1 | tee "$BUILD_DIR/configure.log"

# -k 0 keeps going after errors, so a single run lists every file that doesn't compile for iOS yet
build_status=0
ninja -C "$BUILD_DIR" -k 0 rpcs3_ios 2>&1 | tee "$BUILD_DIR/build.log" || build_status=$?

# The ad-hoc signature only keeps the bundle well-formed; Sideloadly re-signs it with your Apple ID when installing
IPA_PATH="$BUILD_DIR/RPCS3-unsigned.ipa"
if [ "$build_status" -eq 0 ]; then
    APP_DIR="$(find "$BUILD_DIR" -maxdepth 3 -type d -name 'RPCS3.app' | head -n 1)"
    if [ -z "$APP_DIR" ]; then
        echo "RPCS3.app not found in $BUILD_DIR"
        exit 1
    fi
    codesign --force --sign - --timestamp=none "$APP_DIR"
    rm -rf "$BUILD_DIR/ipa" "$IPA_PATH"
    mkdir -p "$BUILD_DIR/ipa/Payload"
    cp -R "$APP_DIR" "$BUILD_DIR/ipa/Payload/"
    (cd "$BUILD_DIR/ipa" && zip -qry "$IPA_PATH" Payload)
    ls -l "$IPA_PATH"
fi

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    {
        echo "## RPCS3 app for iOS"
        echo "Failed build steps: $(grep -c '^FAILED: ' "$BUILD_DIR/build.log" || true)"
        if [ -f "$IPA_PATH" ]; then
            echo "Unsigned IPA: $(du -h "$IPA_PATH" | cut -f1)"
        fi
        echo "### Most common errors"
        echo '```'
        grep -E ': (fatal )?error: ' "$BUILD_DIR/build.log" | sed -E 's/^.*: (fatal )?error: //' | sort | uniq -c | sort -rn | head -n 40 || true
        echo '```'
        echo "### Failed build steps"
        echo '```'
        grep '^FAILED: ' "$BUILD_DIR/build.log" | sed -E 's/^FAILED: //' | head -n 100 || true
        echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$build_status"
