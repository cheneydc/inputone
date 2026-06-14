# InputOne — macOS 输入法全局锁定工具 · 需求文档

## 1. 项目概述

### 1.1 背景

macOS 在切换应用时会自动将输入法切换到该应用上次使用的状态（per-app input source memory）。对于中英文混合工作的用户，这导致在代码编辑器（需英文）和聊天/文档工具（需中文）之间切换时频繁被打断，需要手动按切换键恢复。

### 1.2 目标

开发一款完全免费、高性能、极小资源占用的 macOS 菜单栏应用，提供输入法全局锁定和按 app 白名单锁定功能，替代同类付费软件 InputLock。

### 1.3 设计原则

- **最小资源** — 纯事件驱动，无轮询，无外部依赖
- **最小体积** — 纯 Swift 代码，无 Storyboard/XIB，无第三方框架
- **最小权限** — 仅请求 Accessibility 权限（TIS API 必需）
- **用户掌控** — 所有数据本地存储，无网络请求

---

## 2. 功能需求

### 2.1 核心功能

| ID | 功能 | 描述 | 优先级 |
|----|------|------|--------|
| F-01 | 全局锁定 | 用户选择一个输入法后，所有应用强制使用该输入法 | P0 |
| F-02 | 菜单栏切换 | 从菜单栏下拉菜单中快速切换锁定的输入法 | P0 |
| F-03 | 输入法列表 | 菜单栏下拉菜单中列出系统所有可用输入法 | P0 |
| F-04 | 状态指示 | 菜单栏图标显示当前锁定状态（锁定/解锁） | P0 |
| F-05 | 白名单模式 | 指定某些 app 使用特定输入法，其余不受影响 | P1 |
| F-06 | 模式切换 | 在全局锁定和白名单模式之间切换 | P1 |
| F-07 | 开机自启 | 登录时自动启动（SMAppService） | P1 |
| F-08 | 解锁模式 | 临时关闭锁定，恢复系统默认行为 | P1 |

### 2.2 交互流程

```
启动 → 检查 Accessibility 权限
  ├─ 无权限 → 弹出引导对话框 → 跳转系统偏好设置 → 等待授权
  └─ 有权限 → 读取上次锁定的输入法 → 开始监听

运行时：
  app 切换事件 → 检查当前输入法 → 与锁定输入法对比
    ├─ 不一致 → 调用 TISSelectInputSource 切回
    └─ 一致 → 不做任何操作

菜单栏交互：
  点击图标 → 下拉菜单：
    ├─ 输入法列表（勾选当前锁定项）
    ├─ ────────────
    ├─ 模式切换（全局/白名单）
    ├─ 白名单管理
    ├─ ────────────
    └─ 退出
```

### 2.3 白名单规则模型

```json
{
  "mode": "global",
  "lockedInputSourceID": "com.apple.inputmethod.SCIM.ITABC",
  "whitelist": {
    "com.microsoft.VSCode": "com.apple.keylayout.USExtended",
    "com.googlecode.iterm2": "com.apple.keylayout.USExtended",
    "com.tencent.xinWeChat": "com.apple.inputmethod.SCIM.ITABC"
  }
}
```

- **全局模式**: 所有 app 使用 `lockedInputSourceID`
- **白名单模式**: 白名单中的 app 使用各自指定的输入法；未在白名单中的 app 使用 `lockedInputSourceID`

---

## 3. 非功能需求

### 3.1 性能指标

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| 内存占用 | < 3 MB RSS | `ps -o rss` |
| CPU 占用 | 0%（空闲时） | Activity Monitor |
| 二进制体积 | < 1 MB | `ls -lh` |
| 启动时间 | < 100 ms | 首次菜单栏显示时间 |

### 3.2 兼容性

- macOS 14.0+（Sonoma 及以上）
- 架构: arm64 + x86_64 (Universal Binary)
- 输入法类型: 键盘输入法 + 输入模式（如 SCIM 的中/英模式）

### 3.3 安全

- 无网络访问
- 无数据外传
- 仅请求 Accessibility 权限
- 所有配置存储在 `UserDefaults`（应用沙盒内）

---

## 4. 技术方案

### 4.1 技术栈

| 层面 | 选择 | 理由 |
|------|------|------|
| 语言 | Swift 6 | 原生 macOS 开发，直接调用 Carbon/Cocoa |
| UI | 纯代码 AppKit (NSMenuBar) | 无 Storyboard/XIB，最小体积 |
| API | Carbon TIS + NSWorkspace | 输入法控制 + app 切换事件 |
| 构建 | SwiftPM | 无外部依赖 |
| 自启 | SMAppService (macOS 13+) | 系统原生 LaunchAgent 注册 |

### 4.2 核心 API

```
TISCopyCurrentKeyboardInputSource()      → 当前输入法
TISCopyInputSourceListForLanguage()       → 所有可用输入法
TISGetInputSourceProperty(source, key)    → 获取输入法属性
TISSelectInputSource(targetSource)        → 切换到目标输入法
NSWorkspace.didActivateApplicationNotification  → app 激活事件
```

### 4.3 项目结构

```
inputone/
├── Package.swift
├── Sources/
│   └── InputOne/
│       ├── App.swift                    # @main entry point
│       ├── AppDelegate.swift            # NSApplication + menu bar
│       ├── InputMethodManager.swift     # TIS API 封装
│       ├── InputLocker.swift            # 核心锁定逻辑
│       ├── WhitelistManager.swift       # 白名单管理
│       └── Settings.swift               # UserDefaults 封装
├── Resources/
│   └── AppIcon.icns
└── README.md
```

### 4.4 模块职责

| 模块 | 职责 |
|------|------|
| `App.swift` | `@main` 入口，创建 NSApplication + AppDelegate |
| `AppDelegate.swift` | 应用生命周期管理，构建菜单栏 UI |
| `InputMethodManager.swift` | 封装 TIS API：列出输入法、获取当前、切换输入法 |
| `InputLocker.swift` | 监听 app 切换事件，执行锁定逻辑 |
| `WhitelistManager.swift` | 白名单规则的增删改查 + 持久化 |
| `Settings.swift` | UserDefaults 读写，类型安全封装 |

---

## 5. 里程碑

| 阶段 | 内容 | 预计工时 |
|------|------|----------|
| M1 | 项目初始化 + 菜单栏骨架 + 输入法列表 | 1h |
| M2 | 全局锁定核心逻辑 + Accessibility 权限处理 | 1h |
| M3 | 白名单模式 + 规则管理 UI | 1h |
| M4 | 开机自启 + 图标 + 测试 + 打包 | 1h |

---

## 6. 附录

### 6.1 术语表

| 术语 | 说明 |
|------|------|
| TIS | Text Input Sources，macOS 文本输入源框架 |
| Input Source ID | 输入法唯一标识，如 `com.apple.keylayout.USExtended` |
| Bundle ID | 应用的唯一标识，如 `com.microsoft.VSCode` |
| Accessibility 权限 | macOS 辅助功能权限，TIS API 所需 |

### 6.2 参考

- [InputLock](https://github.com/lessimore/InputLock) — 同类付费软件
- [TIS Reference](https://developer.apple.com/documentation/carbon/text_input_sources) — Carbon TIS API
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — 系统服务管理
