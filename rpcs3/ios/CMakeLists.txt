# Minimal iOS app around the emulator core (rpcs3_emu). For now it links the whole core and shows its status.

set(IOS_BUNDLE_IDENTIFIER "io.github.carlw17543-lgtm.rpcs3" CACHE STRING "Bundle identifier of the iOS app")

# Same version number as the desktop builds, read from rpcs3_version.cpp
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../rpcs3_version.cpp" RPCS3_VERSION_LINE REGEX "version\\{")
if(RPCS3_VERSION_LINE MATCHES "version\\{ *([0-9]+), *([0-9]+), *([0-9]+)")
    set(IOS_BUNDLE_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
else()
    set(IOS_BUNDLE_VERSION "0.0.0")
endif()
set(IOS_BUNDLE_BUILD "1")

configure_file(Info.plist.in "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" @ONLY)

add_executable(rpcs3_ios MACOSX_BUNDLE
    main.mm
    core_bridge.cpp
    frontend_support.cpp
    ../rpcs3_version.cpp
)

# The Qt-free part of RPCS3's input code. On desktop it is built with the Qt UI (rpcs3qt).
target_sources(rpcs3_ios PRIVATE
    ../Input/blob_detector.cpp
    ../Input/ds3_pad_handler.cpp
    ../Input/ds4_pad_handler.cpp
    ../Input/dualsense_pad_handler.cpp
    ../Input/hid_instance.cpp
    ../Input/hid_pad_handler.cpp
    ../Input/pad_thread.cpp
    ../Input/product_info.cpp
    ../Input/ps_move_calibration.cpp
    ../Input/ps_move_config.cpp
    ../Input/ps_move_handler.cpp
    ../Input/ps_move_tracker.cpp
    ../Input/skateboard_pad_handler.cpp
    ../Input/wiimote_handler.cpp
)

set_source_files_properties(main.mm PROPERTIES COMPILE_OPTIONS "-fobjc-arc")

set_target_properties(rpcs3_ios
    PROPERTIES
        OUTPUT_NAME "RPCS3"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist")

target_link_libraries(rpcs3_ios
    PRIVATE
        rpcs3_emu
        3rdparty::fusion # Used by the core's pad code; on desktop it comes in through rpcs3_lib
        iconv
        "-framework Foundation"
        "-framework UIKit"
        "-framework QuartzCore"
        "-framework Metal"
        "-framework IOSurface"
        "-framework CoreGraphics"
        "-framework CoreFoundation"
        "-framework AudioToolbox"
        "-framework CoreAudio"
        "-framework AVFoundation"
        "-framework CoreMIDI"
        "-framework Security"
        "-framework SystemConfiguration")
