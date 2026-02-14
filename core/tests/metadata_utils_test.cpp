// Pasty - Copyright (c) 2026. MIT License.

#include "utils/metadata_utils.h"

#include <cassert>
#include <iostream>

namespace {

void testParseEmptyMetadata() {
    std::cout << "Running testParseEmptyMetadata..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags("");
    assert(tags.empty());
    
    std::cout << "testParseEmptyMetadata PASSED" << std::endl;
}

void testParseInvalidJson() {
    std::cout << "Running testParseInvalidJson..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags("not valid json");
    assert(tags.empty());
    
    tags = pasty::metadata_utils::parseTags("{broken");
    assert(tags.empty());
    
    std::cout << "testParseInvalidJson PASSED" << std::endl;
}

void testParseNoTagsField() {
    std::cout << "Running testParseNoTagsField..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags(R"({"other": "value"})");
    assert(tags.empty());
    
    tags = pasty::metadata_utils::parseTags(R"({"tags": "not_an_array"})");
    assert(tags.empty());
    
    std::cout << "testParseNoTagsField PASSED" << std::endl;
}

void testParseValidTags() {
    std::cout << "Running testParseValidTags..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags(R"({"tags": ["work", "personal"]})");
    assert(tags.size() == 2);
    assert(tags[0] == "work");
    assert(tags[1] == "personal");
    
    std::cout << "testParseValidTags PASSED" << std::endl;
}

void testParseWithNonStringTags() {
    std::cout << "Running testParseWithNonStringTags..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags(R"({"tags": ["valid", 123, null, true, {"obj": "val"}]})");
    assert(tags.size() == 1);
    assert(tags[0] == "valid");
    
    std::cout << "testParseWithNonStringTags PASSED" << std::endl;
}

void testSerializeEmptyTags() {
    std::cout << "Running testSerializeEmptyTags..." << std::endl;
    
    std::vector<std::string> tags;
    auto json = pasty::metadata_utils::serializeTags(tags);
    assert(json.empty());
    
    std::cout << "testSerializeEmptyTags PASSED" << std::endl;
}

void testSerializeOnlyEmptyStrings() {
    std::cout << "Running testSerializeOnlyEmptyStrings..." << std::endl;
    
    std::vector<std::string> tags = {"", "", ""};
    auto json = pasty::metadata_utils::serializeTags(tags);
    assert(json.empty());
    
    std::cout << "testSerializeOnlyEmptyStrings PASSED" << std::endl;
}

void testSerializeValidTags() {
    std::cout << "Running testSerializeValidTags..." << std::endl;
    
    std::vector<std::string> tags = {"work", "personal"};
    auto json = pasty::metadata_utils::serializeTags(tags);
    assert(json == R"({"tags":["work","personal"]})");
    
    std::cout << "testSerializeValidTags PASSED" << std::endl;
}

void testSerializeFiltersEmpty() {
    std::cout << "Running testSerializeFiltersEmpty..." << std::endl;
    
    std::vector<std::string> tags = {"work", "", "personal", ""};
    auto json = pasty::metadata_utils::serializeTags(tags);
    assert(json == R"({"tags":["work","personal"]})");
    
    std::cout << "testSerializeFiltersEmpty PASSED" << std::endl;
}

void testSerializeRemovesDuplicates() {
    std::cout << "Running testSerializeRemovesDuplicates..." << std::endl;
    
    std::vector<std::string> tags = {"work", "personal", "work", "Work"};
    auto json = pasty::metadata_utils::serializeTags(tags);
    assert(json == R"({"tags":["work","personal","Work"]})");
    
    std::cout << "testSerializeRemovesDuplicates PASSED" << std::endl;
}

void testCaseSensitivity() {
    std::cout << "Running testCaseSensitivity..." << std::endl;
    
    auto tags = pasty::metadata_utils::parseTags(R"({"tags": ["Work", "work", "WORK"]})");
    assert(tags.size() == 3);
    assert(tags[0] == "Work");
    assert(tags[1] == "work");
    assert(tags[2] == "WORK");
    
    std::cout << "testCaseSensitivity PASSED" << std::endl;
}

void testRoundTrip() {
    std::cout << "Running testRoundTrip..." << std::endl;
    
    std::vector<std::string> original = {"tag1", "Tag2", "tag3"};
    auto json = pasty::metadata_utils::serializeTags(original);
    auto parsed = pasty::metadata_utils::parseTags(json);
    
    assert(parsed.size() == original.size());
    for (std::size_t i = 0; i < original.size(); ++i) {
        assert(parsed[i] == original[i]);
    }
    
    std::cout << "testRoundTrip PASSED" << std::endl;
}

void testStableSerialization() {
    std::cout << "Running testStableSerialization..." << std::endl;
    
    std::vector<std::string> tags = {"a", "b", "c"};
    auto json1 = pasty::metadata_utils::serializeTags(tags);
    auto json2 = pasty::metadata_utils::serializeTags(tags);
    
    assert(json1 == json2);
    
    std::cout << "testStableSerialization PASSED" << std::endl;
}

void testNormalizeEmptyTags() {
    std::cout << "Running testNormalizeEmptyTags..." << std::endl;
    
    std::vector<std::string> tags;
    auto normalized = pasty::metadata_utils::normalizeTags(tags);
    assert(normalized.empty());
    
    std::cout << "testNormalizeEmptyTags PASSED" << std::endl;
}

void testNormalizeRemovesEmptyAndDuplicates() {
    std::cout << "Running testNormalizeRemovesEmptyAndDuplicates..." << std::endl;
    
    std::vector<std::string> tags = {"a", "", "b", "a", "", "c", "b"};
    auto normalized = pasty::metadata_utils::normalizeTags(tags);
    
    assert(normalized.size() == 3);
    assert(normalized[0] == "a");
    assert(normalized[1] == "b");
    assert(normalized[2] == "c");
    
    std::cout << "testNormalizeRemovesEmptyAndDuplicates PASSED" << std::endl;
}

void testNormalizePreservesOrder() {
    std::cout << "Running testNormalizePreservesOrder..." << std::endl;
    
    std::vector<std::string> tags = {"z", "a", "z", "m", "a"};
    auto normalized = pasty::metadata_utils::normalizeTags(tags);
    
    assert(normalized.size() == 3);
    assert(normalized[0] == "z");
    assert(normalized[1] == "a");
    assert(normalized[2] == "m");
    
    std::cout << "testNormalizePreservesOrder PASSED" << std::endl;
}

void testTagsEqual() {
    std::cout << "Running testTagsEqual..." << std::endl;
    
    std::vector<std::string> tags1 = {"a", "b", "c"};
    std::vector<std::string> tags2 = {"a", "b", "c"};
    std::vector<std::string> tags3 = {"c", "b", "a"};
    std::vector<std::string> tags4 = {"a", "b"};
    std::vector<std::string> tags5 = {"a", "b", "c", "a"};
    
    assert(pasty::metadata_utils::tagsEqual(tags1, tags2));
    assert(!pasty::metadata_utils::tagsEqual(tags1, tags3));
    assert(!pasty::metadata_utils::tagsEqual(tags1, tags4));
    assert(pasty::metadata_utils::tagsEqual(tags1, tags5));
    
    std::cout << "testTagsEqual PASSED" << std::endl;
}

void testTagsEqualWithEmpty() {
    std::cout << "Running testTagsEqualWithEmpty..." << std::endl;
    
    std::vector<std::string> tags1;
    std::vector<std::string> tags2 = {"", ""};
    std::vector<std::string> tags3 = {"a"};
    
    assert(pasty::metadata_utils::tagsEqual(tags1, tags2));
    assert(!pasty::metadata_utils::tagsEqual(tags1, tags3));
    
    std::cout << "testTagsEqualWithEmpty PASSED" << std::endl;
}

} // namespace

int main() {
    testParseEmptyMetadata();
    testParseInvalidJson();
    testParseNoTagsField();
    testParseValidTags();
    testParseWithNonStringTags();
    testSerializeEmptyTags();
    testSerializeOnlyEmptyStrings();
    testSerializeValidTags();
    testSerializeFiltersEmpty();
    testSerializeRemovesDuplicates();
    testCaseSensitivity();
    testRoundTrip();
    testStableSerialization();
    testNormalizeEmptyTags();
    testNormalizeRemovesEmptyAndDuplicates();
    testNormalizePreservesOrder();
    testTagsEqual();
    testTagsEqualWithEmpty();
    
    std::cout << "All metadata_utils tests PASSED!" << std::endl;
    return 0;
}
