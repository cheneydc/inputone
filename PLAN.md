# InputOne 开发计划

## Phase 1 — 项目骨架 & 菜单栏 ✅
1.1 swift package init --type executable
1.2 创建 App.swift — @main 入口
1.3 创建 AppDelegate.swift — NSStatusBar + NSMenu
1.4 创建 InputMethodManager.swift — TIS API 封装
1.5 菜单栏动态列出输入法
1.6 创建占位图标

## Phase 2 — 全局锁定核心逻辑 ✅
2.1 创建 Settings.swift — UserDefaults 封装
2.2 创建 InputLocker.swift — app 切换监听 + 锁定
2.3 菜单栏勾选逻辑
2.4 Accessibility 权限检测
2.5 解锁/锁定切换

## Phase 3 — 白名单模式 ✅
3.1 创建 WhitelistManager.swift — 白名单 CRUD
3.2 模式切换子菜单
3.3 白名单管理子菜单
3.4 添加白名单条目 UI
3.5 InputLocker 双模式支持

## Phase 4 — 开机自启 & 打包 ✅
4.1 开机自启 toggle — SMAppService
4.2 Info.plist — LSUIElement
4.3 AppIcon.icns
4.4 构建脚本 — scripts/build-release.sh
4.5 最终验证
