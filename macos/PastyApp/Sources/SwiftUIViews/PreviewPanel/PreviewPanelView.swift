import SwiftUI

/// Preview panel view showing clipboard entry content
struct PreviewPanelView: View {
    @ObservedObject var viewModel: PreviewPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Divider
            Divider()

            // Action buttons
            actionButtonsView
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an entry to preview")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Spacer()

            // Copy button
            Button(action: {
                viewModel.handleCopyAction()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewModel.copyButtonEnabled ? Color.accentColor : Color.gray)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.copyButtonEnabled)

            // Paste button
            Button(action: {
                viewModel.handlePasteAction()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewModel.pasteButtonEnabled ? Color.accentColor : Color.gray)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.pasteButtonEnabled)

            Spacer()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    PreviewPanelView(viewModel: PreviewPanelViewModel())
        .frame(width: 400, height: 300)
}
