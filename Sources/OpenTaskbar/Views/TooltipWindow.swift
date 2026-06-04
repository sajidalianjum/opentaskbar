import AppKit

final class TooltipWindow: NSWindow {
    static let shared = TooltipWindow()

    private let label: NSTextField
    private let containerView: NSView

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private init() {
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 5
        containerView.layer?.masksToBounds = true

        let bg = NSVisualEffectView()
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bg)

        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.cell?.wraps = false
        containerView.addSubview(label)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 30),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = containerView

        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bg.topAnchor.constraint(equalTo: containerView.topAnchor),
            bg.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -5),
        ])
    }

    func show(text: String, at screenPoint: NSPoint, screen: NSScreen) {
        label.stringValue = text

        let font = NSFont.systemFont(ofSize: 11, weight: .regular)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let width = ceil(textSize.width) + 16
        let height = ceil(textSize.height) + 10

        let screenFrame = screen.visibleFrame

        var x = screenPoint.x - width / 2
        var y = screenPoint.y + 12

        if y + height > screenFrame.maxY {
            y = screenPoint.y - height - 4
        }

        x = max(screenFrame.minX, min(x, screenFrame.maxX - width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - height))

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}
