import Foundation

// UI copy lives here so AppKit can resolve it from the user's preferred
// application language without spreading localization calls throughout the views.
enum L10n {
    private enum Key: String {
        case crashUnexpectedExitTitle = "crash.unexpectedExit.title"
        case crashDockRestoredMessage = "crash.dockRestored.message"
        case crashLaunchButton = "crash.launch.button"

        case permissionAccessibilityRequired = "permission.accessibilityRequired"

        case menuAbout = "menu.about"
        case menuPreferences = "menu.preferences"
        case menuRestoreDockQuit = "menu.restoreDockQuit"

        case commonCancel = "common.cancel"
        case commonClose = "common.close"
        case commonEmptyTrash = "common.emptyTrash"
        case commonForceQuit = "common.forceQuit"
        case commonOK = "common.ok"
        case commonOpen = "common.open"
        case commonOpenSystemSettings = "common.openSystemSettings"
        case commonQuit = "common.quit"
        case commonQuitAll = "common.quitAll"

        case alertQuitAllAppsTitle = "alert.quitAllApps.title"
        case alertAppsQuestion = "alert.apps.question"
        case alertForceQuitTitle = "alert.forceQuit.title"
        case alertUnsavedChangesMessage = "alert.unsavedChanges.message"
        case alertQuitAppsToRightTitle = "alert.quitAppsToRight.title"
        case alertQuitAppsToRightQuestion = "alert.quitAppsToRight.question"
        case alertEmptyTrashTitle = "alert.emptyTrash.title"
        case alertEmptyTrashMessage = "alert.emptyTrash.message"
        case alertCouldNotEmptyTrashTitle = "alert.couldNotEmptyTrash.title"
        case alertFinderErrorMessage = "alert.finderError.message"
        case alertFinderPermissionTitle = "alert.finderPermission.title"
        case alertFinderPermissionMessage = "alert.finderPermission.message"

        case windowFallback = "window.fallback"
        case windowFallbackGeneric = "window.fallbackGeneric"
        case unknownApp = "app.unknown"
        case windowCloseAll = "window.closeAll"
        case windowCloseAllWindows = "window.closeAllWindows"

        case finderNewWindow = "finder.newWindow"
        case finderHome = "finder.home"
        case finderDesktop = "finder.desktop"
        case finderDownloads = "finder.downloads"
        case finderDocuments = "finder.documents"
        case finderApplications = "finder.applications"
        case finderEmptyTrash = "finder.emptyTrash"

        case menuPin = "menu.pin"
        case menuUnpin = "menu.unpin"
        case menuQuitApp = "menu.quitApp"
        case menuQuitAppsToRight = "menu.quitAppsToRight"
        case menuForceQuitApp = "menu.forceQuitApp"

        case tooltipSearchSpotlight = "tooltip.searchSpotlight"
        case accessibilitySearch = "accessibility.search"
        case accessibilityMoreApps = "accessibility.moreApps"
        case overflowMore = "overflow.more"

        case taskbarShowDesktop = "taskbar.showDesktop"
        case taskbarActivityMonitor = "taskbar.activityMonitor"
        case taskbarOpenTrash = "taskbar.openTrash"
        case taskbarQuitClosedApps = "taskbar.quitClosedApps"
        case taskbarQuitAllClosedApps = "taskbar.quitAllClosedApps"
        case taskbarQuitAllApps = "taskbar.quitAllApps"
        case taskbarDontQuitTheseApps = "taskbar.dontQuitTheseApps"
        case taskbarNoApps = "taskbar.noApps"

