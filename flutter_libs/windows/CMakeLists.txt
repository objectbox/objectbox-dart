# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "objectbox_flutter_libs")
project(${PROJECT_NAME} LANGUAGES CXX)

# Enable new CMake policies to avoid FetchContent deprecation warnings
cmake_policy(VERSION 3.14...3.24)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "objectbox_flutter_libs_plugin")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "objectbox_flutter_libs_plugin.cpp"
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(objectbox_flutter_libs_bundled_libraries
  ""
  PARENT_SCOPE
)

# ----------------------------------------------------------------------
# Download and add objectbox-c prebuilt library.

set(OBJECTBOX_VERSION 4.3.0)

set(OBJECTBOX_ARCH ${CMAKE_SYSTEM_PROCESSOR})
if (${OBJECTBOX_ARCH} MATCHES "AMD64")
    set(OBJECTBOX_ARCH x64)
endif ()

include(FetchContent)
FetchContent_Declare(
    objectbox-download
    URL https://github.com/objectbox/objectbox-c/releases/download/v${OBJECTBOX_VERSION}/objectbox-windows-${OBJECTBOX_ARCH}.zip
)

FetchContent_GetProperties(objectbox-download)
if(NOT objectbox-download_POPULATED)
  FetchContent_Populate(objectbox-download)
endif()

set(objectbox_flutter_libs_bundled_libraries
    "${objectbox-download_SOURCE_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}objectbox${CMAKE_SHARED_LIBRARY_SUFFIX}"
    PARENT_SCOPE
)

add_library(objectbox SHARED IMPORTED GLOBAL)
set_target_properties(objectbox PROPERTIES
    IMPORTED_LOCATION ${objectbox-download_SOURCE_DIR}/lib/${CMAKE_SHARED_LIBRARY_PREFIX}objectbox${CMAKE_SHARED_LIBRARY_SUFFIX}
    IMPORTED_IMPLIB ${objectbox-download_SOURCE_DIR}/lib/${CMAKE_IMPORT_LIBRARY_PREFIX}objectbox${CMAKE_IMPORT_LIBRARY_SUFFIX}
)

target_link_libraries(${PLUGIN_NAME} PRIVATE objectbox)