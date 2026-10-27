#!/bin/bash -ex
set -o pipefail

# Configures RPCS3's emulator core (no Qt UI) for iOS arm64 and builds the rpcs3_emu library.
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

# Keep Homebrew's macOS libraries out of the iOS build
export PKG_CONFIG_LIBDIR="$DEPS_DIR/no-pkgconfig"
export PKG_CONFIG_PATH=""
mkdir -p "$PKG_CONFIG_LIBDIR"

cmake -S . -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
    -DCMAKE_C_COMPILER="$CLANG_DIR/clang" \
    -DCMAKE_CXX_COMPILER="$CLANG_DIR/clang++" \
    -DCMAKE_CXX_FLAGS="-nostdinc++ -isystem $IOS_SDK/usr/include/c++/v1" \
    -DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local" \
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
    -DUSE_SYSTEM_MVK=ON \
    -DVulkan_INCLUDE_DIR="$DEPS_DIR/Vulkan-Headers/include" \
    -DVulkan_LIBRARY="$MOLTENVK_LIB" \
    2>&1 | tee "$BUILD_DIR/configure.log"

# -k 0 keeps going after errors, so a single run lists every file that doesn't compile for iOS yet
build_status=0
ninja -C "$BUILD_DIR" -k 0 rpcs3_emu 2>&1 | tee "$BUILD_DIR/build.log" || build_status=$?

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
    {
        echo "## RPCS3 core for iOS"
        echo "Failed build steps: $(grep -c '^FAILED: ' "$BUILD_DIR/build.log" || true)"
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
