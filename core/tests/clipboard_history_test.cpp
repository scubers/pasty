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

void testGetTagsFromNonExistentItem() {
    std::cout << "Running testGetTagsFromNonExistentItem..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_nonexist");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_nonexist"));

    auto tags = service.getTags("non-existent-id");
    assert(tags.empty());

    service.shutdown();
    std::cout << "testGetTagsFromNonExistentItem PASSED" << std::endl;
}

void testSetAndGetTags() {
    std::cout << "Running testSetAndGetTags..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_setget");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_setget"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Test content for tags";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    assert(list.items.size() == 1);
    std::string itemId = list.items[0].id;

    auto tagsBeforeSet = service.getTags(itemId);
    assert(tagsBeforeSet.empty());

    std::vector<std::string> tagsToSet = {"work", "important", "project"};
    assert(service.setTags(itemId, tagsToSet));

    auto tagsAfterSet = service.getTags(itemId);
    assert(tagsAfterSet.size() == 3);
    assert(tagsAfterSet[0] == "work");
    assert(tagsAfterSet[1] == "important");
    assert(tagsAfterSet[2] == "project");

    auto itemAfterSet = service.getById(itemId);
    assert(itemAfterSet.has_value());
    assert(itemAfterSet->updateTimeMs > 1000);

    service.shutdown();
    std::cout << "testSetAndGetTags PASSED" << std::endl;
}

void testSetTagsDeduplicates() {
    std::cout << "Running testSetTagsDeduplicates..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_dedup");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_dedup"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Test dedup";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    std::string itemId = list.items[0].id;

    std::vector<std::string> tagsWithDuplicates = {"work", "work", "personal", "Work"};
    assert(service.setTags(itemId, tagsWithDuplicates));

    auto tags = service.getTags(itemId);
    assert(tags.size() == 3);
    assert(tags[0] == "work");
    assert(tags[1] == "personal");
    assert(tags[2] == "Work");

    service.shutdown();
    std::cout << "testSetTagsDeduplicates PASSED" << std::endl;
}

void testSetTagsFiltersEmpty() {
    std::cout << "Running testSetTagsFiltersEmpty..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_empty");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_empty"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Test empty filter";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    std::string itemId = list.items[0].id;

    std::vector<std::string> tagsWithEmpty = {"work", "", "personal", ""};
    assert(service.setTags(itemId, tagsWithEmpty));

    auto tags = service.getTags(itemId);
    assert(tags.size() == 2);
    assert(tags[0] == "work");
    assert(tags[1] == "personal");

    service.shutdown();
    std::cout << "testSetTagsFiltersEmpty PASSED" << std::endl;
}

void testSetEmptyTagsClearsAll() {
    std::cout << "Running testSetEmptyTagsClearsAll..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_clear");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_clear"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Test clear";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    std::string itemId = list.items[0].id;

    std::vector<std::string> initialTags = {"work", "personal"};
    assert(service.setTags(itemId, initialTags));
    assert(service.getTags(itemId).size() == 2);

    std::vector<std::string> emptyTags;
    assert(service.setTags(itemId, emptyTags));
    assert(service.getTags(itemId).empty());

    service.shutdown();
    std::cout << "testSetEmptyTagsClearsAll PASSED" << std::endl;
}

void testSetTagsDoesNotChangeLastCopyTime() {
    std::cout << "Running testSetTagsDoesNotChangeLastCopyTime..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_tags_lastcopy");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_tags_lastcopy"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Test last copy time";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    std::string itemId = list.items[0].id;
    auto itemBefore = service.getById(itemId);
    assert(itemBefore.has_value());
    pasty::HistoryTimestampMs lastCopyTimeBefore = itemBefore->lastCopyTimeMs;

    std::vector<std::string> tags = {"work"};
    assert(service.setTags(itemId, tags));

    auto itemAfter = service.getById(itemId);
    assert(itemAfter.has_value());
    assert(itemAfter->lastCopyTimeMs == lastCopyTimeBefore);

    service.shutdown();
    std::cout << "testSetTagsDoesNotChangeLastCopyTime PASSED" << std::endl;
}

void testSearchMatchesTagsInMetadata() {
    std::cout << "Running testSearchMatchesTagsInMetadata..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::remove_all("test_history_search_tags");

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize("test_history_search_tags"));

    pasty::ClipboardHistoryIngestEvent event;
    event.text = "Body text without search token";
    event.timestampMs = 1000;
    assert(service.ingest(event));

    auto list = service.list(10, "");
    assert(list.items.size() == 1);
    const std::string itemId = list.items[0].id;

    std::vector<std::string> tags = {"project-alpha"};
    assert(service.setTags(itemId, tags));

    pasty::SearchOptions hit;
    hit.query = "project-alpha";
    auto hitResults = service.search(hit);
    assert(hitResults.size() == 1);
    assert(hitResults[0].id == itemId);

    pasty::SearchOptions miss;
    miss.query = "non-existent-tag";
    auto missResults = service.search(miss);
    assert(missResults.empty());

    service.shutdown();
    std::cout << "testSearchMatchesTagsInMetadata PASSED" << std::endl;
}

int main() {
    testSearch();
    testSearchReturnsImagesWhenQueryIsEmpty();
    testRetentionRespectsSettings();
    testMigrationDirectoryControlsLookup();
    testGetTagsFromNonExistentItem();
    testSetAndGetTags();
    testSetTagsDeduplicates();
    testSetTagsFiltersEmpty();
    testSetEmptyTagsClearsAll();
    testSetTagsDoesNotChangeLastCopyTime();
    testSearchMatchesTagsInMetadata();
    return 0;
}
