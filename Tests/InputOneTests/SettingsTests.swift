import XCTest
import Foundation
@testable import InputOneLib

final class SettingsTests: XCTestCase {
    let suiteName = "com.inputone.tests"

    func makeSettings() -> Settings {
        Settings(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    func test_default_isLocking_is_false() {
        let s = makeSettings()
        XCTAssertFalse(s.isLocking)
    }

    func test_default_mode_is_global() {
        let s = makeSettings()
        XCTAssertEqual(s.mode, .global)
    }

    func test_default_lockedInputSourceID_is_nil() {
        let s = makeSettings()
        XCTAssertNil(s.lockedInputSourceID)
    }

    func test_isLocking_round_trip() {
        let s = makeSettings()
        s.isLocking = true
        XCTAssertTrue(s.isLocking)
        s.isLocking = false
        XCTAssertFalse(s.isLocking)
    }

    func test_mode_round_trip() {
        let s = makeSettings()
        s.mode = .whitelist
        XCTAssertEqual(s.mode, .whitelist)
        s.mode = .global
        XCTAssertEqual(s.mode, .global)
    }

    func test_lockedInputSourceID_round_trip() {
        let s = makeSettings()
        s.lockedInputSourceID = "com.apple.keylayout.USExtended"
        XCTAssertEqual(s.lockedInputSourceID, "com.apple.keylayout.USExtended")
        s.lockedInputSourceID = nil
        XCTAssertNil(s.lockedInputSourceID)
    }

    func test_LockMode_raw_values() {
        XCTAssertEqual(LockMode.global.rawValue, "global")
        XCTAssertEqual(LockMode.whitelist.rawValue, "whitelist")
    }

    func test_LockMode_Codable() {
        let encoded = try? JSONEncoder().encode(LockMode.whitelist)
        let decoded = try? JSONDecoder().decode(LockMode.self, from: encoded ?? Data())
        XCTAssertEqual(decoded, .whitelist)
    }

    func test_default_launchAtLogin_is_false() {
        let s = makeSettings()
        XCTAssertFalse(s.launchAtLogin)
    }

    func test_launchAtLogin_round_trip() {
        let s = makeSettings()
        s.launchAtLogin = true
        XCTAssertTrue(s.launchAtLogin)
        s.launchAtLogin = false
        XCTAssertFalse(s.launchAtLogin)
    }
}
