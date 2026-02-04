import SwiftUI
import AppKit

/// Image preview view for displaying image content
struct ImagePreviewView: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: geometry.size.width - 32,
                        maxHeight: geometry.size.height - 32
                    )
                    .padding(16)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

#Preview {
    let image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Sample image")
    return ImagePreviewView(image: image!)
        .frame(width: 400, height: 300)
}
