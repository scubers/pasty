import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            MonitoringSection(settingsManager: settingsManager)
            StorageConstraintsSection(settingsManager: settingsManager)
        }
        .padding()
    }
}

struct MonitoringSection: View {
    @ObservedObject var settingsManager: SettingsManager
    
    private var pollingIntervalBinding: Binding<Double> {
        Binding(
            get: { Double(settingsManager.settings.clipboard.pollingIntervalMs) },
            set: { settingsManager.settings.clipboard.pollingIntervalMs = Int($0) }
        )
    }

    var body: some View {
        Section(header: Text("Monitoring")) {
            VStack(alignment: .leading) {
                Text("Polling Interval: \(settingsManager.settings.clipboard.pollingIntervalMs) ms")
                Slider(
                    value: pollingIntervalBinding,
                    in: 100...2000,
                    step: 100
                ) {
                    Text("Interval")
                } minimumValueLabel: {
                    Text("100ms")
                } maximumValueLabel: {
                    Text("2s")
                }
            }
        }
    }
}

struct StorageConstraintsSection: View {
    @ObservedObject var settingsManager: SettingsManager
    
    private var maxHistoryCountBinding: Binding<Double> {
        Binding(
            get: { Double(settingsManager.settings.history.maxCount) },
            set: { settingsManager.settings.history.maxCount = Int($0) }
        )
    }
    
    private var maxContentSizeBinding: Binding<Double> {
        Binding(
            get: { Double(settingsManager.settings.clipboard.maxContentSizeBytes) },
            set: { settingsManager.settings.clipboard.maxContentSizeBytes = Int($0) }
        )
    }

    var body: some View {
        Section(header: Text("Storage Constraints")) {
            VStack(alignment: .leading) {
                Text("Max History Items: \(settingsManager.settings.history.maxCount)")
                Slider(
                    value: maxHistoryCountBinding,
                    in: 50...5000,
                    step: 50
                ) {
                    Text("Count")
                } minimumValueLabel: {
                    Text("50")
                } maximumValueLabel: {
                    Text("5000")
                }
            }
            
            VStack(alignment: .leading) {
                Text("Max Content Size: \(settingsManager.settings.clipboard.maxContentSizeBytes / 1024 / 1024) MB")
                Slider(
                    value: maxContentSizeBinding,
                    in: 1024*1024...100*1024*1024,
                    step: 1024*1024
                ) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("1MB")
                } maximumValueLabel: {
                    Text("100MB")
                }
            }
        }
    }
}
