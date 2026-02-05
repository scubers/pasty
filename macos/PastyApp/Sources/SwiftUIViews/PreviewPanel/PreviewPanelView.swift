import SwiftUI
import AppKit

/// Preview panel view showing clipboard entry content
struct PreviewPanelView: View {
    @ObservedObject var viewModel: PreviewPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and metadata
            headerView

            // Sensitive content warning
            if viewModel.isSensitive {
                sensitiveWarningView
            }

            // Preview content
            Group {
                switch viewModel.previewContent {
                case .empty:
                    emptyStateView
                case .text(let text):
                    TextPreviewView(text: text)
                case .image(let image):
                    ImagePreviewView(image: image)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Encryption offer for sensitive content
            if viewModel.isSensitive && !viewModel.isEncrypted {
                encryptionOfferView
            }

            // Action buttons
            actionButtonsView

            // Keyboard shortcut tip
            tipView
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview title
            Text("Preview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // Metadata row
            HStack(spacing: 8) {
                // Source app icon
                if let icon = viewModel.sourceAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }

                // Source app name and timestamp
                Text("\(viewModel.sourceAppName) · \(viewModel.timestamp)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))

                // Pinned badge
                if viewModel.isPinned {
                    Text("Pinned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.98, green: 0.75, blue: 0.14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.25, green: 0.2, blue: 0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(red: 0.98, green: 0.75, blue: 0.14), lineWidth: 1)
                        )
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            Text("Select an entry to preview")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Sensitive Warning

    private var sensitiveWarningView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.96, green: 0.47, blue: 0.04))
            Text("Sensitive content detected")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.8))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.23, green: 0.14, blue: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.96, green: 0.47, blue: 0.04), lineWidth: 1)
        )
    }

    // MARK: - Encryption Offer

    private var encryptionOfferView: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.96, green: 0.47, blue: 0.04))
            VStack(alignment: .leading, spacing: 4) {
                Text("This content looks sensitive")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text("Encrypt to protect it")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
            }
            Spacer()
            Button(action: {
                viewModel.encryptSensitiveContent()
            }) {
                Text("Encrypt")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.96, green: 0.47, blue: 0.04), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Spacer()

            // Copy button
            Button(action: {
                viewModel.handleCopyAction()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                    Text("Copy")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.28))
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.copyButtonEnabled)
            .opacity(viewModel.copyButtonEnabled ? 1.0 : 0.5)

            // Paste button
            Button(action: {
                viewModel.handlePasteAction()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14))
                    Text("Paste")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.28))
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.pasteButtonEnabled)
            .opacity(viewModel.pasteButtonEnabled ? 1.0 : 0.5)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Keyboard Shortcut Tip

    private var tipView: some View {
        HStack {
            Spacer()
            Text("Tip: ⌘↵ paste · ⌘C copy")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
            Spacer()
        }
        .padding(.bottom, 12)
    }
}

#Preview {
    PreviewPanelView(viewModel: PreviewPanelViewModel())
        .frame(width: 400, height: 300)
}
