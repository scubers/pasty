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
                        maxWidth: geometry.size.width - 40,
                        maxHeight: geometry.size.height - 40,
                        alignment: .topLeading
                    )
                    .padding(20)
            }
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    let image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Sample image")
    return ImagePreviewView(image: image!)
        .frame(width: 400, height: 300)
}
