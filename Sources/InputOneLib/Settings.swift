import Foundation

public enum LockMode: String, Codable {
    case global
    case whitelist
}

public final class Settings {
    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        if let suiteName {
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            defaults = .standard
        }
    }

    public var lockedInputSourceID: String? {
        get { defaults.string(forKey: "lockedInputSourceID") }
        set { defaults.set(newValue, forKey: "lockedInputSourceID") }
    }

    public var isLocking: Bool {
        get { defaults.bool(forKey: "isLocking") }
        set { defaults.set(newValue, forKey: "isLocking") }
    }

    public var mode: LockMode {
        get {
            guard let raw = defaults.string(forKey: "mode") else { return .global }
            return LockMode(rawValue: raw) ?? .global
        }
        set { defaults.set(newValue.rawValue, forKey: "mode") }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }
}
