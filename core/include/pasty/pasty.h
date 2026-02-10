// Pasty - Copyright (c) 2026. MIT License.

#ifndef PASTY_PASTY_H
#define PASTY_PASTY_H

#include <pasty/history/types.h>
#include <pasty/history/store.h>
#include <pasty/history/history.h>
#include <pasty/api/history_api.h>

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

#endif
