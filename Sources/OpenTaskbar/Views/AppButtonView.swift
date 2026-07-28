import AppKit

final class AppButtonView: NSView {
    var index: Int
    let bundleIdentifier: String
    private var appGroup: AppGroup
    private var showName: Bool

    private var iconView: NSImageView!
    private var nameLabel: NSTextField?
    private var activeIndicator: NSView!
    private var hoverOverlay: NSView!
    private var isLaunchingPulseActive = false

    private var isHovering = false
    private var trackingArea: NSTrackingArea?
    private var hoverWorkItem: DispatchWorkItem?
    private var mouseDownLocation: NSPoint?
    private var didAnimateEntry: Bool
    private var indicatorWidthConstraint: NSLayoutConstraint?
    private var indicatorHeightConstraint: NSLayoutConstraint?
    private var previousMinimizedIDs: Set<CGWindowID> = []

    private static let sharedWindowListPopover = WindowListPopover()
    private static let sharedThumbnailPopover = ThumbnailPopover()

    var target: AnyObject?
    var action: Selector?
    var rightAction: ((Int) -> Void)?
    var onNeedsRefresh: ((CGWindowID) -> Void)?
    var onFocusChanged: ((CGWindowID, String) -> Void)?

    private var animEnabled: Bool { TaskbarSettings.shared.animationsEnabled }

    init(appGroup: AppGroup, index: Int, showName: Bool, animateEntry: Bool = true) {
        self.appGroup = appGroup
        self.index = index
        self.bundleIdentifier = appGroup.bundleIdentifier
        self.showName = showName
        self.didAnimateEntry = !animateEntry
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
        iconView.unregisterDraggedTypes()
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
        addSubview(activeIndicator)

        setupIndicator()

        updateIndicatorColors()
        setupConstraints()
        setLaunchingPulseActive(appGroup.isLaunching)
        setupTrackingArea()

        updateActiveAccent()

        iconView.wantsLayer = true
        let f = iconView.frame
        iconView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        iconView.frame = f

        previousMinimizedIDs = Set(appGroup.windows.filter(\.isMinimized).map(\.windowID))
    }

    private func setupIndicator() {
        if appGroup.isLaunching {
            activeIndicator.isHidden = false
            activeIndicator.layer?.cornerRadius = 1.5
            activeIndicator.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
            activeIndicator.frame.size = NSSize(width: 16, height: 3)
        } else if appGroup.windows.contains(where: { !$0.isMinimized }) && appGroup.isActive {
            activeIndicator.layer?.cornerRadius = 1.5
            activeIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            activeIndicator.frame.size = NSSize(width: 16, height: 3)
        } else if appGroup.isRunning && !appGroup.windows.isEmpty {
            activeIndicator.layer?.cornerRadius = 1.5
            activeIndicator.frame.size = NSSize(width: 6, height: 3)
        } else if appGroup.isRunning {
            activeIndicator.layer?.cornerRadius = 2
            activeIndicator.frame.size = NSSize(width: 4, height: 4)
        } else {
            activeIndicator.isHidden = true
        }
    }

    private static let launchingPulseKey = "launchingPulse"

    private func setLaunchingPulseActive(_ active: Bool) {
        guard let indicatorLayer = activeIndicator?.layer else { return }
        if active == isLaunchingPulseActive { return }
        isLaunchingPulseActive = active
        if active {
            if !animEnabled {
                indicatorLayer.opacity = 0.7
                return
            }
            indicatorLayer.opacity = 1
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 1.0
            anim.toValue = 0.35
            anim.duration = 0.9
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            indicatorLayer.add(anim, forKey: Self.launchingPulseKey)
        } else {
            indicatorLayer.removeAnimation(forKey: Self.launchingPulseKey)
            indicatorLayer.opacity = 1
        }
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func indicatorColor(darkAlpha: CGFloat) -> CGColor {
        NSColor(red: 66/255, green: 97/255, blue: 123/255, alpha: darkAlpha).cgColor
    }

    private func updateIndicatorColors() {
        if appGroup.isLaunching {
            activeIndicator.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        } else if appGroup.windows.contains(where: { !$0.isMinimized }) && appGroup.isActive {
            activeIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        } else if appGroup.isRunning && !appGroup.windows.isEmpty {
            activeIndicator.layer?.backgroundColor = isDarkAppearance
                ? indicatorColor(darkAlpha: 0.9)
                : NSColor.secondaryLabelColor.withAlphaComponent(0.5).cgColor
        } else if appGroup.isRunning {
            activeIndicator.layer?.backgroundColor = isDarkAppearance
                ? indicatorColor(darkAlpha: 0.7)
                : NSColor.secondaryLabelColor.withAlphaComponent(0.3).cgColor
        }
    }

    private func updateActiveAccent() {
        if !appGroup.windows.isEmpty && appGroup.isActive {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.06).cgColor
        } else {
            layer?.backgroundColor = nil
        }
    }

