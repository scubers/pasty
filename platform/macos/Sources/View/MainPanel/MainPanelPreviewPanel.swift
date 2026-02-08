import AppKit
import SwiftUI
import Foundation

struct MainPanelPreviewPanel: View {
    let item: ClipboardItemRow?
    @StateObject private var imageLoader = MainPanelImageLoader(baseDirectory: AppPaths.appDataDirectory())

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
        Group {
            if item.type == .image {
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
            } else {
                MainPanelLongTextRepresentable(itemId: item.id, text: item.content)
            }
        }
//        .padding(8)
//        .background(MainPanelTokens.Effects.materialRegular.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadiusSmall))
        .onAppear {
            imageLoader.load(path: item.type == .image ? item.imagePath : nil)
        }
        .onChange(of: item.id) { _, _ in
            imageLoader.load(path: item.type == .image ? item.imagePath : nil)
        }
        .onDisappear {
            imageLoader.cancel()
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
