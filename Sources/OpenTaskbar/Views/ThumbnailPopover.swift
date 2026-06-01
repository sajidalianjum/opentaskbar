import AppKit
import ScreenCaptureKit

final class ThumbnailPopover: NSWindow {
    private let thumbnailService = ThumbnailService.shared
    private var windowID: CGWindowID?
    private var imageView: NSImageView!
    private var titleLabel: NSTextField!
    private var currentTask: Task<Void, Never>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupView()
    }

    private func setupView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.layer?.cornerRadius = 8

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true

        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        container.addSubview(visualEffect)
        container.addSubview(imageView)
        container.addSubview(titleLabel)

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            imageView.heightAnchor.constraint(equalToConstant: 160),

            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
        ])

        contentView = container
    }

    func show(for windowID: CGWindowID, title: String, near point: NSPoint) {
        currentTask?.cancel()
        self.windowID = windowID
        titleLabel.stringValue = title

        let screenPoint = NSPoint(x: point.x - frame.width / 2, y: point.y + 10)
        setFrameOrigin(screenPoint)
        orderFront(nil)

        currentTask = Task { @MainActor in
            if let image = await thumbnailService.thumbnail(for: windowID) {
                guard !Task.isCancelled, self.windowID == windowID else { return }
                self.imageView.image = image
            }
        }
    }

    func hide() {
        currentTask?.cancel()
        windowID = nil
        imageView.image = nil
        orderOut(nil)
    }
}