import XCTest
import Cocoa
import UniformTypeIdentifiers
@testable import PastyApp

/// T053: Unit tests for content type detection with priority
final class ContentTypeDetectorTest: XCTestCase {

    var detector: ContentTypeDetector!
    var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        detector = ContentTypeDetector()
        pasteboard = NSPasteboard.general
    }

    override func tearDown() {
        pasteboard.clearContents()
        super.tearDown()
    }

    func testDetectsTextContent() {
        // Given: Pasteboard with text content
        pasteboard.clearContents()
        pasteboard.setString("Sample text", forType: .string)

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should return text
        XCTAssertEqual(contentType, .text, "Should detect text content")
    }

    func testTextHasPriorityOverImage() {
        // Given: Pasteboard with both text and image (text should win)
        pasteboard.clearContents()
        pasteboard.setString("Text", forType: .string)

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should return text (higher priority)
        XCTAssertEqual(contentType, .text, "Text should have priority over image")
    }

    func testDetectsImageContent() {
        // Given: Pasteboard with image content only
        pasteboard.clearContents()
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should return image
        XCTAssertEqual(contentType, .image, "Should detect image content")
    }

    func testDetectsFileReference() {
        // Given: Pasteboard with file URL
        pasteboard.clearContents()
        if let fileURL = URL(string: "file:///tmp/test.txt") {
            pasteboard.setData(fileURL.dataRepresentation, forType: .fileURL)
        }

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should return fileReference
        XCTAssertEqual(contentType, .fileReference, "Should detect file reference")
    }

    func testReturnsUnsupportedForUnknownContent() {
        // Given: Empty pasteboard
        pasteboard.clearContents()

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should return unsupported
        XCTAssertEqual(contentType, .unsupported, "Should return unsupported for unknown content")
    }

    func testPriorityOrderingTextOverFile() {
        // Text > File: If both present, text wins
        pasteboard.clearContents()
        pasteboard.setString("Text", forType: .string)

        let contentType = detector.detectContentType(from: pasteboard)
        XCTAssertEqual(contentType, .text, "Text should have priority over file reference")
    }

    func testPriorityOrderingImageOverFile() {
        // Image > File: If both present, image wins
        pasteboard.clearContents()
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)

        let contentType = detector.detectContentType(from: pasteboard)
        XCTAssertEqual(contentType, .image, "Image should have priority over file reference")
    }

    func testHandlesUTF8PlainText() {
        // Given: Pasteboard with UTF-8 plain text
        pasteboard.clearContents()
        pasteboard.setString("UTF-8 文本", forType: .string)

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should detect as text
        XCTAssertEqual(contentType, .text, "Should detect UTF-8 plain text")
    }

    func testHandlesEmptyString() {
        // Given: Pasteboard with empty string
        pasteboard.clearContents()
        pasteboard.setString("", forType: .string)

        // When: Detecting content type
        let contentType = detector.detectContentType(from: pasteboard)

        // Then: Should still detect as text (empty string is still text)
        XCTAssertEqual(contentType, .text, "Empty string should be detected as text")
    }
}
