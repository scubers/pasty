// Pasty - Copyright (c) 2026. MIT License.

#ifndef PASTY_PASTY_H
#define PASTY_PASTY_H

#include <history/types.h>
#include <history/store.h>
#include <history/history.h>
#include <api/history_api.h>

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
