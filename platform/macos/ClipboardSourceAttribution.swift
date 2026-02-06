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
