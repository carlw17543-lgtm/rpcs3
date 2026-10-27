#!/bin/sh -ex

# Cross-compiles the LLVM submodule into static libraries for iOS arm64.
# RPCS3 picks them up through LLVM_DIR="$LLVM_IOS_PREFIX/lib/cmake/llvm".

LLVM_SRC="$PWD/3rdparty/llvm/llvm/llvm"
WORK_DIR="${RUNNER_TEMP:-/tmp}/llvm-ios-work"
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

COMMON_FLAGS="\
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD=AArch64 \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LIBEDIT=OFF \
    -DLLVM_ENABLE_LIBPFM=OFF"

# Tablegen has to run on the build machine while cross-compiling, so build it natively first
# shellcheck disable=SC2086
cmake -S "$LLVM_SRC" -B "$WORK_DIR/host" -G Ninja $COMMON_FLAGS
ninja -C "$WORK_DIR/host" llvm-tblgen
if ninja -C "$WORK_DIR/host" -t targets all | grep -q '^llvm-min-tblgen:'; then
    ninja -C "$WORK_DIR/host" llvm-min-tblgen
fi

# LLVM only uses Apple's dead-strip flag when the system is named "Darwin", and CMake names it "iOS" here,
# so it would pass GNU ld's --gc-sections to Apple's linker. Dead stripping only affects LLVM's own tools.
# shellcheck disable=SC2086
cmake -S "$LLVM_SRC" -B "$WORK_DIR/ios" -G Ninja $COMMON_FLAGS \
    -DCMAKE_INSTALL_PREFIX="$LLVM_IOS_PREFIX" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
    -DCMAKE_MACOSX_BUNDLE=OFF \
    -DLLVM_HOST_TRIPLE="arm64-apple-ios$IOS_DEPLOYMENT_TARGET" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-ios$IOS_DEPLOYMENT_TARGET" \
    -DLLVM_NATIVE_TOOL_DIR="$WORK_DIR/host/bin" \
    -DLLVM_TABLEGEN="$WORK_DIR/host/bin/llvm-tblgen" \
    -DLLVM_NO_DEAD_STRIP=ON \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_INCLUDE_TOOLS=OFF \
    -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_ENABLE_PLUGINS=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF

ninja -C "$WORK_DIR/ios" install
