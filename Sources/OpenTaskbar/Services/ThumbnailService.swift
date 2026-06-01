import AppKit
import CoreGraphics
import ScreenCaptureKit

final class ThumbnailService {
    static let shared = ThumbnailService()

    private var cache: [CGWindowID: (image: NSImage, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 2.0
    private let thumbnailSize = NSSize(width: 300, height: 200)

    var isEnabled: Bool = true

    private init() {}

    @MainActor
    func thumbnail(for windowID: CGWindowID) async -> NSImage? {
        guard isEnabled else { return nil }

        if let cached = cache[windowID],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.image
        }

        let image: NSImage?

        if #available(macOS 14.0, *) {
            image = await captureWithScreenCaptureKit(windowID: windowID)
        } else {
            image = captureWithCGWindowList(windowID: windowID)
        }

        if let image {
            cache[windowID] = (image: image, timestamp: Date())
        }

        return image
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(windowID: CGWindowID) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return captureWithCGWindowList(windowID: windowID)
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(thumbnailSize.width * 2)
            config.height = Int(thumbnailSize.height * 2)

            let sampleBuffer = try await SCScreenshotManager.captureSampleBuffer(
                contentFilter: filter,
                configuration: config
            )

            guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

            return NSImage(cgImage: cgImage, size: thumbnailSize)
        } catch {
            return captureWithCGWindowList(windowID: windowID)
        }
    }

    private func captureWithCGWindowList(windowID: CGWindowID) -> NSImage? {
        let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        )

        guard let cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let aspectRatio = width / height
        let targetSize: NSSize

        if aspectRatio > thumbnailSize.width / thumbnailSize.height {
            targetSize = NSSize(width: thumbnailSize.width, height: thumbnailSize.width / aspectRatio)
        } else {
            targetSize = NSSize(width: thumbnailSize.height * aspectRatio, height: thumbnailSize.height)
        }

        return NSImage(cgImage: cgImage, size: targetSize)
    }

    func clearCache() {
        cache.removeAll()
    }

    func removeThumbnail(for windowID: CGWindowID) {
        cache.removeValue(forKey: windowID)
    }
}