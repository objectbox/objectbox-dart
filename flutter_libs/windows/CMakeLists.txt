cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "objectbox_flutter_libs")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "objectbox_flutter_libs_plugin")

add_library(${PLUGIN_NAME} SHARED
  "objectbox_flutter_libs_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin
set(objectbox_flutter_libs_bundled_libraries
  ""
  PARENT_SCOPE
)

# ----------------------------------------------------------------------

set(OBJECTBOX_VERSION 0.14.0)

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