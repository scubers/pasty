// Pasty2 - Copyright (c) 2026. MIT License.

#include "pasty/settings/settings_api.h"
#include "pasty/api/history_api.h"
#include <string>
#include <mutex>
#include <cstdlib>

namespace {
    // Default value, should be overwritten by platform initialization
    int g_max_history_count = 1000;
    std::mutex g_settings_mutex;
}

extern "C" {

void pasty_settings_initialize(int max_history_count) {
    std::lock_guard<std::mutex> lock(g_settings_mutex);
    if (max_history_count > 0) {
        g_max_history_count = max_history_count;
    }
}

void pasty_settings_update(const char* key, const char* value) {
    if (!key || !value) return;
    
    std::string k(key);
    std::string v(value);
    
    std::lock_guard<std::mutex> lock(g_settings_mutex);
    if (k == "history.maxCount") {
        try {
            int count = std::stoi(v);
            if (count > 0) {
                g_max_history_count = count;
                pasty_history_enforce_retention(count);
            }
        } catch (...) {
            // Ignore invalid int conversion
        }
    }
}

int pasty_settings_get_max_history_count() {
    std::lock_guard<std::mutex> lock(g_settings_mutex);
    return g_max_history_count;
}

}
