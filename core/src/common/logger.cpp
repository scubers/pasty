#include "common/logger.h"
#include <cstdarg>
#include <cstdio>
#include <vector>

namespace pasty {

PastyLogCallback Logger::s_callback = nullptr;
#ifdef NDEBUG
LogLevel Logger::s_level = LogLevel::Info;
#else
LogLevel Logger::s_level = LogLevel::Debug;
#endif

void Logger::initialize(PastyLogCallback callback) {
    s_callback = callback;
}

void Logger::log(LogLevel level, const char* tag, const char* file, int line, const char* format, ...) {
    if (level < s_level || !s_callback) {
        return;
    }

    va_list args;
    va_start(args, format);

    // Calculate required size
    va_list args_copy;
    va_copy(args_copy, args);
    int size = std::vsnprintf(nullptr, 0, format, args_copy);
    va_end(args_copy);

    if (size > 0) {
        std::vector<char> buffer(size + 1);
        std::vsnprintf(buffer.data(), buffer.size(), format, args);
        s_callback(static_cast<int>(level), tag, buffer.data(), file, line);
    }

    va_end(args);
}

LogLevel Logger::getLevel() {
    return s_level;
}

void Logger::setLevel(LogLevel level) {
    s_level = level;
}

} // namespace pasty

extern "C" {
    void pasty_logger_initialize(PastyLogCallback callback) {
        pasty::Logger::initialize(callback);
    }
}
