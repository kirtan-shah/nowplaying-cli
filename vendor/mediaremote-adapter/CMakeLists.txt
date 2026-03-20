cmake_minimum_required(VERSION 3.15)
project(MediaRemoteAdapter LANGUAGES OBJC)

set(ADAPTER_VERSION_MAJOR 0)
set(ADAPTER_VERSION_MINOR 1)
set(ADAPTER_VERSION_PATCH 0)
set(ADAPTER_VERSION_SHORT "${ADAPTER_VERSION_MAJOR}.${ADAPTER_VERSION_MINOR}")
set(ADAPTER_VERSION
    "${ADAPTER_VERSION_MAJOR}.${ADAPTER_VERSION_MINOR}.${ADAPTER_VERSION_PATCH}"
)

set(MEDIAREMOTEADAPTER_FRAMEWORK_NAME "MediaRemoteAdapter"
    CACHE STRING "The output name of the adapter framework")
set(MEDIAREMOTEADAPTER_TEST_CLIENT_NAME "MediaRemoteAdapterTestClient"
    CACHE STRING "The output name of the adapter test client")

set(ADAPTER_SOURCES
    src/adapter/env.m
    src/adapter/get.m
    src/adapter/globals.m
    src/adapter/keys.m
    src/adapter/now_playing.m
    src/adapter/repeat.m
    src/adapter/seek.m
    src/adapter/send.m
    src/adapter/shuffle.m
    src/adapter/speed.m
    src/adapter/stream.m
    src/adapter/test.m
    src/private/MediaRemote.m
    src/utility/Debounce.m
    src/utility/helpers.m)
set(HEADERS include/MediaRemoteAdapter.h)

set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64")

add_library(MediaRemoteAdapter SHARED ${ADAPTER_SOURCES})

set_target_properties(
    MediaRemoteAdapter
    PROPERTIES FRAMEWORK TRUE
               FRAMEWORK_VERSION A
               MACOSX_FRAMEWORK_IDENTIFIER
               "com.vandenbe.${MEDIAREMOTEADAPTER_FRAMEWORK_NAME}"
               MACOSX_FRAMEWORK_SHORT_VERSION_STRING "${ADAPTER_VERSION_SHORT}"
               MACOSX_FRAMEWORK_BUNDLE_VERSION "${ADAPTER_VERSION}"
               MACOSX_FRAMEWORK_BUNDLE_NAME
               "${MEDIAREMOTEADAPTER_FRAMEWORK_NAME}"
               PUBLIC_HEADER "${HEADERS}"
               OUTPUT_NAME "${MEDIAREMOTEADAPTER_FRAMEWORK_NAME}")

target_link_libraries(MediaRemoteAdapter "-framework Foundation"
                      "-framework AppKit" "-framework JavaScriptCore")

find_library(UT_FRAMEWORK UniformTypeIdentifiers)
if(UT_FRAMEWORK)
    target_link_libraries(MediaRemoteAdapter ${UT_FRAMEWORK})
endif()

target_include_directories(MediaRemoteAdapter
                           PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(MediaRemoteAdapter
                           PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

target_compile_options(MediaRemoteAdapter PRIVATE "-fobjc-arc")

# Ensure that symbols are visible, otherwise the Perl script can't call into
# functions that are exported by the framework.
target_compile_options(MediaRemoteAdapter PRIVATE -fvisibility=default)

add_custom_command(
    TARGET MediaRemoteAdapter
    POST_BUILD
    COMMAND codesign --force --deep --sign -
            $<TARGET_BUNDLE_DIR:MediaRemoteAdapter>
    COMMENT "Ad-hoc signing ${MEDIAREMOTEADAPTER_FRAMEWORK_NAME}.framework")

add_executable(MediaRemoteAdapterTestClient src/test/main.m
                                            src/test/NowPlayingTest.m)
target_link_libraries(MediaRemoteAdapterTestClient
                      PRIVATE "-framework Foundation" "-framework MediaPlayer")
target_include_directories(MediaRemoteAdapterTestClient
                           PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/test)
set_target_properties(MediaRemoteAdapterTestClient
                      PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")
set_source_files_properties(src/test/main.m PROPERTIES COMPILE_FLAGS
                                                       "-fobjc-arc")
set_source_files_properties(src/test/NowPlayingTest.m PROPERTIES COMPILE_FLAGS
                                                                 "-fobjc-arc")
set_target_properties(
    MediaRemoteAdapterTestClient
    PROPERTIES OUTPUT_NAME "${MEDIAREMOTEADAPTER_TEST_CLIENT_NAME}")
