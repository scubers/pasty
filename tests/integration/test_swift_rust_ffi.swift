#!/usr/bin/env swift
// Integration tests for Swift-Rust FFI bridge
//
// These tests verify that Swift can correctly call Rust FFI functions
// and handle memory management across the language boundary.

import Foundation

// MARK: - FFI Function Declarations

@_silgen_name("pasty_get_version")
func pasty_get_version() -> UnsafeMutablePointer<CChar>?

@_silgen_name("pasty_init")
func pasty_init() -> Int32

@_silgen_name("pasty_shutdown")
func pasty_shutdown() -> Int32

@_silgen_name("pasty_free_string")
func pasty_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

@_silgen_name("pasty_get_last_error")
func pasty_get_last_error() -> UnsafeMutablePointer<CChar>?

// MARK: - Test Framework

class TestRunner {
    private var testsPassed = 0
    private var testsFailed = 0
    private var testResults: [String] = []

    func runTest(_ name: String, test: () -> Bool) {
        print("Running: \(name)...", terminator: " ")

        if test() {
            print("✓ PASS")
            testsPassed += 1
            testResults.append("✓ \(name)")
        } else {
            print("✗ FAIL")
            testsFailed += 1
            testResults.append("✗ \(name)")
        }
    }

    func printSummary() {
        print("\n" + String(repeating: "=", count: 60))
        print("Test Summary")
        print(String(repeating: "=", count: 60))
        print("Total: \(testsPassed + testsFailed) | Passed: \(testsPassed) | Failed: \(testsFailed)")
        print()

        for result in testResults {
            print(result)
        }

        print()
        if testsFailed == 0 {
            print("🎉 All tests passed!")
        } else {
            print("⚠️  Some tests failed")
        }
    }

    var exitCode: Int32 {
        return testsFailed == 0 ? 0 : 1
    }
}

// MARK: - Tests

let runner = TestRunner()

// Test 1: Verify pasty_get_version() returns valid semver string
runner.runTest("FFI: pasty_get_version() returns valid semver") {
    guard let cString = pasty_get_version() else {
        print("ERROR: pasty_get_version() returned null")
        return false
    }

    // Convert UnsafeMutablePointer<CChar> to String
    let version = String(cString: cString)

    // Validate semver format (e.g., "0.1.0")
    let semverPattern = #"^\d+\.\d+\.\d+"#
    let semverRegex = try? NSRegularExpression(pattern: semverPattern)
    let range = NSRange(location: 0, length: version.utf16.count)
    let match = semverRegex?.firstMatch(in: version, range: range)

    if match == nil {
        print("ERROR: Version '\(version)' does not match semver format")
        return false
    }

    print("Version: \(version)")
    return true
}

// Test 2: Verify pasty_init() and pasty_shutdown() can be called without crashes
runner.runTest("FFI: pasty_init() and pasty_shutdown() complete successfully") {
    let initResult = pasty_init()
    if initResult != 0 {
        let error = pasty_get_last_error()
        let errorMsg = error.map { String(cString: $0) } ?? "Unknown error"
        print("ERROR: pasty_init() failed with code \(initResult): \(errorMsg)")
        return false
    }

    let shutdownResult = pasty_shutdown()
    if shutdownResult != 0 {
        let error = pasty_get_last_error()
        let errorMsg = error.map { String(cString: $0) } ?? "Unknown error"
        print("ERROR: pasty_shutdown() failed with code \(shutdownResult): \(errorMsg)")
        return false
    }

    // Initialize again for subsequent tests
    let reinitResult = pasty_init()
    if reinitResult != 0 {
        print("ERROR: Re-initialization failed")
        return false
    }

    return true
}

// Test 3: Verify string memory management (Rust allocates, Swift frees)
runner.runTest("FFI: String memory management works correctly") {
    // Allocate a string by calling get_last_error (should return null if no error)
    let errorPtr = pasty_get_last_error()

    // Test freeing null pointer (should be safe)
    pasty_free_string(nil)

    // If errorPtr is not null, verify we can free it
    if let errorPtr = errorPtr {
        // Copy the string first
        let errorMsg = String(cString: errorPtr)
        print("Error message (if any): \(errorMsg)")

        // Free the string
        pasty_free_string(errorPtr)

        // Note: We can't really verify the memory was freed safely from Swift,
        // but we can at least verify the call doesn't crash
    }

    return true
}

// Test 4: Verify multiple init/shutdown cycles work
runner.runTest("FFI: Multiple init/shutdown cycles work") {
    for i in 1...3 {
        let result = pasty_init()
        if result != 0 {
            print("ERROR: Init cycle \(i) failed")
            return false
        }

        let shutdownResult = pasty_shutdown()
        if shutdownResult != 0 {
            print("ERROR: Shutdown cycle \(i) failed")
            return false
        }
    }

    // Re-initialize for cleanup
    _ = pasty_init()

    return true
}

// Test 5: Verify get_version after init
runner.runTest("FFI: get_version() works after init()") {
    let version1 = pasty_get_version().map { String(cString: $0) }

    _ = pasty_shutdown()
    _ = pasty_init()

    let version2 = pasty_get_version().map { String(cString: $0) }

    if version1 != version2 {
        print("ERROR: Version changed after re-init: '\(version1 ?? "nil")' vs '\(version2 ?? "nil")'")
        return false
    }

    return true
}

// Print summary and exit
runner.printSummary()
exit(runner.exitCode)
