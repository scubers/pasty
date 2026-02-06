// Pasty2 - Copyright (c) 2026. MIT License.

#include "Pasty.h"

namespace pasty {

static const char* VERSION = "0.1.0";
static const char* APP_NAME = "Pasty2";

ClipboardManager::ClipboardManager()
    : m_initialized(false) {
}

ClipboardManager::~ClipboardManager() {
    if (m_initialized) {
        shutdown();
    }
}

std::string ClipboardManager::getVersion() {
    return std::string(VERSION);
}

std::string ClipboardManager::getAppName() {
    return std::string(APP_NAME);
}

bool ClipboardManager::initialize() {
    if (m_initialized) {
        return true;
    }
    
    m_initialized = true;
    return true;
}

void ClipboardManager::shutdown() {
    if (!m_initialized) {
        return;
    }
    
    m_initialized = false;
}

bool ClipboardManager::isInitialized() const {
    return m_initialized;
}

}
