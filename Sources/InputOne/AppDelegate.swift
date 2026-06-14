import Cocoa
import InputOneLib

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let manager = InputMethodManager()
    private let settings = Settings()
    private let whitelistManager = WhitelistManager()
    private lazy var locker = InputLocker(
        manager: manager,
        settings: settings,
        whitelistManager: whitelistManager
    )
    private lazy var whitelistWindowController = WhitelistWindowController(
        whitelistManager: whitelistManager,
        manager: manager,
        locker: locker,
        settings: settings
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        StatusBarIcon.set(on: statusItem.button, isLocking: settings.isLocking)
        rebuildMenu()

        if settings.isLocking {
            checkAccessibilityPermission()
            locker.start()
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.minimumWidth = 220

        let enableItem = NSMenuItem(
            title: settings.isLocking ? "Turn Off" : "Turn On",
            action: #selector(toggleLock),
            keyEquivalent: ""
        )
        enableItem.state = settings.isLocking ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(.separator())

        let current = manager.currentInputSourceInfo()
        let sources = manager.listInputSourceInfo()

        for source in sources {
            let item = NSMenuItem(
                title: source.name,
                action: #selector(selectInputSource(_:)),
                keyEquivalent: ""
            )
            item.representedObject = source
            item.state = source.id == current?.id ? .on : .off
            item.isEnabled = settings.isLocking
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        let globalItem = NSMenuItem(title: "Global", action: #selector(setMode(_:)), keyEquivalent: "")
        globalItem.representedObject = LockMode.global
        globalItem.state = settings.mode == .global ? .on : .off
        modeMenu.addItem(globalItem)
        let whitelistModeItem = NSMenuItem(title: "Whitelist", action: #selector(setMode(_:)), keyEquivalent: "")
        whitelistModeItem.representedObject = LockMode.whitelist
        whitelistModeItem.state = settings.mode == .whitelist ? .on : .off
        modeMenu.addItem(whitelistModeItem)
        modeItem.submenu = modeMenu
        modeItem.isEnabled = settings.isLocking
        menu.addItem(modeItem)

        let whitelistMenuItem = NSMenuItem(title: "Whitelist...", action: #selector(showWhitelistWindow), keyEquivalent: "")
        whitelistMenuItem.isEnabled = settings.isLocking && settings.mode == .whitelist
        menu.addItem(whitelistMenuItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = settings.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc private func toggleLock() {
        guard AXIsProcessTrusted() else { return }
        settings.isLocking.toggle()
        if settings.isLocking {
            if let current = manager.currentInputSourceInfo() {
                settings.lockedInputSourceID = current.id
            }
            locker.start()
            locker.enforceLock()
        } else {
            locker.stop()
        }
        StatusBarIcon.set(on: statusItem.button, isLocking: settings.isLocking)
        rebuildMenu()
    }

    @objc private func selectInputSource(_ sender: NSMenuItem) {
        guard let source = sender.representedObject as? InputSourceInfo else { return }
        settings.lockedInputSourceID = source.id
        _ = manager.selectInputSource(withID: source.id)
        rebuildMenu()
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? LockMode else { return }
        settings.mode = mode
        rebuildMenu()
        if settings.isLocking {
            locker.enforceLock()
        }
    }

    @objc private func showWhitelistWindow() {
        whitelistWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLogin() {
        guard AXIsProcessTrusted() else { return }
        settings.launchAtLogin.toggle()
        if settings.launchAtLogin {
            registerLaunchAgent()
        } else {
            unregisterLaunchAgent()
        }
        rebuildMenu()
    }

    private func registerLaunchAgent() {
        let agentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let plistPath = agentDir.appendingPathComponent("com.inputone.app.plist")
        let executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first!

        let plist: [String: Any] = [
            "Label": "com.inputone.app",
            "Program": executablePath,
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
            "StandardOutPath": "/tmp/inputone-launchd.log",
            "StandardErrorPath": "/tmp/inputone-launchd.log",
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              (try? data.write(to: plistPath)) != nil
        else {
            settings.launchAtLogin = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["bootstrap", "gui/\(getuid())", plistPath.path]
        try? proc.run()
        proc.waitUntilExit()
    }

    private func unregisterLaunchAgent() {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.inputone.app.plist")
        try? FileManager.default.removeItem(at: plistPath)
    }

    private func checkAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "InputOne needs Accessibility access to control input methods. Please grant it in System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
