import SwiftUI
import Combine

extension Notification.Name {
    static let tagEditorSaveHotkeyTriggered = Notification.Name("tagEditorSaveHotkeyTriggered")
}

struct TagEditorSheet: View {
    @EnvironmentObject var viewModel: MainPanelViewModel
    @Binding var focusToken: Int
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tagsContentView
            Divider()
            suggestionsView
            recentTagsView
            Divider()
            inputView
        }
        .frame(width: 360, height: 320)
        .background {
            MainPanelVisualEffectView(
                material: MainPanelTokens.Effects.materialHudWindow,
                blendingMode: .behindWindow
            )
            MainPanelTokens.Colors.surface.opacity(0.1)
        }
        .onAppear {
            requestInputFocus()
        }
        .onChange(of: focusToken) { _, _ in
            requestInputFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tagEditorSaveHotkeyTriggered)) { _ in
            saveAndClose()
        }
    }

    private var headerView: some View {
        HStack {
            Text("Edit tags")
                .font(.headline)
            Spacer()
            Button(action: { viewModel.send(.closeTagEditor) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var tagsContentView: some View {
        ScrollView {
            FlowLayout(spacing: 8) {
                ForEach(viewModel.state.editingTags, id: \.self) { tag in
                    TagChip(tag: tag) {
                        viewModel.send(.tagRemoved(tag))
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var suggestionsView: some View {
        if !viewModel.state.tagSuggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Sugesstion")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    ForEach(Array(viewModel.state.tagSuggestions.enumerated()), id: \.element) { index, tag in
                        Button(action: {
                            viewModel.send(.selectTagSuggestion(index))
                        }) {
                            Text(tag)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(index == viewModel.state.selectedSuggestionIndex ? Color.accentColor.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.upArrow, modifiers: [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var recentTagsView: some View {
        let availableRecentTags = viewModel.state.recentTags.filter { !viewModel.state.editingTags.contains($0) }
        if !availableRecentTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Recent")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    ForEach(availableRecentTags, id: \.self) { tag in
                        Button {
                            viewModel.send(.tagAdded(tag))
                        } label: {
                            TagPill(tag: tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("Add tags...", text: Binding(
                get: { inputText },
                set: { newValue in
                    inputText = newValue
                    viewModel.send(.tagInputChanged(newValue))
                }
            ))
            .focused($isInputFocused)
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .onSubmit {
                addTag()
            }
            Button("Save") {
                saveAndClose()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func addTag() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.send(.tagAdded(trimmed))
        inputText = ""
    }

    private func saveAndClose() {
        if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
            addTag()
        }
        viewModel.send(.saveTags(viewModel.state.editingTags))
    }

    private func requestInputFocus() {
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }
}

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void

    private var style: TagPillStyle {
        TagPillPalette.style(for: tag)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(style.foreground)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(style.foreground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(style.background.opacity(0.2))
        .overlay(
            Capsule()
                .stroke(style.background.opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
