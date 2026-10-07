# AGENTS.md — Melody Keeeys（旋律按键）

给 AI 编码代理的项目工作指南。人类开发者请先看 [README.md](README.md) 与 [PLAN.md](PLAN.md)。

## 项目一句话

跨平台（macOS / Windows / Linux）菜单栏键盘音效应用：全局监听键盘，按当前音效包给 5 类按键层实时配音。Flutter 桌面 + miniaudio(FFI) + 自写原生键盘钩子。应用英文名 **Melody Keeeys**，中文名 **旋律按键**（原型图里的 KeySound 只是视觉参考，勿再使用）。

## 目录导览

| 路径 | 内容 |
|---|---|
| `lib/app/` | 主题（`theme/app_colors.dart` 双色板 ThemeExtension、`theme/app_tokens.dart` 圆角/间距/字体）、`settings_app.dart` 设置窗口壳（全高侧边栏+右上状态芯片）、`features/` 四个设置页 |
| `lib/core/audio/` | `audio_engine_ffi.dart`（miniaudio FFI 绑定，槽位=包序号×6+层序号）、`sound_pack.dart`（22 包元数据+6 层枚举）、`sound_engine.dart`（引擎控制器+KeyHookChannel） |
| `lib/core/hooks/` | `keymap_classifier.dart` 三平台键码表 → 5 层分类（改键位映射只动这里） |
| `lib/core/tray/` | `tray_service.dart` 托盘（tray_manager 0.7 nativeapi TrayIcon API；图标=Lucide 7 选 1） |
| `lib/core/settings/` | `settings_model.dart`（AppSettings+UiTheme+kTrayIcons）、`settings_repository.dart`（shared_preferences JSON） |
| `lib/core/system/` | `hotkey_service.dart` 全局热键（Option+Shift+K 静音 / Option+Shift+] 轮换） |
| `lib/features/hud/` | 托盘 HUD 弹窗（desktop_multi_window 第二窗口，入口 `runHudWindow`，main args 首参 `multi_window`） |
| `plugins/native_core/` | 本地插件。C 音频引擎在 `macos/Classes/src/`（**唯一副本**，Windows/Linux CMake 反向引用此路径）；`macos/Classes/NativeCorePlugin.swift` CGEventTap；`windows/` WH_KEYBOARD_LL；`linux/` evdev |
| `assets/sounds/` | 132 个 WAV（22 包 × 6 层，**全部为真实录音素材**，已统一响度归一化；授权与来源见 `assets/sounds/CREDITS.md`）。导入脚本：`tool/import_real_sounds.py`（01-10，kbsim/Kenney/Tickeys）+ `tool/import_tickeys_sounds.py`（11-22）。新增包要同时改 `sound_pack.dart` 的 kBuiltinPacks + `pubspec.yaml` 资源目录；资源有改动时提升 `sound_engine.dart` 里 `_extractAssets` 的 `assetVersion`，否则已安装实例不会刷新 WAV |
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
# 音效素材导入（一次性，需先克隆源仓库，详见 CREDITS.md）
python3 tool/import_real_sounds.py --kbsim <kbsim/src/assets/audio> --kenney <kenney/Audio> --tickeys <tickeys/data>
python3 tool/import_tickeys_sounds.py <tickeys/Tickeys.app/Contents/Resources/data>
python3 tool/make_lucide_tray_icons.py    # 重新生成 Lucide 托盘图标
python3 tool/make_tray_icons.py           # 旧版自绘托盘图标（about 页仍在用 tray_256.png）
```

## 代码约定与注意点

- **颜色一律 `context.colors.xxx`**（ThemeExtension，浅/深双套在 `app_colors.dart`）；不要新增静态色常量。文字样式必须在 `buildAppTheme` 里绑定 `onSurface`（null color 会在浅色下变白字）。
- **文案语言（用户固定要求）**：界面语言=中文——状态、按钮、徽章、滑杆标签、音效名称等所有用户可见文案一律中文；英文仅作辅助（音效包英文原名在中文名之后以弱化标签显示；品牌名 Melody Keeeys、快捷键 Option+Shift+K、技术名词如 miniaudio 保留原文）。数据模型 `SoundPack` 用 `name`（中文主名）+ `nameEn`（英文原名）+ `description`（纯中文）三字段；勿再用原型里的 `tag` 字段。布局上**中文名优先占位、英文名 Flexible 可截断**，否则中文名会被英文挤压（教训：`Row` 里先 Flexible 中文名会显示成"清..."）。
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
- **tap 必须是 active tap 不能是 listenOnly（2026-10-07 第二课）**：listen-only tap 在最近的 macOS 上要「输入监控」权限，且该 TCC 记录同样绑定签名、重建即失效，失效时 tap 创建"成功"但零事件（症状：所有键无声、引擎芯片假绿、无任何报错）。改为 `options: .defaultTap`（事件原样透传不拦截）后只依赖稳定的辅助功能授权。验证方法：debug 构建看 `[melody] key code=...` 日志是否随按键输出。
- **桌面多窗口子窗口插件注册**：desktop_multi_window 的每个子窗口跑独立 Flutter engine，插件不会自动注册——必须在 `macos/Runner/MainFlutterWindow.swift` 里 `FlutterMultiWindowPlugin.setOnWindowCreatedCallback { RegisterGeneratedPlugins(registry: $0) }`，否则 HUD 里 window_manager 等全部 MissingPluginException（曾导致点托盘 HUD 完全弹不出来）。
- **HUD soundDir 传递**：`main.dart` 里必须 `appLifecycle.soundDir = soundEngine.soundDir`（曾遗漏导致 HUD 预览引擎无采样、且 `_soundDir!` 空断言崩溃）。
- **HUD 定位**：托盘 bounds 随 `WindowConfiguration.arguments` 一起传给 HUD，在 `runHudWindow()` 启动时立即定位（首开时发 `place` 消息会与引擎启动竞态导致丢失，HUD 曾弹在屏幕中间）；屏幕尺寸必须用 `view.display.size / devicePixelRatio`，**不能用 `view.physicalSize`**（那是 HUD 自己窗口的尺寸，clamp 会全错）。`hudTopLeft()` 是纯函数，可单测。
- **HUD 显示流程（黑窗/反复重建的坑）**：主窗口**不要**远程 `controller.show()` 一个还没启动完的 HUD 引擎——会先在默认位置闪黑窗再跳位。正确流程：HUD 隐藏创建（`hiddenAtLaunch`）→ HUD 自己首帧后 `windowManager.show()` 并 `_command('ready')` 通知主窗口 → 主窗口 `markHudReady()` 后走「reuse + place + show」。另：`_pushStateToHud` 的 catch 里**不能直接丢弃 controller**——引擎启动期 `CHANNEL_UNREGISTERED` 是暂时的，误删会导致每次点击新建一个窗口（黑窗累积）；要先 `WindowController.getAll()` 确认窗口真的没了才丢，且 push 成功本身可当作 ready 兜底。
- **Impeller 渲染问题**：Intel Mac（UHD 630）上 Impeller 会渲染字形损坏（文字变噪点/沙子），Info.plist 里 `FLTEnableImpeller=false` 强制回 Skia。修改 plist 后必须重新构建才生效。

## 会话收尾清单（用户固定要求）

每次开发工作结束后必须：
1. `flutter build macos --release` 重新打包，并告知用户 .app 路径（`build/macos/Build/Products/Release/melody_keeeys.app`）；
2. 同步文档（AGENTS.md / DESIGN.md / README.md / PLAN.md），保持代码与文档一致；
3. `git add -A && git commit && git push`（用户已授权每次提交+推送）。
