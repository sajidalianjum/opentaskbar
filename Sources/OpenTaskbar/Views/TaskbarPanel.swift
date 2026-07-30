import AppKit

final class ClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view !== self ? view : nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

final class TaskbarPanel: NSPanel {
    private let windowManager: WindowManager
    private let settings = TaskbarSettings.shared
    private var contentView_: TaskbarContentView?
    private var hiddenForFullscreen: Bool = false

    init(screen: NSScreen, windowManager: WindowManager) {
        self.windowManager = windowManager
        let height = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(TaskbarSettings.shared.iconSize))
        let rect = ScreenGeometry.taskbarRect(for: screen, height: height, isDockStyle: TaskbarSettings.shared.style == .dock)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isMovableByWindowBackground = false
        isMovable = false
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false

        let clickThroughView = ClickThroughView()
        clickThroughView.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(clickThroughView)
        NSLayoutConstraint.activate([
            clickThroughView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            clickThroughView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            clickThroughView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            clickThroughView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
        ])

        let taskbarView = TaskbarContentView(windowManager: windowManager)
        self.contentView_ = taskbarView
        clickThroughView.addSubview(taskbarView)

        taskbarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            taskbarView.leadingAnchor.constraint(equalTo: clickThroughView.leadingAnchor),
            taskbarView.trailingAnchor.constraint(equalTo: clickThroughView.trailingAnchor),
            taskbarView.topAnchor.constraint(equalTo: clickThroughView.topAnchor),
            taskbarView.bottomAnchor.constraint(equalTo: clickThroughView.bottomAnchor)
        ])

        contentView_?.reloadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: TaskbarSettings.settingsDidChange, object: nil
        )
    }

    @objc private func settingsChanged() {
        guard let screen = NSScreen.screens.first(where: { NSIntersectsRect($0.frame, frame) }) else { return }
        updateFrame(for: screen)
    }

    func updateFrame(for screen: NSScreen) {
        let height = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(settings.iconSize))
        let rect = ScreenGeometry.taskbarRect(for: screen, height: height, isDockStyle: settings.style == .dock)
        setFrame(rect, display: true, animate: true)
    }

    func reloadContent() {
        contentView_?.reloadData()
    }

    func setHiddenForFullscreen(_ hidden: Bool) {
        hiddenForFullscreen = hidden
        if hidden {
            if isVisible { orderOut(nil) }
        } else {
            if !isVisible { orderFront(nil) }
        }
    }

    override func orderFront(_ sender: Any?) {
        guard !hiddenForFullscreen else { return }
        super.orderFront(sender)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let expectedHeight = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(settings.iconSize))
        var rect = frameRect
        rect.size.height = expectedHeight
        super.setFrame(rect, display: flag && !hiddenForFullscreen)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        let expectedHeight = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(settings.iconSize))
        var rect = frameRect
        rect.size.height = expectedHeight
        super.setFrame(rect, display: displayFlag && !hiddenForFullscreen, animate: animateFlag)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let height = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(settings.iconSize))
        guard let targetScreen = screen ?? NSScreen.main else {
            return frameRect
        }
        return ScreenGeometry.taskbarRect(for: targetScreen, height: height, isDockStyle: settings.style == .dock)
    }

    override var canBecomeKey: Bool { false }

    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}