import SwiftUI

struct OCRSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "Main") {
                    SettingsRow(title: "Enable OCR", icon: "text.viewfinder") {
                        PastyToggle(isOn: Binding(
                            get: { settingsManager.settings.ocr.enabled },
                            set: { settingsManager.settings.ocr.enabled = $0 }
                        ))
                    }
                    
                    if settingsManager.settings.ocr.enabled {
                        SettingsRow(title: "Include in Search", icon: "magnifyingglass") {
                            PastyToggle(isOn: Binding(
                                get: { settingsManager.settings.ocr.includeInSearch },
                                set: { settingsManager.settings.ocr.includeInSearch = $0 }
                            ))
                        }
                    }
                }
                
                if settingsManager.settings.ocr.enabled {
                    SettingsSection(title: "Configuration") {
                        SettingsRow(title: "Recognition Level", icon: "speedometer") {
                            Picker("", selection: Binding(
                                get: { settingsManager.settings.ocr.recognitionLevel },
                                set: { settingsManager.settings.ocr.recognitionLevel = $0 }
                            )) {
                                Text("Accurate").tag("accurate")
                                Text("Fast").tag("fast")
                            }
                            .pickerStyle(.menu)
                        }
                        
                         SettingsRow(title: "Confidence Threshold", icon: "chart.bar") {
                             VStack(alignment: .trailing) {
                                Text(String(format: "%.2f", settingsManager.settings.ocr.confidenceThreshold))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                PastySlider(
                                    value: Binding(
                                        get: { Double(settingsManager.settings.ocr.confidenceThreshold) },
                                        set: { settingsManager.settings.ocr.confidenceThreshold = Float($0) }
                                    ),
                                    range: 0.1...1.0
                                )
                            }
                        }
                    }
                    
                    SettingsSection(title: "Languages") {
                        VStack(spacing: 0) {
                             ForEach(languages.sorted(by: { $0.key < $1.key }), id: \.key) { key, name in
                                LanguageRow(
                                    name: name,
                                    isSelected: settingsManager.settings.ocr.languages.contains(key)
                                )
                                .onTapGesture {
                                    toggleLanguage(key)
                                }
                                
                                if key != languages.keys.sorted().last {
                                     Divider()
                                         .background(DesignSystem.Colors.border)
                                }
                            }
                        }
                        .background(DesignSystem.Colors.controlBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
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

struct LanguageRow: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(DesignSystem.Colors.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
