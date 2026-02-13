add_executable(pasty_test clipboard_history_test.cpp)

target_link_libraries(pasty_test
    PRIVATE
        PastyCore
        SQLite::SQLite3
)

add_executable(settings_test settings_api_test.cpp)

target_link_libraries(settings_test
    PRIVATE
    PastyCore
)

add_executable(logger_test logger_test.cpp)

target_link_libraries(logger_test
    PRIVATE
    PastyCore
)

add_executable(cloud_drive_sync_test cloud_drive_sync_test.cpp)

target_link_libraries(cloud_drive_sync_test
    PRIVATE
        PastyCore
        SQLite::SQLite3
)

add_executable(cloud_drive_sync_exporter_test cloud_drive_sync_exporter_test.cpp)

target_link_libraries(cloud_drive_sync_exporter_test
    PRIVATE
        PastyCore
)

add_executable(cloud_drive_sync_importer_test cloud_drive_sync_importer_test.cpp)

target_link_libraries(cloud_drive_sync_importer_test
    PRIVATE
        PastyCore
        SQLite::SQLite3
)

add_executable(cloud_drive_sync_state_test cloud_drive_sync_state_test.cpp)

target_link_libraries(cloud_drive_sync_state_test
    PRIVATE
        PastyCore
)

add_executable(sodium_link_test crypto_sodium_link_test.cpp)

target_include_directories(sodium_link_test
    PRIVATE
        ${LIBSODIUM_INCLUDE_DIRS}
)

target_link_directories(sodium_link_test
    PRIVATE
        ${LIBSODIUM_LIBRARY_DIRS}
)

target_link_libraries(sodium_link_test
    PRIVATE
        PastyCore
        ${LIBSODIUM_LIBRARIES}
)

add_executable(encryption_test encryption_manager_test.cpp)

target_include_directories(encryption_test
    PRIVATE
        ${LIBSODIUM_INCLUDE_DIRS}
)

target_link_directories(encryption_test
    PRIVATE
        ${LIBSODIUM_LIBRARY_DIRS}
)

target_link_libraries(encryption_test
    PRIVATE
        PastyCore
        ${LIBSODIUM_LIBRARIES}
)

# Copy migrations for testing
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/../migrations DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

add_test(NAME history_test COMMAND pasty_test)
add_test(NAME settings_test COMMAND settings_test)
add_test(NAME logger_test COMMAND logger_test)
add_test(NAME cloud_sync_test COMMAND cloud_drive_sync_test)
add_test(NAME cloud_sync_exporter_test COMMAND cloud_drive_sync_exporter_test)
add_test(NAME cloud_sync_importer_test COMMAND cloud_drive_sync_importer_test)
add_test(NAME cloud_sync_state_test COMMAND cloud_drive_sync_state_test)
add_test(NAME sodium_link_test COMMAND sodium_link_test)
add_test(NAME encryption_test COMMAND encryption_test)
