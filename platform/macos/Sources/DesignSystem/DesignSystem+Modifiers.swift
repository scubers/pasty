import SwiftUI

extension View {
    func glassEffect(
        cornerRadius: CGFloat = 12,
        opacity: Double = 0.05,
        borderOpacity: Double = 0.1
    ) -> some View {
        self.background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                Color.white.opacity(opacity)
            }
            .cornerRadius(cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.5)
        )
    }
    
    func panelBackground() -> some View {
        self.background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
    
    func cardStyle() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}
