import Foundation
import Cocoa
import UniformTypeIdentifiers

struct ImageHandler: ContentHandler {
    private static let supportedImageFormats: [(uti: String, format: String)] = [
        (UTType.png.identifier, "png"),
        (UTType.jpeg.identifier, "jpeg"),
        ("public.jpg", "jpg"),
        (UTType.tiff.identifier, "tiff"),
        (UTType.gif.identifier, "gif"),
        (UTType.webP.identifier, "webp"),
        (UTType.bmp.identifier, "bmp"),
        ("public.heic", "heic"),
        ("public.heif", "heif"),
        (UTType.icns.identifier, "icns"),
        ("com.apple.pict", "pict"),
    ]

    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        var imageData: Data?
        var format: String = "png"

        for (uti, fmt) in Self.supportedImageFormats {
            if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(uti)) {
                imageData = data
                format = fmt
                break
            }
        }

        guard let finalData = imageData else {
            return
        }

        coordinator.storeImageContent(finalData, format: format, source: source)
    }
}
