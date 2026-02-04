import SwiftUI

/// Text preview view for displaying text content
struct TextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

#Preview {
    TextPreviewView(text: "This is a sample text content that will be displayed in the preview panel.")
        .frame(width: 400, height: 300)
}
