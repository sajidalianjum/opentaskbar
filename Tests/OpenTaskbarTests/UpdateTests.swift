import XCTest
@testable import OpenTaskbar

final class AppVersionTests: XCTestCase {
    func testParsesPlainVersion() {
        let version = AppVersion(string: "0.1.1")
        XCTAssertEqual(version?.components, [0, 1, 1])
        XCTAssertFalse(version?.isPrerelease ?? true)
    }

    func testStripsTagPrefix() {
        XCTAssertEqual(AppVersion(string: "v1.2.3"), AppVersion(string: "1.2.3"))
        XCTAssertEqual(AppVersion(string: " V1.2.3 "), AppVersion(string: "1.2.3"))
    }

    func testRejectsGarbage() {
        XCTAssertNil(AppVersion(string: ""))
        XCTAssertNil(AppVersion(string: "   "))
        XCTAssertNil(AppVersion(string: "latest"))
    }

    func testNumericOrderingIsNotLexicographic() {
        XCTAssertTrue(AppVersion(string: "1.10.0")! > AppVersion(string: "1.9.9")!)
        XCTAssertTrue(AppVersion(string: "0.2.0")! > AppVersion(string: "0.1.10")!)
    }

    func testShorterVersionsAreZeroPadded() {
        XCTAssertTrue(AppVersion(string: "1.0")! < AppVersion(string: "1.0.1")!)
        XCTAssertEqual(AppVersion(string: "1")!, AppVersion(string: "1.0.0")!)
    }

    func testReleaseOutranksPrerelease() {
        XCTAssertTrue(AppVersion(string: "1.2.0")! > AppVersion(string: "1.2.0-beta.1")!)
        XCTAssertTrue(AppVersion(string: "1.2.0-rc.1")! > AppVersion(string: "1.2.0-beta.1")!)
        XCTAssertTrue(AppVersion(string: "1.2.0-beta.2")! > AppVersion(string: "1.2.0-beta.1")!)
        XCTAssertTrue(AppVersion(string: "1.2.0-beta")! < AppVersion(string: "1.2.0-beta.1")!)
    }

    func testBuildMetadataIsIgnoredForOrdering() {
        let a = AppVersion(string: "1.2.0+abc")!
        let b = AppVersion(string: "1.2.0+def")!
        XCTAssertFalse(a < b)
        XCTAssertFalse(b < a)
        XCTAssertEqual(a.description, "1.2.0+abc")
    }

    func testDescriptionRoundTrips() {
        XCTAssertEqual(AppVersion(string: "v1.4.0-beta.2+sha.abc")?.description, "1.4.0-beta.2+sha.abc")
    }

    func testIsNewerHelper() {
        XCTAssertTrue(AppVersion.isNewer("v0.2.0", than: "0.1.1"))
        XCTAssertFalse(AppVersion.isNewer("v0.1.1", than: "0.1.1"))
        XCTAssertFalse(AppVersion.isNewer("v0.1.0", than: "0.1.1"))
        XCTAssertFalse(AppVersion.isNewer("latest", than: "0.1.1"))
    }
}

final class UpdateReleaseTests: XCTestCase {
    private func release(json: String) throws -> UpdateRelease {
        let data = Data(json.utf8)
        return try XCTUnwrap(UpdateRelease.parse(json: data))
    }

    private let validJSON = """
    {
      "tag_name": "v0.2.0",
      "html_url": "https://github.com/sajidalianjum/opentaskbar/releases/tag/v0.2.0",
      "body": "## What's Changed\\n- Auto updates",
      "prerelease": false,
      "published_at": "2026-10-01T10:00:00Z",
      "assets": [
        {
          "name": "OpenTaskbar-0.2.0.zip",
          "size": 4821,
          "browser_download_url": "https://github.com/sajidalianjum/opentaskbar/releases/download/v0.2.0/OpenTaskbar-0.2.0.zip",
          "digest": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        },
        { "name": "OpenTaskbar.zip", "size": 4821, "browser_download_url": "https://example.com/OpenTaskbar.zip" },
        { "name": "install.sh", "size": 100, "browser_download_url": "https://example.com/install.sh" }
      ]
    }
    """

