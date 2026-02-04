import SwiftUI

/// Filter buttons view with dark theme matching design.jpeg
struct FilterButtonsView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Content type filter buttons
            ForEach(ContentFilter.allCases, id: \.self) { filter in
                FilterButton(
                    title: filter.rawValue,
                    isSelected: viewModel.contentFilter == filter
                ) {
                    viewModel.handle(.filter(filter))
                }
            }

            // Pinned filter toggle (square icon with yellow/orange background)
            PinnedFilterButton(isActive: viewModel.isPinnedFilterActive) {
                viewModel.handle(.togglePinnedFilter)
            }
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? Color.white : Color(red: 0.6, green: 0.6, blue: 0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActiveColor)
                )
        }
        .buttonStyle(.plain)
    }

    private var isActiveColor: Color {
        if isSelected {
            // Pink/magenta for active state matching design
            return Color(red: 0.93, green: 0.25, blue: 0.98)  // #ec3dfa
        } else {
            // Darker background for inactive state
            return Color(red: 0.18, green: 0.18, blue: 0.20)  // #2e2e33
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? activeColor : inactiveColor)
                    .frame(width: 36, height: 36)

                // Yellow/orange square icon matching design
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color(red: 1.0, green: 0.92, blue: 0.4) : Color(red: 0.5, green: 0.5, blue: 0.5))
                    .frame(width: 16, height: 16)
            }
        }
        .buttonStyle(.plain)
        .help(isActive ? "Show all entries" : "Show only pinned entries")
    }

    private var activeColor: Color {
        // Yellow/orange background for active (#fbbf24)
        Color(red: 0.98, green: 0.75, blue: 0.14)
    }

    private var inactiveColor: Color {
        // Dark background for inactive
        Color(red: 0.18, green: 0.18, blue: 0.20)
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
