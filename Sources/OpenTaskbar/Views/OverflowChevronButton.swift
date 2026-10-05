import AppKit

final class OverflowChevronButton: NSView {
    private var imageView: NSImageView!
    private var badgeLabel: NSTextField?
    private var hoverOverlay: NSView!
    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    var target: AnyObject?
    var action: Selector?
    var overflowCount: Int = 0 {
        didSet {
            if overflowCount > 0 {
                if badgeLabel == nil {
                    let label = NSTextField(labelWithString: L10n.number(overflowCount))
                    label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
                    label.textColor = .labelColor
                    label.alignment = .center
                    badgeLabel = label
                    label.translatesAutoresizingMaskIntoConstraints = false
                    addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: centerXAnchor),
                        label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 1),
                    ])
                }
                badgeLabel?.stringValue = L10n.number(overflowCount)
            } else {
                badgeLabel?.removeFromSuperview()
                badgeLabel = nil
            }
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

        let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: L10n.moreAppsAccessibility)
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
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: ScreenGeometry.hoverTrackingRect(for: bounds),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverOverlay.isHidden = false
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverOverlay.isHidden = true
        layer?.backgroundColor = nil
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseUp(with event: NSEvent) {
        if isHovering {
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

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}
