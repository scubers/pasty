import SwiftUI

struct SearchBarView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text("⌘")
                .font(.system(size: 13))
                .foregroundColor(DesignColors.icon)

            TextField("Search clipboard…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(DesignColors.text2)

            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignColors.text1)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignColors.stroke, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        DesignColors.mat1
        SearchBarView(viewModel: MainPanelViewModel())
            .frame(width: 300)
    }
    .frame(width: 400, height: 100)
}
