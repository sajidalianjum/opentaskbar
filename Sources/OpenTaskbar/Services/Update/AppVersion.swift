import Foundation

struct AppVersion: Comparable, Hashable, CustomStringConvertible {
    let components: [Int]
    let prereleaseIdentifiers: [String]
    let buildMetadata: String?

    init?(string raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text.first == "v" || text.first == "V" {
            text.removeFirst()
        }

        var build: String?
        if let plusIndex = text.firstIndex(of: "+") {
            build = String(text[text.index(after: plusIndex)...])
            text = String(text[..<plusIndex])
        }

        var prerelease: [String] = []
        if let dashIndex = text.firstIndex(of: "-") {
            let suffix = String(text[text.index(after: dashIndex)...])
            text = String(text[..<dashIndex])
            prerelease = suffix
                .split(separator: ".", omittingEmptySubsequences: true)
                .map(String.init)
        }

        let parsed = text
            .split(separator: ".", omittingEmptySubsequences: true)
            .compactMap { part -> Int? in
                let digits = part.prefix { $0.isNumber }
                guard !digits.isEmpty else { return nil }
                return Int(digits)
            }

        guard !parsed.isEmpty else { return nil }

        components = parsed
        prereleaseIdentifiers = prerelease
        buildMetadata = build
    }

    init(components: [Int], prereleaseIdentifiers: [String] = [], buildMetadata: String? = nil) {
        self.components = components
        self.prereleaseIdentifiers = prereleaseIdentifiers
        self.buildMetadata = buildMetadata
    }

    var isPrerelease: Bool {
        !prereleaseIdentifiers.isEmpty
    }

    var description: String {
        var text = components.map(String.init).joined(separator: ".")
        if !prereleaseIdentifiers.isEmpty {
            text += "-" + prereleaseIdentifiers.joined(separator: ".")
        }
        if let buildMetadata {
            text += "+" + buildMetadata
        }
        return text
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.isOrderedBefore(rhs)
    }

    // `1` and `1.0.0` are the same release, so equality follows the same
    // ordering rather than comparing the raw component arrays. Build metadata
    // is deliberately excluded: SemVer ignores it for precedence.
    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !lhs.isOrderedBefore(rhs) && !rhs.isOrderedBefore(lhs)
    }

    func hash(into hasher: inout Hasher) {
        // Pad to a canonical width so 1, 1.0 and 1.0.0 hash alike.
        let width = 4
        let padded = (0..<width).map { index in index < components.count ? components[index] : 0 }
        hasher.combine(padded)
        hasher.combine(prereleaseIdentifiers)
    }

    func isOrderedBefore(_ other: AppVersion) -> Bool {
        let count = max(components.count, other.components.count)
        for index in 0..<count {
            let left = index < components.count ? components[index] : 0
            let right = index < other.components.count ? other.components[index] : 0
            if left != right { return left < right }
        }

        // A release outranks any prerelease of the same version: 1.2.0 > 1.2.0-beta.1
        if prereleaseIdentifiers.isEmpty != other.prereleaseIdentifiers.isEmpty {
            return !prereleaseIdentifiers.isEmpty
        }

        let identifierCount = max(prereleaseIdentifiers.count, other.prereleaseIdentifiers.count)
        for index in 0..<identifierCount {
            guard index < prereleaseIdentifiers.count else { return true }
            guard index < other.prereleaseIdentifiers.count else { return false }
            let left = prereleaseIdentifiers[index]
            let right = other.prereleaseIdentifiers[index]
            if left == right { continue }

            switch (Int(left), Int(right)) {
            case let (leftNumber?, rightNumber?):
                return leftNumber < rightNumber
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return left < right
            }
        }

        return false
    }

    static var bundleVersion: AppVersion? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }
        return AppVersion(string: raw)
    }

    static var bundleBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let candidateVersion = AppVersion(string: candidate),
              let currentVersion = AppVersion(string: current) else { return false }
        return candidateVersion > currentVersion
    }
}