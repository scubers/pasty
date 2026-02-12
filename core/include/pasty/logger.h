#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Callback type: level, tag, message, file, line
typedef void (*PastyLogCallback)(int level, const char* tag, const char* message, const char* file, int line);

void pasty_logger_initialize(PastyLogCallback callback);

#ifdef __cplusplus
}
#endif
