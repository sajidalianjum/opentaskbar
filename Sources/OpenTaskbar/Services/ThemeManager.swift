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

        if settings.translucentBar {
            effectView.isHidden = false
            effectView.material = material
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.layer?.backgroundColor = nil

            switch settings.backgroundTheme {
            case .system:
                solidView?.isHidden = true
                effectView.appearance = nil
                parent.appearance = nil

            case .dark:
                solidView?.isHidden = true
                effectView.appearance = NSAppearance(named: .darkAqua)
                parent.appearance = NSAppearance(named: .darkAqua)

            case .light:
                solidView?.isHidden = true
                effectView.appearance = NSAppearance(named: .aqua)
                parent.appearance = NSAppearance(named: .aqua)

            case .custom:
                solidView?.isHidden = true
                let color = settings.customBackgroundColor
                effectView.layer?.backgroundColor = color.withAlphaComponent(0.35).cgColor
                effectView.appearance = Self.appearance(for: color)
                parent.appearance = Self.appearance(for: color)
            }
        } else {
            effectView.isHidden = true

            let opaqueColor: NSColor
            switch settings.backgroundTheme {
            case .system:
                let isDark = parent.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                opaqueColor = isDark ? NSColor(calibratedWhite: 0.08, alpha: 1.0) : NSColor(calibratedWhite: 0.92, alpha: 1.0)
                parent.appearance = nil
            case .dark:
                opaqueColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
                parent.appearance = NSAppearance(named: .darkAqua)
            case .light:
                opaqueColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
                parent.appearance = NSAppearance(named: .aqua)
            case .custom:
                opaqueColor = settings.customBackgroundColor
                parent.appearance = Self.appearance(for: opaqueColor)
            }

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
            solidView?.layer?.backgroundColor = opaqueColor.cgColor
            solidView?.layer?.cornerRadius = cornerRadius
        }
    }

    static func appearance(for color: NSColor) -> NSAppearance {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
        return luminance > 0.5 ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
    }
}
