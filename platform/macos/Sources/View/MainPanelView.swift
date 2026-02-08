import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: Binding(
                get: { viewModel.state.searchQuery },
                set: { viewModel.send(.searchChanged($0)) }
            ))
            
            Divider()
            
            HSplitView {
                ItemList(
                    items: viewModel.state.items,
                    selectedItem: viewModel.state.selectedItem,
                    onSelect: { viewModel.send(.itemSelected($0)) }
                )
                .frame(minWidth: 250, maxWidth: .infinity)
                
                PreviewPanel(item: viewModel.state.selectedItem)
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
            
            Divider()
            
            FooterView()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

private struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search clipboard history...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.title2)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct ItemList: View {
    let items: [ClipboardItemRow]
    let selectedItem: ClipboardItemRow?
    let onSelect: (ClipboardItemRow) -> Void
    
    var body: some View {
        List(items) { item in
            ItemRow(item: item, isSelected: selectedItem == item)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(item)
                }
        }
        .listStyle(PlainListStyle())
    }
}

private struct ItemRow: View {
    let item: ClipboardItemRow
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: item.type == .image ? "photo" : "text.alignleft")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
                
                HStack {
                    Text(item.sourceAppId)
                    Text("•")
                    Text(item.timestamp, style: .time)
                }
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}

private struct PreviewPanel: View {
    let item: ClipboardItemRow?
    
    var body: some View {
        Group {
            if let item = item {
                VStack(alignment: .leading, spacing: 0) {
                    if item.type == .image {
                        if let path = item.imagePath, let nsImage = NSImage(contentsOfFile: path) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                        } else {
                            Text("Image not found")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        ScrollView {
                            Text(item.content)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .textSelection(.enabled)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text(item.type == .image ? "Image" : "Text")
                        Spacer()
                        if let w = item.imageWidth, let h = item.imageHeight {
                            Text("\(w)x\(h)")
                        } else {
                            Text("\(item.content.count) chars")
                        }
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            } else {
                Text("Select an item to preview")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

private struct FooterView: View {
    var body: some View {
        HStack {
            Text("Cmd+Shift+V to toggle panel")
            Spacer()
            Text("Enter to paste")
            Text("Esc to close")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

