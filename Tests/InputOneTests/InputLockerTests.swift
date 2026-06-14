import XCTest
import Foundation
@testable import InputOneLib

final class MockInputMethodManager: InputMethodManaging {
    var sources: [InputSourceInfo] = []
    var current: InputSourceInfo?
    var selectedID: String?

    func listInputSourceInfo() -> [InputSourceInfo] { sources }
    func currentInputSourceInfo() -> InputSourceInfo? { current }
    func selectInputSource(withID id: String) -> Bool {
        selectedID = id
        return true
    }
}

final class MockAppInfoProvider: AppInfoProviding {
    var bundleID: String?
    func frontmostAppBundleID() -> String? { bundleID }
}

final class InputLockerTests: XCTestCase {
    let suiteName = "com.inputone.locker.tests"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    func makeLocker(
        current: InputSourceInfo?,
        targetID: String?,
        isLocking: Bool,
        mode: LockMode = .global,
        whitelist: [String: String] = [:],
        frontmostApp: String? = nil
    ) -> (InputLocker, MockInputMethodManager, Settings, MockAppInfoProvider) {
        let mock = MockInputMethodManager()
        mock.current = current
        let settings = Settings(suiteName: suiteName)
        settings.isLocking = isLocking
        settings.lockedInputSourceID = targetID
        settings.mode = mode
        let wm = WhitelistManager(suiteName: suiteName)
        for (bundleID, sourceID) in whitelist {
            wm.setRule(bundleID: bundleID, sourceID: sourceID)
        }
        let appInfo = MockAppInfoProvider()
        appInfo.bundleID = frontmostApp
        let locker = InputLocker(manager: mock, settings: settings, whitelistManager: wm, appInfoProvider: appInfo)
        return (locker, mock, settings, appInfo)
    }

    // MARK: - Global mode

    func test_enforceLock_does_nothing_when_not_locking() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "CN",
            isLocking: false
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }

    func test_enforceLock_does_nothing_when_targetID_is_nil() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: nil,
            isLocking: true
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }

    func test_enforceLock_does_nothing_when_already_on_target() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "US",
            isLocking: true
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }

    func test_enforceLock_switches_when_on_different_input_source() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "CN",
            isLocking: true
        )
        locker.enforceLock()
        XCTAssertEqual(mock.selectedID, "CN")
    }

    func test_enforceLock_does_nothing_when_current_is_nil() {
        let (locker, mock, _, _) = makeLocker(
            current: nil,
            targetID: "CN",
            isLocking: true
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }

    // MARK: - Whitelist mode

    func test_whitelist_mode_uses_rule_for_frontmost_app() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "CN",
            isLocking: true,
            mode: .whitelist,
            whitelist: ["com.example.app": "JP"],
            frontmostApp: "com.example.app"
        )
        locker.enforceLock()
        XCTAssertEqual(mock.selectedID, "JP")
    }

    func test_whitelist_mode_falls_back_to_default_when_no_rule() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "CN",
            isLocking: true,
            mode: .whitelist,
            whitelist: ["com.other.app": "JP"],
            frontmostApp: "com.example.app"
        )
        locker.enforceLock()
        XCTAssertEqual(mock.selectedID, "CN")
    }

    func test_whitelist_mode_falls_back_to_default_when_no_frontmost_app() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "US", name: "US"),
            targetID: "CN",
            isLocking: true,
            mode: .whitelist,
            whitelist: ["com.example.app": "JP"],
            frontmostApp: nil
        )
        locker.enforceLock()
        XCTAssertEqual(mock.selectedID, "CN")
    }

    func test_whitelist_mode_does_nothing_when_already_on_rule() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "JP", name: "JP"),
            targetID: "CN",
            isLocking: true,
            mode: .whitelist,
            whitelist: ["com.example.app": "JP"],
            frontmostApp: "com.example.app"
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }

    func test_whitelist_mode_does_nothing_when_already_on_default() {
        let (locker, mock, _, _) = makeLocker(
            current: InputSourceInfo(id: "CN", name: "CN"),
            targetID: "CN",
            isLocking: true,
            mode: .whitelist,
            whitelist: [:],
            frontmostApp: "com.example.app"
        )
        locker.enforceLock()
        XCTAssertNil(mock.selectedID)
    }
}
