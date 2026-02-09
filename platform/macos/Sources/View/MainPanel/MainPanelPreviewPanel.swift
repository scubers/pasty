import AppKit
import SwiftUI
import Foundation

struct MainPanelPreviewPanel: View {
    let item: ClipboardItemRow?
    @StateObject private var imageLoader = MainPanelImageLoader()
    @State private var isShowingOcrText = false

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: MainPanelTokens.Layout.paddingCompact) {
                    header
                    content(for: item)
                }
                .padding(MainPanelTokens.Layout.padding)
            } else {
                Text("Select an item to preview")
                    .foregroundStyle(MainPanelTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MainPanelTokens.Colors.card)
        .background(MainPanelTokens.Effects.materialUltraThin.opacity(0.3))
        .overlay {
            RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius)
                .stroke(MainPanelTokens.Colors.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Preview")
                .font(MainPanelTokens.Typography.smallBold)
                .foregroundStyle(MainPanelTokens.Colors.textSecondary)
                .textCase(.uppercase)
            Spacer()
//            actionButton("Copy", icon: "doc.on.doc", primary: true)
//            actionButton("Edit", icon: "pencil")
//            actionButton("Delete", icon: "trash")
        }
    }

    private func content(for item: ClipboardItemRow) -> some View {
        VStack(alignment: .leading, spacing: MainPanelTokens.Layout.paddingCompact) {
            if item.type == .image {
                ZStack(alignment: .topTrailing) {
                    if let nsImage = imageLoader.image {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall))
                    } else if imageLoader.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MainPanelTokens.Colors.accentPrimary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Image not found")
                            .foregroundStyle(MainPanelTokens.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    ocrBadge(for: item)
                        .padding(8)
                }

                if isShowingOcrText, let ocrText = item.ocrText, !ocrText.isEmpty {
                    ScrollView {
                        Text(ocrText)
                            .font(MainPanelTokens.Typography.small)
                            .foregroundStyle(MainPanelTokens.Colors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                    .padding(8)
                    .background(MainPanelTokens.Colors.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall)
                            .stroke(MainPanelTokens.Colors.border, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall))
                }
            } else {
                MainPanelLongTextRepresentable(itemId: item.id, text: item.content)
            }
        }
//        .padding(8)
//        .background(MainPanelTokens.Effects.materialRegular.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall))
        .onAppear {
            isShowingOcrText = false
            imageLoader.load(path: item.type == .image ? item.imagePath : nil)
        }
        .onChange(of: item.id) { _, _ in
            isShowingOcrText = false
            imageLoader.load(path: item.type == .image ? item.imagePath : nil)
        }
        .onDisappear {
            imageLoader.cancel()
        }
    }

    @ViewBuilder
    private func ocrBadge(for item: ClipboardItemRow) -> some View {
        if item.type == .image {
            let status = item.ocrStatus ?? .pending
            switch status {
            case .completed:
                if let text = item.ocrText, !text.isEmpty {
                    Button {
                        isShowingOcrText.toggle()
                    } label: {
                        Image(systemName: "text.viewfinder")
                            .foregroundStyle(MainPanelTokens.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .help(String(text.prefix(100)))
                } else {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(MainPanelTokens.Colors.textMuted)
                        .help("OCR completed, no text detected")
                }
            case .processing:
                Image(systemName: "eye")
                    .foregroundStyle(MainPanelTokens.Colors.accentPrimary)
                    .help("OCR in progress")
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("OCR failed")
            case .pending:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func actionButton(_ title: String, icon: String, primary: Bool = false) -> some View {
        Button {
        } label: {
            Label(title, systemImage: icon)
                .font(MainPanelTokens.Typography.small)
        }
        .buttonStyle(.plain)
        .foregroundStyle(primary ? MainPanelTokens.Colors.textPrimary : MainPanelTokens.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            if primary {
                MainPanelTokens.Colors.accentGradient
            } else {
                Color.white.opacity(0.08)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall)
                .stroke(MainPanelTokens.Colors.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall))
        .shadow(
            color: primary ? MainPanelTokens.Effects.buttonShadow.color : .clear,
            radius: primary ? MainPanelTokens.Effects.buttonShadow.radius : 0,
            x: primary ? MainPanelTokens.Effects.buttonShadow.x : 0,
            y: primary ? MainPanelTokens.Effects.buttonShadow.y : 0
        )
    }

    private func imageOrLength(_ item: ClipboardItemRow) -> String {
        if let width = item.imageWidth, let height = item.imageHeight {
            return "\(width)x\(height)"
        }
        return "\(item.content.count) chars"
    }

    private func metadataLabel(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(MainPanelTokens.Colors.textSecondary)
        }
    }

    private func metadataDivider() -> some View {
        Text("•")
            .foregroundStyle(MainPanelTokens.Colors.textMuted)
    }
}
