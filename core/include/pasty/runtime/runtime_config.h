#pragma once

#include <string>

namespace pasty {

struct RuntimeConfig {
    std::string storageDirectory;
    std::string migrationDirectory;
    int defaultMaxHistoryCount = 1000;
};

} // namespace pasty
