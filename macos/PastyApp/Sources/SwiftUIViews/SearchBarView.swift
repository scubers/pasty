import SwiftUI

/// Search bar view with dark theme matching design.jpeg
struct SearchBarView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                .font(.system(size: 14))

            TextField("Search clipboard...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .accentColor(Color(red: 0.345, green: 0.337, blue: 0.839))  // Purple

            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.165, green: 0.165, blue: 0.165))  // #2a2a2a
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.2, green: 0.2, blue: 0.2), lineWidth: 1)  // #333333
        )
    }
}

#Preview {
    ZStack {
        Color(red: 0.102, green: 0.102, blue: 0.102)  // #1a1a1a
        SearchBarView(viewModel: MainPanelViewModel())
            .frame(width: 300)
    }
    .frame(width: 400, height: 100)
}