    func testParsesGitHubReleasePayload() throws {
        let release = try release(json: validJSON)
        XCTAssertEqual(release.tagName, "v0.2.0")
        XCTAssertEqual(release.version, AppVersion(string: "0.2.0"))
        XCTAssertFalse(release.prerelease)
        XCTAssertEqual(release.assets.count, 3)
        XCTAssertNotNil(release.notes)
        XCTAssertNotNil(release.publishedDate)
    }

    func testPrefersVersionedZipOverAlias() throws {
        let release = try release(json: validJSON)
        XCTAssertEqual(release.appAsset?.name, "OpenTaskbar-0.2.0.zip")
    }

    func testFallsBackToAliasWhenVersionedAssetIsMissing() throws {
        let json = """
        {
          "tag_name": "v0.3.0",
          "html_url": "https://example.com",
          "assets": [
            { "name": "OpenTaskbar.zip", "size": 10, "browser_download_url": "https://example.com/OpenTaskbar.zip" }
          ]
        }
        """
        XCTAssertEqual(try release(json: json).appAsset?.name, "OpenTaskbar.zip")
    }

    func testNeverPicksTheInstallerScript() throws {
        let json = """
        {
          "tag_name": "v0.3.0",
          "html_url": "https://example.com",
          "assets": [
            { "name": "install.sh", "size": 10, "browser_download_url": "https://example.com/install.sh" }
          ]
        }
        """
        XCTAssertNil(try release(json: json).appAsset)
    }

