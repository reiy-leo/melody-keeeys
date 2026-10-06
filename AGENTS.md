# AGENTS.md — Melody Keeeys（旋律按键）

给 AI 编码代理的项目工作指南。人类开发者请先看 [README.md](README.md) 与 [PLAN.md](PLAN.md)。

## 项目一句话

跨平台（macOS / Windows / Linux）菜单栏键盘音效应用：全局监听键盘，按当前音效包给 5 类按键层实时配音。Flutter 桌面 + miniaudio(FFI) + 自写原生键盘钩子。应用英文名 **Melody Keeeys**，中文名 **旋律按键**（原型图里的 KeySound 只是视觉参考，勿再使用）。

## 目录导览

| 路径 | 内容 |
|---|---|
| `lib/app/` | 主题（`theme/app_colors.dart` 双色板 ThemeExtension、`theme/app_tokens.dart` 圆角/间距/字体）、`settings_app.dart` 设置窗口壳（全高侧边栏+右上状态芯片）、`features/` 四个设置页 |
| `lib/core/audio/` | `audio_engine_ffi.dart`（miniaudio FFI 绑定，槽位=包序号×6+层序号）、`sound_pack.dart`（10 包元数据+5 层枚举）、`sound_engine.dart`（引擎控制器+KeyHookChannel） |
| `lib/core/hooks/` | `keymap_classifier.dart` 三平台键码表 → 5 层分类（改键位映射只动这里） |
| `lib/core/tray/` | `tray_service.dart` 托盘（tray_manager 0.7 nativeapi TrayIcon API；图标=Lucide 7 选 1） |
| `lib/core/settings/` | `settings_model.dart`（AppSettings+UiTheme+kTrayIcons）、`settings_repository.dart`（shared_preferences JSON） |
| `lib/core/system/` | `hotkey_service.dart` 全局热键（Option+Shift+K 静音 / Option+Shift+] 轮换） |
| `lib/features/hud/` | 托盘 HUD 弹窗（desktop_multi_window 第二窗口，入口 `runHudWindow`，main args 首参 `multi_window`） |
| `plugins/native_core/` | 本地插件。C 音频引擎在 `macos/Classes/src/`（**唯一副本**，Windows/Linux CMake 反向引用此路径）；`macos/Classes/NativeCorePlugin.swift` CGEventTap；`windows/` WH_KEYBOARD_LL；`linux/` evdev |
| `assets/sounds/` | 60 个合成占位 WAV（发布前需替换真实素材） |
| `assets/icons/` | 托盘图标（`tool/make_lucide_tray_icons.py` 生成 Lucide 7 图标 ×3 变体）+ 旧版自绘图 |
| `docs/prototypes/` | Google Stitch 原型图 + 原始设计系统（KeySound 字样仅供参考） |
| `tool/` | 资产生成与冒烟测试脚本 |
| `packaging/` | Windows Inno Setup 脚本 |

## 构建环境（本机关键坑）

- **Flutter**：`brew install --cask flutter`（PATH 已有）。
- **CocoaPods 必须用 brew ruby 的 gem**，构建前导出：
  `export PATH="/usr/local/lib/ruby/gems/4.0.0/bin:/usr/local/opt/ruby/bin:/usr/local/bin:$PATH"`
  系统 ruby 2.6 的 gem 原生扩展全坏；tray_manager 0.7+（依赖 nativeapi）不支持 SPM，macOS 构建绕不开 CocoaPods。
- **C 音频引擎独立冒烟测试**（不启 Flutter 即可验证出声）：
  `clang -I plugins/native_core/macos/Classes/src -o /tmp/ae_test tool/audio_smoke_test.c plugins/native_core/macos/Classes/src/audio_engine.c -framework CoreAudio -framework AudioToolbox -framework AudioUnit -framework CoreFoundation && /tmp/ae_test assets/sounds/<pack>/alpha.wav`

## 常用命令

```bash
flutter pub get                      # 依赖
flutter analyze                      # 提交前必须 0 issue
flutter build macos --debug|--release
python3 tool/make_placeholder_sounds.py   # 重新生成占位音效
python3 tool/make_lucide_tray_icons.py    # 重新生成 Lucide 托盘图标
python3 tool/make_tray_icons.py           # 旧版自绘托盘图标（about 页仍在用 tray_256.png）
```

