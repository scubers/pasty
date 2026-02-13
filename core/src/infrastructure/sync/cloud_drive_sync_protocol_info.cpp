// Pasty - Copyright (c) 2026. MIT License.

#include "cloud_drive_sync_protocol_info.h"

#include <common/logger.h>

#include <cstdio>
#include <filesystem>
#include <fstream>

#include <nlohmann/json.hpp>
#include <sodium.h>

namespace pasty {

namespace {

constexpr int kSchemaVersion = 1;
constexpr std::size_t kSaltBytes = 16;
constexpr const char* kEncryptionMode = "e2ee";
constexpr const char* kKdfAlg = "argon2id13";

std::string metaDirectoryPath(const std::string& syncRootPath) {
    return syncRootPath + "/meta";
}

std::string protocolInfoPath(const std::string& syncRootPath) {
    return metaDirectoryPath(syncRootPath) + "/protocol-info.json";
}

bool ensureSodiumInitialized() {
    static const bool initialized = []() {
        return sodium_init() >= 0;
    }();
    return initialized;
}

std::string saltToBase64(const std::array<unsigned char, kSaltBytes>& salt) {
    char encoded[sodium_base64_ENCODED_LEN(kSaltBytes, sodium_base64_VARIANT_ORIGINAL)] = {};
    sodium_bin2base64(encoded,
                      sizeof(encoded),
                      salt.data(),
                      salt.size(),
                      sodium_base64_VARIANT_ORIGINAL);
    return std::string(encoded);
}

bool parseSaltBase64(const std::string& encoded, std::array<unsigned char, kSaltBytes>& outSalt) {
    std::size_t decodedBytes = 0;
    const int rc = sodium_base642bin(outSalt.data(),
                                     outSalt.size(),
                                     encoded.c_str(),
                                     encoded.size(),
                                     nullptr,
                                     &decodedBytes,
                                     nullptr,
                                     sodium_base64_VARIANT_ORIGINAL);
    return rc == 0 && decodedBytes == outSalt.size();
}

std::string generateKeyId() {
    unsigned char keyIdRaw[16] = {};
    randombytes_buf(keyIdRaw, sizeof(keyIdRaw));

    char keyIdHex[(16 * 2) + 1] = {};
    sodium_bin2hex(keyIdHex, sizeof(keyIdHex), keyIdRaw, sizeof(keyIdRaw));
    return std::string(keyIdHex);
}

} // namespace

std::optional<CloudDriveSyncProtocolInfo> CloudDriveSyncProtocolInfo::Load(const std::string& syncRootPath) {
    if (syncRootPath.empty()) {
        return std::nullopt;
    }

    const std::string infoPath = protocolInfoPath(syncRootPath);
    std::ifstream file(infoPath);
    if (!file.is_open()) {
        return std::nullopt;
    }

    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    using Json = nlohmann::json;
    Json json;
    try {
        json = Json::parse(content, nullptr, false);
    } catch (...) {
        PASTY_LOG_WARN("Core.SyncProtocolInfo", "Failed to parse protocol-info.json: %s", infoPath.c_str());
        return std::nullopt;
    }

    if (json.is_discarded() || !json.is_object()) {
        return std::nullopt;
    }

    const int schemaVersion = json.value("schema_version", 0);
    if (schemaVersion != kSchemaVersion) {
        return std::nullopt;
    }

    if (!json.contains("key_id") || !json["key_id"].is_string()) {
        return std::nullopt;
    }

    if (!json.contains("encryption") || !json["encryption"].is_object()) {
        return std::nullopt;
    }
    const Json& encryption = json["encryption"];

    if (!encryption.contains("mode") || !encryption["mode"].is_string() || encryption["mode"].get<std::string>() != kEncryptionMode) {
        return std::nullopt;
    }

    if (!encryption.contains("kdf") || !encryption["kdf"].is_object()) {
        return std::nullopt;
    }
    const Json& kdf = encryption["kdf"];

    if (!kdf.contains("alg") || !kdf["alg"].is_string() || kdf["alg"].get<std::string>() != kKdfAlg) {
        return std::nullopt;
    }
    if (!kdf.contains("opslimit") || !kdf["opslimit"].is_number_unsigned()) {
        return std::nullopt;
    }
    if (!kdf.contains("memlimit") || !kdf["memlimit"].is_number_unsigned()) {
        return std::nullopt;
    }
    if (!kdf.contains("salt_b64") || !kdf["salt_b64"].is_string()) {
        return std::nullopt;
    }

    std::array<unsigned char, kSaltBytes> salt{};
    if (!parseSaltBase64(kdf["salt_b64"].get<std::string>(), salt)) {
        return std::nullopt;
    }

    CloudDriveSyncProtocolInfo info;
    info.schemaVersion = schemaVersion;
    info.keyId = json["key_id"].get<std::string>();
    info.encryptionMode = encryption["mode"].get<std::string>();
    info.kdfAlg = kdf["alg"].get<std::string>();
    info.kdfOpslimit = kdf["opslimit"].get<unsigned long long>();
    info.kdfMemlimit = kdf["memlimit"].get<std::size_t>();
    info.kdfSalt = salt;
    return info;
}

bool CloudDriveSyncProtocolInfo::CreateE2EE(const std::string& syncRootPath,
                                            unsigned long long opslimit,
                                            std::size_t memlimit) {
    if (syncRootPath.empty() || !ensureSodiumInitialized()) {
        return false;
    }

    const std::string metaPath = metaDirectoryPath(syncRootPath);
    std::error_code ec;
    std::filesystem::create_directories(metaPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncProtocolInfo", "Failed to create meta directory: %s", metaPath.c_str());
        return false;
    }

    std::array<unsigned char, kSaltBytes> salt{};
    randombytes_buf(salt.data(), salt.size());

    using Json = nlohmann::json;
    Json json;
    json["schema_version"] = kSchemaVersion;
    json["key_id"] = generateKeyId();
    json["encryption"] = {
        {"mode", kEncryptionMode},
        {"kdf", {
            {"alg", kKdfAlg},
            {"opslimit", opslimit},
            {"memlimit", memlimit},
            {"salt_b64", saltToBase64(salt)}
        }}
    };

    const std::string finalPath = protocolInfoPath(syncRootPath);
    const std::string tempPath = finalPath + ".tmp";
    const std::string content = json.dump(2);

    std::ofstream output(tempPath, std::ios::trunc);
    if (!output.is_open()) {
        PASTY_LOG_ERROR("Core.SyncProtocolInfo", "Failed to open temp protocol-info file: %s", tempPath.c_str());
        return false;
    }

    output << content;
    output.flush();
    output.close();

    if (std::rename(tempPath.c_str(), finalPath.c_str()) != 0) {
        PASTY_LOG_ERROR("Core.SyncProtocolInfo", "Failed to rename protocol-info temp file to: %s", finalPath.c_str());
        std::remove(tempPath.c_str());
        return false;
    }

    return true;
}

} // namespace pasty
