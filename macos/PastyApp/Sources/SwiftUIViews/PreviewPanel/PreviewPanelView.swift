import SwiftUI

struct PreviewPanelView: View {
    @ObservedObject var viewModel: PreviewPanelViewModel

    var body: some View {
        VStack() {
            previewCardView
        }
//        .padding(14)
    }

    private var previewCardView: some View {
        VStack(spacing: 10) {
            cardHeaderView

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
            .frame(minHeight: 220, maxHeight: .infinity, alignment: .topLeading)

            actionButtonsView
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(DesignColors.stroke, lineWidth: 1)
                )
        )
    }

    private var cardHeaderView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.text0)

                HStack(spacing: 8) {
                    if let icon = viewModel.sourceAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }

                    Text("\(viewModel.sourceAppName) · \(viewModel.timestamp)")
                        .font(.system(size: 12))
                        .foregroundColor(DesignColors.text1)

                    if viewModel.isPinned {
                        Text("📌")
                            .font(.system(size: 10))
                    }
                }
            }

            Spacer()

            if viewModel.isPinned {
                Text("Pinned")
                    .font(.system(size: 11))
                    .foregroundColor(DesignColors.text1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(DesignColors.stroke, lineWidth: 1)
                            )
                    )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(DesignColors.text1)
            Text("Select an entry to preview")
                .font(.system(size: 13))
                .foregroundColor(DesignColors.text1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionButtonsView: some View {
        HStack(spacing: 10) {
            Spacer()

            Button(action: {
                viewModel.handleCopyAction()
            }) {
                Text("Copy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.text0)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignColors.stroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.copyButtonEnabled)
            .opacity(viewModel.copyButtonEnabled ? 1.0 : 0.5)

            Button(action: {
                viewModel.handlePasteAction()
            }) {
                Text("Paste")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.text0)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.35), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.pasteButtonEnabled)
            .opacity(viewModel.pasteButtonEnabled ? 1.0 : 0.5)

            Spacer()
        }
    }
}

#Preview {
    PreviewPanelView(viewModel: PreviewPanelViewModel())
        .frame(width: 400, height: 400)
        .background(DesignColors.mat2)
}
