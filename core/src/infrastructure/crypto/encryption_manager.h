#pragma once

#include <array>
#include <cstddef>
#include <string>
#include <vector>

namespace pasty {

class EncryptionManager {
public:
    static constexpr std::size_t kKeyBytes = 32;
    static constexpr std::size_t kSaltBytes = 16;
    static constexpr std::size_t kNonceBytes = 24;

    using Key = std::array<unsigned char, kKeyBytes>;
    using Salt = std::array<unsigned char, kSaltBytes>;
    using Bytes = std::vector<unsigned char>;

    struct EncryptedPayload {
        Bytes nonce;
        Bytes ciphertext;
    };

    static bool deriveMasterKey(const std::string& passphrase,
                                const Salt& salt,
                                unsigned long long opslimit,
                                std::size_t memlimit,
                                Key& outKey);

    static bool encrypt(const Key& key,
                        const Bytes& plaintext,
                        const Bytes& aad,
                        EncryptedPayload& outPayload);

    static bool decrypt(const Key& key,
                        const Bytes& nonce,
                        const Bytes& ciphertext,
                        const Bytes& aad,
                        Bytes& outPlaintext);

private:
    static bool ensureInitialized();
};

}
