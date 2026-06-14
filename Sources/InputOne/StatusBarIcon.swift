import AppKit

final class StatusBarIcon {
    @MainActor static func set(on button: NSStatusBarButton?, isLocking: Bool) {
        guard let button else { return }

        var image: NSImage?

        if let url = Bundle.module.url(forResource: "lock", withExtension: "png") {
            image = NSImage(contentsOf: url)
        }

        guard let img = image else {
            button.title = "⌨"
            button.image = nil
            return
        }

        img.size = NSSize(width: 18, height: 18)
        button.image = img
    }
}
