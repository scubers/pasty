# macOS Structure Refactor Migration Mapping

This file records the pre-migration to post-migration Swift path mapping for change `macos-structure-refactor`.

| Original Path | New Path |
|---|---|
| `platform/macos/Sources/App.swift` | `platform/macos/Sources/App.swift` |
| `platform/macos/Sources/DesignSystem/Components/DangerButton.swift` | `platform/macos/Sources/DesignSystem/Components/DangerButton.swift` |
| `platform/macos/Sources/DesignSystem/Components/PastySlider.swift` | `platform/macos/Sources/DesignSystem/Components/PastySlider.swift` |
| `platform/macos/Sources/DesignSystem/Components/PastyToggle.swift` | `platform/macos/Sources/DesignSystem/Components/PastyToggle.swift` |
| `platform/macos/Sources/DesignSystem/Components/VisualEffectBlur.swift` | `platform/macos/Sources/DesignSystem/Components/VisualEffectBlur.swift` |
| `platform/macos/Sources/DesignSystem/DesignSystem+Modifiers.swift` | `platform/macos/Sources/DesignSystem/DesignSystem+Modifiers.swift` |
| `platform/macos/Sources/DesignSystem/DesignSystem.swift` | `platform/macos/Sources/DesignSystem/DesignSystem.swift` |
| `platform/macos/Sources/DesignSystem/String+Color.swift` | `platform/macos/Sources/DesignSystem/String+Color.swift` |
| `platform/macos/Sources/Model/ClipboardItemRow.swift` | `platform/macos/Sources/Features/MainPanel/Model/ClipboardItemRow.swift` |
| `platform/macos/Sources/Model/ClipboardSourceAttribution.swift` | `platform/macos/Sources/Features/MainPanel/Model/ClipboardSourceAttribution.swift` |
| `platform/macos/Sources/Settings/AboutSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/AboutSettingsView.swift` |
| `platform/macos/Sources/Settings/AppearanceSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/AppearanceSettingsView.swift` |
| `platform/macos/Sources/Settings/ClipboardSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/ClipboardSettingsView.swift` |
| `platform/macos/Sources/Settings/GeneralSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/GeneralSettingsView.swift` |
| `platform/macos/Sources/Settings/OCRSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/OCRSettingsView.swift` |
| `platform/macos/Sources/Settings/SettingsDirectoryView.swift` | `platform/macos/Sources/Features/Settings/View/SettingsDirectoryView.swift` |
| `platform/macos/Sources/Settings/SettingsManager.swift` | `platform/macos/Sources/Services/Impl/SettingsManager.swift` |
| `platform/macos/Sources/Settings/SettingsView.swift` | `platform/macos/Sources/Features/Settings/View/SettingsView.swift` |
| `platform/macos/Sources/Settings/SettingsWindowController.swift` | `platform/macos/Sources/Features/Settings/View/SettingsWindowController.swift` |
| `platform/macos/Sources/Settings/ShortcutsSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/ShortcutsSettingsView.swift` |
| `platform/macos/Sources/Settings/StorageLocationHelper.swift` | `platform/macos/Sources/Features/Settings/View/StorageLocationHelper.swift` |
| `platform/macos/Sources/Settings/StorageLocationSettingsView.swift` | `platform/macos/Sources/Features/Settings/View/StorageLocationSettingsView.swift` |
| `platform/macos/Sources/Settings/Views/SettingsContentContainer.swift` | `platform/macos/Sources/Features/Settings/View/Views/SettingsContentContainer.swift` |
| `platform/macos/Sources/Settings/Views/SettingsNavigation.swift` | `platform/macos/Sources/Features/Settings/View/Views/SettingsNavigation.swift` |
| `platform/macos/Sources/Settings/Views/SettingsSection.swift` | `platform/macos/Sources/Features/Settings/View/Views/SettingsSection.swift` |
| `platform/macos/Sources/Settings/Views/SettingsSidebarView.swift` | `platform/macos/Sources/Features/Settings/View/Views/SettingsSidebarView.swift` |
| `platform/macos/Sources/Utils/AppPaths.swift` | `platform/macos/Sources/Utilities/AppPaths.swift` |
| `platform/macos/Sources/Utils/ClipboardHistoryService.swift` | `platform/macos/Sources/Services/Interface/ClipboardHistoryService.swift` |
| `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift` | `platform/macos/Sources/Services/Impl/ClipboardHistoryServiceImpl.swift` |
| `platform/macos/Sources/Utils/ClipboardWatcher.swift` | `platform/macos/Sources/Services/Impl/ClipboardWatcher.swift` |
| `platform/macos/Sources/Utils/CombineExtensions.swift` | `platform/macos/Sources/Utilities/CombineExtensions.swift` |
| `platform/macos/Sources/Utils/DeleteConfirmationHotkeyOwner.swift` | `platform/macos/Sources/Utilities/DeleteConfirmationHotkeyOwner.swift` |
| `platform/macos/Sources/Utils/HotkeyService.swift` | `platform/macos/Sources/Services/Interface/HotkeyService.swift` |
| `platform/macos/Sources/Utils/HotkeyServiceImpl.swift` | `platform/macos/Sources/Services/Impl/HotkeyServiceImpl.swift` |
| `platform/macos/Sources/Utils/InAppHotkeyPermissionManager.swift` | `platform/macos/Sources/Utilities/InAppHotkeyPermissionManager.swift` |
| `platform/macos/Sources/Utils/InAppHotkeyPermissionTypes.swift` | `platform/macos/Sources/Utilities/InAppHotkeyPermissionTypes.swift` |
| `platform/macos/Sources/Utils/LoggerService.swift` | `platform/macos/Sources/Utilities/LoggerService.swift` |
| `platform/macos/Sources/Utils/MainPanelInteractionService.swift` | `platform/macos/Sources/Services/Impl/MainPanelInteractionService.swift` |
| `platform/macos/Sources/Utils/OCRService.swift` | `platform/macos/Sources/Services/Impl/OCRService.swift` |
| `platform/macos/Sources/View/HistoryViewController.swift` | `platform/macos/Sources/Features/MainPanel/View/HistoryViewController.swift` |
| `platform/macos/Sources/View/HistoryWindowController.swift` | `platform/macos/Sources/Features/MainPanel/View/HistoryWindowController.swift` |
| `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTableCellView.swift` | `platform/macos/Sources/Features/MainPanel/View/AppKit/MainPanelItemTableCellView.swift` |
| `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTableRepresentable.swift` | `platform/macos/Sources/Features/MainPanel/View/AppKit/MainPanelItemTableRepresentable.swift` |
| `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTableView.swift` | `platform/macos/Sources/Features/MainPanel/View/AppKit/MainPanelItemTableView.swift` |
| `platform/macos/Sources/View/MainPanel/AppKit/MainPanelLongTextRepresentable.swift` | `platform/macos/Sources/Features/MainPanel/View/AppKit/MainPanelLongTextRepresentable.swift` |
| `platform/macos/Sources/View/MainPanel/AppKit/MainPanelLongTextView.swift` | `platform/macos/Sources/Features/MainPanel/View/AppKit/MainPanelLongTextView.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelContent.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelContent.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelFooterView.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelFooterView.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelImageLoader.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelImageLoader.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelMaterials.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelMaterials.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelPreviewPanel.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelPreviewPanel.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelSearchBar.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelSearchBar.swift` |
| `platform/macos/Sources/View/MainPanel/MainPanelTokens.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelTokens.swift` |
| `platform/macos/Sources/View/MainPanelView.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelView.swift` |
| `platform/macos/Sources/View/MainPanelWindowController.swift` | `platform/macos/Sources/Features/MainPanel/View/MainPanelWindowController.swift` |
| `platform/macos/Sources/ViewModel/HistoryItemViewModel.swift` | `platform/macos/Sources/Features/MainPanel/Model/HistoryItemViewModel.swift` |
| `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` | `platform/macos/Sources/Features/MainPanel/ViewModel/MainPanelViewModel.swift` |

