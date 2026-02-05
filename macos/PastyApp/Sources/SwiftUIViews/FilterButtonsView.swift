import SwiftUI

struct FilterButtonsView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ContentFilter.allCases, id: \.self) { filter in
                FilterButton(
                    title: filter.rawValue,
                    isSelected: viewModel.contentFilter == filter
                ) {
                    viewModel.handle(.filter(filter))
                }
            }
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(DesignColors.text1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(DesignColors.pill)
                        .overlay(
                            Capsule()
                                .stroke(DesignColors.stroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        DesignColors.mat1
        FilterButtonsView(viewModel: MainPanelViewModel())
            .frame(width: 400)
    }
    .frame(width: 450, height: 100)
}
