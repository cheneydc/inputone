# InputOne — Agent Guide

## Project

macOS menu bar app that locks input methods globally or per-app. SwiftPM, no external dependencies.

## Build & Run

```sh
swift build                      # debug
swift build -c release           # release (strips symbols)
swift run                        # run from terminal (will show in menu bar)
bash scripts/build-release.sh    # universal binary + .app bundle
```

## Architecture

- `Sources/InputOneLib/` — library target (testable), contains all business logic
- `Sources/InputOne/` — executable target (thin shell), contains AppKit UI only
- `Tests/InputOneTests/` — 27 XCTest tests
- `@main` in `App.swift` → `AppDelegate.swift` sets up NSMenuBar
- `InputMethodManager.swift` wraps Carbon TIS C API
- `InputLocker.swift` listens to `NSWorkspace.didActivateApplicationNotification` + `DistributedNotificationCenter` for input source changes (event-driven, no polling)
- `WhitelistManager.swift` + `Settings.swift` for persistence via UserDefaults
- No Storyboard, XIB, or third-party frameworks

## Key Constraints

- **Accessibility permission required** — `TISSelectInputSource` needs `AXIsProcessTrusted`. App must prompt and guide user to System Settings → Privacy & Security → Accessibility
- **LSUIElement = true** in Info.plist — app runs as menu bar only (no Dock icon)
- **SMAppService** for login item (macOS 13+), not legacy LaunchAgent plists
- **Universal binary** — build with `bash scripts/build-release.sh`
- **Deployment target**: macOS 14.0

## Testing

```sh
swift test
```

## Release

```sh
bash scripts/build-release.sh
# Bundle at build/InputOne.app
```

## Requirements Doc

See `REQUIREMENTS.md` for full spec.