        case settingsWindowTitle = "settings.windowTitle"
        case settingsGeneral = "settings.general"
        case settingsAppearance = "settings.appearance"
        case settingsDisplayOptions = "settings.displayOptions"
        case settingsStyle = "settings.style"
        case settingsTaskbar = "settings.taskbar"
        case settingsDock = "settings.dock"
        case settingsBarAlignment = "settings.barAlignment"
        case settingsLeft = "settings.left"
        case settingsCenter = "settings.center"
        case settingsRight = "settings.right"
        case settingsShowOnAllScreens = "settings.showOnAllScreens"
        case settingsBackgroundTheme = "settings.backgroundTheme"
        case settingsSystem = "settings.system"
        case settingsDark = "settings.dark"
        case settingsLight = "settings.light"
        case settingsCustom = "settings.custom"
        case settingsCustomColor = "settings.customColor"
        case settingsAppIconSize = "settings.appIconSize"
        case settingsBarSpacing = "settings.barSpacing"
        case settingsIconSizeValue = "settings.iconSizeValue"
        case settingsSpacingValue = "settings.spacingValue"
        case settingsLaunchAtLogin = "settings.launchAtLogin"
        case settingsEnableAnimations = "settings.enableAnimations"
        case settingsShowWindowThumbnails = "settings.showWindowThumbnails"
        case settingsMinimizeOnActiveAppClick = "settings.minimizeOnActiveAppClick"
        case settingsShowAppNames = "settings.showAppNames"
        case settingsShowSpotlightButton = "settings.showSpotlightButton"
        case settingsHideOnFullscreen = "settings.hideOnFullscreen"
        case settingsQuitAppsWhenWindowsClose = "settings.quitAppsWhenWindowsClose"
        case settingsKeepZoomedWindowsAboveTaskbar = "settings.keepZoomedWindowsAboveTaskbar"
        case settingsShowRunningAppsWithoutWindows = "settings.showRunningAppsWithoutWindows"
        case settingsResetDefaults = "settings.resetDefaults"
        case settingsLanguage = "settings.language"
        case settingsLanguageSystem = "settings.languageSystem"

        case updateSection = "update.section"
        case updateAutomaticChecks = "update.automaticChecks"
        case updateInstallAutomatically = "update.installAutomatically"
        case updateIncludePrereleases = "update.includePrereleases"
        case updateCheckNow = "update.checkNow"
        case updateInstallNow = "update.installNow"
        case updateStatusIdle = "update.status.idle"
        case updateStatusChecking = "update.status.checking"
        case updateStatusUpToDate = "update.status.upToDate"
        case updateStatusAvailable = "update.status.available"
        case updateStatusDownloading = "update.status.downloading"
        case updateStatusInstalling = "update.status.installing"
        case updateStatusFailed = "update.status.failed"
        case updateLastChecked = "update.lastChecked"
        case updateLastCheckedNever = "update.lastCheckedNever"
        case updateMenuCheck = "update.menu.check"
        case updateMenuCheckWhileChecking = "update.menu.checkWhileChecking"
        case updateMenuInstall = "update.menu.install"
        case updateAvailableTitle = "update.available.title"
        case updateInstallAndRelaunch = "update.installAndRelaunch"
        case updateShowReleaseNotes = "update.showReleaseNotes"
        case updateSkipVersion = "update.skipVersion"
        case updateRemindLater = "update.remindLater"
        case updateFailedTitle = "update.failed.title"
        case updateFailedMessage = "update.failed.message"
        case updateErrorOffline = "update.error.offline"
        case updateErrorNotModified = "update.error.notModified"
        case updateErrorRateLimited = "update.error.rateLimited"
        case updateErrorHTTPStatus = "update.error.httpStatus"
        case updateErrorInvalidResponse = "update.error.invalidResponse"
        case updateErrorNoAsset = "update.error.noAsset"
        case updateErrorChecksum = "update.error.checksum"
        case updateErrorDownloadFailed = "update.error.downloadFailed"
        case updateErrorUnpackFailed = "update.error.unpackFailed"
        case updateErrorValidationFailed = "update.error.validationFailed"
        case updateErrorNotWritable = "update.error.notWritable"
        case updateErrorSelfUpdateBlocked = "update.error.selfUpdateBlocked"
        case updateErrorInstallFailed = "update.error.installFailed"
    }

    private static var languageOverride: String?
    private static let tableName = "Localizable"

