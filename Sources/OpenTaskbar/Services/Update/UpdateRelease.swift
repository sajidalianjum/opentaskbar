import Foundation

struct ReleaseAsset: Decodable, Equatable {
    let name: String
    let size: Int
    let downloadURL: URL
    let digest: String?

    var sha256: String? {
        guard let digest else { return nil }
        let trimmed = digest.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.hasPrefix("sha256:") else { return nil }
        let hex = String(trimmed.dropFirst("sha256:".count))
        guard hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return hex
    }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case downloadURL = "browser_download_url"
        case digest
    }
}

struct UpdateRelease: Decodable, Equatable {
    let tagName: String
    let htmlURL: URL
    let body: String?
    let prerelease: Bool
    let publishedAt: String?
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case prerelease
        case publishedAt = "published_at"
        case assets
    }

    // GitHub omits optional fields on older/minimal releases, so everything but
    // the tag and the asset list has a default: an under-specified payload
    // should never stop the app from reporting "you are up to date".
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        htmlURL = try container.decodeIfPresent(URL.self, forKey: .htmlURL)
            ?? URL(string: "https://github.com")!
        body = try container.decodeIfPresent(String.self, forKey: .body)
        prerelease = try container.decodeIfPresent(Bool.self, forKey: .prerelease) ?? false
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt)
        assets = try container.decodeIfPresent([ReleaseAsset].self, forKey: .assets) ?? []
    }

    init(tagName: String, htmlURL: URL, body: String?, prerelease: Bool, publishedAt: String?, assets: [ReleaseAsset]) {
        self.tagName = tagName
        self.htmlURL = htmlURL
        self.body = body
        self.prerelease = prerelease
        self.publishedAt = publishedAt
        self.assets = assets
    }

    var version: AppVersion? {
        AppVersion(string: tagName)
    }

    var appAsset: ReleaseAsset? {
        UpdateRelease.preferredAppAsset(in: assets, appName: "OpenTaskbar", version: version)
    }

    var notes: String? {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return body
    }

    var publishedDate: Date? {
        guard let publishedAt else { return nil }
        return ISO8601DateFormatter().date(from: publishedAt)
    }

    static func parse(json data: Data) -> UpdateRelease? {
        try? JSONDecoder().decode(UpdateRelease.self, from: data)
    }

    // Releases attach both `OpenTaskbar-<version>.zip` and the version-less
    // `OpenTaskbar.zip` alias. The versioned asset wins because it is
    // unambiguous; the alias is the fallback for older releases carrying only
    // that. Other assets (`install.sh`, `.sha256`) are never candidates — the
    // app installs itself rather than shelling out to the installer.
    static func preferredAppAsset(in assets: [ReleaseAsset], appName: String, version: AppVersion?) -> ReleaseAsset? {
        if let version {
            let expected = "\(appName)-\(version).zip"
            if let exact = assets.first(where: { $0.name == expected }) {
                return exact
            }
        }
        if let versioned = assets.first(where: {
            $0.name.hasPrefix("\(appName)-") && $0.name.hasSuffix(".zip") && !$0.name.contains("/")
        }) {
            return versioned
        }
        return assets.first(where: { $0.name == "\(appName).zip" })
    }
}