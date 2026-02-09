import SwiftUI

struct OCRSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable OCR", isOn: Binding(
                    get: { settingsManager.settings.ocr.enabled },
                    set: { settingsManager.settings.ocr.enabled = $0 }
                ))
            }
            
            if settingsManager.settings.ocr.enabled {
                Section(header: Text("Configuration")) {
                    VStack(alignment: .leading) {
                        Text("Confidence Threshold: \(String(format: "%.2f", settingsManager.settings.ocr.confidenceThreshold))")
                        Slider(
                            value: Binding(
                                get: { Double(settingsManager.settings.ocr.confidenceThreshold) },
                                set: { settingsManager.settings.ocr.confidenceThreshold = Float($0) }
                            ),
                            in: 0.1...1.0,
                            step: 0.05
                        ) {
                            Text("Confidence")
                        } minimumValueLabel: {
                            Text("Low")
                        } maximumValueLabel: {
                            Text("High")
                        }
                    }
                    
                    Picker("Recognition Level", selection: Binding(
                        get: { settingsManager.settings.ocr.recognitionLevel },
                        set: { settingsManager.settings.ocr.recognitionLevel = $0 }
                    )) {
                        Text("Accurate").tag("accurate")
                        Text("Fast").tag("fast")
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Include in Search", isOn: Binding(
                        get: { settingsManager.settings.ocr.includeInSearch },
                        set: { settingsManager.settings.ocr.includeInSearch = $0 }
                    ))
                }
                
                Section(header: Text("Languages")) {
                    let languages = [
                        "en": "English",
                        "zh-Hans": "Chinese (Simplified)",
                        "zh-Hant": "Chinese (Traditional)",
                        "ja": "Japanese",
                        "ko": "Korean",
                        "ru": "Russian",
                        "fr": "French",
                        "de": "German",
                        "es": "Spanish",
                        "pt": "Portuguese",
                        "it": "Italian",
                        "uk": "Ukrainian"
                    ]
                    
                    List {
                        ForEach(languages.sorted(by: { $0.key < $1.key }), id: \.key) { key, name in
                            HStack {
                                Text(name)
                                Spacer()
                                if settingsManager.settings.ocr.languages.contains(key) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleLanguage(key)
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
        .padding()
    }
    
    private func toggleLanguage(_ code: String) {
        var langs = settingsManager.settings.ocr.languages
        if let index = langs.firstIndex(of: code) {
            langs.remove(at: index)
        } else {
            langs.append(code)
        }
        settingsManager.settings.ocr.languages = langs
    }
}
