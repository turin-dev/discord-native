cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "flutter_webrtc")
project(${PROJECT_NAME} LANGUAGES CXX)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
  cmake_policy(SET CMP0135 NEW)
endif()

# Add the libwebrtc dependency
include("${CMAKE_CURRENT_SOURCE_DIR}/../third_party/CMakeLists.txt")

get_filename_component(FLUTTER_WEBRTC_SOURCE_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
set(DISCORD_NATIVE_THIRD_PARTY_DIR
  "${FLUTTER_WEBRTC_SOURCE_DIR}/../..")

set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(USE_SHARED_MBEDTLS_LIBRARY OFF CACHE BOOL "" FORCE)
set(USE_STATIC_MBEDTLS_LIBRARY ON CACHE BOOL "" FORCE)
add_subdirectory(
  "${DISCORD_NATIVE_THIRD_PARTY_DIR}/mbedtls"
  "${CMAKE_CURRENT_BINARY_DIR}/mbedtls"
  EXCLUDE_FROM_ALL
)

add_library(MbedTLS::MbedTLS INTERFACE IMPORTED)
set_target_properties(MbedTLS::MbedTLS PROPERTIES
  INTERFACE_LINK_LIBRARIES "mbedtls;mbedx509;mbedcrypto"
)
set(MbedTLS_INCLUDE_DIR "${DISCORD_NATIVE_THIRD_PARTY_DIR}/mbedtls/include")
set(MbedTLS_LIBRARY mbedtls)
set(MbedCrypto_LIBRARY mbedcrypto)
set(MbedX509_LIBRARY mbedx509)
set(MBEDTLS_INCLUDE_DIRS "${MbedTLS_INCLUDE_DIR}")
set(MBEDTLS_LIBRARIES MbedTLS::MbedTLS)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(USE_MBEDTLS ON CACHE BOOL "" FORCE)
set(NO_WEBSOCKET ON CACHE BOOL "" FORCE)
set(NO_EXAMPLES ON CACHE BOOL "" FORCE)
set(NO_TESTS ON CACHE BOOL "" FORCE)
set(WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
add_subdirectory(
  "${DISCORD_NATIVE_THIRD_PARTY_DIR}/libdatachannel"
  "${CMAKE_CURRENT_BINARY_DIR}/libdatachannel"
  EXCLUDE_FROM_ALL
)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_webrtc_plugin")

add_definitions(-DLIB_WEBRTC_API_DLL)
add_definitions(-DRTC_DESKTOP_DEVICE)

add_library(${PLUGIN_NAME} SHARED
  "../common/cpp/src/flutter_common.cc"
  "../common/cpp/src/flutter_data_channel.cc"
  "../common/cpp/src/flutter_data_packet_cryptor.cc"
  "../common/cpp/src/discord_video_transport.cc"
  "../common/cpp/src/discord_h264_capture_encoder.cc"
  "../common/cpp/src/discord_h264_render_decoder.cc"
  "../common/cpp/src/discord_dave_encryptor.cc"
  "../common/cpp/src/flutter_discord_video.cc"
  "../common/cpp/src/flutter_frame_cryptor.cc"
  "../common/cpp/src/flutter_media_stream.cc"
  "../common/cpp/src/flutter_utf8_sanitize.cc"
  "../common/cpp/src/flutter_peerconnection.cc"
  "../common/cpp/src/flutter_frame_capturer.cc"
  "../common/cpp/src/flutter_video_renderer.cc"
  "../common/cpp/src/flutter_screen_capture.cc"
  "../common/cpp/src/flutter_webrtc.cc"
  "../common/cpp/src/flutter_webrtc_base.cc"
  "application_loopback_capturer.cc"
  "loopback_capturer_factory.cc"
  "flutter_webrtc_plugin.cc"
  "task_runner_windows.cc"
)

include_directories(
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/cpp/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/svpng"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/include"
  "${DISCORD_NATIVE_THIRD_PARTY_DIR}/libdatachannel/include"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/cpp/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter
  flutter_wrapper_plugin
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/libwebrtc.dll.lib"
  datachannel-static
  avrt.lib
  ksuser.lib
  mmdevapi.lib
  mf.lib
  mfplat.lib
  mfuuid.lib
  ole32.lib
  runtimeobject.lib
  uuid.lib
  winmm.lib
)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_webrtc_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libwebrtc/lib/libwebrtc.dll"
  PARENT_SCOPE
)
