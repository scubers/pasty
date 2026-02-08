#include <pasty/history/history.h>
#include <pasty/history/store.h>
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

int main() {
    testSearch();
    return 0;
}
