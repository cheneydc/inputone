import Foundation

public final class WhitelistManager {
    private let defaults: UserDefaults
    private var cache: [String: String]

    public init(suiteName: String? = nil) {
        if let suiteName {
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            defaults = .standard
        }
        cache = Self.load(from: defaults)
    }

    private static func load(from defaults: UserDefaults) -> [String: String] {
        guard let data = defaults.data(forKey: "whitelist"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: "whitelist")
    }

    public func setRule(bundleID: String, sourceID: String) {
        cache[bundleID] = sourceID
        save()
    }

    public func removeRule(bundleID: String) {
        cache.removeValue(forKey: bundleID)
        save()
    }

    public func rule(for bundleID: String) -> String? {
        cache[bundleID]
    }

    public func allRules() -> [String: String] {
        cache
    }

    public func clear() {
        cache = [:]
        defaults.removeObject(forKey: "whitelist")
    }
}
