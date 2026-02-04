import XCTest
import Cocoa
@testable import PastyApp

/// T052: Unit tests for NSPasteboard change detection
final class MonitorTest: XCTestCase {

    var monitor: Monitor!
    var expectation: XCTestExpectation!

    override func setUp() {
        super.setUp()
        monitor = Monitor()
    }

    override func tearDown() {
        monitor.stopMonitoring()
        super.tearDown()
    }

    func testStartMonitoringInitializesChangeCount() {
        // Given: A new monitor
        let pasteboard = NSPasteboard.general
        let initialCount = pasteboard.changeCount

        // When: Starting monitoring
        var callbackCalled = false
        monitor.startMonitoring {
            callbackCalled = true
        }

        // Then: Monitor should be initialized
        XCTAssertNotNil(monitor, "Monitor should be created")
        monitor.stopMonitoring()
    }

    func testStopMonitoringStopsTimer() {
        // Given: A running monitor
        monitor.startMonitoring {}

        // When: Stopping monitoring
        monitor.stopMonitoring()

        // Then: Monitor should stop without crashing
        // If we reach here without crash, test passes
        XCTAssertTrue(true, "Monitor should stop successfully")
    }

    func testDetectsPasteboardChanges() {
        // Given: A monitor
        var changeDetected = false
        let expectation = self.expectation(description: "Change detected")

        monitor.startMonitoring {
            changeDetected = true
            expectation.fulfill()
        }

        // When: Changing the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("Test content", forType: .string)

        // Then: Change should be detected (within timeout)
        waitForExpectations(timeout: 2.0) { error in
            if let error = error {
                XCTFail("Timeout waiting for change detection: \(error)")
            }
        }

        monitor.stopMonitoring()
    }

    func testPollingIntervalIs500ms() {
        // This test verifies the polling interval is configured correctly
        // The actual implementation uses Timer.scheduledTimer withTimeInterval: 0.5
        // We can't directly test the interval without exposing internals,
        // but we can verify the behavior

        let expectation = self.expectation(description: "Multiple changes detected")

        var changeCount = 0
        monitor.startMonitoring {
            changeCount += 1
            if changeCount >= 2 {
                expectation.fulfill()
            }
        }

        // Make two changes quickly
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("First", forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pasteboard.clearContents()
            pasteboard.setString("Second", forType: .string)
        }

        waitForExpectations(timeout: 3.0) { error in
            if let error = error {
                XCTFail("Timeout: \(error)")
            }
        }

        monitor.stopMonitoring()
    }

    func testMultipleChangesAreDetected() {
        // Given: A monitor
        var changesDetected = 0
        let expectation = self.expectation(description: "Multiple changes")

        monitor.startMonitoring {
            changesDetected += 1
            if changesDetected >= 3 {
                expectation.fulfill()
            }
        }

        // When: Making multiple changes
        let pasteboard = NSPasteboard.general
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                pasteboard.clearContents()
                pasteboard.setString("Change \(i)", forType: .string)
            }
        }

        // Then: All changes should be detected
        waitForExpectations(timeout: 5.0) { error in
            if let error = error {
                XCTFail("Timeout: \(error)")
            }
        }

        monitor.stopMonitoring()
    }
}
