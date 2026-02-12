#include <settings/settings_api.h>
#include <cassert>
#include <iostream>

void testInitialize() {
    std::cout << "Running testInitialize..." << std::endl;
    pasty_settings_initialize(100);
    assert(pasty_settings_get_max_history_count() == 100);
    std::cout << "testInitialize PASSED" << std::endl;
}

void testUpdate() {
    std::cout << "Running testUpdate..." << std::endl;
    pasty_settings_initialize(50);
    assert(pasty_settings_get_max_history_count() == 50);

    pasty_settings_update("history.maxCount", "200");
    assert(pasty_settings_get_max_history_count() == 200);

    pasty_settings_update("history.maxCount", "invalid");
    assert(pasty_settings_get_max_history_count() == 200);

    pasty_settings_update("history.maxCount", "-1");
    assert(pasty_settings_get_max_history_count() == 200);

    pasty_settings_update("unknown.key", "300");
    assert(pasty_settings_get_max_history_count() == 200);

    std::cout << "testUpdate PASSED" << std::endl;
}

int main() {
    testInitialize();
    testUpdate();
    return 0;
}
