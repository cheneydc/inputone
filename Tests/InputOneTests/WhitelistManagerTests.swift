import XCTest
import Foundation
@testable import InputOneLib

final class WhitelistManagerTests: XCTestCase {
    let suiteName = "com.inputone.whitelist.tests"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    func makeManager() -> WhitelistManager {
        WhitelistManager(suiteName: suiteName)
    }

    func test_default_empty() {
        let wm = makeManager()
        XCTAssertTrue(wm.allRules().isEmpty)
        XCTAssertNil(wm.rule(for: "com.example.app"))
    }

    func test_set_and_get_rule() {
        let wm = makeManager()
        wm.setRule(bundleID: "com.example.app", sourceID: "com.apple.keylayout.USExtended")
        XCTAssertEqual(wm.rule(for: "com.example.app"), "com.apple.keylayout.USExtended")
    }

    func test_set_rule_overwrites() {
        let wm = makeManager()
        wm.setRule(bundleID: "com.example.app", sourceID: "a")
        wm.setRule(bundleID: "com.example.app", sourceID: "b")
        XCTAssertEqual(wm.rule(for: "com.example.app"), "b")
    }

    func test_remove_rule() {
        let wm = makeManager()
        wm.setRule(bundleID: "com.example.app", sourceID: "a")
        wm.removeRule(bundleID: "com.example.app")
        XCTAssertNil(wm.rule(for: "com.example.app"))
    }

    func test_allRules() {
        let wm = makeManager()
        wm.setRule(bundleID: "com.a", sourceID: "s1")
        wm.setRule(bundleID: "com.b", sourceID: "s2")
        let rules = wm.allRules()
        XCTAssertEqual(rules["com.a"], "s1")
        XCTAssertEqual(rules["com.b"], "s2")
        XCTAssertEqual(rules.count, 2)
    }

    func test_clear() {
        let wm = makeManager()
        wm.setRule(bundleID: "com.a", sourceID: "s1")
        wm.clear()
        XCTAssertTrue(wm.allRules().isEmpty)
    }

    func test_persistence_across_instances() {
        let wm1 = makeManager()
        wm1.setRule(bundleID: "com.example.app", sourceID: "com.apple.keylayout.USExtended")

        let wm2 = makeManager()
        XCTAssertEqual(wm2.rule(for: "com.example.app"), "com.apple.keylayout.USExtended")
    }
}
