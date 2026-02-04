import AppKit

extension NSImage {
    /// Create a thumbnail of the image with specified size
    func thumbnail(size: NSSize) -> NSImage? {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        self.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        return resizedImage
    }

    /// Resize image to fit within max size while maintaining aspect ratio
    func resized(maxSize: NSSize) -> NSImage? {
        let widthRatio = maxSize.width / self.size.width
        let heightRatio = maxSize.height / self.size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = NSSize(
            width: self.size.width * ratio,
            height: self.size.height * ratio
        )

        return thumbnail(size: newSize)
    }
}
