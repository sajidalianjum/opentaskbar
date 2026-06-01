import AppKit

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
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