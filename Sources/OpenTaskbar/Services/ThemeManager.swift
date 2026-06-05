import AppKit

final class ThemeManager {
    static let shared = ThemeManager()

    static func apply(
        to effectView: NSVisualEffectView,
        solidView: inout NSView?,
        parent: NSView,
        material: NSVisualEffectView.Material = .sidebar,
        cornerRadius: CGFloat = 0,
        shadowView: inout NSView?
    ) {
        let settings = TaskbarSettings.shared

        if settings.translucentBar {
            effectView.isHidden = false
            effectView.material = material
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.layer?.backgroundColor = nil
            solidView?.isHidden = true

            switch settings.backgroundTheme {
            case .system:
                hideShadow(&shadowView)
                effectView.appearance = nil
                parent.appearance = nil

            case .dark:
                hideShadow(&shadowView)
                effectView.appearance = NSAppearance(named: .darkAqua)
                parent.appearance = NSAppearance(named: .darkAqua)

            case .light:
                hideShadow(&shadowView)
                effectView.appearance = NSAppearance(named: .aqua)
                parent.appearance = NSAppearance(named: .aqua)

            case .glassmorphism:
                effectView.material = .hudWindow
                effectView.appearance = nil
                parent.appearance = nil
                showShadow(on: &shadowView, parent: parent, effectView: effectView, cornerRadius: cornerRadius)

            case .custom:
                hideShadow(&shadowView)
                let color = settings.customBackgroundColor
                effectView.layer?.backgroundColor = color.withAlphaComponent(0.35).cgColor
                effectView.appearance = Self.appearance(for: color)
                parent.appearance = Self.appearance(for: color)
            }
        } else {
            effectView.isHidden = true
            hideShadow(&shadowView)

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
            case .glassmorphism:
                let isDark = parent.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                opaqueColor = isDark ? NSColor(calibratedWhite: 0.08, alpha: 1.0) : NSColor(calibratedWhite: 0.92, alpha: 1.0)
                parent.appearance = nil
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

    private static func hideShadow(_ shadowView: inout NSView?) {
        shadowView?.isHidden = true
        shadowView?.layer?.shadowOpacity = 0
    }

    private static func showShadow(on shadowView: inout NSView?, parent: NSView, effectView: NSView, cornerRadius: CGFloat) {
        if shadowView == nil {
            let shadow = NSView()
            shadow.wantsLayer = true
            shadow.translatesAutoresizingMaskIntoConstraints = false
            shadow.layer?.masksToBounds = false
            parent.addSubview(shadow, positioned: .below, relativeTo: effectView)
            NSLayoutConstraint.activate([
                shadow.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                shadow.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                shadow.topAnchor.constraint(equalTo: effectView.topAnchor),
                shadow.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            ])
            shadowView = shadow
        }
        guard let shadow = shadowView else { return }
        shadow.isHidden = false
        shadow.layer?.backgroundColor = nil
        shadow.layer?.cornerRadius = cornerRadius
        shadow.layer?.shadowOpacity = 0.2
        shadow.layer?.shadowRadius = 6
        shadow.layer?.shadowOffset = NSSize(width: 0, height: -4)
        shadow.layer?.shadowColor = NSColor.black.cgColor
    }

    static func appearance(for color: NSColor) -> NSAppearance {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
        return luminance > 0.5 ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
    }
}
