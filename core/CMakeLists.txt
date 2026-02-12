cmake_minimum_required(VERSION 3.16)
project(PastyCore VERSION 0.1.0 LANGUAGES CXX)

# C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 编译选项
add_compile_options(-Wall -Wextra -Wpedantic)

# 查找 SQLite3
find_package(SQLite3 REQUIRED)

# 源文件
set(PASTY_CORE_SOURCES
    src/api/runtime_json_api.cpp
    src/application/history/clipboard_service.cpp
    src/common/logger.cpp
    src/infrastructure/settings/in_memory_settings_store.cpp
    src/runtime/core_runtime.cpp
    src/store/sqlite_clipboard_history_store.cpp
    src/utils/runtime_json_utils.cpp
)

# 头文件目录
set(PASTY_CORE_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(PASTY_CORE_PUBLIC_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)

# 静态库
add_library(PastyCore STATIC ${PASTY_CORE_SOURCES})

target_include_directories(PastyCore
    PUBLIC
        ${PASTY_CORE_PUBLIC_INCLUDE_DIR}
        ${PASTY_CORE_INCLUDE_DIR}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/thirdparty
)

target_link_libraries(PastyCore
    PRIVATE
        SQLite::SQLite3
)

# 设置输出名称
set_target_properties(PastyCore PROPERTIES
    OUTPUT_NAME PastyCore
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

# 安装规则
install(TARGETS PastyCore
    ARCHIVE DESTINATION lib
)

install(DIRECTORY
    include/pasty
    src/api
    src/common
    src/history
    src/ports
    src/runtime
    src/utils
    DESTINATION include
    FILES_MATCHING PATTERN "*.h"
)

install(FILES src/module.modulemap
    DESTINATION include
)

# 安装迁移文件
install(FILES
    migrations/0001-initial-schema.sql
    migrations/0002-add-search-index.sql
    migrations/0003-add-metadata.sql
    migrations/0004-add-ocr-support.sql
    DESTINATION share/pasty/migrations
)

# 测试（可选）
option(PASTY_BUILD_TESTS "Build tests" OFF)

if(PASTY_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
