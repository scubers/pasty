// Pasty2 - Copyright (c) 2026. MIT License.

#ifndef PASTY_H
#define PASTY_H

#include <string>

namespace pasty {

class ClipboardManager {
public:
    ClipboardManager();
    ~ClipboardManager();

    static std::string getVersion();
    static std::string getAppName();

    bool initialize();
    bool initializeWithStorageDirectory(const std::string& baseDirectory);
    void shutdown();
    bool isInitialized() const;

private:
    bool m_initialized;
};

}

extern "C" {

bool pasty_history_ingest_text(const char* text, const char* source_app_id);
bool pasty_history_ingest_image(const unsigned char* bytes, unsigned long byte_count, int width, int height, const char* format_hint, const char* source_app_id);
const char* pasty_history_list_json(int limit);
bool pasty_history_delete(const char* id);
void pasty_history_set_storage_directory(const char* path);

}

#endif
