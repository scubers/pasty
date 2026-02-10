// Pasty - Copyright (c) 2026. MIT License.

import Foundation

enum AppPaths {
    static func appDataDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent(getAppName(), isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(getAppName(), isDirectory: true)
        }

        return directory
    }
    
    private static func getAppName() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String

        return appName ?? "Pasty"
    }
}