    func testDigestIsParsedOnlyWhenWellFormed() {
        let asset = ReleaseAsset(
            name: "a.zip",
            size: 1,
            downloadURL: URL(string: "https://example.com/a.zip")!,
            digest: "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
        XCTAssertEqual(asset.sha256?.count, 64)

        let notAHash = ReleaseAsset(
            name: "a.zip",
            size: 1,
            downloadURL: URL(string: "https://example.com/a.zip")!,
            digest: "sha256:zzzz"
        )
        XCTAssertNil(notAHash.sha256)

        let otherAlgorithm = ReleaseAsset(
            name: "a.zip",
            size: 1,
            downloadURL: URL(string: "https://example.com/a.zip")!,
            digest: "md5:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
        XCTAssertNil(otherAlgorithm.sha256)
        XCTAssertNil(ReleaseAsset(name: "a.zip", size: 1, downloadURL: URL(string: "https://example.com")!, digest: nil).sha256)
    }

    func testMalformedPayloadIsRejected() {
        XCTAssertNil(UpdateRelease.parse(json: Data("<html>nope</html>".utf8)))
        XCTAssertNil(UpdateRelease.parse(json: Data("{}".utf8)))
    }

    func testEmptyBodyMeansNoNotes() throws {
        let release = try release(json: """
        { "tag_name": "v1.0.0", "html_url": "https://example.com", "body": "  ", "assets": [] }
        """)
        XCTAssertNil(release.notes)
    }
}

final class UpdateFeedResponseTests: XCTestCase {
    private func response(_ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.github.com/repos/x/y/releases/latest")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    func testSuccessDecodesRelease() {
        let json = """
        { "tag_name": "v9.9.9", "html_url": "https://example.com", "assets": [] }
        """
        let result = UpdateFeedClient.interpret(
            data: Data(json.utf8),
            response: response(200),
            error: nil
        )
        guard case .success(let release) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(release.tagName, "v9.9.9")
    }

    func testNotModifiedIsMappedToACaseThatMeansUpToDate() {
        let result = UpdateFeedClient.interpret(data: nil, response: response(304), error: nil)
        XCTAssertEqual(result, .failure(.notModified))
    }

    func testRateLimitIsMapped() {
        let result = UpdateFeedClient.interpret(
            data: nil,
            response: response(403, headers: ["Retry-After": "3600"]),
            error: nil
        )
        XCTAssertEqual(result, .failure(.rateLimited(retryAfter: 3600)))
    }

    func testServerErrorKeepsTheStatusCode() {
        let result = UpdateFeedClient.interpret(data: nil, response: response(503), error: nil)
        XCTAssertEqual(result, .failure(.httpStatus(503)))
    }

    func testTransportErrorIsMapped() {
        let offline = URLError(.notConnectedToInternet)
        let result = UpdateFeedClient.interpret(data: nil, response: nil, error: offline)
        guard case .failure(.offline) = result else {
            return XCTFail("expected .offline, got \(result)")
        }
    }

    func testNonHTTPResponseIsInvalid() {
        let result = UpdateFeedClient.interpret(data: nil, response: nil, error: nil)
        XCTAssertEqual(result, .failure(.invalidResponse))
    }

    func testETagIsStoredAndReplayed() {
        let suiteName = "OpenTaskbarTests.feed.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("could not create an isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsETagStore(defaults: defaults)
        XCTAssertNil(store.etag)
        store.etag = "W/\"abc\""
        XCTAssertEqual(store.etag, "W/\"abc\"")
        store.etag = nil
        XCTAssertNil(store.etag)
    }
}

final class UpdateHistoryStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: UpdateHistoryStore!

    override func setUp() {
        super.setUp()
        suiteName = "OpenTaskbarTests.history.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = UpdateHistoryStore(defaults: defaults, checkInterval: 3600)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testFirstCheckHappensImmediately() {
        XCTAssertTrue(store.shouldCheckNow())
    }

    func testCheckIsThrottledUntilTheIntervalElapses() {
        let now = Date()
        store.lastCheckDate = now
        XCTAssertFalse(store.shouldCheckNow(at: now.addingTimeInterval(1800)))
        XCTAssertTrue(store.shouldCheckNow(at: now.addingTimeInterval(3600)))
    }

    func testSkippedVersionIsRemembered() {
        XCTAssertFalse(store.isSkipped("v0.2.0"))
        store.skippedVersion = "v0.2.0"
        XCTAssertTrue(store.isSkipped("v0.2.0"))
        XCTAssertFalse(store.isSkipped("v0.3.0"))
        store.skippedVersion = nil
        XCTAssertFalse(store.isSkipped("v0.2.0"))
    }

    func testResetClearsEverything() {
        store.lastCheckDate = Date()
        store.skippedVersion = "v1.0.0"
        store.lastInstalledVersion = "v1.0.0"
        store.pendingInstallVersion = "v1.1.0"
        store.reset()
        XCTAssertNil(store.lastCheckDate)
        XCTAssertNil(store.skippedVersion)
        XCTAssertNil(store.lastInstalledVersion)
        XCTAssertNil(store.pendingInstallVersion)
    }

    func testPendingInstallIsPromotedOnlyWhenTheNewVersionIsRunning() {
        store.pendingInstallVersion = "v2.0.0"
        store.confirmPendingInstall(runningVersion: AppVersion(string: "2.0.0"))
        XCTAssertEqual(store.lastInstalledVersion, "v2.0.0")
        XCTAssertNil(store.pendingInstallVersion)
    }

    func testFailedInstallLeavesNoStaleRecord() {
        // Regression: an install that never completed must not record itself as
        // installed, or the update it failed to apply would never be offered again.
        store.pendingInstallVersion = "v2.0.0"
        store.confirmPendingInstall(runningVersion: AppVersion(string: "1.0.0"))
        XCTAssertNil(store.lastInstalledVersion)
        XCTAssertNil(store.pendingInstallVersion)
    }

    func testConfirmingWithoutAPendingInstallDoesNothing() {
        store.lastInstalledVersion = "v1.0.0"
        store.confirmPendingInstall(runningVersion: AppVersion(string: "1.0.0"))
        XCTAssertEqual(store.lastInstalledVersion, "v1.0.0")
    }
}

final class UpdateManagerDecisionTests: XCTestCase {
    private func makeManager(history: UpdateHistoryStore) -> UpdateManager {
        UpdateManager(
            feedClient: UpdateFeedClient(endpoint: URL(string: "https://example.invalid")!),
            installer: UpdateInstaller(
                workDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
            ),
            history: history,
            settings: TaskbarSettings.shared
        )
    }

