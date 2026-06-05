import AppKit

final class OverflowPopover: NSWindow {
    private var appRows: [OverflowRowView] = []
    private var groups: [AppGroup] = []
    private var hideWorkItem: DispatchWorkItem?
    private(set) var isHovering = false

    private let visualEffect: NSVisualEffectView
    private var solidBackgroundView: NSView?
    private let stackView: NSStackView

    static let rowHeight: CGFloat = 36
    static let popoverWidth: CGFloat = 240
    static let padding: CGFloat = 6
    static let gapAboveButton: CGFloat = 6
    static let maxVisibleRows: Int = 15

    var onAppActivated: ((Int) -> Void)?

    init() {
        visualEffect = NSVisualEffectView()
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.popoverWidth, height: 100),
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

        contentView!.wantsLayer = true
        contentView!.layer?.cornerRadius = 10
        contentView!.layer?.masksToBounds = true

        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView!.addSubview(visualEffect)
        contentView!.addSubview(stackView)

        let trackingView = PopoverTrackingView()
        trackingView.popover = self
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(trackingView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: Self.padding),
            stackView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -Self.padding),
            stackView.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: Self.padding),
            stackView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -Self.padding),

            visualEffect.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: contentView!.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),

            trackingView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])
    }

    func show(groups: [AppGroup], anchorPoint: NSPoint, screen: NSScreen) {
        cancelHideTimer()
        self.groups = groups

        applyTheme()

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        appRows.removeAll()

        let visibleCount = min(groups.count, Self.maxVisibleRows)
        let hasOverflow = groups.count > Self.maxVisibleRows

        for i in 0..<visibleCount {
            let group = groups[i]
            let row = OverflowRowView(appGroup: group)
            let capturedIndex = i
            row.onActivate = { [weak self] in
                self?.activateApp(at: capturedIndex)
            }
            appRows.append(row)
            stackView.addArrangedSubview(row)

            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: Self.rowHeight),
            ])
        }

        if hasOverflow {
            let overflowCount = groups.count - Self.maxVisibleRows
            let moreLabel = NSTextField(labelWithString: "+\(overflowCount) more")
            moreLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            moreLabel.textColor = .secondaryLabelColor
            moreLabel.alignment = .center
            moreLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(moreLabel)
            NSLayoutConstraint.activate([
                moreLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                moreLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                moreLabel.heightAnchor.constraint(equalToConstant: 20),
            ])
        }

        let rowCount = min(groups.count, Self.maxVisibleRows) + (hasOverflow ? 1 : 0)
        let contentHeight = CGFloat(rowCount) * Self.rowHeight
            + CGFloat(max(rowCount - 1, 0)) * stackView.spacing
            + Self.padding * 2

        let popoverX = anchorPoint.x - Self.popoverWidth / 2
        let popoverY = anchorPoint.y + Self.gapAboveButton

        let clampedX = max(screen.visibleFrame.minX,
                           min(popoverX, screen.visibleFrame.maxX - Self.popoverWidth))
        let clampedY = min(popoverY, screen.visibleFrame.maxY - contentHeight)

        setFrame(NSRect(x: clampedX, y: clampedY, width: Self.popoverWidth, height: contentHeight), display: true)
        orderFront(nil)
        invalidateShadow()
    }

    func hide() {
        cancelHideTimer()
        groups = []
        appRows.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        orderOut(nil)
    }

    func scheduleHide(delay: TimeInterval = 0.25) {
        cancelHideTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.isHovering else { return }
            self.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancelHideTimer() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            cancelHideTimer()
        }
    }

    private func applyTheme() {
        var dummyShadow: NSView? = nil
        ThemeManager.apply(
            to: visualEffect,
            solidView: &solidBackgroundView,
            parent: contentView!,
            material: .sidebar,
            cornerRadius: contentView!.layer?.cornerRadius ?? 0,
            shadowView: &dummyShadow
        )
    }

    private func activateApp(at index: Int) {
        guard index < groups.count else { return }
        onAppActivated?(index)
        hide()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PopoverTrackingView: NSView {
    weak var popover: OverflowPopover?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        popover?.setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        popover?.setHovering(false)
        popover?.scheduleHide()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}

private final class OverflowRowView: NSView {
    private let appGroup: AppGroup
    private let iconImageView: NSImageView
    private let nameLabel: NSTextField
    private let countLabel: NSTextField?
    private var trackingArea: NSTrackingArea?

    var onActivate: (() -> Void)?

    init(appGroup: AppGroup) {
        self.appGroup = appGroup

        let iconSize: CGFloat = 20
        let icon = appGroup.icon.resized(to: NSSize(width: iconSize, height: iconSize))
        iconImageView = NSImageView(image: icon)
        iconImageView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel = NSTextField(labelWithString: appGroup.localizedName)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.textColor = appGroup.isActive ? .labelColor : .secondaryLabelColor

        if appGroup.windowCount > 1 {
            let count = NSTextField(labelWithString: "\(appGroup.windowCount)")
            count.font = NSFont.systemFont(ofSize: 11)
            count.textColor = .tertiaryLabelColor
            count.alignment = .right
            countLabel = count
        } else {
            countLabel = nil
        }

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 4

        addSubview(iconImageView)
        addSubview(nameLabel)
        if let countLabel { addSubview(countLabel) }

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize),

            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        if let countLabel {
            countLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                countLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
                countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            ])
        } else {
            NSLayoutConstraint.activate([
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            ])
        }

        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    override func mouseUp(with event: NSEvent) {
        onActivate?()
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
