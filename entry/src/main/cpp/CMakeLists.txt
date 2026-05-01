cmake_minimum_required(VERSION 3.4.1)

project(entry)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_SKIP_BUILD_RPATH TRUE)

set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../..")
set(SHARED_CPP_ROOT "${REPO_ROOT}/cpp")
set(MEGASOURCE_ROOT "${SHARED_CPP_ROOT}/megasource")
set(LOVE_ROOT "${SHARED_CPP_ROOT}/love")

set(OHOS ON)

set(LOVE_JIT ON CACHE BOOL "" FORCE)
set(MEGA_LOVE "${LOVE_ROOT}")
add_subdirectory("${MEGASOURCE_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/megasource")

add_library(entry SHARED
  entry_napi.cpp
)

target_compile_definitions(entry PRIVATE SDL_PLATFORM_OHOS=1)

target_include_directories(entry PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  "${LOVE_ROOT}/src"
)

find_library(EGL-lib EGL)
find_library(GLES-lib GLESv2)
find_library(Vulkan-lib vulkan)
find_library(ace-ndk-lib ace_ndk.z)
find_library(native-window-lib native_window)

target_link_libraries(entry PUBLIC
  ${EGL-lib}
  ${GLES-lib}
  ${Vulkan-lib}
  ${ace-ndk-lib}
  ${native-window-lib}
  libace_napi.z.so
  SDL3-shared
  love
)
