#include <application/history/clipboard_service.h>
#include <history/clipboard_history_store.h>
#include <infrastructure/settings/in_memory_settings_store.h>
#include <store/sqlite_clipboard_history_store.h>

#include <cassert>
#include <filesystem>
#include <iostream>
#include <vector>

namespace {

std::filesystem::path findRepoRoot() {
    const std::filesystem::path current = std::filesystem::current_path();
    const std::vector<std::filesystem::path> candidates = {
        current / "core/migrations",
        current / "../core/migrations",
        current / "../../core/migrations",
        current / "../../../core/migrations",
        current / "../../../../core/migrations",
    };

    for (const auto& candidate : candidates) {
        std::filesystem::path migrationFile = candidate / "0001-initial-schema.sql";
        if (std::filesystem::exists(migrationFile)) {
            // candidate is <repoRoot>/core/migrations, so repo root is candidate.parent_path().parent_path()
            return std::filesystem::absolute(candidate).parent_path().parent_path();
        }
    }

    std::cerr << "Current path: " << current << std::endl;
    std::cerr << "Searched for migrations in:" << std::endl;
    for (const auto& candidate : candidates) {
        std::cerr << "  " << candidate << std::endl;
    }
    assert(false && "Could not locate repo root for tests");
    return {};
}

std::filesystem::path getTestsOutputBaseDir() {
    static std::filesystem::path base = [] {
        std::filesystem::path repoRoot = findRepoRoot();
        std::filesystem::path baseDir = repoRoot / "build" / "core-tests";
        std::filesystem::create_directories(baseDir);
        return baseDir;
    }();
    return base;
}

void configureMigrationDirectoryForTests() {
    std::filesystem::path repoRoot = findRepoRoot();
    std::filesystem::path migrationsDir = repoRoot / "core" / "migrations";
    pasty::setClipboardHistoryMigrationDirectory(migrationsDir.string());
}

pasty::ClipboardService makeService(pasty::SettingsStore& settings) {
    return pasty::ClipboardService(pasty::createClipboardHistoryStore(), settings);
}

} // namespace

void testSearch() {
    std::cout << "Running testSearch..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_images";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_retention";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(2);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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

    std::filesystem::path baseDir = getTestsOutputBaseDir();
    pasty::setClipboardHistoryMigrationDirectory("/tmp/pasty-missing-migrations");
    {
        std::filesystem::path testDir1 = baseDir / "test_history_missing_migration";
        std::filesystem::remove_all(testDir1);
        pasty::InMemorySettingsStore settings(1000);
        auto service = makeService(settings);
        assert(!service.initialize(testDir1.string()));
    }

    configureMigrationDirectoryForTests();
    {
        std::filesystem::path testDir2 = baseDir / "test_history_migration_ok";
        std::filesystem::remove_all(testDir2);
        pasty::InMemorySettingsStore settings(1000);
        auto service = makeService(settings);
        assert(service.initialize(testDir2.string()));
        assert(std::filesystem::exists(testDir2 / "history.sqlite3"));
        service.shutdown();
    }

    std::cout << "testMigrationDirectoryControlsLookup PASSED" << std::endl;
}

void testGetTagsFromNonExistentItem() {
    std::cout << "Running testGetTagsFromNonExistentItem..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_nonexist";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

    auto tags = service.getTags("non-existent-id");
    assert(tags.empty());

    service.shutdown();
    std::cout << "testGetTagsFromNonExistentItem PASSED" << std::endl;
}

void testSetAndGetTags() {
    std::cout << "Running testSetAndGetTags..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_setget";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_dedup";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_empty";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_clear";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_tags_lastcopy";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_search_tags";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

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

void testTextDedupePreservesTags() {
    std::cout << "Running testTextDedupePreservesTags..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_dedupe_tags_text";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

    pasty::ClipboardHistoryIngestEvent event1;
    event1.text = "Duplicate text content";
    event1.timestampMs = 1000;
    assert(service.ingest(event1));

    auto list1 = service.list(10, "");
    assert(list1.items.size() == 1);
    std::string itemId = list1.items[0].id;

    std::vector<std::string> tags = {"work", "important"};
    assert(service.setTags(itemId, tags));

    auto tagsAfterSet = service.getTags(itemId);
    assert(tagsAfterSet.size() == 2);

    pasty::ClipboardHistoryIngestEvent event2;
    event2.text = "Duplicate text content";
    event2.timestampMs = 2000;
    assert(service.ingest(event2));

    auto list2 = service.list(10, "");
    assert(list2.items.size() == 1);

    auto tagsAfterDedupe = service.getTags(itemId);
    assert(tagsAfterDedupe.size() == 2);
    assert(tagsAfterDedupe[0] == "work");
    assert(tagsAfterDedupe[1] == "important");

    auto item = service.getById(itemId);
    assert(item.has_value());
    assert(item->lastCopyTimeMs == 2000);

    service.shutdown();
    std::cout << "testTextDedupePreservesTags PASSED" << std::endl;
}

void testImageDedupePreservesTags() {
    std::cout << "Running testImageDedupePreservesTags..." << std::endl;

    configureMigrationDirectoryForTests();
    std::filesystem::path testDir = getTestsOutputBaseDir() / "test_history_dedupe_tags_image";
    std::filesystem::remove_all(testDir);

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(testDir.string()));

    pasty::ClipboardHistoryIngestEvent event1;
    event1.itemType = pasty::ClipboardItemType::Image;
    event1.image.bytes = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00};
    event1.image.formatHint = "png";
    event1.timestampMs = 1000;
    assert(service.ingest(event1));

    auto list1 = service.list(10, "");
    assert(list1.items.size() == 1);
    std::string itemId = list1.items[0].id;

    std::vector<std::string> tags = {"personal", "screenshot"};
    assert(service.setTags(itemId, tags));

    auto tagsAfterSet = service.getTags(itemId);
    assert(tagsAfterSet.size() == 2);

    pasty::ClipboardHistoryIngestEvent event2;
    event2.itemType = pasty::ClipboardItemType::Image;
    event2.image.bytes = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00};
    event2.image.formatHint = "png";
    event2.timestampMs = 2000;
    assert(service.ingest(event2));

    auto list2 = service.list(10, "");
    assert(list2.items.size() == 1);

    auto tagsAfterDedupe = service.getTags(itemId);
    assert(tagsAfterDedupe.size() == 2);
    assert(tagsAfterDedupe[0] == "personal");
    assert(tagsAfterDedupe[1] == "screenshot");

    auto item = service.getById(itemId);
    assert(item.has_value());
    assert(item->lastCopyTimeMs == 2000);

    service.shutdown();
    std::cout << "testImageDedupePreservesTags PASSED" << std::endl;
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
    testTextDedupePreservesTags();
    testImageDedupePreservesTags();
    return 0;
}
