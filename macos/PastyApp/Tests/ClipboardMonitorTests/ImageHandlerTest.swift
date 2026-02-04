import XCTest
import Cocoa
@testable import PastyApp

/// T055: Unit tests for image handler processing
final class ImageHandlerTest: XCTestCase {

    var handler: ImageHandler!
    var pasteboard: NSPasteboard!
    var mockCoordinator: MockClipboardCoordinator!

    override func setUp() {
        super.setUp()
        handler = ImageHandler()
        pasteboard = NSPasteboard.general
        mockCoordinator = MockClipboardCoordinator()
    }

    override func tearDown() {
        pasteboard.clearContents()
        super.tearDown()
    }

    func testExtractsPNGImageFromPasteboard() {
        // Given: Pasteboard with PNG image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Image data should be extracted
        XCTAssertNotNil(mockCoordinator.lastStoredImageData, "Should extract PNG image data")
        XCTAssertEqual(mockCoordinator.lastStoredImageFormat, "png", "Should detect PNG format")
    }

    func testExtractsTIFFImageFromPasteboard() {
        // Given: Pasteboard with TIFF image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Image data should be extracted
        XCTAssertNotNil(mockCoordinator.lastStoredImageData, "Should extract TIFF image data")
        XCTAssertEqual(mockCoordinator.lastStoredImageFormat, "tiff", "Should detect TIFF format")
    }

    func testPrefersPNGOverTIFF() {
        // Given: Pasteboard with both PNG and TIFF
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)
        pasteboard.setData(image.tiffRepresentation, forType: .tiff)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Should prefer PNG format
        XCTAssertEqual(mockCoordinator.lastStoredImageFormat, "png", "Should prefer PNG over TIFF")
    }

    func testHandlesLargeImage() {
        // Given: Pasteboard with large image data
        let largeSize = NSSize(width: 4000, height: 4000)
        let image = NSImage(size: largeSize)
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Large image should be handled
        XCTAssertNotNil(mockCoordinator.lastStoredImageData, "Should handle large images")
        XCTAssertTrue((mockCoordinator.lastStoredImageData?.count ?? 0) > 0, "Image data should not be empty")
    }

    func testHandlesSmallImage() {
        // Given: Pasteboard with small image
        let smallSize = NSSize(width: 10, height: 10)
        let image = NSImage(size: smallSize)
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Small image should be handled
        XCTAssertNotNil(mockCoordinator.lastStoredImageData, "Should handle small images")
    }

    func testDoesNothingWhenNoImagePresent() {
        // Given: Empty pasteboard
        pasteboard.clearContents()

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Should not store anything
        XCTAssertNil(mockCoordinator.lastStoredImageData, "Should not extract from empty pasteboard")
    }

    func testDoesNothingWhenTextContentPresent() {
        // Given: Pasteboard with text (not image)
        pasteboard.clearContents()
        pasteboard.setString("Text content", forType: .string)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Should not store image data
        XCTAssertNil(mockCoordinator.lastStoredImageData, "Should not extract image from text content")
    }

    func testPassesSourceApplicationCorrectly() {
        // Given: Pasteboard with image and specific source
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)

        let source = SourceApplication(bundleId: "com.example.app", appName: "ExampleApp", pid: 5678)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Source application should be passed correctly
        XCTAssertEqual(mockCoordinator.lastSource?.bundleId, "com.example.app", "Should pass source bundle ID")
        XCTAssertEqual(mockCoordinator.lastSource?.appName, "ExampleApp", "Should pass source app name")
        XCTAssertEqual(mockCoordinator.lastSource?.pid, 5678, "Should pass source PID")
    }

    func testImageDataIsNotEmpty() {
        // Given: Pasteboard with image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation, forType: .png)

        let source = SourceApplication(bundleId: "com.test.app", appName: "TestApp", pid: 1234)

        // When: Handling the pasteboard
        handler.handle(pasteboard: pasteboard, source: source, coordinator: mockCoordinator)

        // Then: Image data should not be empty
        XCTAssertTrue((mockCoordinator.lastStoredImageData?.count ?? 0) > 0, "Image data should not be empty")
    }
}

// MARK: - Mock Coordinator

class MockClipboardCoordinator: ClipboardCoordinator {
    var lastStoredImageData: Data?
    var lastStoredImageFormat: String?
    var lastSource: SourceApplication?

    override func storeTextContent(_ text: String, source: SourceApplication) {
        // Not used in image handler tests
    }

    override func storeImageContent(_ data: Data, format: String, source: SourceApplication) {
        lastStoredImageData = data
        lastStoredImageFormat = format
        lastSource = source
    }
}
