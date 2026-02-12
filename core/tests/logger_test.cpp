#include <common/logger.h>
#include <iostream>
#include <vector>
#include <string>
#include <cassert>
#include <cstring>

using namespace pasty;

struct LogEntry {
    LogLevel level;
    std::string tag;
    std::string message;
    std::string file;
    int line;
};

std::vector<LogEntry> g_logs;

void testCallback(int level, const char* tag, const char* message, const char* file, int line) {
    g_logs.push_back({static_cast<LogLevel>(level), tag, message, file, line});
}

void testBasicLogging() {
    g_logs.clear();
    Logger::initialize((PastyLogCallback)testCallback);
    Logger::setLevel(LogLevel::Verbose);

    PASTY_LOG_INFO("Tag1", "Message %d", 1);
    
    assert(g_logs.size() == 1);
    assert(g_logs[0].level == LogLevel::Info);
    assert(g_logs[0].tag == "Tag1");
    assert(g_logs[0].message == "Message 1");
    
    std::cout << "testBasicLogging passed" << std::endl;
}

void testLevelFiltering() {
    g_logs.clear();
    Logger::initialize((PastyLogCallback)testCallback);
    Logger::setLevel(LogLevel::Info);

    PASTY_LOG_DEBUG("Tag2", "Should not be logged");
    PASTY_LOG_INFO("Tag2", "Should be logged");
    PASTY_LOG_WARN("Tag2", "Should be logged too");

    assert(g_logs.size() == 2);
    assert(g_logs[0].level == LogLevel::Info);
    assert(g_logs[0].message == "Should be logged");
    assert(g_logs[1].level == LogLevel::Warn);
    assert(g_logs[1].message == "Should be logged too");

    std::cout << "testLevelFiltering passed" << std::endl;
}

int main() {
    testBasicLogging();
    testLevelFiltering();
    return 0;
}
