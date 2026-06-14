import Cocoa

@main
struct App {
    static func main() {
        enforceSingleInstance()

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    static func enforceSingleInstance() {
        let pidFile = URL(fileURLWithPath: "/tmp/inputone.pid")
        let currentPID = ProcessInfo.processInfo.processIdentifier

        if let oldPIDData = try? Data(contentsOf: pidFile),
           let oldPIDStr = String(data: oldPIDData, encoding: .utf8),
           let oldPID = Int32(oldPIDStr.trimmingCharacters(in: .whitespacesAndNewlines)),
           oldPID != currentPID,
           kill(oldPID, 0) == 0 {
            kill(oldPID, SIGKILL)
        }

        try? "\(currentPID)\n".data(using: .utf8)?.write(to: pidFile, options: .atomic)
    }
}
