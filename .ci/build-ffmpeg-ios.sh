#!/bin/sh -ex

# Builds static FFmpeg libraries for iOS arm64, the same version as RPCS3's bundled ffmpeg-core headers.
# RPCS3 picks them up through USE_SYSTEM_FFMPEG, FFMPEG_INCLUDE_DIR and FFMPEG_LIBRARIES.

SRC_DIR="${RUNNER_TEMP:-/tmp}/ffmpeg-src"
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
IOS_FLAGS="-arch arm64 -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"

git clone --depth=1 --branch "n$FFMPEG_VER" https://github.com/FFmpeg/FFmpeg.git "$SRC_DIR"
cd "$SRC_DIR"

# --disable-autodetect keeps optional system libraries such as VideoToolbox out of the build.
# RPCS3 only links avformat, avcodec, avutil, swscale and swresample.
./configure \
    --prefix="$FFMPEG_IOS_PREFIX" \
    --enable-cross-compile \
    --target-os=darwin \
    --arch=aarch64 \
    --cc="$(xcrun --sdk iphoneos -f clang)" \
    --sysroot="$IOS_SDK" \
    --extra-cflags="$IOS_FLAGS" \
    --extra-ldflags="$IOS_FLAGS" \
    --enable-static \
    --disable-shared \
    --enable-pic \
    --disable-autodetect \
    --disable-programs \
    --disable-doc \
    --disable-avdevice \
    --disable-avfilter ||
    { tail -n 60 ffbuild/config.log; exit 1; }

make -j"$(sysctl -n hw.ncpu)"
make install
