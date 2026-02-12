import SwiftUI

struct OCRSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    private var themeColor: Color { viewModel.settings.appearance.themeColor.toColor() }
    
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
                            get: { viewModel.settings.ocr.enabled },
                            set: { newValue in
                                viewModel.updateSettings { $0.ocr.enabled = newValue }
                            }
                        ), activeColor: themeColor)
                    }
                    
                    if viewModel.settings.ocr.enabled {
                        SettingsRow(title: "Include in Search", icon: "magnifyingglass") {
                            PastyToggle(isOn: Binding(
                                get: { viewModel.settings.ocr.includeInSearch },
                                set: { newValue in
                                    viewModel.updateSettings { $0.ocr.includeInSearch = newValue }
                                }
                            ), activeColor: themeColor)
                        }
                    }
                }
                
                if viewModel.settings.ocr.enabled {
                    SettingsSection(title: "Configuration") {
                        SettingsRow(title: "Recognition Level", icon: "speedometer") {
                            Picker("", selection: Binding(
                                get: { viewModel.settings.ocr.recognitionLevel },
                                set: { newValue in
                                    viewModel.updateSettings { $0.ocr.recognitionLevel = newValue }
                                }
                            )) {
                                Text("Accurate").tag("accurate")
                                Text("Fast").tag("fast")
                            }
                            .pickerStyle(.menu)
                        }
                        
                         SettingsRow(title: "Confidence Threshold", icon: "chart.bar") {
                             VStack(alignment: .trailing) {
                                Text(String(format: "%.2f", viewModel.settings.ocr.confidenceThreshold))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                PastySlider(
                                    value: Binding(
                                        get: { Double(viewModel.settings.ocr.confidenceThreshold) },
                                        set: { newValue in
                                            viewModel.updateSettings { $0.ocr.confidenceThreshold = Float(newValue) }
                                        }
                                    ),
                                    accentColor: themeColor,
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
                                    isSelected: viewModel.settings.ocr.languages.contains(key)
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
        viewModel.toggleOCRLanguage(code)
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
