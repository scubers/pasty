add_executable(pasty_test history_test.cpp)

target_link_libraries(pasty_test
    PRIVATE
        PastyCore
        SQLite::SQLite3
)

# Copy migrations for testing
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/../migrations DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

add_test(NAME history_test COMMAND pasty_test)
