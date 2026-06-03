import AppKit

final class ThemeManager {
    static let shared = ThemeManager()

    static func apply(
        to effectView: NSVisualEffectView,
        solidView: inout NSView?,
        parent: NSView,
        material: NSVisualEffectView.Material = .sidebar,
        cornerRadius: CGFloat = 0
    ) {
        let settings = TaskbarSettings.shared

        switch settings.backgroundTheme {
        case .system:
            solidView?.isHidden = true
            effectView.isHidden = false
            effectView.material = material
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.appearance = nil
            parent.appearance = nil

        case .dark:
            solidView?.isHidden = true
            effectView.isHidden = false
            effectView.material = material
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.appearance = NSAppearance(named: .darkAqua)
            parent.appearance = NSAppearance(named: .darkAqua)

        case .light:
            solidView?.isHidden = true
            effectView.isHidden = false
            effectView.material = material
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.appearance = NSAppearance(named: .aqua)
            parent.appearance = NSAppearance(named: .aqua)

        case .custom:
            effectView.isHidden = true
            if solidView == nil {
                let solid = NSView()
                solid.wantsLayer = true
                solid.layer?.masksToBounds = true
                solid.translatesAutoresizingMaskIntoConstraints = false
                parent.addSubview(solid, positioned: .below, relativeTo: effectView)
                NSLayoutConstraint.activate([
                    solid.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                    solid.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                    solid.topAnchor.constraint(equalTo: effectView.topAnchor),
                    solid.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
                ])
                solidView = solid
            }
            solidView?.isHidden = false
            let color = settings.customBackgroundColor
            solidView?.layer?.backgroundColor = color.cgColor
            solidView?.layer?.cornerRadius = cornerRadius
            parent.appearance = Self.appearance(for: color)
        }
    }

    static func appearance(for color: NSColor) -> NSAppearance {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
        return luminance > 0.5 ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
    }
}
