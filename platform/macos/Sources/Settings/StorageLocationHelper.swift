import Foundation
import AppKit
import SwiftUI

struct StorageLocationHelper {
    static func selectNewDirectory(settingsManager: SettingsManager, onComplete: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select a new location for Pasty settings and data"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                onComplete(url)
            } else {
                onComplete(nil)
            }
        }
    }

    static func validateAndSetDirectory(_ url: URL, settingsManager: SettingsManager, showError: @escaping (String) -> Void, showRestart: @escaping () -> Void) {
        guard validateDirectory(url) else {
            showError("The selected directory is not writable.")
            return
        }

        settingsManager.setClipboardDataDirectory(url)
        showRestart()
    }

    static func validateDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            return false
        }

        guard fileManager.isReadableFile(atPath: url.path),
              fileManager.isWritableFile(atPath: url.path) else {
            return false
        }

        let probeURL = url.appendingPathComponent(".pasty_write_probe_\(UUID().uuidString)")
        do {
            try Data("ok".utf8).write(to: probeURL, options: .atomic)
            try? fileManager.removeItem(at: probeURL)
            return true
        } catch {
            try? fileManager.removeItem(at: probeURL)
            return false
        }
    }
}
