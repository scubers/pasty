#include "encryption_manager.h"

#include <sodium.h>

namespace pasty {

namespace {

const unsigned char* dataOrNull(const EncryptionManager::Bytes& value) {
    return value.empty() ? nullptr : value.data();
}

}

bool EncryptionManager::ensureInitialized() {
    static const bool initialized = []() {
        return sodium_init() >= 0;
    }();

    return initialized;
}

bool EncryptionManager::deriveMasterKey(const std::string& passphrase,
                                        const Salt& salt,
                                        unsigned long long opslimit,
                                        std::size_t memlimit,
                                        Key& outKey) {
    if (!ensureInitialized()) {
        return false;
    }

    outKey.fill(0);
    Bytes passphraseBuffer(passphrase.begin(), passphrase.end());

    const int rc = crypto_pwhash(outKey.data(),
                                 outKey.size(),
                                 reinterpret_cast<const char*>(dataOrNull(passphraseBuffer)),
                                 static_cast<unsigned long long>(passphraseBuffer.size()),
                                 salt.data(),
                                 opslimit,
                                 memlimit,
                                 crypto_pwhash_ALG_ARGON2ID13);

    sodium_memzero(passphraseBuffer.data(), passphraseBuffer.size());

    if (rc != 0) {
        sodium_memzero(outKey.data(), outKey.size());
        return false;
    }

    return true;
}

bool EncryptionManager::encrypt(const Key& key,
                                const Bytes& plaintext,
                                const Bytes& aad,
                                EncryptedPayload& outPayload) {
    if (!ensureInitialized()) {
        return false;
    }

    outPayload.nonce.resize(kNonceBytes);
    randombytes_buf(outPayload.nonce.data(), outPayload.nonce.size());

    outPayload.ciphertext.resize(plaintext.size() + crypto_aead_xchacha20poly1305_ietf_ABYTES);

    unsigned long long ciphertextLength = 0;
    const int rc = crypto_aead_xchacha20poly1305_ietf_encrypt(outPayload.ciphertext.data(),
                                                               &ciphertextLength,
                                                               dataOrNull(plaintext),
                                                               static_cast<unsigned long long>(plaintext.size()),
                                                               dataOrNull(aad),
                                                               static_cast<unsigned long long>(aad.size()),
                                                               nullptr,
                                                               outPayload.nonce.data(),
                                                               key.data());

    if (rc != 0) {
        sodium_memzero(outPayload.ciphertext.data(), outPayload.ciphertext.size());
        outPayload.ciphertext.clear();
        outPayload.nonce.clear();
        return false;
    }

    outPayload.ciphertext.resize(static_cast<std::size_t>(ciphertextLength));
    return true;
}

bool EncryptionManager::decrypt(const Key& key,
                                const Bytes& nonce,
                                const Bytes& ciphertext,
                                const Bytes& aad,
                                Bytes& outPlaintext) {
    if (!ensureInitialized() || nonce.size() != kNonceBytes || ciphertext.size() < crypto_aead_xchacha20poly1305_ietf_ABYTES) {
        return false;
    }

    outPlaintext.assign(ciphertext.size() - crypto_aead_xchacha20poly1305_ietf_ABYTES, 0);
    unsigned long long plaintextLength = 0;

    const int rc = crypto_aead_xchacha20poly1305_ietf_decrypt(outPlaintext.data(),
                                                               &plaintextLength,
                                                               nullptr,
                                                               dataOrNull(ciphertext),
                                                               static_cast<unsigned long long>(ciphertext.size()),
                                                               dataOrNull(aad),
                                                               static_cast<unsigned long long>(aad.size()),
                                                               dataOrNull(nonce),
                                                               key.data());

    if (rc != 0) {
        sodium_memzero(outPlaintext.data(), outPlaintext.size());
        outPlaintext.clear();
        return false;
    }

    outPlaintext.resize(static_cast<std::size_t>(plaintextLength));
    return true;
}

}
