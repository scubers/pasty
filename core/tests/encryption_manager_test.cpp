#include <infrastructure/crypto/encryption_manager.h>
#include <sodium.h>
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

void testDeriveKeyDeterminism() {
    std::cout << "Running testDeriveKeyDeterminism..." << std::endl;
    
    std::string passphrase = "correct horse battery staple";
    pasty::EncryptionManager::Salt salt;
    for (size_t i = 0; i < salt.size(); ++i) salt[i] = static_cast<unsigned char>(i);

    pasty::EncryptionManager::Key key1, key2;
    
    assert(pasty::EncryptionManager::deriveMasterKey(passphrase, salt, crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_MEMLIMIT_INTERACTIVE, key1));
    assert(pasty::EncryptionManager::deriveMasterKey(passphrase, salt, crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_MEMLIMIT_INTERACTIVE, key2));

    assert(key1 == key2);
    
    std::cout << "testDeriveKeyDeterminism PASSED" << std::endl;
}

void testDifferentSaltYieldsDifferentKey() {
    std::cout << "Running testDifferentSaltYieldsDifferentKey..." << std::endl;
    
    std::string passphrase = "correct horse battery staple";
    pasty::EncryptionManager::Salt salt1, salt2;
    for (size_t i = 0; i < salt1.size(); ++i) salt1[i] = static_cast<unsigned char>(i);
    for (size_t i = 0; i < salt2.size(); ++i) salt2[i] = static_cast<unsigned char>(i + 1);

    pasty::EncryptionManager::Key key1, key2;
    
    assert(pasty::EncryptionManager::deriveMasterKey(passphrase, salt1, crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_MEMLIMIT_INTERACTIVE, key1));
    assert(pasty::EncryptionManager::deriveMasterKey(passphrase, salt2, crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_MEMLIMIT_INTERACTIVE, key2));

    assert(key1 != key2);
    
    std::cout << "testDifferentSaltYieldsDifferentKey PASSED" << std::endl;
}

void testEncryptDecryptRoundtrip() {
    std::cout << "Running testEncryptDecryptRoundtrip..." << std::endl;
    
    pasty::EncryptionManager::Key key;
    for (size_t i = 0; i < key.size(); ++i) key[i] = static_cast<unsigned char>(i);
    
    pasty::EncryptionManager::Bytes plaintext = {'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd'};
    pasty::EncryptionManager::Bytes aad = {'S', 'o', 'm', 'e', ' ', 'A', 'A', 'D'};
    
    pasty::EncryptionManager::EncryptedPayload payload;
    assert(pasty::EncryptionManager::encrypt(key, plaintext, aad, payload));
    
    pasty::EncryptionManager::Bytes decrypted;
    assert(pasty::EncryptionManager::decrypt(key, payload.nonce, payload.ciphertext, aad, decrypted));
    
    assert(plaintext == decrypted);
    
    std::cout << "testEncryptDecryptRoundtrip PASSED" << std::endl;
}

void testDecryptFailsWithWrongAad() {
    std::cout << "Running testDecryptFailsWithWrongAad..." << std::endl;
    
    pasty::EncryptionManager::Key key;
    for (size_t i = 0; i < key.size(); ++i) key[i] = static_cast<unsigned char>(i);
    
    pasty::EncryptionManager::Bytes plaintext = {'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd'};
    pasty::EncryptionManager::Bytes aad = {'S', 'o', 'm', 'e', ' ', 'A', 'A', 'D'};
    pasty::EncryptionManager::Bytes wrongAad = {'W', 'r', 'o', 'n', 'g', ' ', 'A', 'A', 'D'};
    
    pasty::EncryptionManager::EncryptedPayload payload;
    assert(pasty::EncryptionManager::encrypt(key, plaintext, aad, payload));
    
    pasty::EncryptionManager::Bytes decrypted;
    assert(!pasty::EncryptionManager::decrypt(key, payload.nonce, payload.ciphertext, wrongAad, decrypted));
    
    std::cout << "testDecryptFailsWithWrongAad PASSED" << std::endl;
}

void testDecryptFailsWithWrongKey() {
    std::cout << "Running testDecryptFailsWithWrongKey..." << std::endl;
    
    pasty::EncryptionManager::Key key;
    for (size_t i = 0; i < key.size(); ++i) key[i] = static_cast<unsigned char>(i);
    
    pasty::EncryptionManager::Key wrongKey;
    for (size_t i = 0; i < wrongKey.size(); ++i) wrongKey[i] = static_cast<unsigned char>(i + 1);
    
    pasty::EncryptionManager::Bytes plaintext = {'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd'};
    pasty::EncryptionManager::Bytes aad = {'S', 'o', 'm', 'e', ' ', 'A', 'A', 'D'};
    
    pasty::EncryptionManager::EncryptedPayload payload;
    assert(pasty::EncryptionManager::encrypt(key, plaintext, aad, payload));
    
    pasty::EncryptionManager::Bytes decrypted;
    assert(!pasty::EncryptionManager::decrypt(wrongKey, payload.nonce, payload.ciphertext, aad, decrypted));
    
    std::cout << "testDecryptFailsWithWrongKey PASSED" << std::endl;
}

int main() {
    testDeriveKeyDeterminism();
    testDifferentSaltYieldsDifferentKey();
    testEncryptDecryptRoundtrip();
    testDecryptFailsWithWrongAad();
    testDecryptFailsWithWrongKey();
    return 0;
}
