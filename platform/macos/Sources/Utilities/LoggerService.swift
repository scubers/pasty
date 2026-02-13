import Foundation
import CocoaLumberjack
import CocoaLumberjackSwift
import PastyCore

// Global C-compatible callback function
private func coreLogCallback(level: Int32, tag: UnsafePointer<CChar>!, message: UnsafePointer<CChar>!, file: UnsafePointer<CChar>!, line: Int32) {
    let msgStr = message.map { String(cString: $0) } ?? ""
    let tagStr = tag.map { String(cString: $0) }
    let fileStr = file.map { String(cString: $0) } ?? ""
    
    // Default level for DDLogMessage
    #if DEBUG
    let ddLevel: DDLogLevel = .debug
    #else
    let ddLevel: DDLogLevel = .info
    #endif
    
    let flag: DDLogFlag
    // Map pasty.LogLevel (int) to DDLogFlag
    // Verbose = 0, Debug = 1, Info = 2, Warn = 3, Error = 4
    switch level {
    case 0: flag = .verbose
    case 1: flag = .debug
    case 2: flag = .info
    case 3: flag = .warning
    case 4: flag = .error
    default: flag = .info
    }
    
    // Construct the log message
    let logMsg = DDLogMessage(
        format: msgStr,
        args: getVaList([]),
        level: ddLevel,
        flag: flag,
        context: 0,
        file: fileStr,
        function: nil,
        line: UInt(line),
        tag: tagStr,
        options: [],
        timestamp: Date()
    )
    
    DDLog.sharedInstance.log(asynchronous: true, message: logMsg)
}

class LogFormatter: NSObject, DDLogFormatter {
    private let dateFormatter: DateFormatter
    
    override init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        super.init()
    }
    
    func format(message logMessage: DDLogMessage) -> String? {
        let level: String
        switch logMessage.flag {
        case .verbose: level = "V"
        case .debug:   level = "D"
        case .info:    level = "I"
        case .warning: level = "W"
        case .error:   level = "E"
        default:       level = "?"
        }
        
        let timestamp = dateFormatter.string(from: logMessage.timestamp)
        let file = (logMessage.file as NSString).lastPathComponent
        return "\(timestamp) [\(level)] [\(file):\(logMessage.line)] \(logMessage.message)"
    }
}

class LoggerService {
    static let shared = LoggerService()
    
    private init() {}
    
    func setup() {
        // Console logger
        let osLogger = DDOSLogger.sharedInstance
        osLogger.logFormatter = LogFormatter()
        DDLog.add(osLogger)
        
        // File logger
        let logsDir = AppPaths.appDataDirectory().appendingPathComponent("Logs")
        let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDir.path)
        let fileLogger = DDFileLogger(logFileManager: logFileManager)
        
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        fileLogger.maximumFileSize = 10 * 1024 * 1024 // 10MB
        
        DDLog.add(fileLogger)
        
        // Register callback to Core
        pasty_logger_initialize(coreLogCallback)
        
        // Log startup
        LoggerService.info("LoggerService initialized. Logs directory: \(logsDir.path)")
    }
    
    // MARK: - Public API
    
    static func verbose(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        DDLogVerbose("\(message())", file: file, function: function, line: line)
    }
    
    static func debug(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        DDLogDebug("\(message())", file: file, function: function, line: line)
    }
    
    static func info(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        DDLogInfo("\(message())", file: file, function: function, line: line)
    }
    
    static func warn(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        DDLogWarn("\(message())", file: file, function: function, line: line)
    }
    
    static func error(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        DDLogError("\(message())", file: file, function: function, line: line)
    }
}
