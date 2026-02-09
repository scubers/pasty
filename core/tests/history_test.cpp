#include <pasty/history/history.h>
#include <pasty/history/store.h>
#include <pasty/settings/settings_api.h>
#include <cassert>
#include <iostream>
#include <vector>
#include <filesystem>

void testSearch() {
    std::cout << "Running testSearch..." << std::endl;
    auto store = pasty::createClipboardHistoryStore();
    pasty::ClipboardHistory history(std::move(store));
    
    std::filesystem::remove_all("test_history");
    assert(history.initialize("test_history"));
    
    // Ingest some data
    pasty::ClipboardHistoryIngestEvent event1;
    event1.text = "Hello World";
    event1.timestampMs = 1000;
    history.ingest(event1);
    
    pasty::ClipboardHistoryIngestEvent event2;
    event2.text = "Another Item";
    event2.timestampMs = 2000;
    history.ingest(event2);
    
    pasty::ClipboardHistoryIngestEvent event3;
    event3.text = "Hello Pasty";
    event3.timestampMs = 3000;
    history.ingest(event3);
    
    // Search "Hello"
    pasty::SearchOptions options;
    options.query = "Hello";
    auto results = history.search(options);
    
    assert(results.size() == 2);
    assert(results[0].content == "Hello Pasty"); // Sorted by time DESC
    assert(results[1].content == "Hello World");
    
    std::cout << "testSearch PASSED" << std::endl;
}

void testSearchReturnsImagesWhenQueryIsEmpty() {
    std::cout << "Running testSearchReturnsImagesWhenQueryIsEmpty..." << std::endl;
    auto store = pasty::createClipboardHistoryStore();
    pasty::ClipboardHistory history(std::move(store));

    std::filesystem::remove_all("test_history_images");
    assert(history.initialize("test_history_images"));

    pasty::ClipboardHistoryIngestEvent textEvent;
    textEvent.text = "Hello World";
    textEvent.timestampMs = 1000;
    history.ingest(textEvent);

    pasty::ClipboardHistoryIngestEvent imageEvent;
    imageEvent.itemType = pasty::ClipboardItemType::Image;
    imageEvent.image.bytes = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}; // PNG signature (minimal valid PNG)
    imageEvent.image.formatHint = "png";
    imageEvent.timestampMs = 2000;
    history.ingest(imageEvent);

    pasty::SearchOptions options;
    options.query = "";
    auto results = history.search(options);

    assert(results.size() == 2);
    assert(results[0].type == pasty::ClipboardItemType::Image); // Results sorted by time DESC
    assert(results[1].type == pasty::ClipboardItemType::Text);

    std::cout << "testSearchReturnsImagesWhenQueryIsEmpty PASSED" << std::endl;
}

void testRetentionRespectsSettings() {
    std::cout << "Running testRetentionRespectsSettings..." << std::endl;
    auto store = pasty::createClipboardHistoryStore();
    pasty::ClipboardHistory history(std::move(store));

    std::filesystem::remove_all("test_history_retention");
    assert(history.initialize("test_history_retention"));

    pasty_settings_initialize(2);

    pasty::ClipboardHistoryIngestEvent e1; e1.text = "1"; e1.timestampMs = 1000; history.ingest(e1);
    pasty::ClipboardHistoryIngestEvent e2; e2.text = "2"; e2.timestampMs = 2000; history.ingest(e2);
    pasty::ClipboardHistoryIngestEvent e3; e3.text = "3"; e3.timestampMs = 3000; history.ingest(e3);

    auto results = history.list(10, "");
    assert(results.items.size() == 2);
    assert(results.items[0].content == "3");
    assert(results.items[1].content == "2");

    std::cout << "testRetentionRespectsSettings PASSED" << std::endl;
}

int main() {
    testSearch();
    testSearchReturnsImagesWhenQueryIsEmpty();
    testRetentionRespectsSettings();
    return 0;
}
