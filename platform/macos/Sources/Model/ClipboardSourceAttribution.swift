// Pasty2 - Copyright (c) 2026. MIT License.

import AppKit

enum ClipboardSourceAttribution {
    static func detectSourceAppID(from pasteboard: NSPasteboard = .general) -> String {
        if let source = pasteboard.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.source")),
           !source.isEmpty {
            return source
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !frontmost.isEmpty {
            return frontmost
        }

        return ""
    }
}

final class AppInfoProvider {
    static let shared = AppInfoProvider()

    private var cache: [String: AppInfo] = [:]
    private let cacheLock = NSLock()
    private let fileManager = FileManager.default

    private init() {}

    func info(for bundleIdentifier: String) -> AppInfo {
        guard !bundleIdentifier.isEmpty else {
            return AppInfo(name: "Unknown", icon: nil)
        }

        cacheLock.lock()
        if let cached = cache[bundleIdentifier] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var result: AppInfo

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let name = appName(from: appURL) ?? bundleIdentifier
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)

            icon.size = NSSize(width: 16, height: 16)

            result = AppInfo(name: name, icon: icon)
        } else {
            result = AppInfo(name: bundleIdentifier, icon: nil)
        }

        cacheLock.lock()
        cache[bundleIdentifier] = result
        cacheLock.unlock()

        return result
    }

    private func appName(from url: URL) -> String? {
        let infoPlistPath = url.appendingPathComponent("Contents/Info.plist").path

        guard let plist = NSDictionary(contentsOfFile: infoPlistPath) else {
            return nil
        }

        if let displayName = plist["CFBundleDisplayName"] as? String {
            return displayName
        }

        if let bundleName = plist["CFBundleName"] as? String {
            return bundleName
        }

        return url.deletingPathExtension().lastPathComponent
    }
}

struct AppInfo {
    let name: String
    let icon: NSImage?

    init(name: String, icon: NSImage?) {
        self.name = name
        self.icon = icon
    }
}
