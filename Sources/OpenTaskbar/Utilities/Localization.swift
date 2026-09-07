import Foundation

// UI copy lives here so AppKit can resolve it from the user's preferred
// application language without spreading localization calls throughout the views.
enum L10n {
    private enum Key: String {
        case crashUnexpectedExitTitle = "crash.unexpectedExit.title"
        case crashDockRestoredMessage = "crash.dockRestored.message"
        case crashLaunchButton = "crash.launch.button"

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
        case settingsShowAppNames = "settings.showAppNames"
        case settingsShowSpotlightButton = "settings.showSpotlightButton"
        case settingsHideOnFullscreen = "settings.hideOnFullscreen"
        case settingsQuitAppsWhenWindowsClose = "settings.quitAppsWhenWindowsClose"
        case settingsKeepZoomedWindowsAboveTaskbar = "settings.keepZoomedWindowsAboveTaskbar"
        case settingsShowRunningAppsWithoutWindows = "settings.showRunningAppsWithoutWindows"
        case settingsResetDefaults = "settings.resetDefaults"
    }

    private static let bundle = Bundle.main
    private static let tableName = "Localizable"

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

    static func number(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private static func localizedNumber(_ value: Int) -> String {
        number(value)
    }
}
