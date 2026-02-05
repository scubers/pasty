import SwiftUI

struct TextPreviewView: View {
    let text: String

    var body: some View {
        ScrollView(.vertical) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(DesignColors.text0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    TextPreviewView(text: "Update shared data dir should prompt restart...\n\nAlso keep scroll position when reopening panel.")
        .frame(width: 400, height: 300)
        .background(DesignColors.mat2)
}
