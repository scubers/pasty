import SwiftUI

/// Filter buttons view with dark theme matching design.jpeg
struct FilterButtonsView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 6) {
            // Content type filter buttons
            ForEach(ContentFilter.allCases, id: \.self) { filter in
                FilterButton(
                    title: filter.rawValue,
                    isSelected: viewModel.contentFilter == filter
                ) {
                    viewModel.handle(.filter(filter))
                }
            }

            // Pinned filter toggle (square icon, orange/yellow)
            PinnedFilterButton(isActive: viewModel.isPinnedFilterActive) {
                viewModel.handle(.togglePinnedFilter)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? Color.white : Color(white: 0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActiveColor)
                )
        }
        .buttonStyle(.plain)
    }

    private var isActiveColor: Color {
        if isSelected {
            // Purple for active state (#5856d6)
            return Color(red: 0.345, green: 0.337, blue: 0.839)
        } else {
            // Dark gray for inactive state (#2a2a2a)
            return Color(red: 0.165, green: 0.165, blue: 0.165)
        }
    }
}

// MARK: - Pinned Filter Button

struct PinnedFilterButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? activeColor : inactiveColor)
                    .frame(width: 28, height: 28)

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "pin")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .help(isActive ? "Show all entries" : "Show only pinned entries")
    }

    private var activeColor: Color {
        // Orange for active (#ff9500)
        Color(red: 1.0, green: 0.584, blue: 0.0)
    }

    private var inactiveColor: Color {
        // Dark gray for inactive (#2a2a2a)
        Color(red: 0.165, green: 0.165, blue: 0.165)
    }
}

#Preview {
    ZStack {
        Color(red: 0.102, green: 0.102, blue: 0.102)  // #1a1a1a
        FilterButtonsView(viewModel: MainPanelViewModel())
            .frame(width: 400)
    }
    .frame(width: 450, height: 100)
}
