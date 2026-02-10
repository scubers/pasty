#pragma once

#include <string>

#ifdef __cplusplus
extern "C" {
#endif

// Callback type: level, tag, message, file, line
typedef void (*PastyLogCallback)(int level, const char* tag, const char* message, const char* file, int line);

void pasty_logger_initialize(PastyLogCallback callback);

#ifdef __cplusplus
}
#endif

namespace pasty {

enum class LogLevel {
    Verbose = 0,
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4,
    None = 5
};

class Logger {
public:
    static void initialize(PastyLogCallback callback);
    static void log(LogLevel level, const char* tag, const char* file, int line, const char* format, ...);
    static LogLevel getLevel();
    static void setLevel(LogLevel level);

private:
    static PastyLogCallback s_callback;
    static LogLevel s_level;
};

} // namespace pasty

// Macros
#define PASTY_LOG_VERBOSE(tag, fmt, ...) \
    if (pasty::Logger::getLevel() <= pasty::LogLevel::Verbose) \
        pasty::Logger::log(pasty::LogLevel::Verbose, tag, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

#define PASTY_LOG_DEBUG(tag, fmt, ...) \
    if (pasty::Logger::getLevel() <= pasty::LogLevel::Debug) \
        pasty::Logger::log(pasty::LogLevel::Debug, tag, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

#define PASTY_LOG_INFO(tag, fmt, ...) \
    if (pasty::Logger::getLevel() <= pasty::LogLevel::Info) \
        pasty::Logger::log(pasty::LogLevel::Info, tag, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

#define PASTY_LOG_WARN(tag, fmt, ...) \
    if (pasty::Logger::getLevel() <= pasty::LogLevel::Warn) \
        pasty::Logger::log(pasty::LogLevel::Warn, tag, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

#define PASTY_LOG_ERROR(tag, fmt, ...) \
    if (pasty::Logger::getLevel() <= pasty::LogLevel::Error) \
        pasty::Logger::log(pasty::LogLevel::Error, tag, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