    private static var bundle: Bundle {
        if let code = languageOverride, !code.isEmpty,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return languageBundle
        }
        return Bundle.main
    }

    static func applyLanguage(_ code: String) {
        languageOverride = code
    }

    private static func text(_ key: Key, fallback: String) -> String {
        bundle.localizedString(forKey: key.rawValue, value: fallback, table: tableName)
    }

    private static func format(_ key: Key, fallback: String, _ argument: CVarArg) -> String {
        String.localizedStringWithFormat(text(key, fallback: fallback), argument)
    }

    private static func format(_ key: Key, fallback: String, _ first: CVarArg, _ second: CVarArg) -> String {
        String.localizedStringWithFormat(text(key, fallback: fallback), first, second)
    }

    static var unexpectedExitTitle: String {
        text(.crashUnexpectedExitTitle, fallback: "OpenTaskbar exited unexpectedly")
    }

    static var dockRestoredMessage: String {
        text(.crashDockRestoredMessage, fallback: "Your Dock has been restored. Would you like to launch OpenTaskbar again?")
    }

    static var launchOpenTaskbar: String {
        text(.crashLaunchButton, fallback: "Launch OpenTaskbar")
    }

    static var accessibilityPermissionRequired: String {
        text(.permissionAccessibilityRequired, fallback: "Accessibility Permission Required")
    }

    static var aboutOpenTaskbar: String {
        text(.menuAbout, fallback: "About OpenTaskbar")
    }

    static var preferences: String {
        text(.menuPreferences, fallback: "Preferences…")
    }

    static var restoreDockAndQuit: String {
        text(.menuRestoreDockQuit, fallback: "Restore Dock & Quit")
    }

    static var cancel: String {
        text(.commonCancel, fallback: "Cancel")
    }

    static var close: String {
        text(.commonClose, fallback: "Close")
    }

    static var emptyTrash: String {
        text(.commonEmptyTrash, fallback: "Empty Trash")
    }

    static var forceQuit: String {
        text(.commonForceQuit, fallback: "Force Quit")
    }

    static var ok: String {
        text(.commonOK, fallback: "OK")
    }

    static var open: String {
        text(.commonOpen, fallback: "Open")
    }

    static var openSystemSettings: String {
        text(.commonOpenSystemSettings, fallback: "Open System Settings")
    }

    static var quit: String {
        text(.commonQuit, fallback: "Quit")
    }

    static var quitAll: String {
        text(.commonQuitAll, fallback: "Quit All")
    }

    static var quitAllAppsTitle: String {
        text(.alertQuitAllAppsTitle, fallback: "Quit All Apps")
    }

    static func appsQuestion(count: Int, names: String) -> String {
        format(
            .alertAppsQuestion,
            fallback: "Are you sure you want to quit the following %d apps?\n\n%@",
            count,
            names
        )
    }

    static func forceQuitTitle(appName: String) -> String {
        format(.alertForceQuitTitle, fallback: "Force Quit %@?", appName)
    }

    static var unsavedChangesMessage: String {
        text(.alertUnsavedChangesMessage, fallback: "You will lose any unsaved changes. This action cannot be undone.")
    }

    static var quitAppsToRightTitle: String {
        text(.alertQuitAppsToRightTitle, fallback: "Quit Apps to the Right")
    }

    static func quitAppsToRightQuestion(count: Int, names: String) -> String {
        format(
            .alertQuitAppsToRightQuestion,
            fallback: "Do you want to quit the following %d apps?\n\n%@",
            count,
            names
        )
    }

    static var emptyTrashTitle: String {
        text(.alertEmptyTrashTitle, fallback: "Empty the Trash?")
    }

    static var emptyTrashMessage: String {
        text(.alertEmptyTrashMessage, fallback: "Are you sure you want to permanently delete all items in the Trash?")
    }

    static var couldNotEmptyTrashTitle: String {
        text(.alertCouldNotEmptyTrashTitle, fallback: "Couldn't Empty the Trash")
    }

    static func finderErrorMessage(code: Int) -> String {
        format(
            .alertFinderErrorMessage,
            fallback: "Finder reported an error (%d). See /tmp/opentaskbar.log for details.",
            code
        )
    }

    static var finderPermissionTitle: String {
        text(.alertFinderPermissionTitle, fallback: "Finder Permission Needed")
    }

    static var finderPermissionMessage: String {
        text(
            .alertFinderPermissionMessage,
            fallback: "macOS blocked OpenTaskbar from controlling Finder. To fix this, allow it in System Settings > Privacy & Security > Automation."
        )
    }

    static func window(number: Int) -> String {
        format(.windowFallback, fallback: "Window %d", number)
    }

    static var genericWindow: String {
        text(.windowFallbackGeneric, fallback: "Window")
    }

    static var unknownApp: String {
        text(.unknownApp, fallback: "Unknown")
    }

    static var closeAllWindows: String {
        text(.windowCloseAllWindows, fallback: "Close All Windows")
    }

    static var closeAll: String {
        text(.windowCloseAll, fallback: "Close All")
    }

    static var newFinderWindow: String {
        text(.finderNewWindow, fallback: "New Finder Window")
    }

    static var home: String {
        text(.finderHome, fallback: "Home")
    }

    static var desktop: String {
        text(.finderDesktop, fallback: "Desktop")
    }

    static var downloads: String {
        text(.finderDownloads, fallback: "Downloads")
    }

    static var documents: String {
        text(.finderDocuments, fallback: "Documents")
    }

    static var applications: String {
        text(.finderApplications, fallback: "Applications")
    }

    static var emptyTrashMenu: String {
        text(.finderEmptyTrash, fallback: "Empty Trash…")
    }

    static var pin: String {
        text(.menuPin, fallback: "Pin to taskbar")
    }

    static var unpin: String {
        text(.menuUnpin, fallback: "Unpin from taskbar")
    }

    static func quitApp(appName: String) -> String {
        format(.menuQuitApp, fallback: "Quit %@", appName)
    }

    static var quitAppsToRight: String {
        text(.menuQuitAppsToRight, fallback: "Quit Apps to the Right")
    }

    static func forceQuitApp(appName: String) -> String {
        format(.menuForceQuitApp, fallback: "Force Quit %@", appName)
    }

    static var searchSpotlightTooltip: String {
        text(.tooltipSearchSpotlight, fallback: "Search (Spotlight)")
    }

    static var searchAccessibility: String {
        text(.accessibilitySearch, fallback: "Search")
    }

    static var moreAppsAccessibility: String {
        text(.accessibilityMoreApps, fallback: "More apps")
    }

    static func moreOverflow(count: Int) -> String {
        format(.overflowMore, fallback: "+%d more", count)
    }

    static var showDesktop: String {
        text(.taskbarShowDesktop, fallback: "Show Desktop")
    }

    static var activityMonitor: String {
        text(.taskbarActivityMonitor, fallback: "Activity Monitor")
    }

    static var openTrash: String {
        text(.taskbarOpenTrash, fallback: "Open Trash")
    }

    static func quitClosedApps(count: Int) -> String {
        format(.taskbarQuitClosedApps, fallback: "Quit %d Closed Apps", count)
    }

    static var quitAllClosedApps: String {
        text(.taskbarQuitAllClosedApps, fallback: "Quit All Closed Apps")
    }

    static var quitAllApps: String {
        text(.taskbarQuitAllApps, fallback: "Quit All Apps")
    }

    static var dontQuitTheseApps: String {
        text(.taskbarDontQuitTheseApps, fallback: "Don't Quit These Apps")
    }

    static var noApps: String {
        text(.taskbarNoApps, fallback: "No apps")
    }

    static var settingsWindowTitle: String {
        text(.settingsWindowTitle, fallback: "OpenTaskbar Preferences")
    }

    static var general: String {
        text(.settingsGeneral, fallback: "General")
    }

    static var appearance: String {
        text(.settingsAppearance, fallback: "Appearance")
    }

    static var displayOptions: String {
        text(.settingsDisplayOptions, fallback: "Display Options")
    }

    static var style: String {
        text(.settingsStyle, fallback: "Style")
    }

    static var taskbar: String {
        text(.settingsTaskbar, fallback: "Taskbar")
    }

    static var dock: String {
        text(.settingsDock, fallback: "Dock")
    }

    static var barAlignment: String {
        text(.settingsBarAlignment, fallback: "Bar Alignment")
    }

    static var left: String {
        text(.settingsLeft, fallback: "Left")
    }

    static var center: String {
        text(.settingsCenter, fallback: "Center")
    }

    static var right: String {
        text(.settingsRight, fallback: "Right")
    }

    static var showOnAllScreens: String {
        text(.settingsShowOnAllScreens, fallback: "Show on All Screens")
    }

    static var backgroundTheme: String {
        text(.settingsBackgroundTheme, fallback: "Background Theme")
    }

    static var system: String {
        text(.settingsSystem, fallback: "System")
    }

    static var dark: String {
        text(.settingsDark, fallback: "Dark")
    }

    static var light: String {
        text(.settingsLight, fallback: "Light")
    }

    static var custom: String {
        text(.settingsCustom, fallback: "Custom")
    }

    static var customColor: String {
        text(.settingsCustomColor, fallback: "Custom Color")
    }

    static var appIconSize: String {
        text(.settingsAppIconSize, fallback: "App Icon Size")
    }

    static var barSpacing: String {
        text(.settingsBarSpacing, fallback: "Bar Spacing")
    }

    static func iconSizeValue(_ value: Int) -> String {
        format(.settingsIconSizeValue, fallback: "%@ pt", localizedNumber(value))
    }

    static func spacingValue(_ value: Int) -> String {
        format(.settingsSpacingValue, fallback: "%@ px", localizedNumber(value))
    }

    static var launchAtLogin: String {
        text(.settingsLaunchAtLogin, fallback: "Launch at Login")
    }

    static var enableAnimations: String {
        text(.settingsEnableAnimations, fallback: "Enable Animations")
    }

    static var showWindowThumbnails: String {
        text(.settingsShowWindowThumbnails, fallback: "Show Window Thumbnails on Hover")
    }

    static var minimizeOnActiveAppClick: String {
        text(.settingsMinimizeOnActiveAppClick, fallback: "Minimize or Cycle Windows on Active App Click")
    }

    static var showAppNames: String {
        text(.settingsShowAppNames, fallback: "Show App Names")
    }

    static var showSpotlightButton: String {
        text(.settingsShowSpotlightButton, fallback: "Show Spotlight Button")
    }

    static var hideOnFullscreen: String {
        text(.settingsHideOnFullscreen, fallback: "Hide Taskbar on Fullscreen")
    }

    static var quitAppsWhenWindowsClose: String {
        text(.settingsQuitAppsWhenWindowsClose, fallback: "Quit Apps When All Windows Close")
    }

    static var keepZoomedWindowsAboveTaskbar: String {
        text(.settingsKeepZoomedWindowsAboveTaskbar, fallback: "Keep Zoomed Windows Above Taskbar")
    }

    static var showRunningAppsWithoutWindows: String {
        text(.settingsShowRunningAppsWithoutWindows, fallback: "Show Running Apps With No Windows")
    }

    static var resetDefaults: String {
        text(.settingsResetDefaults, fallback: "Reset to Defaults")
    }

    static var settingsLanguage: String {
        text(.settingsLanguage, fallback: "Language")
    }

    static var systemDefaultLanguage: String {
        text(.settingsLanguageSystem, fallback: "System Default")
    }

    struct LanguageOption {
        let code: String
        let displayName: String
    }

    static let supportedLanguageCodes = [
        "en", "de", "fr", "es", "it", "ja", "ko", "zh-Hans", "pt-BR", "ar", "hi", "ur"
    ]

    static var languageOptions: [LanguageOption] {
        var options = [LanguageOption(code: "", displayName: systemDefaultLanguage)]
        for code in supportedLanguageCodes {
            let name = Locale(identifier: code).localizedString(forIdentifier: code) ?? code
            options.append(LanguageOption(code: code, displayName: name))
        }
        return options
    }

    static func number(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func localizedNumber(_ value: Int) -> String {
        number(value)
    }

    static var updateSection: String {
        text(.updateSection, fallback: "Updates")
    }

    static var updateAutomaticChecks: String {
        text(.updateAutomaticChecks, fallback: "Automatically Check for Updates")
    }

    static var updateInstallAutomatically: String {
        text(.updateInstallAutomatically, fallback: "Download and Install Updates Automatically")
    }

    static var updateIncludePrereleases: String {
        text(.updateIncludePrereleases, fallback: "Include Pre-release Versions")
    }

    static var updateCheckNow: String {
        text(.updateCheckNow, fallback: "Check for Updates…")
    }

    static var updateInstallNow: String {
        text(.updateInstallNow, fallback: "Install Update and Relaunch")
    }

    static var updateStatusIdle: String {
        text(.updateStatusIdle, fallback: "Checked once a day.")
    }

    static var updateStatusChecking: String {
        text(.updateStatusChecking, fallback: "Checking for updates…")
    }

    static func updateStatusUpToDate(_ version: String) -> String {
        format(.updateStatusUpToDate, fallback: "OpenTaskbar %@ is up to date.", version)
    }

    static func updateStatusAvailable(_ version: String) -> String {
        format(.updateStatusAvailable, fallback: "Version %@ is available.", version)
    }

    static func updateStatusDownloading(_ percent: Int) -> String {
        format(.updateStatusDownloading, fallback: "Downloading… %d%%", percent)
    }

    static var updateStatusInstalling: String {
        text(.updateStatusInstalling, fallback: "Installing…")
    }

    static func updateStatusFailed(_ reason: String) -> String {
        format(.updateStatusFailed, fallback: "Update failed: %@", reason)
    }

    static func updateLastChecked(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return format(.updateLastChecked, fallback: "Last checked: %@", formatter.string(from: date))
    }

    static var updateLastCheckedNever: String {
        text(.updateLastCheckedNever, fallback: "Never checked for updates.")
    }

    static var updateMenuCheck: String {
        text(.updateMenuCheck, fallback: "Check for Updates…")
    }

    static var updateMenuCheckWhileChecking: String {
        text(.updateMenuCheckWhileChecking, fallback: "Checking for Updates…")
    }

    static func updateMenuInstall(_ version: String) -> String {
        format(.updateMenuInstall, fallback: "Update to %@ and Relaunch…", version)
    }

    static func updateAvailableTitle(_ version: String) -> String {
        format(.updateAvailableTitle, fallback: "An update to %@ is available.", version)
    }

    static var updateInstallAndRelaunch: String {
        text(.updateInstallAndRelaunch, fallback: "Install and Relaunch")
    }

    static var updateShowReleaseNotes: String {
        text(.updateShowReleaseNotes, fallback: "Release Notes")
    }

    static var updateSkipVersion: String {
        text(.updateSkipVersion, fallback: "Skip This Version")
    }

    static var updateRemindLater: String {
        text(.updateRemindLater, fallback: "Remind Me Later")
    }

    static var updateFailedTitle: String {
        text(.updateFailedTitle, fallback: "Could Not Check for Updates")
    }

    static var updateFailedMessage: String {
        text(.updateFailedMessage, fallback: "OpenTaskbar could not reach the update server.")
    }

    static var updateErrorOffline: String {
        text(.updateErrorOffline, fallback: "Could not reach the update server")
    }

    static var updateErrorNotModified: String {
        text(.updateErrorNotModified, fallback: "No newer release is available.")
    }

    static var updateErrorRateLimited: String {
        text(.updateErrorRateLimited, fallback: "The update server is rate limiting requests. Try again later.")
    }

    static func updateErrorHTTPStatus(_ code: Int) -> String {
        format(.updateErrorHTTPStatus, fallback: "The update server returned HTTP %d.", code)
    }

    static var updateErrorInvalidResponse: String {
        text(.updateErrorInvalidResponse, fallback: "The update server returned an unexpected response.")
    }

    static var updateErrorNoAsset: String {
        text(.updateErrorNoAsset, fallback: "This release does not contain a macOS app download.")
    }

    static var updateErrorChecksum: String {
        text(.updateErrorChecksum, fallback: "The download did not match its published checksum and was discarded.")
    }

    static var updateErrorDownloadFailed: String {
        text(.updateErrorDownloadFailed, fallback: "The download failed")
    }

    static var updateErrorUnpackFailed: String {
        text(.updateErrorUnpackFailed, fallback: "The update archive could not be unpacked")
    }

    static var updateErrorValidationFailed: String {
        text(.updateErrorValidationFailed, fallback: "The downloaded app failed verification")
    }

    static func updateErrorNotWritable(_ path: String) -> String {
        format(
            .updateErrorNotWritable,
            fallback: "OpenTaskbar is installed at a location that cannot be replaced (%@). Re-run Scripts/install.sh or reinstall to update.",
            path
        )
    }

    static func updateErrorSelfUpdateBlocked(_ path: String) -> String {
        format(
            .updateErrorSelfUpdateBlocked,
            fallback: "macOS does not allow OpenTaskbar to replace itself at %@. macOS protects folders like Documents, Desktop and Downloads from being modified by apps. Reinstall OpenTaskbar into /Applications to enable in-app updates.",
            path
        )
    }

    static var updateErrorInstallFailed: String {
        text(.updateErrorInstallFailed, fallback: "The update could not be installed")
    }
}
