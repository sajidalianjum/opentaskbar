import AppKit

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let result = NSImage(size: size)
        if let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) {
            result.addRepresentation(rep)
        }
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        result.isTemplate = self.isTemplate
        return result
    }

    func roundedCorners(radius: CGFloat) -> NSImage {
        let size = self.size
        let result = NSImage(size: size)
        result.lockFocus()

        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius)
        path.addClip()
        self.draw(in: NSRect(origin: .zero, size: size))

        result.unlockFocus()
        return result
    }

    static func systemIcon(for identifier: String, size: NSSize = NSSize(width: 32, height: 32)) -> NSImage {
        if let image = NSImage(systemSymbolName: identifier, accessibilityDescription: identifier) {
            return image.resized(to: size)
        }
        return NSImage(size: size)
    }
}