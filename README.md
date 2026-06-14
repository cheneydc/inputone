# InputOne

**Lock your input method on macOS — globally or per app.**

**在 macOS 上锁定你的输入法 — 全局锁定或按应用锁定。**

[![Platform](https://img.shields.io/badge/platform-macOS_14.0+-007AFF)](https://github.com/cheneydc/inputone)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

---

## Features / 功能

- **Global Lock** — Lock all apps to one input method. No more unexpected switching when you switch between apps.
- **Whitelist Mode** — Set different input methods for different apps. VS Code in English, WeChat in Chinese — automatically.
- **Per-context Protection** — Even within the same app (e.g. browser address bar vs. page input), InputOne keeps your input method locked.
- **Zero Resource Idle** — Event-driven, no polling. 0% CPU when idle, < 3 MB memory.
- **Launch at Login** — Start automatically when you log in.
- **Privacy First** — No network access, no data collection. All settings stored locally in UserDefaults.

---

- **全局锁定** — 所有应用强制使用同一个输入法，切换应用不再被打断。
- **白名单模式** — 不同应用使用不同输入法。VS Code 用英文，微信用中文 — 自动切换。
- **同应用保护** — 即使在同一个应用内（如浏览器地址栏 vs 页面输入框），也能保持输入法锁定。
- **零资源占用** — 纯事件驱动，无轮询。空闲时 CPU 0%，内存 < 3 MB。
- **开机自启** — 登录时自动启动。
- **隐私优先** — 无网络访问，无数据收集。所有配置本地存储在 UserDefaults。

---

## Installation / 安装

### Download / 下载

Download the latest DMG from [Releases](https://github.com/cheneydc/inputone/releases), or build from source:

从 [Releases](https://github.com/cheneydc/inputone/releases) 下载最新 DMG，或从源码构建：

```bash
git clone https://github.com/cheneydc/inputone.git
cd inputone
bash scripts/build-release.sh
# Output: build/InputOne.dmg
```

### Setup / 首次使用

1. Open `InputOne.dmg` and drag `InputOne.app` to `Applications`.
2. Launch InputOne from Applications.
3. Go to **System Settings → Privacy & Security → Accessibility**, grant InputOne access.
4. Click the menu bar icon, turn on **Enable**, and select your input method.

---

1. 打开 `InputOne.dmg`，将 `InputOne.app` 拖入 `Applications`。
2. 从 Applications 启动 InputOne。
3. 前往 **系统设置 → 隐私与安全性 → 辅助功能**，授权 InputOne。
4. 点击菜单栏图标，开启 **Enable**，选择你的输入法。

---

## Usage / 使用说明

```
Menu bar icon / 菜单栏图标:

  ⌨ (blue / 蓝色)   — Locked / 已锁定
  ⌨ (gray / 灰色)   — Unlocked / 未锁定

Menu / 菜单:

  Turn On / Turn Off          — Enable or disable locking / 开启或关闭锁定
  ────────────
  输入法列表                    — Select the locked input method / 选择锁定的输入法
  ────────────
  Mode ▸ Global / Whitelist   — Switch locking mode / 切换锁定模式
  Whitelist...                — Manage per-app rules / 管理白名单规则
  ────────────
  Launch at Login             — Auto-start on login / 开机自启
  Quit                        — Exit / 退出
```

### Whitelist Mode / 白名单模式

1. Switch mode to **Whitelist**.
2. Click **Whitelist...** → **+ Add App** → select an app from the list.
3. Choose the input method for that app from the dropdown.
4. Rules take effect immediately.

---

1. 将模式切换为 **Whitelist**。
2. 点击 **Whitelist...** → **+ Add App** → 从列表中选择应用。
3. 从下拉菜单中选择该应用的输入法。
4. 规则立即生效。

---

## Build from Source / 从源码构建

```bash
# Debug / 调试
swift build
swift run

# Release / 发布
bash scripts/build-release.sh
# Output: build/InputOne.dmg

# Run tests / 运行测试
swift test
```

### Requirements / 系统要求

- macOS 14.0+ (Sonoma)
- Xcode 16+ or Command Line Tools
- Accessibility permission (required by `TISSelectInputSource`)

---

## Architecture / 架构

```
inputone/
├── Sources/
│   ├── InputOne/               # AppKit UI (thin shell)
│   │   ├── App.swift           # @main entry
│   │   ├── AppDelegate.swift   # NSMenuBar + lifecycle
│   │   ├── StatusBarIcon.swift # Menu bar icon
│   │   ├── WhitelistWindowController.swift  # Whitelist window
│   │   └── AppPickerViewController.swift    # App picker sheet
│   └── InputOneLib/            # Business logic (testable)
│       ├── InputMethodManager.swift  # Carbon TIS API wrapper
│       ├── InputLocker.swift         # Event-driven lock engine
│       ├── WhitelistManager.swift    # Whitelist persistence
│       ├── Settings.swift            # UserDefaults wrapper
│       └── AppInfoProvider.swift     # Frontmost app detection
├── Tests/InputOneTests/        # 27 XCTest tests
├── Resources/                  # Info.plist, AppIcon.icns
└── scripts/build-release.sh    # Universal binary + DMG
```

### Key Design Decisions / 关键设计

| Decision / 决策 | Choice / 选择 | Rationale / 理由 |
|----------------|---------------|------------------|
| Language / 语言 | Swift 6 | Native macOS, direct Carbon/Cocoa access |
| UI / 界面 | Pure code AppKit | No Storyboard/XIB, minimal binary size |
| Engine / 引擎 | Event-driven | `NSWorkspace` + `DistributedNotificationCenter`, no polling |
| Dependencies / 依赖 | None | Zero third-party frameworks |
| Persistence / 持久化 | UserDefaults | Local only, no network |

---

## Testing / 测试

```bash
swift test
```

27 tests covering:
- `SettingsTests` — 8 tests (defaults, round-trip, Codable)
- `InputLockerTests` — 10 tests (global lock, whitelist mode, edge cases)
- `WhitelistManagerTests` — 7 tests (CRUD, persistence, clear)

---

## License / 许可证

MIT License. See [LICENSE](LICENSE) for details.

---

## Related / 相关

- [InputLock](https://github.com/lessimore/InputLock) — Commercial alternative / 同类付费软件
- [Carbon TIS Reference](https://developer.apple.com/documentation/carbon/text_input_sources)
