#pragma once

#include <array>
#include <cstddef>
#include <optional>
#include <string>

namespace pasty {

struct CloudDriveSyncProtocolInfo {
    int schemaVersion = 0;
    std::string keyId;
    std::string encryptionMode;
    std::string kdfAlg;
    unsigned long long kdfOpslimit = 0;
    std::size_t kdfMemlimit = 0;
    std::array<unsigned char, 16> kdfSalt{};

    static std::optional<CloudDriveSyncProtocolInfo> Load(const std::string& syncRootPath);
    static bool CreateE2EE(const std::string& syncRootPath,
                           unsigned long long opslimit,
                           std::size_t memlimit);
};

} // namespace pasty
