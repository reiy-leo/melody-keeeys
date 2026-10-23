# AGENTS.md — Melody Keeeys（旋律键音）

给 AI 编码代理的项目工作指南。人类开发者请先看 [README.md](README.md) 与 [PLAN.md](PLAN.md)。

## 项目一句话

跨平台（macOS / Windows / Linux）菜单栏键盘音效应用：全局监听键盘，按当前音效包给 5 类按键层实时配音。Flutter 桌面 + miniaudio(FFI) + 自写原生键盘钩子。应用英文名 **Melody Keeeys**，中文名 **旋律键音**（原型图里的 KeySound 只是视觉参考，勿再使用）。

## 目录导览

| 路径 | 内容 |
|---|---|
| `lib/app/` | 主题（`theme/app_colors.dart` 双色板 ThemeExtension、`theme/app_tokens.dart` 圆角/间距/字体）、`settings_app.dart` 设置窗口壳（全高侧边栏+右上状态芯片）、`features/` 四个设置页 |
| `lib/core/audio/` | `audio_engine_ffi.dart`（miniaudio FFI 绑定，槽位=包序号×6+层序号）、`sound_pack.dart`（22 包元数据+6 层枚举）、`sound_engine.dart`（引擎控制器+KeyHookChannel） |
| `lib/core/hooks/` | `keymap_classifier.dart` 三平台键码表 → 5 层分类（改键位映射只动这里） |
| `lib/core/tray/` | `tray_service.dart` 托盘（tray_manager 0.7 nativeapi TrayIcon API；图标=Lucide 7 选 1） |
| `lib/core/settings/` | `settings_model.dart`（AppSettings+UiTheme+kTrayIcons）、`settings_repository.dart`（shared_preferences JSON） |
| `lib/core/system/` | `hotkey_service.dart` 全局热键（Option+Shift+K 静音 / Option+Shift+] 轮换） |
| `lib/features/hud/` | 托盘 HUD 弹窗（Windows/Linux；desktop_multi_window 第二窗口，入口 `runHudWindow`）。macOS 用原生 `HudView.swift` |
| `plugins/native_core/` | 本地插件。C 音频引擎在 `macos/Classes/src/`（**唯一副本**，Windows/Linux CMake 反向引用此路径）；`macos/Classes/MelodyHost.swift` macOS 原生常驻宿主（菜单栏/钩子/音频/热键/设置，见下文）、`HudView.swift` 原生托盘面板、`NativeCorePlugin.swift` 设置引擎的权限查询与通道桥；`windows/` WH_KEYBOARD_LL；`linux/` evdev |
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
- **说明文案一律进 tooltip（用户要求，2026-10-22）**：设置页不放常驻灰色说明行。`SettingsRow(tooltip:)` / `SectionCard(tooltip:)` 会在标题旁渲染 `InfoTip`（`?` 图标，悬停 250ms 显示）；`SectionCard.subtitle` 只留给实时状态（延迟、引擎版本等）。卡片类选项（左键行为）整卡包 `Tooltip`，音效包列表的描述挂在包名 tooltip 上。
- **热路径性能约定（2026-10-22）**：
  - 每次按键**不得** `notifyListeners()`：计数走 `soundEngine.keystrokes`（`ValueNotifier<int>`），只有显示计数的芯片用 `ValueListenableBuilder` 监听。否则每键都会重建所有设置页、碰托盘、给 HUD 推 JSON。
  - 设置持久化去抖：`updateSettings` / `selectPack` 只改内存状态并 `_scheduleSave`（400ms），不 await 写盘；退出前 `appLifecycle.quit()` 会 `await soundEngine.flushSettings()`。
  - `selectPack` 先换槽位并立即播放试听，再通知 UI/托盘；全部包已预解码，切换只是改索引。
  - 托盘 `rebuildMenu` 只在签名（当前包/引擎开关/左键行为）变化时动 native（含 tooltip）；`_pushStateToHud` 对相同 payload 去重（showHud / ready 时 `force`）。
  - **HUD 不再自建音频引擎**：试听一律 `_command('preview')` 交给主窗口引擎（旧实现在 HUD 里再解码一遍 132 段采样，内存翻倍且每次试听响两遍）。
  - C 引擎自建 `ma_resource_manager`，解码格式 s16 @ 48kHz（默认是 f32），132 段采样常驻 PCM 约 6MB（原约 12.5MB）；声部带 `MA_SOUND_FLAG_NO_SPATIALIZATION`。Linux 上用 gcc + null 后端可做无声基准：加载 22 包实测采样占用 14.5MB → 8.1MB RSS。
