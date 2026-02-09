// Pasty2 - Copyright (c) 2026. MIT License.

#ifndef PASTY_SETTINGS_SETTINGS_API_H
#define PASTY_SETTINGS_SETTINGS_API_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize core settings with default values from platform
// max_history_count: Maximum number of history items to keep
void pasty_settings_initialize(int max_history_count);

// Update a specific setting
// key: setting key (e.g. "history.maxCount")
// value: setting value as string
void pasty_settings_update(const char* key, const char* value);

// Get current max history count setting
int pasty_settings_get_max_history_count();

#ifdef __cplusplus
}
#endif

#endif // PASTY_SETTINGS_SETTINGS_API_H
