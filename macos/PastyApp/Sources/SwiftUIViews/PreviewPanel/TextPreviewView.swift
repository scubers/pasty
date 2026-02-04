import SwiftUI

/// Text preview view for displaying text content
struct TextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    TextPreviewView(text: "Update shared data dir should prompt restart...\n\nAlso keep scroll position when reopening panel.")
        .frame(width: 400, height: 300)
}