- **菜单栏常驻（2026-10-23 用户要求）**：启动不显示设置窗（`MainFlutterWindow.order` 里 `hiddenWindowAtLaunch()`；Windows `SetNextFrameCallback` 与 Linux `first_frame_cb` 不再自动 show），只有 `hookRunning == false`（缺权限）时 `appLifecycle.init(showSettings: true)`。`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` 必须返回 **false**——关设置窗/HUD 子窗口销毁都不能结束进程（曾导致启动即退出、关窗即退出），退出只走托盘菜单 `appLifecycle.quit()`。`AppSettings.silentStart` 字段保留仅为兼容旧配置，已无 UI、不再读取。
- **设置改动**：`AppSettings` 加字段要同时改 `copyWith / toJson / fromJson` 三处；HUD 通过 `toJson` 接收状态，新字段自动跟随。
- **FFI 符号**：`ae_*` 用 `AE_API`(used+default visibility) + Swift `@_silgen_name("ae_version")` 锚定，防止死代码剥离（dlsym 找不到符号的教训见 git log）。
- **CocoaPods 不收 pod 根之外的源文件**：共享 C 源码放 `plugins/native_core/macos/Classes/src/`。
- **托盘 API**：tray_manager ≥0.6 是 nativeapi 风格（`TrayIcon.create()` / `Menu.create()` / `MenuItem.createWithLabelAndType`），旧的 `trayManager.setContextMenu(Menu(items:...))` 已废弃不可用。
- **托盘三个致命坑**（2026-10-07 踩过，别再踩）：
  1. nativeapi 的 `ImageAsset.fromAsset` 只认 release 布局路径；托盘图标一律走 `TrayService._resolvedAssetFile()`（debug/release/三平台候选路径 + 回退链），失败时**保留当前图标**（nativeapi 对 null icon 会显示应用默认图标）。
  2. `ContextMenuTrigger` 默认是左键弹菜单，必须显式 `setContextMenuTrigger(ContextMenuTrigger.rightClicked)`，否则左键的 ClickedEvent 不派发（左键轮换失效）。
  3. Menu/MenuItem 的 Dart 局部变量 GC 后 Finalizer 释放 native 句柄 → 右键菜单悬空无反应。TrayService 用字段持有 `_menu`/`_menuItems`。
  验证点击可用 System Events：`osascript -e 'tell app "System Events" to tell process "Melody Keeeys" to click menu bar item 1 of menu bar 2'`，点击后读 plist 的 activePackId 是否轮换。
