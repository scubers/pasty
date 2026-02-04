import Cocoa

/// Metadata about the application that provided clipboard content
struct SourceApplication {
    let bundleId: String
    let appName: String
    let pid: Int32

    /// Get the current (frontmost) application
    static func current() -> SourceApplication {
        let workspace = NSWorkspace.shared
        let app = workspace.frontmostApplication

        return SourceApplication(
            bundleId: app?.bundleIdentifier ?? "unknown",
            appName: app?.localizedName ?? "Unknown",
            pid: app?.processIdentifier ?? 0
        )
    }
}