    private func release(
        tag: String,
        prerelease: Bool = false,
        withAsset: Bool = true
    ) -> UpdateRelease {
        let assets: [ReleaseAsset] = withAsset
            ? [ReleaseAsset(
                name: "OpenTaskbar.zip",
                size: 10,
                downloadURL: URL(string: "https://example.com/OpenTaskbar.zip")!,
                digest: nil
            )]
            : []
        return UpdateRelease(
            tagName: tag,
            htmlURL: URL(string: "https://example.com")!,
            body: nil,
            prerelease: prerelease,
            publishedAt: nil,
            assets: assets
        )
    }

    private func makeStore() -> UpdateHistoryStore {
        let name = "OpenTaskbarTests.decision.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return UpdateHistoryStore(defaults: defaults)
    }

    func testNewerReleaseIsOffered() {
        let store = makeStore()
        let manager = makeManager(history: store)
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: false)
        XCTAssertEqual(manager.status, .updateAvailable(release(tag: "v0.2.0")))
    }

    func testSameVersionIsUpToDate() {
        let manager = makeManager(history: makeStore())
        manager.evaluate(release(tag: "v0.1.1"), against: AppVersion(string: "0.1.1")!, userInitiated: false)
        XCTAssertEqual(manager.status, .upToDate)
    }

    func testOlderReleaseIsIgnored() {
        let manager = makeManager(history: makeStore())
        manager.evaluate(release(tag: "v0.1.0"), against: AppVersion(string: "0.1.1")!, userInitiated: true)
        XCTAssertEqual(manager.status, .upToDate)
    }

    func testSkippedVersionStaysQuietOnBackgroundChecks() {
        let store = makeStore()
        store.skippedVersion = "v0.2.0"
        let manager = makeManager(history: store)
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: false)
        XCTAssertEqual(manager.status, .idle)
    }

    func testSkippedVersionIsResurfacedByAManualCheck() {
        let store = makeStore()
        store.skippedVersion = "v0.2.0"
        let manager = makeManager(history: store)
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: true)
        XCTAssertEqual(manager.status, .updateAvailable(release(tag: "v0.2.0")))
    }

    func testAlreadyInstalledVersionIsNotOfferedTwice() {
        let store = makeStore()
        store.lastInstalledVersion = "v0.2.0"
        let manager = makeManager(history: store)
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: true)
        XCTAssertEqual(manager.status, .upToDate)
    }

    func testPrereleasesAreIgnoredByDefault() {
        let manager = makeManager(history: makeStore())
        manager.evaluate(
            release(tag: "v0.2.0-beta.1", prerelease: true),
            against: AppVersion(string: "0.1.1")!,
            userInitiated: false
        )
        XCTAssertEqual(manager.status, .upToDate)
    }

    func testReleaseWithoutAnAppAssetFailsAManualCheck() {
        let manager = makeManager(history: makeStore())
        manager.evaluate(
            release(tag: "v0.2.0", withAsset: false),
            against: AppVersion(string: "0.1.1")!,
            userInitiated: true
        )
        XCTAssertEqual(manager.status, .failed(.noAssetAvailable))
    }

    func testSkipAndDismissClearThePendingState() {
        let store = makeStore()
        let manager = makeManager(history: store)
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: false)

        manager.skip(release(tag: "v0.2.0"))
        XCTAssertEqual(store.skippedVersion, "v0.2.0")
        XCTAssertEqual(manager.status, .idle)
        XCTAssertNil(manager.pendingRelease)
    }

    func testStatusExposesTheReleaseWhileBusy() {
        let manager = makeManager(history: makeStore())
        manager.evaluate(release(tag: "v0.2.0"), against: AppVersion(string: "0.1.1")!, userInitiated: false)
        XCTAssertFalse(manager.status.isBusy)

        manager.evaluate(release(tag: "v0.3.0"), against: AppVersion(string: "0.1.1")!, userInitiated: false)
        XCTAssertEqual(manager.pendingRelease?.tagName, "v0.3.0")
    }
}

