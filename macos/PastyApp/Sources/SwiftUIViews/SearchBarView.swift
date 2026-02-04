import SwiftUI

/// Search bar view with dark theme matching design.jpeg
struct SearchBarView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Command key icon
            Image(systemName: "command")
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                .font(.system(size: 16, weight: .medium))

            TextField("Search clipboard...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                .accentColor(Color(red: 0.8, green: 0.4, blue: 0.6))  // Pink/purple accent

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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))  // Darker background #1f1f24
        .cornerRadius(10)
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
