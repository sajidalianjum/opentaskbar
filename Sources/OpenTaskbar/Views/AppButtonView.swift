import AppKit

final class AppButtonView: NSView {
    let index: Int
    let bundleIdentifier: String
    private let appGroup: AppGroup
    private var showName: Bool

    private var iconView: NSImageView!
    private var nameLabel: NSTextField?
    private var activeIndicator: NSView!
    private var countBadge: NSView?
    private var countLabel: NSTextField?
    private var hoverOverlay: NSView!

    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    private static let sharedPopover = WindowListPopover()

    var target: AnyObject?
    var action: Selector?
    var rightAction: ((Int) -> Void)?

    init(appGroup: AppGroup, index: Int, showName: Bool) {
        self.appGroup = appGroup
        self.index = index
        self.bundleIdentifier = appGroup.bundleIdentifier
        self.showName = showName
        super.init(frame: .zero)
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

        let iconSize = CGFloat(TaskbarSettings.shared.iconSize)
        let scaledIcon = appGroup.icon.resized(to: NSSize(width: iconSize, height: iconSize))

        iconView = NSImageView(image: scaledIcon)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        if showName {
            nameLabel = NSTextField(labelWithString: appGroup.localizedName)
            nameLabel?.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            nameLabel?.textColor = appGroup.isActive ? .labelColor : .secondaryLabelColor
            nameLabel?.lineBreakMode = .byTruncatingTail
            nameLabel?.maximumNumberOfLines = 1
            nameLabel?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            if let nameLabel {
                addSubview(nameLabel)
            }
        }

        activeIndicator = NSView()
        activeIndicator.wantsLayer = true
        activeIndicator.layer?.cornerRadius = 1.5
        addSubview(activeIndicator)

        if appGroup.isActive {
            activeIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            activeIndicator.frame.size = NSSize(width: 16, height: 3)
        } else if appGroup.isRunning {
            activeIndicator.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.5).cgColor
            activeIndicator.frame.size = NSSize(width: 6, height: 3)
        } else {
            activeIndicator.isHidden = true
        }

        if appGroup.hasMultipleWindows {
            setupCountBadge()
        }

        setupConstraints()
        setupTrackingArea()
    }

    private func setupCountBadge() {
        countBadge = NSView()
        countBadge?.wantsLayer = true
        countBadge?.layer?.cornerRadius = 8
        countBadge?.layer?.backgroundColor = NSColor.controlAccentColor.cgColor

        countLabel = NSTextField(labelWithString: "\(appGroup.windowCount)")
        countLabel?.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        countLabel?.textColor = .white
        countLabel?.alignment = .center

        if let badge = countBadge, let label = countLabel {
            addSubview(badge)
            addSubview(label)
        }
    }

    private func setupConstraints() {
        [iconView, activeIndicator, hoverOverlay].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        nameLabel?.translatesAutoresizingMaskIntoConstraints = false
        countBadge?.translatesAutoresizingMaskIntoConstraints = false
        countLabel?.translatesAutoresizingMaskIntoConstraints = false

        let iconLeading: CGFloat = 8
        let iconHeight = CGFloat(TaskbarSettings.shared.iconSize)

        NSLayoutConstraint.activate([
            hoverOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            hoverOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            hoverOverlay.topAnchor.constraint(equalTo: topAnchor),
            hoverOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: iconLeading),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconHeight),
            iconView.heightAnchor.constraint(equalToConstant: iconHeight),

            activeIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activeIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            activeIndicator.widthAnchor.constraint(equalToConstant: appGroup.isActive ? 16 : 6),
            activeIndicator.heightAnchor.constraint(equalToConstant: 3),
        ])

        if showName, let nameLabel {
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
                nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            ])
        }

        if let badge = countBadge, let label = countLabel {
            NSLayoutConstraint.activate([
                badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                badge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                badge.widthAnchor.constraint(equalToConstant: 16),
                badge.heightAnchor.constraint(equalToConstant: 16),

                label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            ])
        }
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

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverOverlay.isHidden = false
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor

        showWindowListIfNeeded()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverOverlay.isHidden = true
        layer?.backgroundColor = nil

        Self.sharedPopover.scheduleHide()
    }

    private func showWindowListIfNeeded() {
        let settings = TaskbarSettings.shared
        guard !settings.showThumbnails, appGroup.hasMultipleWindows else { return }

        let popover = Self.sharedPopover
        popover.cancelHideTimer()

        guard let screen = window?.screen ?? NSScreen.main else { return }

        let buttonRectInScreen = convert(bounds, to: nil)
        let screenPoint: NSPoint
        if let windowFrame = window?.frame {
            screenPoint = NSPoint(
                x: windowFrame.origin.x + buttonRectInScreen.midX,
                y: windowFrame.origin.y + buttonRectInScreen.maxY
            )
        } else {
            screenPoint = NSPoint(x: buttonRectInScreen.midX, y: buttonRectInScreen.maxY)
        }

        popover.show(windows: appGroup.windows, anchorPoint: screenPoint, screen: screen)
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
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

    override func rightMouseDown(with event: NSEvent) {
        rightAction?(index)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if appGroup.isActive {
            let accentColor = NSColor.controlAccentColor.withAlphaComponent(0.06)
            accentColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
    }
}