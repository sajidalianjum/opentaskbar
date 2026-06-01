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

    init(screen: NSScreen, windowManager: WindowManager) {
        self.windowManager = windowManager
        let height = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(TaskbarSettings.shared.iconSize))
        let rect = ScreenGeometry.taskbarRect(for: screen, height: height)

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
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
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

        windowManager.onAppGroupsChanged = { [weak self] in
            self?.contentView_?.reloadData()
        }
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
        let rect = ScreenGeometry.taskbarRect(for: screen, height: height)
        setFrame(rect, display: true, animate: true)
    }

    override var canBecomeKey: Bool { false }

    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}