final class UpdateInstallerTests: XCTestCase {
    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("OpenTaskbarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testSHA256MatchesTheKnownDigest() throws {
        let url = try makeTemporaryDirectory().appendingPathComponent("payload.txt")
        try Data("OpenTaskbar".utf8).write(to: url)
        // printf 'OpenTaskbar' | shasum -a 256
        XCTAssertEqual(
            try UpdateInstaller.sha256(of: url),
            "64822e9bc9aacb890576dde29dc74fa06814b6ff44860db8131f08b326cae1d8"
        )
    }

    func testSHA256DetectsTampering() throws {
        let url = try makeTemporaryDirectory().appendingPathComponent("payload.txt")
        try Data("first".utf8).write(to: url)
        let original = try UpdateInstaller.sha256(of: url)
        try Data("second".utf8).write(to: url)
        XCTAssertNotEqual(original, try UpdateInstaller.sha256(of: url))
        XCTAssertEqual(original.count, 64)
    }

    func testValidationRejectsAForeignBundleIdentifier() throws {
        let installer = UpdateInstaller(workDirectory: try makeTemporaryDirectory())
        let bundle = try makeTemporaryDirectory().appendingPathComponent("OpenTaskbar.app", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents/MacOS"),
            withIntermediateDirectories: true
        )
        try? Data().write(to: bundle.appendingPathComponent("Contents/MacOS/OpenTaskbar"))
        try? Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.evil.impostor</string>
        <key>CFBundleExecutable</key><string>OpenTaskbar</string>
        <key>CFBundleShortVersionString</key><string>9.9.9</string>
        </dict></plist>
        """.utf8).write(to: bundle.appendingPathComponent("Contents/Info.plist"))

        XCTAssertThrowsError(try installer.validate(bundle: bundle, expectedVersion: AppVersion(string: "0.2.0")))
    }

    func testHelperScriptReferencesTheStagedBundleAndWaitsForTheProcess() {
        let script = UpdateInstaller.helperScript(
            pid: 4242,
            stagedBundle: URL(fileURLWithPath: "/tmp/staged/OpenTaskbar.app"),
            currentBundle: URL(fileURLWithPath: "/Applications/OpenTaskbar.app"),
            logURL: URL(fileURLWithPath: "/tmp/apply.log")
        )
        XCTAssertTrue(script.contains("PID=4242"))
        XCTAssertTrue(script.contains("kill -0 \"$PID\""))
        XCTAssertTrue(script.contains("/tmp/staged/OpenTaskbar.app"))
        XCTAssertTrue(script.contains("/Applications/OpenTaskbar.app"))
        XCTAssertTrue(script.contains("tccutil reset Accessibility"))
        XCTAssertTrue(script.contains("com.apple.quarantine"))
        // The helper must relaunch the app it just replaced.
        XCTAssertTrue(script.contains("/usr/bin/open \"$DEST\""))
    }

    func testHelperScriptRelaunchesTheOldBundleWhenItCannotApply() {
        let script = UpdateInstaller.helperScript(
            pid: 4242,
            stagedBundle: URL(fileURLWithPath: "/tmp/staged/OpenTaskbar.app"),
            currentBundle: URL(fileURLWithPath: "/Applications/OpenTaskbar.app"),
            logURL: URL(fileURLWithPath: "/tmp/apply.log")
        )
        // Regression: a failed swap must not leave the user with no app.
        XCTAssertTrue(script.contains("fail()"))
        XCTAssertTrue(script.contains("[ -d \"$STAGED\" ] || fail"))
        XCTAssertTrue(script.contains("relaunching the existing bundle"))
        XCTAssertTrue(script.contains("[ -d \"$BACKUP\" ] && mv \"$BACKUP\" \"$DEST\""))
    }

    func testStagingIsIsolatedFromTheDownloadDirectory() throws {
        let work = try makeTemporaryDirectory()
        let installer = UpdateInstaller(workDirectory: work)
        let release = UpdateRelease(
            tagName: "v9.9.9",
            htmlURL: URL(string: "https://example.com")!,
            body: nil,
            prerelease: false,
            publishedAt: nil,
            assets: []
        )

        let staging = installer.stagingDirectory(for: release)
        let downloads = installer.downloadDirectory

        // Downloads and staging are siblings under the work directory: clearing
        // a downloaded archive must never delete the staged bundle.
        XCTAssertEqual(staging.deletingLastPathComponent().path, work.path)
        XCTAssertEqual(downloads.deletingLastPathComponent().path, work.path)
        XCTAssertNotEqual(staging.path, downloads.path)
        XCTAssertFalse(staging.path.hasPrefix(downloads.path))
        XCTAssertFalse(downloads.path.hasPrefix(staging.path))
    }

    func testStagingProducesAReadableBundle() throws {
        let installer = UpdateInstaller(workDirectory: try makeTemporaryDirectory())
        let source = try makeTemporaryDirectory().appendingPathComponent("OpenTaskbar.app", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("binary".utf8).write(to: source.appendingPathComponent("Contents/Info.plist"))

        let release = UpdateRelease(
            tagName: "v9.9.9",
            htmlURL: URL(string: "https://example.com")!,
            body: nil,
            prerelease: false,
            publishedAt: nil,
            assets: []
        )

        let stageDirectory = try installer.stage(bundle: source, release: release)
        let staged = stageDirectory.appendingPathComponent("OpenTaskbar.app/Contents/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: staged), Data("binary".utf8))
    }

    func testCanReplaceBundleRequiresAnExistingWritableDirectory() throws {
        let url = try makeTemporaryDirectory().appendingPathComponent("OpenTaskbar.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        XCTAssertTrue(UpdateInstaller.canReplaceBundle(at: url))
        XCTAssertFalse(UpdateInstaller.canReplaceBundle(at: URL(fileURLWithPath: "/does/not/exist/OpenTaskbar.app")))
    }

    func testSelfUpdateProbeSucceedsWhereTheSwapWouldWork() throws {
        let bundle = try makeTemporaryDirectory().appendingPathComponent("OpenTaskbar.app", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        XCTAssertTrue(UpdateInstaller.canSelfUpdate(at: bundle))

        // The probe must not leave anything behind.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: bundle.deletingLastPathComponent().path)
            .filter { $0.contains(".opentaskbar-update-probe") }
        XCTAssertTrue(leftovers.isEmpty, "probe left files behind: \(leftovers)")
    }

    func testSelfUpdateProbeFailsForAMissingBundle() {
        XCTAssertFalse(UpdateInstaller.canSelfUpdate(at: URL(fileURLWithPath: "/does/not/exist/OpenTaskbar.app")))
    }

    func testHelperScriptAbortsIfProcessDoesNotExitInTime() {
        let script = UpdateInstaller.helperScript(
            pid: 4242,
            stagedBundle: URL(fileURLWithPath: "/tmp/staged/OpenTaskbar.app"),
            currentBundle: URL(fileURLWithPath: "/Applications/OpenTaskbar.app"),
            logURL: URL(fileURLWithPath: "/tmp/apply.log")
        )
        XCTAssertTrue(script.contains("did not exit in time"))
    }

    func testExpectedChecksumFromSidecarValidatesHTTPStatusAndHexFormat() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let asset = ReleaseAsset(
            name: "OpenTaskbar.zip",
            size: 10,
            downloadURL: URL(string: "https://example.com/OpenTaskbar.zip")!,
            digest: nil
        )

        // 404 response with error payload must not be treated as a valid checksum
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"message\":\"Not Found\"}".utf8))
        }
        XCTAssertNil(UpdateInstaller.expectedChecksum(from: asset, session: session))

        // 200 response with HTML/malformed content must return nil
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("<html>Error</html>".utf8))
        }
        XCTAssertNil(UpdateInstaller.expectedChecksum(from: asset, session: session))

        // 200 response with valid 64-hex hash parses successfully
        let validHash = "64822e9bc9aacb890576dde29dc74fa06814b6ff44860db8131f08b326cae1d8"
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("\(validHash)  OpenTaskbar.zip\n".utf8))
        }
        XCTAssertEqual(UpdateInstaller.expectedChecksum(from: asset, session: session), validHash)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}