    deinit {
        iconView?.layer?.removeAllAnimations()
        activeIndicator?.layer?.removeAllAnimations()
        layer?.removeAllAnimations()
    }

    // ─── Entry Animation ────────────────────────────────────────────

    private func playEntryAnimation() {
        guard animEnabled else {
            layer?.opacity = 1
            didAnimateEntry = true
            return
        }

        let offset: CGFloat = -20
        layer?.opacity = 0.01
        layer?.transform = CATransform3DTranslate(CATransform3DIdentity, 0, offset, 0)

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.01
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.3
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let slideUp = CABasicAnimation(keyPath: "transform.translation.y")
        slideUp.fromValue = offset
        slideUp.toValue = 0
        slideUp.duration = 0.3
        slideUp.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer?.opacity = 1
        layer?.transform = CATransform3DIdentity

        layer?.add(fadeIn, forKey: "entryFade")
        layer?.add(slideUp, forKey: "entrySlide")

        didAnimateEntry = true
    }

    // ─── Mouse ──────────────────────────────────────────────────────

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil

        if isHovering {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        } else {
            updateActiveAccent()
        }

        if let target = target as? NSObject, let action = action {
            target.perform(action, with: self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation = mouseDownLocation else { return }
        let currentLocation = event.locationInWindow
        let distance = hypot(currentLocation.x - startLocation.x, currentLocation.y - startLocation.y)
        guard distance > 5 else { return }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString("\(bundleIdentifier):\(index)", forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        if let rep = bitmapImageRepForCachingDisplay(in: bounds) {
            cacheDisplay(in: bounds, to: rep)
            let dragImage = NSImage(size: bounds.size)
            dragImage.addRepresentation(rep)
            draggingItem.setDraggingFrame(bounds, contents: dragImage)
        }
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }



    // ─── In-Place State Update ──────────────────────────────────────

    func updateAppGroupState(_ newGroup: AppGroup) {
        let oldGroup = appGroup

        let wasLaunching = oldGroup.isLaunching
        let isNowLaunching = newGroup.isLaunching

        let oldMinIDs = Set(oldGroup.windows.filter(\.isMinimized).map(\.windowID))
        let newMinIDs = Set(newGroup.windows.filter(\.isMinimized).map(\.windowID))
        let newlyMinimized = newMinIDs.subtracting(oldMinIDs)
        let newlyUnminimized = oldMinIDs.subtracting(newMinIDs)

        appGroup = newGroup

        if !wasLaunching && isNowLaunching {
            didAnimateEntry = false
        }

        let activeChanged = oldGroup.isActive != newGroup.isActive
        let runningChanged = oldGroup.isRunning != newGroup.isRunning
        let launchingChanged = wasLaunching != isNowLaunching
        let windowsChanged = oldGroup.windows.map(\.windowID) != newGroup.windows.map(\.windowID)

        if newGroup.isLaunching && !didAnimateEntry {
            playEntryAnimation()
        } else if activeChanged || runningChanged || launchingChanged || windowsChanged || !newlyMinimized.isEmpty || !newlyUnminimized.isEmpty {
            updateIndicatorColors()
            activeIndicator.isHidden = !newGroup.isRunning && !newGroup.isLaunching
        }

        if activeChanged || launchingChanged || windowsChanged {
            updateActiveAccent()
        }

        if launchingChanged {
            setLaunchingPulseActive(isNowLaunching)
        }

        if activeChanged || runningChanged || launchingChanged || !newlyMinimized.isEmpty || !newlyUnminimized.isEmpty {
            let w: CGFloat
            let h: CGFloat
            let cr: CGFloat
            if newGroup.isLaunching {
                w = 16; h = 3; cr = 1.5
            } else if newGroup.windows.contains(where: { !$0.isMinimized }) && newGroup.isActive {
                w = 16; h = 3; cr = 1.5
            } else if newGroup.isRunning && !newGroup.windows.isEmpty {
                w = 6; h = 3; cr = 1.5
            } else if newGroup.isRunning {
                w = 4; h = 4; cr = 2
            } else {
                w = 4; h = 4; cr = 2
            }
            indicatorWidthConstraint?.constant = w
            indicatorHeightConstraint?.constant = h
            activeIndicator.layer?.cornerRadius = cr
        }



        if showName, let label = nameLabel {
            label.textColor = newGroup.isActive ? .labelColor : .secondaryLabelColor
        }
    }

    // ─── Hover ──────────────────────────────────────────────────────

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        hoverOverlay.isHidden = false
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor

        let delay = TaskbarSettings.shared.hoverDelay
        guard delay > 0 else {
            showHoverPopover()
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.showHoverPopover()
        }
        hoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hoverOverlay.isHidden = true
        updateActiveAccent()

        hoverWorkItem?.cancel()
        hoverWorkItem = nil

        Self.sharedWindowListPopover.scheduleHide()
        Self.sharedThumbnailPopover.scheduleHide()
    }

    private func showHoverPopover() {
        guard !appGroup.windows.isEmpty else { return }
        let settings = TaskbarSettings.shared

        if settings.showThumbnails {
            showThumbnailPopover()
        } else if appGroup.hasMultipleWindows {
            showWindowListPopover()
        }
    }

    private func showWindowListPopover() {
        let popover = Self.sharedWindowListPopover
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

        let capturedOnNeedsRefresh = onNeedsRefresh
        popover.onWindowClosed = { windowID in
            capturedOnNeedsRefresh?(windowID)
        }
        let capturedBundleID = bundleIdentifier
        let capturedOnFocusChanged = onFocusChanged
        popover.onWindowActivated = { windowID, _ in
            capturedOnFocusChanged?(windowID, capturedBundleID)
        }
        popover.show(windows: appGroup.windows, appIcon: appGroup.icon, anchorPoint: screenPoint, screen: screen)
    }

    private func showThumbnailPopover() {
        let popover = Self.sharedThumbnailPopover
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

        let capturedOnNeedsRefresh = onNeedsRefresh
        popover.onWindowClosed = { windowID in
            capturedOnNeedsRefresh?(windowID)
        }
        let capturedBundleID = bundleIdentifier
        let capturedOnFocusChanged = onFocusChanged
        popover.onWindowActivated = { windowID, _ in
            capturedOnFocusChanged?(windowID, capturedBundleID)
        }
        popover.show(windows: appGroup.windows, appIcon: appGroup.icon, anchorPoint: screenPoint, screen: screen)
    }

    override func rightMouseDown(with event: NSEvent) {
        rightAction?(index)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && !didAnimateEntry {
            playEntryAnimation()
            didAnimateEntry = true
        }
    }

    func setDragHovering(_ hovering: Bool) {
        if hovering {
            hoverOverlay.isHidden = false
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        } else {
            hoverOverlay.isHidden = true
            updateActiveAccent()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateIndicatorColors()
    }

    private func setupConstraints() {
        [iconView, activeIndicator, hoverOverlay].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        nameLabel?.translatesAutoresizingMaskIntoConstraints = false

        let iconLeading: CGFloat = 8
        let iconHeight = CGFloat(TaskbarSettings.shared.iconSize)

        let indicatorWidth: CGFloat
        let indicatorHeight: CGFloat
        if appGroup.isLaunching {
            indicatorWidth = 16
            indicatorHeight = 3
        } else if appGroup.windows.contains(where: { !$0.isMinimized }) && appGroup.isActive {
            indicatorWidth = 16
            indicatorHeight = 3
        } else if appGroup.isRunning && appGroup.windows.isEmpty {
            indicatorWidth = 4
            indicatorHeight = 4
        } else {
            indicatorWidth = 6
            indicatorHeight = 3
        }

        let wid = activeIndicator.widthAnchor.constraint(equalToConstant: indicatorWidth)
        let hei = activeIndicator.heightAnchor.constraint(equalToConstant: indicatorHeight)
        indicatorWidthConstraint = wid
        indicatorHeightConstraint = hei

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
            wid,
            hei,
        ])

        if showName, let nameLabel {
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
                nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            ])
        }
    }

    private func setupTrackingArea() {
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
}

extension AppButtonView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
}
