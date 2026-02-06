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
    void shutdown();
    bool isInitialized() const;

private:
    bool m_initialized;
};

}

#endif
