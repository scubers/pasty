import XCTest
import Cocoa
@testable import PastyApp

/// T054: Unit tests for text handler extraction
final class TextHandlerTest: XCTestCase {

    var handler: TextHandler!
    var pasteboard: NSPasteboard!
    var mockCoordinator: MockClipboardCoordinator!

    override func setUp() {
        super.setUp()
        handler = TextHandler()
        pasteboard = NSPasteboard.general
        mockCoordinator = MockClipboardCoordinator()
    }

    override func tearDown() {
        pasteboard.clearContents()
        super.tearDown()
    }

    func testExtractsTextFromPasteboard() {
        // Given: Pasteboard with text content
        let testText = "Sample text content"
        pasteboard.clearContents()
        pasteboard.setString(testText, forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Text should be extracted and stored
        XCTAssertEqual(mockCoordinator.lastStoredText, testText, "Should extract and store text")
    }

    func testHandlesEmptyString() {
        // Given: Pasteboard with empty string
        pasteboard.clearContents()
        pasteboard.setString("", forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Empty string should be stored
        XCTAssertEqual(mockCoordinator.lastStoredText, "", "Should handle empty string")
    }

    func testHandlesMultilineText() {
        // Given: Pasteboard with multiline text
        let multilineText = """
        Line 1
        Line 2
        Line 3
        """
        pasteboard.clearContents()
        pasteboard.setString(multilineText, forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Multiline text should be preserved
        XCTAssertEqual(mockCoordinator.lastStoredText, multilineText, "Should preserve multiline text")
    }

    func testHandlesSpecialCharacters() {
        // Given: Pasteboard with special characters
        let specialText = "Special: !@#$%^&*()[]{}\"'\\"
        pasteboard.clearContents()
        pasteboard.setString(specialText, forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Special characters should be preserved
        XCTAssertEqual(mockCoordinator.lastStoredText, specialText, "Should handle special characters")
    }

    func testHandlesUnicodeCharacters() {
        // Given: Pasteboard with Unicode characters
        let unicodeText = "Hello 世界 🌍 Ñoño"
        pasteboard.clearContents()
        pasteboard.setString(unicodeText, forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Unicode should be preserved
        XCTAssertEqual(mockCoordinator.lastStoredText, unicodeText, "Should handle Unicode characters")
    }

    func testHandlesVeryLongText() {
        // Given: Pasteboard with very long text
        let longText = String(repeating: "A", count: 100000)
        pasteboard.clearContents()
        pasteboard.setString(longText, forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Long text should be handled
        XCTAssertEqual(mockCoordinator.lastStoredText, longText, "Should handle long text")
    }

    func testDoesNothingWhenNoTextPresent() {
        // Given: Empty pasteboard
        pasteboard.clearContents()

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Should not store anything
        XCTAssertNil(mockCoordinator.lastStoredText, "Should not extract from empty pasteboard")
    }

    func testPassesSourceApplicationCorrectly() {
        // Given: Pasteboard with text and specific source
        pasteboard.clearContents()
        pasteboard.setString("Test", forType: .string)

        let source = SourceApplication(bundleId: "com.example.app", appName: "ExampleApp", pid: 5678)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Source application should be passed correctly
        XCTAssertEqual(mockCoordinator.lastSource?.bundleId, "com.example.app", "Should pass source bundle ID")
        XCTAssertEqual(mockCoordinator.lastSource?.appName, "ExampleApp", "Should pass source app name")
        XCTAssertEqual(mockCoordinator.lastSource?.pid, 5678, "Should pass source PID")
    }
}

// MARK: - Mock Coordinator

class MockClipboardCoordinator: ClipboardCoordinator {
    var lastStoredText: String?
    var lastSource: SourceApplication?

    override func storeTextContent(_ text: String, source: SourceApplication) {
        lastStoredText = text
        lastSource = source
    }

    override func storeImageContent(_ data: Data, format: String, source: SourceApplication) {
        // Not used in text handler tests
    }
}
