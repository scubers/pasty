import Cocoa
import UniformTypeIdentifiers

struct ContentTypeDetector {
    private static let imageTypes: [String] = [
        UTType.image.identifier,
        UTType.png.identifier,
        UTType.jpeg.identifier,
        "public.jpg",
        UTType.tiff.identifier,
        UTType.gif.identifier,
        UTType.webP.identifier,
        UTType.bmp.identifier,
        UTType.icns.identifier,
        "public.heic",
        "public.heif",
        "com.apple.pict",
        "com.compuserve.gif",
        "public.svg-image",
    ]

    func detectContentType(from pasteboard: NSPasteboard) -> ClipboardContentType {
        let types = pasteboard.types ?? []

        if types.contains(NSPasteboard.PasteboardType(UTType.text.identifier)) ||
           types.contains(NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier)) ||
           types.contains(NSPasteboard.PasteboardType(UTType.plainText.identifier)) {
            return .text
        }

        for imageType in Self.imageTypes {
            if types.contains(NSPasteboard.PasteboardType(imageType)) {
                return .image
            }
        }

        if types.contains(NSPasteboard.PasteboardType(UTType.fileURL.identifier)) {
            return .fileReference
        }

        return .unsupported
    }
}
