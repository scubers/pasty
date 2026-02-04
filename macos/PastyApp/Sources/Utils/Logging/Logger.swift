import Foundation
import os.log

/// Structured logging utility with JSON output support
enum Logger {
    /// Log levels
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    /// Shared logger instance
    private static let logger = OSLog(subsystem: "com.pasty.PastyApp", category: "clipboard-panel")

    /// Log debug message
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    /// Log info message
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    /// Log warning message
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    /// Log error message
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
    }

    /// Internal log method
    private static func log(level: Level, message: String, file: String, function: String, line: Int) {
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"

        switch level {
        case .debug:
            os_log("%{public}@", log: logger, type: .debug, logMessage)
        case .info:
            os_log("%{public}@", log: logger, type: .info, logMessage)
        case .warning:
            os_log("%{public}@", log: logger, type: .default, logMessage)
        case .error:
            os_log("%{public}@", log: logger, type: .error, logMessage)
        }
    }
}
