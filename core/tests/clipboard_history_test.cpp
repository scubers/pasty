#include <application/history/clipboard_service.h>
#include <history/clipboard_history_store.h>
#include <infrastructure/settings/in_memory_settings_store.h>
#include <store/sqlite_clipboard_history_store.h>

#include <cassert>
#include <filesystem>
#include <iostream>
#include <vector>

namespace {

void configureMigrationDirectoryForTests() {
    const std::filesystem::path current = std::filesystem::current_path();
    const std::vector<std::filesystem::path> candidates = {
        current / "../migrations",
        current / "core/migrations",
        current / "../core/migrations",
        current / "../../core/migrations",
        current / "../../../core/migrations",
    };

    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate / "0001-initial-schema.sql")) {
            pasty::setClipboardHistoryMigrationDirectory(std::filesystem::absolute(candidate).string());
            return;
        }
    }

    assert(false && "Could not locate migration directory for tests");
}

pasty::ClipboardService makeService(pasty::SettingsStore& settings) {
    return pasty::ClipboardService(pasty::createClipboardHistoryStore(), settings);
}

} // namespace

void testSearch() {
    std::cout << "Running testSearch..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history"));

    pasty::ClipboardHistoryIngestEvent event1;
    event1.text = "Hello World";
    event1.timestampMs = 1000;
    assert(service.ingest(event1));

    pasty::ClipboardHistoryIngestEvent event2;
    event2.text = "Another Item";
    event2.timestampMs = 2000;
    assert(service.ingest(event2));

    pasty::ClipboardHistoryIngestEvent event3;
    event3.text = "Hello Pasty";
    event3.timestampMs = 3000;
    assert(service.ingest(event3));

    pasty::SearchOptions options;
    options.query = "Hello";
    auto results = service.search(options);

    assert(results.size() == 2);
    assert(results[0].content == "Hello Pasty");
    assert(results[1].content == "Hello World");

    service.shutdown();
    std::cout << "testSearch PASSED" << std::endl;
}

void testSearchReturnsImagesWhenQueryIsEmpty() {
    std::cout << "Running testSearchReturnsImagesWhenQueryIsEmpty..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_images");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_images"));

    pasty::ClipboardHistoryIngestEvent textEvent;
    textEvent.text = "Hello World";
    textEvent.timestampMs = 1000;
    assert(service.ingest(textEvent));

    pasty::ClipboardHistoryIngestEvent imageEvent;
    imageEvent.itemType = pasty::ClipboardItemType::Image;
    imageEvent.image.bytes = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
    imageEvent.image.formatHint = "png";
    imageEvent.timestampMs = 2000;
    assert(service.ingest(imageEvent));

    pasty::SearchOptions options;
    options.query = "";
    auto results = service.search(options);

    assert(results.size() == 2);
    assert(results[0].type == pasty::ClipboardItemType::Image);
    assert(results[1].type == pasty::ClipboardItemType::Text);

    service.shutdown();
    std::cout << "testSearchReturnsImagesWhenQueryIsEmpty PASSED" << std::endl;
}

void testRetentionRespectsSettings() {
    std::cout << "Running testRetentionRespectsSettings..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_retention");

    pasty::InMemorySettingsStore settings(2);
    auto service = makeService(settings);
    assert(service.initialize("test_history_retention"));

    pasty::ClipboardHistoryIngestEvent e1; e1.text = "1"; e1.timestampMs = 1000; assert(service.ingest(e1));
    pasty::ClipboardHistoryIngestEvent e2; e2.text = "2"; e2.timestampMs = 2000; assert(service.ingest(e2));
    pasty::ClipboardHistoryIngestEvent e3; e3.text = "3"; e3.timestampMs = 3000; assert(service.ingest(e3));

    auto results = service.list(10, "");
    assert(results.items.size() == 2);
    assert(results.items[0].content == "3");
    assert(results.items[1].content == "2");

    service.shutdown();
    std::cout << "testRetentionRespectsSettings PASSED" << std::endl;
}

void testMigrationDirectoryControlsLookup() {
    std::cout << "Running testMigrationDirectoryControlsLookup..." << std::endl;

    pasty::setClipboardHistoryMigrationDirectory("/tmp/pasty-missing-migrations");
    {
        std::filesystem::remove_all("test_history_missing_migration");
        pasty::InMemorySettingsStore settings(1000);
        auto service = makeService(settings);
        assert(!service.initialize("test_history_missing_migration"));
    }

    configureMigrationDirectoryForTests();
    {
        std::filesystem::remove_all("test_history_migration_ok");
        pasty::InMemorySettingsStore settings(1000);
        auto service = makeService(settings);
        assert(service.initialize("test_history_migration_ok"));
        assert(std::filesystem::exists("test_history_migration_ok/history.sqlite3"));
        service.shutdown();
    }

    std::cout << "testMigrationDirectoryControlsLookup PASSED" << std::endl;
}

int main() {
    testSearch();
    testSearchReturnsImagesWhenQueryIsEmpty();
    testRetentionRespectsSettings();
    testMigrationDirectoryControlsLookup();
    return 0;
}
