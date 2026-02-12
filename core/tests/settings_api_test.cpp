#include <api/runtime_json_api.h>
#include <cassert>
#include <iostream>

void testInitialize() {
    std::cout << "Running testInitialize..." << std::endl;
    pasty_runtime_ref runtime = pasty_runtime_create();
    assert(runtime != nullptr);
    pasty_settings_initialize(runtime, 100);
    assert(pasty_settings_get_max_history_count(runtime) == 100);
    pasty_runtime_destroy(runtime);
    std::cout << "testInitialize PASSED" << std::endl;
}

void testUpdate() {
    std::cout << "Running testUpdate..." << std::endl;
    pasty_runtime_ref runtime = pasty_runtime_create();
    assert(runtime != nullptr);
    pasty_settings_initialize(runtime, 50);
    assert(pasty_settings_get_max_history_count(runtime) == 50);

    pasty_settings_update(runtime, "history.maxCount", "200");
    assert(pasty_settings_get_max_history_count(runtime) == 200);

    pasty_settings_update(runtime, "history.maxCount", "invalid");
    assert(pasty_settings_get_max_history_count(runtime) == 200);

    pasty_settings_update(runtime, "history.maxCount", "-1");
    assert(pasty_settings_get_max_history_count(runtime) == 200);

    pasty_settings_update(runtime, "unknown.key", "300");
    assert(pasty_settings_get_max_history_count(runtime) == 200);
    pasty_runtime_destroy(runtime);

    std::cout << "testUpdate PASSED" << std::endl;
}

int main() {
    testInitialize();
    testUpdate();
    return 0;
}
