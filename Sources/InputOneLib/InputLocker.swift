import AppKit
import Carbon

public final class InputLocker: @unchecked Sendable {
    private let manager: InputMethodManaging
    private let settings: Settings
    private let whitelistManager: WhitelistManager
    private let appInfoProvider: AppInfoProviding
    private var appSwitchObserver: NSObjectProtocol?
    private var inputSourceObserver: NSObjectProtocol?
    private var isCorrecting = false

    public init(
        manager: InputMethodManaging,
        settings: Settings,
        whitelistManager: WhitelistManager = WhitelistManager(),
        appInfoProvider: AppInfoProviding = AppInfoProvider()
    ) {
        self.manager = manager
        self.settings = settings
        self.whitelistManager = whitelistManager
        self.appInfoProvider = appInfoProvider
    }

    public func start() {
        guard settings.isLocking else { return }

        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onAppSwitch()
        }

        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onInputSourceChanged()
        }
    }

    public func stop() {
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        appSwitchObserver = nil
        inputSourceObserver = nil
    }

    public func enforceLock() {
        guard settings.isLocking else { return }
        guard let targetID = resolveTargetID() else { return }
        guard let current = manager.currentInputSourceInfo() else { return }
        if current.id != targetID {
            isCorrecting = true
            _ = manager.selectInputSource(withID: targetID)
            isCorrecting = false
        }
    }

    private func onAppSwitch() {
        guard settings.isLocking else { return }
        guard let targetID = resolveTargetID() else { return }
        checkAndCorrect(targetID: targetID, attempt: 0)
    }

    private func onInputSourceChanged() {
        guard settings.isLocking, !isCorrecting else { return }
        guard let targetID = resolveTargetID() else { return }
        guard let current = manager.currentInputSourceInfo() else { return }
        if current.id != targetID {
            isCorrecting = true
            _ = manager.selectInputSource(withID: targetID)
            isCorrecting = false
        }
    }

    private func checkAndCorrect(targetID: String, attempt: Int) {
        guard attempt < 5 else { return }
        guard AXIsProcessTrusted() else { return }
        guard let current = manager.currentInputSourceInfo() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.checkAndCorrect(targetID: targetID, attempt: attempt + 1)
            }
            return
        }
        if current.id != targetID {
            isCorrecting = true
            _ = manager.selectInputSource(withID: targetID)
            isCorrecting = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.checkAndCorrect(targetID: targetID, attempt: attempt + 1)
            }
        }
    }

    private func resolveTargetID() -> String? {
        switch settings.mode {
        case .global:
            return settings.lockedInputSourceID
        case .whitelist:
            if let bundleID = appInfoProvider.frontmostAppBundleID(),
               let rule = whitelistManager.rule(for: bundleID) {
                return rule
            }
            return settings.lockedInputSourceID
        }
    }
}