## 代码约定与注意点

- **颜色一律 `context.colors.xxx`**（ThemeExtension，浅/深双套在 `app_colors.dart`）；不要新增静态色常量。文字样式必须在 `buildAppTheme` 里绑定 `onSurface`（null color 会在浅色下变白字）。
- **设置改动**：`AppSettings` 加字段要同时改 `copyWith / toJson / fromJson` 三处；HUD 通过 `toJson` 接收状态，新字段自动跟随。
- **FFI 符号**：`ae_*` 用 `AE_API`(used+default visibility) + Swift `@_silgen_name("ae_version")` 锚定，防止死代码剥离（dlsym 找不到符号的教训见 git log）。
- **CocoaPods 不收 pod 根之外的源文件**：共享 C 源码放 `plugins/native_core/macos/Classes/src/`。
- **托盘 API**：tray_manager ≥0.6 是 nativeapi 风格（`TrayIcon.create()` / `Menu.create()` / `MenuItem.createWithLabelAndType`），旧的 `trayManager.setContextMenu(Menu(items:...))` 已废弃不可用。
- **托盘三个致命坑**（2026-10-07 踩过，别再踩）：
  1. nativeapi 的 `ImageAsset.fromAsset` 只认 release 布局路径；托盘图标一律走 `TrayService._resolvedAssetFile()`（debug/release/三平台候选路径 + 回退链），失败时**保留当前图标**（nativeapi 对 null icon 会显示应用默认图标）。
  2. `ContextMenuTrigger` 默认是左键弹菜单，必须显式 `setContextMenuTrigger(ContextMenuTrigger.rightClicked)`，否则左键的 ClickedEvent 不派发（左键轮换失效）。
  3. Menu/MenuItem 的 Dart 局部变量 GC 后 Finalizer 释放 native 句柄 → 右键菜单悬空无反应。TrayService 用字段持有 `_menu`/`_menuItems`。
  验证点击可用 System Events：`osascript -e 'tell app "System Events" to tell process "melody_keeeys" to click menu bar item 1 of menu bar 2'`，点击后读 plist 的 activePackId 是否轮换。
- 桌面多窗口：HUD 的窗口通信用 `WindowController.invokeMethod`（main→HUD 方法名 `hudState`，HUD→main 方法名 `hudCommand`）；启动日志里一行 benign 的 desktop_multi_window "Failed to send message" 可忽略。
- macOS 权限：CGEventTap 需辅助功能授权（设置页有引导横幅；横幅复查后授权成功要清空 `_permissionError` 并重试 `startHook()`——hook 只在启动时尝试一次，窗口重新聚焦也会自动复查）；entitlements 已关沙箱，Info.plist `LSUIElement=true`。
- **辅助功能授权稳定性（2026-10-07 踩过）**：TCC 授权是绑定签名的——ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`）下存的是 cdhash，每次重新构建 cdhash 变化导致授权失效；且 macOS 15 无 AX 权限时 `CGEvent.tapCreate` 也会成功（收不到事件），曾让芯片假绿。现已改为用 Apple Development 证书签名（team `EHBQV2H8YV`，`CODE_SIGN_IDENTITY` 用证书 SHA-1 hash），授权绑定到证书身份，重建不再掉；`startKeyHook` 里显式用 `AXIsProcessTrusted()` 门控。改动签名配置后需手动删掉 TCC 里的旧 cdhash 记录（`tccutil reset Accessibility dev.melodykeeeys.melodyKeeeys`）并重新勾选一次。
- **Impeller 渲染问题**：Intel Mac（UHD 630）上 Impeller 会渲染字形损坏（文字变噪点/沙子），Info.plist 里 `FLTEnableImpeller=false` 强制回 Skia。修改 plist 后必须重新构建才生效。

## 会话收尾清单（用户固定要求）

每次开发工作结束后必须：
1. `flutter build macos --release` 重新打包，并告知用户 .app 路径（`build/macos/Build/Products/Release/melody_keeeys.app`）；
2. 同步文档（AGENTS.md / DESIGN.md / README.md / PLAN.md），保持代码与文档一致；
3. `git add -A && git commit && git push`（用户已授权每次提交+推送）。