- 桌面多窗口：HUD 的窗口通信用 `WindowController.invokeMethod`（main→HUD 方法名 `hudState`，HUD→main 方法名 `hudCommand`）；启动日志里一行 benign 的 desktop_multi_window "Failed to send message" 可忽略。
- macOS 权限：CGEventTap 需辅助功能授权（设置页有引导横幅；横幅复查后授权成功要清空 `_permissionError` 并重试 `startHook()`——hook 只在启动时尝试一次，窗口重新聚焦也会自动复查）；entitlements 已关沙箱，Info.plist `LSUIElement=true`。
- **辅助功能授权稳定性（2026-10-07 踩过）**：TCC 授权是绑定签名的——ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`）下存的是 cdhash，每次重新构建 cdhash 变化导致授权失效；且 macOS 15 无 AX 权限时 `CGEvent.tapCreate` 也会成功（收不到事件），曾让芯片假绿。现已改为用 Apple Development 证书签名（team `EHBQV2H8YV`，`CODE_SIGN_IDENTITY` 用证书 SHA-1 hash），授权绑定到证书身份，重建不再掉；`startKeyHook` 里显式用 `AXIsProcessTrusted()` 门控。改动签名配置后需手动删掉 TCC 里的旧 cdhash 记录（`tccutil reset Accessibility dev.melodykeeeys.melodyKeeeys`）并重新勾选一次。
- **tap 必须是 active tap 不能是 listenOnly（2026-10-07 第二课）**：listen-only tap 在最近的 macOS 上要「输入监控」权限，且该 TCC 记录同样绑定签名、重建即失效，失效时 tap 创建"成功"但零事件（症状：所有键无声、引擎芯片假绿、无任何报错）。改为 `options: .defaultTap`（事件原样透传不拦截）后只依赖稳定的辅助功能授权。验证方法：debug 构建看 `[melody] key code=...` 日志是否随按键输出。
- **桌面多窗口子窗口插件注册**：desktop_multi_window 的每个子窗口跑独立 Flutter engine，插件不会自动注册——必须在 `macos/Runner/MainFlutterWindow.swift` 里 `FlutterMultiWindowPlugin.setOnWindowCreatedCallback { RegisterGeneratedPlugins(registry: $0) }`，否则 HUD 里 window_manager 等全部 MissingPluginException（曾导致点托盘 HUD 完全弹不出来）。
- **HUD 定位**：托盘 bounds 随 `WindowConfiguration.arguments` 一起传给 HUD，在 `runHudWindow()` 启动时立即定位（首开时发 `place` 消息会与引擎启动竞态导致丢失，HUD 曾弹在屏幕中间）；屏幕尺寸必须用 `view.display.size / devicePixelRatio`，**不能用 `view.physicalSize`**（那是 HUD 自己窗口的尺寸，clamp 会全错）。`hudTopLeft()` 是纯函数，可单测。
- **HUD 显示流程（黑窗/反复重建的坑）**：主窗口**不要**远程 `controller.show()` 一个还没启动完的 HUD 引擎——会先在默认位置闪黑窗再跳位。正确流程：HUD 隐藏创建（`hiddenAtLaunch`）→ HUD 自己首帧后 `windowManager.show()` 并 `_command('ready')` 通知主窗口 → 主窗口 `markHudReady()` 后走「reuse + place + show」。另：`_pushStateToHud` 的 catch 里**不能直接丢弃 controller**——引擎启动期 `CHANNEL_UNREGISTERED` 是暂时的，误删会导致每次点击新建一个窗口（黑窗累积）；要先 `WindowController.getAll()` 确认窗口真的没了才丢，且 push 成功本身可当作 ready 兜底。
- **Impeller 渲染问题**：Intel Mac（UHD 630）上 Impeller 会渲染字形损坏（文字变噪点/沙子），Info.plist 里 `FLTEnableImpeller=false` 强制回 Skia。修改 plist 后必须重新构建才生效。

## 会话收尾清单（用户固定要求）

每次开发工作结束后必须：
1. `flutter build macos --release` 重新打包，并告知用户 .app 路径（`build/macos/Build/Products/Release/Melody Keeeys.app`）；
2. 同步文档（AGENTS.md / DESIGN.md / README.md / PLAN.md），保持代码与文档一致；
3. `git add -A && git commit && git push`（用户已授权每次提交+推送）。

### 已知环境问题（2026-10-07）

- **SSH 推送故障**：1Password SSH agent 报 `communication with agent failed`，SSH 推送/拉取全部失败。已把 origin 切到 HTTPS（`https://github.com/reiy-leo/melody-keeeys.git`），并用 `gh auth setup-git` 配好凭据助手（gh token 走 keyring），`git push`/`git fetch` 现在直接可用。若 1Password 修复后可自行决定是否切回 SSH。
- **提交签名故障**：全局 `commit.gpgsign=true` 走 1Password `op-ssh-sign`，同样因 agent 故障报 `error: 1Password: agent returned an error`。临时绕过：`git -c commit.gpgsign=false commit`。1Password 修复后签名会自动恢复，无需改配置。
- **发布（2026-10-23 起）**：推 `v*` 标签触发 `.github/workflows/release.yml`，GitHub Actions 三平台构建（macOS 用 ad-hoc 签名替换本地证书配置、Universal zip；Windows x64 zip；Linux x64 tar.gz），自动建 Release；标签带 `-`（如 `v0.2.0-alpha.1`）即标为预发布。说明文案在 `.github/release-notes.md`，每次发版前改。
- **截图工具**：README 截图用 debug 专用 `ScreenshotHost`（`lib/shared/debug_screenshot.dart`），`flutter build macos --debug --dart-define=MELODY_SCREENSHOTS=true` 后运行，写入 `/tmp/melody_shot_req`（内容=输出路径）即可触发主窗口截图，HUD 用 `/tmp/melody_shot_hud_req`。不依赖系统屏幕录制权限。

## macOS 原生宿主（2026-10-24，内存架构）

