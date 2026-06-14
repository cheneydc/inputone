import AppKit

public protocol AppInfoProviding: AnyObject {
    func frontmostAppBundleID() -> String?
}

public final class AppInfoProvider: AppInfoProviding {
    public init() {}
    public func frontmostAppBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
