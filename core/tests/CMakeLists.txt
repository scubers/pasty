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

# Copy migrations for testing
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/../migrations DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

add_test(NAME history_test COMMAND pasty_test)
add_test(NAME settings_test COMMAND settings_test)
add_test(NAME logger_test COMMAND logger_test)
