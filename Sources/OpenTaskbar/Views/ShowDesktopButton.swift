import AppKit

final class ShowDesktopButton: NSView {
    private var imageView: NSImageView!
    private var hoverOverlay: NSView!

    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    var target: AnyObject?
    var action: Selector?

    var isShowingDesktop = false {
        didSet {
            updateAppearance()
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        hoverOverlay = NSView()
        hoverOverlay.wantsLayer = true
        hoverOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        hoverOverlay.layer?.cornerRadius = 6
        hoverOverlay.isHidden = true
        addSubview(hoverOverlay)

        let image = NSImage(systemSymbolName: "rectangle.compress.vertical", accessibilityDescription: "Show Desktop")
        imageView = NSImageView(image: image ?? NSImage())
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .labelColor
        addSubview(imageView)

        setupConstraints()
        setupTrackingArea()
    }

    private func setupConstraints() {
        [imageView, hoverOverlay].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            hoverOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            hoverOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            hoverOverlay.topAnchor.constraint(equalTo: topAnchor),
            hoverOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    private func updateAppearance() {
        if isShowingDesktop {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            imageView.contentTintColor = NSColor.controlAccentColor
        } else if !isHovering {
            layer?.backgroundColor = nil
            imageView.contentTintColor = .labelColor
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverOverlay.isHidden = false
        if !isShowingDesktop {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverOverlay.isHidden = true
        if !isShowingDesktop {
            layer?.backgroundColor = nil
        }
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        if isShowingDesktop {
            updateAppearance()
        } else if isHovering {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        } else {
            layer?.backgroundColor = nil
        }

        if let target = target as? NSObject, let action = action {
            target.perform(action, with: self)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
}
