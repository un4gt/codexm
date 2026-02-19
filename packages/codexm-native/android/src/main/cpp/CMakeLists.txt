cmake_minimum_required(VERSION 3.22.1)
project(codexm_native C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(codexm_git SHARED
  codexmgit_jni.cpp
  git_ops.cpp
)

find_library(log-lib log)

# --- OpenSSL (Prefab) ---
# libgit2 expects OpenSSL to be discoverable via find_package(OpenSSL).
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# --- libgit2 (FetchContent) ---
include(FetchContent)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_CLI OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(USE_SSH OFF CACHE STRING "" FORCE)
set(USE_HTTPS "OpenSSL" CACHE STRING "" FORCE)

FetchContent_Declare(libgit2
  # NOTE: Prefer `GIT_REPOSITORY` over `URL` here: some networks can reach git
  # but time out on GitHub archive downloads (codeload).
  GIT_REPOSITORY https://github.com/libgit2/libgit2.git
  GIT_TAG v1.9.0
  GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(libgit2)

# --- libgit2 headers ---
# Our JNI wrapper includes <git2.h>. Ensure the libgit2 include dir is visible.
# Some libgit2 CMake configurations don't propagate include dirs as expected to downstream targets.
target_include_directories(codexm_git PRIVATE
  "${libgit2_SOURCE_DIR}/include"
  "${libgit2_BINARY_DIR}/include"
)

# libgit2's CMake target is `libgit2package` (not `git2`).
target_link_libraries(codexm_git PRIVATE libgit2package ${log-lib})
