import AppKit

final class ClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view !== self ? view : nil
    }
}

final class TaskbarPanel: NSPanel {
    private let windowManager: WindowManager
    private var contentView_: TaskbarContentView?

    init(screen: NSScreen, windowManager: WindowManager) {
        self.windowManager = windowManager
        let rect = ScreenGeometry.taskbarRect(for: screen)

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
    }

    func updateFrame(for screen: NSScreen) {
        let rect = ScreenGeometry.taskbarRect(for: screen)
        setFrame(rect, display: true)
    }

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }
}