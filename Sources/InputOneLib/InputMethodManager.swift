import AppKit
import Carbon

public struct InputSourceInfo: Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

struct InputSource {
    let info: InputSourceInfo
    let raw: TISInputSource
}

public protocol InputMethodManaging: AnyObject {
    func listInputSourceInfo() -> [InputSourceInfo]
    func currentInputSourceInfo() -> InputSourceInfo?
    func selectInputSource(withID id: String) -> Bool
}

public final class InputMethodManager: InputMethodManaging {
    public init() {}

    func listInputSources() -> [InputSource] {
        let types: [CFString] = [kTISTypeKeyboardInputMode, kTISTypeKeyboardLayout]
        var seen = Set<String>()
        var result: [InputSource] = []

        for type in types {
            let properties: [CFString: Any] = [
                kTISPropertyInputSourceType: type as Any,
            ]
            guard let list = TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
                continue
            }
            for ref in list {
                guard
                    let idPtr = TISGetInputSourceProperty(ref, kTISPropertyInputSourceID),
                    let namePtr = TISGetInputSourceProperty(ref, kTISPropertyLocalizedName)
                else { continue }
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                guard !seen.contains(id) else { continue }
                seen.insert(id)
                let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
                result.append(InputSource(info: InputSourceInfo(id: id, name: name), raw: ref))
            }
        }

        return result
    }

    public func listInputSourceInfo() -> [InputSourceInfo] {
        listInputSources().map { $0.info }
    }

    func currentInputSource() -> InputSource? {
        guard let ref = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard
            let idPtr = TISGetInputSourceProperty(ref, kTISPropertyInputSourceID),
            let namePtr = TISGetInputSourceProperty(ref, kTISPropertyLocalizedName)
        else { return nil }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        return InputSource(info: InputSourceInfo(id: id, name: name), raw: ref)
    }

    public func currentInputSourceInfo() -> InputSourceInfo? {
        currentInputSource()?.info
    }

    func selectInputSource(_ source: InputSource) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        return TISSelectInputSource(source.raw) == noErr
    }

    public func selectInputSource(withID id: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let properties: [CFString: Any] = [
            kTISPropertyInputSourceID: id,
        ]
        guard let list = TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let target = list.first
        else { return false }
        return TISSelectInputSource(target) == noErr
    }
}
