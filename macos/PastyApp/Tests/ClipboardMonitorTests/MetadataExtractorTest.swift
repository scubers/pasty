import XCTest
import Cocoa
@testable import PastyApp

/// T056: Unit tests for source app extraction
final class MetadataExtractorTest: XCTestCase {

    func testGetCurrentApplicationReturnsBundleId() {
        // Given: Running application
        // When: Getting current application
        let source = SourceApplication.current()

        // Then: Should return a bundle ID
        XCTAssertFalse(source.bundleId.isEmpty, "Should return a bundle ID")
        XCTAssertNotEqual(source.bundleId, "unknown", "Should detect actual bundle ID in test environment")
    }

    func testGetCurrentApplicationReturnsAppName() {
        // Given: Running application
        // When: Getting current application
        let source = SourceApplication.current()

        // Then: Should return an app name
        XCTAssertFalse(source.appName.isEmpty, "Should return an app name")
        XCTAssertNotEqual(source.appName, "Unknown", "Should detect actual app name in test environment")
    }

    func testGetCurrentApplicationReturnsPID() {
        // Given: Running application
        // When: Getting current application
        let source = SourceApplication.current()

        // Then: Should return a valid PID
        XCTAssertGreaterThan(source.pid, 0, "Should return a valid PID")
    }

    func testSourceApplicationStructureIsCorrect() {
        // Given: A source application
        let source = SourceApplication(
            bundleId: "com.example.test",
            appName: "TestApp",
            pid: 1234
        )

        // Then: Should have correct structure
        XCTAssertEqual(source.bundleId, "com.example.test", "Should store bundle ID")
        XCTAssertEqual(source.appName, "TestApp", "Should store app name")
        XCTAssertEqual(source.pid, 1234, "Should store PID")
    }

    func testHandlesUnknownApplication() {
        // This test verifies behavior when application detection fails
        // In normal operation, NSWorkspace.shared.frontmostApplication should always return something

        // Given: Current application (may be unknown in some test environments)
        let source = SourceApplication.current()

        // When: Accessing properties
        // Then: Should not crash and return defaults
        XCTAssertNotNil(source.bundleId, "Bundle ID should not be nil")
        XCTAssertNotNil(source.appName, "App name should not be nil")
        XCTAssertNotNil(source.pid, "PID should not be nil")
    }

    func testSourceApplicationWithValidPID() {
        // Given: Source application with valid PID range
        let source = SourceApplication(
            bundleId: "com.test.app",
            appName: "Test",
            pid: Int32(ProcessInfo.processInfo.processIdentifier)
        )

        // Then: PID should be valid
        XCTAssertEqual(source.pid, Int32(ProcessInfo.processInfo.processIdentifier), "Should accept valid PID")
    }

    func testMultipleSourceApplicationsAreIndependent() {
        // Given: Two source applications
        let source1 = SourceApplication(
            bundleId: "com.test.app1",
            appName: "TestApp1",
            pid: 1111
        )

        let source2 = SourceApplication(
            bundleId: "com.test.app2",
            appName: "TestApp2",
            pid: 2222
        )

        // Then: Should be independent
        XCTAssertNotEqual(source1.bundleId, source2.bundleId, "Bundle IDs should be different")
        XCTAssertNotEqual(source1.appName, source2.appName, "App names should be different")
        XCTAssertNotEqual(source1.pid, source2.pid, "PIDs should be different")
    }

    func testSourceApplicationHandlesSpecialCharactersInBundleId() {
        // Given: Bundle ID with special characters (valid format)
        let source = SourceApplication(
            bundleId: "com.example.test-app",
            appName: "Test App",
            pid: 1234
        )

        // Then: Should handle special characters
        XCTAssertEqual(source.bundleId, "com.example.test-app", "Should handle hyphen in bundle ID")
    }

    func testSourceApplicationHandlesUnicodeInAppName() {
        // Given: App name with Unicode characters
        let source = SourceApplication(
            bundleId: "com.test.app",
            appName: "测试应用",
            pid: 1234
        )

        // Then: Should handle Unicode
        XCTAssertEqual(source.appName, "测试应用", "Should handle Unicode in app name")
    }

    func testGetCurrentApplicationIsConsistent() {
        // Given: Multiple calls to current()
        let source1 = SourceApplication.current()
        let source2 = SourceApplication.current()

        // Then: Should return consistent results for same process
        // (assuming app doesn't change between calls)
        XCTAssertEqual(source1.bundleId, source2.bundleId, "Bundle ID should be consistent")
        XCTAssertEqual(source1.appName, source2.appName, "App name should be consistent")
        XCTAssertEqual(source1.pid, source2.pid, "PID should be consistent")
    }
}
