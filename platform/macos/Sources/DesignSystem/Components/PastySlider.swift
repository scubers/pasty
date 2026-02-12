import SwiftUI

struct PastySlider: View {
    @Binding var value: Double
    var accentColor: Color = DesignSystem.Colors.accent
    var range: ClosedRange<Double> = 0...1
    var title: String? = nil

    var body: some View {
        HStack {
            if let title = title {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(DesignSystem.Colors.controlBackground)
                        .frame(height: 4)
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                        )

                    // Active Track
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(0, CGFloat(normalizedValue) * geometry.size.width), height: 4)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(geometry.size.width - 16, CGFloat(normalizedValue) * geometry.size.width - 8)))
                }
                .contentShape(Rectangle()) // Make gesture area bigger?
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gestureValue in
                            let percentage = min(max(0, gestureValue.location.x / geometry.size.width), 1)
                            let newValue = range.lowerBound + percentage * (range.upperBound - range.lowerBound)
                            self.value = newValue
                        }
                )
                .frame(height: 16)
            }
            .frame(height: 16)
            .frame(width: 150)
        }
    }
    
    private var normalizedValue: Double {
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}