Rei 实测 alpha.3 常驻仍约 120MB：只要进程里挂着 Flutter 引擎（Dart VM、Skia、字体、GPU surface）就降不下去，采样 PCM 才约 6.5MB。所以 macOS 改为「原生常驻 + Flutter 按需」：

- **常驻部分全在 `plugins/native_core/macos/Classes/MelodyHost.swift`**（单例 `MelodyHost.shared`，`AppDelegate` 在 didFinishLaunching 时 `start()`）：NSStatusItem 菜单栏图标与右键菜单、CGEventTap 键盘钩子（独立线程）、按键分类与播放策略（移植自 `sound_engine.dart` / `keymap_classifier.dart` 的 macOS 表）、C 音频引擎（`@_silgen_name` 直调 `ae_*`，所有引擎操作在串行 `audioQueue`）、Carbon 全局热键、设置读写（UserDefaults `flutter.melody_keeeys.settings.v1`，与 shared_preferences 同一键，旧配置无缝沿用，400ms 去抖，退出时 flush；退出走 `MelodyHost.quit()`，AppDelegate 的 applicationShouldTerminate 直接 .terminateNow，绕开 Flutter 的退出握手——设置引擎已销毁时无人应答会卡住退出）、开机自启（`launch_at_startup` 通道，SMAppService，macOS 13+）。
- **托盘面板（HUD）在 macOS 是原生 SwiftUI**（`HudView.swift`，NSPopover，打开时构建、关闭即释放）。Flutter 版 HUD（`lib/features/hud/`、desktop_multi_window）只给 Windows/Linux 用。
- **设置窗口按需起引擎**：`macos/Runner/MainFlutterWindow.swift` 的 `SettingsWindowHost` 在打开时新建 `FlutterViewController`（新引擎），关闭时 `shutDownEngine()` 并清空 contentView；NSWindow 本身复用以保留位置大小。启动不再从 xib 建窗口（MainMenu.xib 已删 window 和 `mainFlutterWindow` outlet）。
- **插件手动注册**：设置引擎只注册 NativeCorePlugin / ScreenRetriever / SharedPreferences / WindowManager（见 `registerPlugins`），不注册 desktop_multi_window、hotkey_manager。**以后 macOS 新增插件必须加到这里**，不会自动走 `RegisterGeneratedPlugins`。
- **Dart 侧（`kNativeHost = Platform.isMacOS`）**：`main()` 走 `_runHostedSettings()`，只跑设置页；`SoundEngine` 变成瘦客户端，经 `melody/host` 通道：`getState` / `updateSettings`(JSON 字符串) / `selectPack` / `preview` / `startHook` / `settingsShown` / `settingsClosed` / `quit`；宿主回推 `state`（菜单栏/热键/面板引起的变化；Flutter 发起的改动不回推，避免滑杆回跳）和 `keystrokes`（250ms 节流）。关窗 = `onWindowClose` → `settingsClosed` → 宿主销毁引擎。
- **音效包清单**：宿主读 `assets/sounds/packs.json`（由 `python3 tool/gen_packs_json.py` 从 `kBuiltinPacks` 生成，`test/packs_manifest_test.dart` 校验一致）。**改包要重新生成**。采样直接从 `App.framework/Resources/flutter_assets/assets/sounds/` 读取，macOS 不再解压到 Application Support。
- Windows/Linux 仍是原架构（Dart 常驻 + FFI + Flutter HUD + parked 设置窗），下面两条只对它们有效：
  - Hidden settings window is *parked*: `settingsVisible` false unmounts the MaterialApp, clears the image cache and shrinks the window to 64×64. Go through `_parkSettings()`, never a bare `windowManager.hide()`.
  - The Flutter HUD hides on blur and after 30 s asks `melody/hud_window` to close itself (no native implementation on Windows/Linux, so it just stays hidden).

## 应用名与图标

- 英文名 Melody Keeeys，中文名「旋律键音」。macOS 产物 `Melody Keeeys.app`；Finder/访达的中文名来自 `macos/Runner/zh-Hans.lproj/InfoPlist.strings`（`LSHasLocalizedDisplayName`），en 同理。
- 应用图标源图 `assets/icons/source/app_icon_source.webp`（背景棋盘格是烘焙进去的，脚本按圆角矩形抠图）；改图后运行 `python3 tool/make_app_icons.py` 重新生成 macOS appiconset、Windows ico 和关于页 `assets/icons/app_icon.png`。菜单栏托盘图标不在此列。
