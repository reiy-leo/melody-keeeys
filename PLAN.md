# Melody Keeeys（旋律按键）实施计划

> 跨平台键盘音效应用：macOS / Windows / Linux 菜单栏（托盘）应用。
> 全局监听键盘敲击，按当前音效包播放对应按键声音。左键点击托盘图标切换下一个音效，右键选择具体音效或打开设置。
>
> 原型资料已归档至 [docs/prototypes/](docs/prototypes/)（Google Stitch 初稿：托盘弹窗 HUD + 设置窗口三页）。

---

## 1. 产品定义

| 项目 | 内容 |
|---|---|
| 应用名 | **Melody Keeeys**（英文名，托盘/HUD/窗口标题展示用）；中文名 **旋律按键**（关于页、中文 UI 副标题） |
| 形态 | 常驻菜单栏/托盘的应用（无 Dock/任务栏常驻窗口），主窗口即设置窗口 |
| 核心功能 | 全局键盘监听 → 按键分类映射 → 低延迟播放对应音效 |
| 默认音效 | 22 个内置音效包（见 §5） |
| 交互 | 左键托盘图标 = 轮换下一个音效（可在设置中改为弹出 HUD，HUD 顶部有「正在使用：音效包」卡片）；右键 = 上下文菜单（首行固定显示「正在使用：当前音效包」，悬停 tooltip 同步显示） |
| 设置窗口 | 侧边栏 4 项：通用、音效、菜单栏（侧边栏底部：关于） |
| UI 语言 | **中文优先**：所有界面文案（状态、按钮、徽章、音效名称）一律中文；英文仅作辅助（音效包英文原名以弱化标签形式显示，品牌名与快捷键等专有名词保留原文）。文案结构上预留 i18n（zh-CN 默认 + en） |

### 与原型的两处差异说明
1. **左键行为**：原型「菜单栏」页中「Left-Click Action」有两个选项且 *Cycle Next Sound* 为选中态 —— 与需求文字「点击自动切换下一个音效」一致。实现为**可配置项，默认轮换音效**；「显示托盘 HUD 弹窗」作为备选行为。
2. **关于页**：原型把 About 放在侧边栏底部（ENGINE STATUS / 版本号处），按需求保留此位置，并作为独立 Tab 页面。

---

## 2. 技术选型

**框架**：Flutter desktop（`flutter create --platforms=macos,windows,linux`），单一代码库。

### 插件/依赖

| 能力 | 方案 | 备注 |
|---|---|---|
| 托盘图标与菜单 | `tray_manager` | 三平台支持；Linux 走 appindicator，有平台差异（见 §8 风险） |
| 窗口控制（无边框、关闭时隐藏、开机位置） | `window_manager` | 关闭设置窗口 = 隐藏而非退出 |
| HUD 弹窗（第二窗口） | `desktop_multi_window` | 备选方案：单窗口 `setAsFrameless()` 模式切换（见 §8） |
| 设置持久化 | `shared_preferences` | JSON 导出/导入自实现 |
| 开机自启 | `launch_at_startup` | macOS SMAppService / Windows 注册表 / Linux .desktop |
| 全局快捷键 | `hotkey_manager` | 「全局静音」「快速轮换音效包」 |
| 字体 | 打包 TTF（Space Grotesk + Plus Jakarta Sans） | 避免运行时联网下载 |
| 状态管理 | `Riverpod` | 引擎状态、设置在多窗口间共享 |
| 音频播放 | **miniaudio（单头文件 C 库）+ dart:ffi** | 见 §3，键击音必须低延迟+高复音 |
| 全局键盘钩子 | **自写平台原生插件**（MethodChannel） | 无现成跨平台插件，见 §3 |

### 为什么音频不用 just_audio/media_kit
键击音要求：极低触发延迟（<30ms 端到端）、高复音并发（快速打字每秒 10+ 次）、多实例预加载。`just_audio` 等基于系统播放器的方案实例重、延迟不稳定。**miniaudio** 是单 C 文件、三平台后端（CoreAudio / WASAPI / ALSA·PulseAudio·PipeWire·Jack）、内建解码与复音引擎，通过 FFI 直接在 Dart 里 `ma_engine_play_sound`，一次集成三平台通用，且是整个应用唯一需要碰的 C 代码。

---

## 3. 架构

```
┌────────────────────────── Flutter（Dart）──────────────────────────┐
│  TrayService          SettingsWindow          HudWindow            │
│  (托盘事件/菜单)      (4 Tab 设置页)          (desktop_multi_window)│
│        │                     │                      ▲               │
│        └──────────► EngineController (Riverpod) ────┘               │
│                            │                                        │
│      KeymapClassifier      │  SettingsRepository(shared_prefs)      │
│   (键码→5类按键层)          │                                        │
└────────┼───────────────────┼────────────────────────────────────────┘
         │ MethodChannel     │ dart:ffi
┌────────▼─────────┐  ┌──────▼──────────┐
│ key_hook 原生插件 │  │ audio_engine.c  │← miniaudio
│ mac: CGEventTap  │  │ (预加载/复音/    │
│ win: WH_KEYBD_LL │  │  音量/音高)      │
│ linux: evdev     │  └─────────────────┘
│ (input组只读)    │
└──────────────────┘
```

### 3.1 全局键盘钩子（自写，每平台一份原生代码）

| 平台 | 实现 | 权限 |
|---|---|---|
| macOS | `CGEventTap`（active tap，监听 keyDown/keyUp，事件原样透传不拦截）。**不用 listen-only**：listen-only 在近期 macOS 上额外要「输入监控」权限，且该 TCC 记录绑定签名、重建即失效，失效时 tap 创建"成功"但收不到任何事件 | 需要用户授予「辅助功能」权限；App 首次运行引导跳转系统设置（TCC），未授权时 UI 显示引导横幅；授权绑定代码签名，须用开发证书签名（ad-hoc 下每次重建 cdhash 变化会使授权失效） |
| Windows | `SetWindowsHookEx(WH_KEYBOARD_LL)` + 独立消息循环线程，过滤 `LLKHF_INJECTED` 防自触发 | 无需管理员 |
| Linux | evdev 只读监听：读取 `/dev/input/event*`，静态扫描码表映射键码；X11 与 Wayland 会话通用 | 需把用户加入 `input` 组（一次性）；应用内提供权限检测、一键指引与重新检查 |

关键约定：原生层只上报 `{platformKeycode, isKeyDown, timestamp}`，**分类映射、防抖、选音全在 Dart 侧**，便于统一逻辑与热更新调参。

### 3.2 音频引擎（miniaudio via FFI）
- 启动时 `ma_engine` 初始化；当前音效包的 5~6 个采样解码进内存（`ma_audio_buffer`），切换音效包时换载。
- 播放：`ma_sound_set_pitch`（音高抖动）、per-layer gain（音量补偿）。
- 首次运行把 `assets/sounds/**` 拷贝到应用数据目录再由 C 侧加载（避开资源路径问题），或直接内存字节加载（首选，免拷贝）。
- C 代码通过各平台构建系统接入：Windows/Linux 的 `CMakeLists.txt`、macOS 的 Xcode 工程，无需实验性 native-assets。
- 绑定用 ffigen 生成或手写（约 10 个函数，建议手写）。

### 3.3 按键 → 音效层分类（对齐原型「Physical Acoustic Key-Layers 5 Layers」）
| 层 | 覆盖键 |
|---|---|
| 1 Alpha | A–Z、数字、常用符号 |
| 2 Space | 空格（稳定器深底音） |
| 3 Enter/Backspace | Enter、Backspace、Delete、Tab |
| 4 Modifiers | Shift/Ctrl/Alt/Cmd/Caps |
| 5 Function/Nav | F1–F12、方向键、Esc、Home/End 等 |

每个音效包为每层提供一段采样 + 每层 tone 偏移；可选 key-release 采样（松键上行程音）。

### 3.4 DSP / 行为参数（对应原型 General & Sound Effects 页）
- 音量（-12 ~ +6 dB）、音高抖动 Pitch Jitter 0~50%
- Anti-Ghosting 抑制窗口：10–100ms（默认 35ms），窗口内同类重复触发合并；OS 按键自动重复按此抑制
- 修饰键长按连发（Modifier Auto-Repeat）开关
- Key-Release 上行程音 开关 + damping
- 缓冲延迟预设：Ultra / Native / Safe（映射 miniaudio period 参数三档）

---

## 4. 目录结构

```
lib/
  main.dart                 # 引导：托盘、引擎、窗口、开机模式
  app/                      # 主题（DESIGN.md 色板/字体/圆角 token 化）、路由、i18n
  core/
    audio/audio_engine.dart        # FFI 绑定与封装
    hooks/key_hook_channel.dart    # MethodChannel 统一接口
    hooks/keymap_classifier.dart   # 键码→层分类、防抖
    tray/tray_service.dart         # 托盘图标、左右键行为、菜单构建
    settings/settings_repository.dart / settings_model.dart
    system/launch_at_startup.dart / hotkey_service.dart / foreground_app.dart(二期)
  features/
    general/ sounds/ menubar/ about/   # 设置窗口四页
    hud/                                # 托盘 HUD 弹窗
  shared/widgets/           # PillButton、M3 开关、滑杆、卡片、侧边栏等复用组件
native/
  audio_engine.c + miniaudio.h   # 唯一的 C 代码（各平台构建脚本接入）
macos/ windows/ linux/          # flutter create 生成的宿主 + 各自 key_hook 原生代码
assets/sounds/<pack_id>/alpha|space|enter|modifier|nav|release.{wav,ogg}
assets/fonts/ assets/icons/
tool/import_real_sounds.py      # 真实音效导入脚本（见 §5）
```

---

## 5. 内置 22 个音效包（原型 10 个 + Tickeys 风格 7 个）

原型的 10 个：

| # | 包名 | 中文名 | 素材（真实录音） |
|---|---|---|---|
| 01 | Cherry MX Blue | 清脆青轴 | kbsim `mxblue`（MIT） |
| 02 | Gateron Oil King | 麻将音 | kbsim `blackink`（MIT） |
| 03 | Holy Panda | 圣熊猫轴 | kbsim `holypanda`（MIT） |
| 04 | IBM Model M | 弹簧经典 | kbsim `buckling`（MIT） |
| 05 | Kailh Box White | 凯华白盒 | kbsim `boxnavy`（MIT） |
| 06 | Topre Electrostatic | 静电容 | kbsim `topre`（MIT） |
| 07 | Bubble Pop | 水泡泡 | Tickeys `bubble`（CC BY 3.0） |
| 08 | Sci-Fi Laser | 电子镭射 | Kenney Sci-Fi Sounds（CC0） |
| 09 | Typewriter 1930s | 老式打字机 | Tickeys `typewriter`（MIT） |
| 10 | Silent Red | 消音红轴 | kbsim `redink`（MIT） |

参考 [Tickeys](https://github.com/yingDev/Tickeys)（MIT）新增的 7 个——**直接使用其内置的真实音效素材**（非合成），经 `tool/import_tickeys_sounds.py` 按 Tickeys 的 `schemes.json` 映射到本项目 6 层结构；授权明细见 [assets/sounds/CREDITS.md](assets/sounds/CREDITS.md)：

| # | 包名 | 中文名 | 素材来源 |
|---|---|---|---|
| 11 | Bubble | 咕噜气泡 | Tickeys `bubble/`（Freesound: Glaneur de sons，CC BY 3.0） |
| 12 | Typewriter | 经典打字机 | Tickeys `typewriter/`（MIT 仓库分发） |
| 13 | Mechanical | 机械键盘 | Tickeys `mechanical/`（Freesound: jim-ph，**CC0**） |
| 14 | Sword | 利剑出鞘 | Tickeys `sword/`（MIT 仓库分发） |
| 15 | Cherry G80-3000 | 樱桃 G80-3000 | Tickeys `Cherry_G80_3000/`（MIT 仓库分发） |
| 16 | Cherry G80-3494 | 樱桃 G80-3494 | Tickeys `Cherry_G80_3494/`（MIT 仓库分发） |
| 17 | Drum | 鼓点 | Tickeys `drum/`（Freesound: Veiler，**CC0**） |

拟音特效 5 个（Freesound CC0 真实录音，`tool/import_foley_sounds.py` 从长录音切分）：

| # | 包名 | 中文名 | 素材来源（均为 CC0） |
|---|---|---|---|
| 18 | Sandpaper | 砂纸摩擦 | Freesound #726831（砂纸打磨录音，取 6-17s 摩擦段） |
| 19 | Chalk | 粉笔书写 | Freesound #378400（粉笔黑板书写，500Hz 高通滤除隆隆声后取 9-14s） |
| 20 | iPad Tap | iPad 点触 | Freesound #531501（触屏点按拟音，锚定检测出的 8 个点按瞬态） |
| 21 | Plastic Bag | 塑料袋揉搓 | Freesound #405014（塑料袋揉搓，取 10-36s 高质感段） |
| 22 | Straw Sip | 吸管喝水 | Freesound #699625（吸管吮吸，取 4-23s 段） |

各方案的按键映射（Tickeys schemes.json）：`36`=回车→enter 层、`49`=空格→space 层、`51`=退格→release 层，其余按键从变体池轮询映射到 alpha/modifier/nav。

**素材获取策略**（已完成）：
1. **现状**：22 包全部为真实录音素材——01-06/10 用 [kbsim](https://github.com/tplai/kbsim)（MIT）真实轴体录音，08 用 [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds)（CC0），07/09/11-17 用 [Tickeys](https://github.com/yingDev/Tickeys) 内置素材；导入脚本 `tool/import_real_sounds.py` + `tool/import_tickeys_sounds.py`，统一响度归一化。授权明细见 [assets/sounds/CREDITS.md](assets/sounds/CREDITS.md)。
2. **公开发布**：保留 Bubble 系（07/11）的 CC BY 3.0 署名即可；其余为 MIT/CC0，无附加要求。
3. **兜底**：实现「导入自定义音效包」（Sound Effects 页原型已有入口），用户可自带素材。

> 新增音效包的三处联动：`sound_pack.dart` 的 `kBuiltinPacks`、`pubspec.yaml` 的资源条目、导入脚本中的映射表；音频内容变更需提升 `sound_engine.dart` 中 `_extractAssets` 的 `assetVersion`。

---

## 6. 交互规格

### 托盘图标
- **左键**（默认）：轮换到下一个音效包 + 播放新包 Alpha 层采样作为听觉确认 + 菜单勾选态更新。可在设置改为「弹出 HUD」。
- **右键**：上下文菜单 = 22 个音效包（单选勾选态，选中即切换）＋ 分隔线 ＋「快速面板 HUD」＋「设置…」＋「退出」。
- Linux 差异：appindicator 下左右键可能无法区分（左键通常直接弹菜单）——菜单首项固定为「切换下一个音效」，保证行为可达。

### 托盘 HUD 弹窗（原型「TRAY HUD」，第二窗口）
340px 宽、无边框、置顶、失焦自动关闭；内容：引擎开关+延迟徽章、当前音效卡片（CURRENT 徽章、Strike 试听、波形可视化、音量/音高抖动滑杆）、音效包列表（勾选+试听）。

### 设置窗口（900×640 可调，关闭=隐藏）
侧边栏：Logo（Melody Keeeys / 旋律按键，替代原型中的 KeySound 字样）＋ 通用 / 音效 / 菜单栏 ＋ 底部（引擎状态、版本、**关于**）。
- **通用**：引擎状态头（延迟/音量）、开机自启、静默启动（启动进托盘不出窗）、智能静音应用列表（二期）、音频引擎通道说明卡、全局热键 ×2、Anti-Ghosting 滑杆、修饰键连发开关、底部「敲击测试」区、恢复默认。
- **音效**：10 包列表（延迟徽章、试听、ACTIVE 态）、当前包详情（描述+频谱可视化）、5 层按键层 tone 滑杆、DSP 引擎（音量补偿/音高抖动/松键音/缓冲预设）、打字沙盒（实时试音+计数）。
- **菜单栏**：左键行为绑定（轮换音效 / 弹出 HUD）、右键说明、滚轮微调音量（二期）、图标样式三选（一期仅 Minimal Capsule，另两个二期）、沙盒。
- **关于**：版本、开源许可、检查更新（存根）、GitHub 链接。

---

## 7. 里程碑

### M1 — 骨架与音频内核（可听）
- flutter create 三平台脚手架；DESIGN.md 色板/字体/组件 token 化，主题就位
- miniaudio FFI 接入三平台编译；导入脚本生成 22 包真实音效资源
- 应用内测试按钮播放 5 层采样；音量/音高/复音验证
- 验收：三平台运行，点按钮即时出声（复音 10/s 不丢音，体感延迟 <30ms）

### M2 — 全局监听与托盘（可用）★核心
- 三平台 key_hook 原生插件；键码→5 层分类；防抖/自动重复抑制；音高抖动
- macOS 辅助功能权限引导流；Windows 注入事件过滤；Linux evdev 监听与 input 组权限检测/指引
- tray_manager：左键轮换（听觉确认）、右键菜单（选择音效/设置/退出）、设置窗口关闭即隐藏
- 验收：真机全局打字出对应音效；托盘全交互可用；三平台一致

### M3 — 设置窗口与持久化（好用）
- 四 Tab 设置页按原型实现；shared_preferences 持久化；22 包元数据
- 开机自启、静默启动、全局热键（静音/轮换）
- 导入自定义音效包；恢复默认
- 验收：设置全项生效且重启保持；新用户 5 分钟内可完成首次配置

### M4 — HUD、静音名单与打包（可发布）
- desktop_multi_window HUD 弹窗（或单窗口回退方案）
- 前台应用检测实现「智能静音名单」（Zoom/游戏/DAW 自动静音）
- 打包分发：macOS .dmg（非沙盒 entitlements + 权限文档）、Windows 安装器（Inno Setup）、Linux AppImage/deb
- README：三平台安装与权限说明
- 验收：三平台安装包全新机器可装可跑；发布候选

### 二期池（原型中已有、暂不排期）
托盘图标动态样式（Audio Spectrum / Haptic Dot、打字呼吸动画）、滚轮音量微调、打字统计/热力图（今日敲击数、WPM、键位热区）、自定义包管理页、检查更新。

---

## 8. 关键风险与对策

| # | 风险 | 影响 | 对策 |
|---|---|---|---|
| R1 | macOS 辅助功能权限不通过则核心功能失效 | 高 | 首启引导页 + 状态实时检测 + 「重新检查」按钮；文档说明 |
| R2 | Linux 用户未加入 `input` 组则 evdev 无法读取键盘事件 | 中 | 应用内运行时检测 + 一键指引（`usermod -aG input $USER` 后重新登录）+ 重新检查按钮；未授权时 UI 明示且其余功能可用 |
| R3 | Linux 托盘左右键不分（appindicator） | 中 | 菜单首项「切换下一个音效」；设置页注明平台差异 |
| R4 | 音效素材授权风险 | 低 | 已全量替换为真实录音（kbsim MIT / Kenney CC0 / Tickeys MIT+CC0 / Freesound CC0 拟音），Bubble 系署名待保留；自定义包导入兜底 |
| R5 | FFI/C 构建跨三平台踩坑 | 中 | audio_engine.c 单文件 + 各平台 CMake/Xcode 标准接入；M1 即三平台 CI 编译验证 |
| R6 | desktop_multi_window HUD 通信不稳 | 低 | 回退单窗口 `setAsFrameless()` 模式切换方案 |
| R7 | 键击→出声端到端延迟超标 | 中 | MethodChannel 传码（微秒级）+ 内存预解码 + miniaudio 小 period；M1 建立延迟测量 |
| R8 | 键盘钩子自触发/循环 | 低 | Windows 过滤 INJECTED 位；macOS active tap 事件原样透传（不消费）；事件只上报不拦截 |

---

## 9. 实施偏差记录（按计划执行过程中的决策）

| 原计划 | 实际落地 | 原因 |
|---|---|---|
| 托盘 `tray_manager` 旧 Menu/TrayListener API | `tray_manager ^0.7.0`（基于 nativeapi 的 TrayIcon/Menu） | 0.6+ 重构为新 API，旧 API 已废弃 |
| 状态管理 Riverpod | 全局单例 `SoundEngine extends ChangeNotifier` + `ListenableBuilder` | 单窗口状态源简单直接，减少一层依赖 |
| 开机自启 `setAsLoginItemService` | `launch_at_startup` 0.5.x 的 `enable()/disable()` | 包 API 演进 |
| miniaudio 槽位：仅加载当前音效包 | 启动时预解码全部 22 包（132 段 × ~0.15s ≈ 5MB） | 切换/试听零延迟，内存可忽略 |
| `native/` 目录 | 移入 `plugins/native_core/macos/Classes/src/`（本地路径插件） | CocoaPods 拒收 pod 根之外的源文件；Windows/Linux CMake 改指同一路径，仍是单一副本 |
| miniaudio engine_config.periods | 仅设 periodSizeInFrames（0.11.25 无 periods 字段） | API 演进；延迟预设仍映射 mixer 更新粒度 |
| ae_* 符号 | `AE_API`(used+default visibility) + Swift `@_silgen_name("ae_version")` 锚定 | 死代码剥离会移除无人静态引用的 FFI 符号 |
| 首次运行 | silentStart 默认 false | 首次用户必须看到设置窗口完成权限授予 |
| 仅深色主题 | 浅色/深色/跟随系统三态（`uiTheme` 设置 + ThemeExtension 双色板，见 DESIGN.md） | 用户需求；浅色为同色系加深主色保证对比度 |
| 自绘托盘图标 | Lucide 图标 7 选 1（`trayIcon` 设置，默认 keyboard-music），qlmanage+色度键生成三变体 | 用户需求；旧自绘 256px 仅 about 页留用 |
| 侧边栏布局 | 全高侧边栏（红绿灯落在其顶部、与导航图标对齐），状态芯片移至右上顶栏 | 用户反馈：贯通 + 红绿灯对齐/不遮挡 |
| hotkey_manager 依赖 | 仍在（Carbon RegisterEventHotKey，无需辅助功能权限） | 评估过用钩子流自检组合键，暂不必要 |

## 10. 立即下一步
1. `flutter create . --project-name melody_keeeys --platforms=macos,windows,linux`（Dart 包名用下划线形式；各平台显示名配置为 Melody Keeeys / 旋律按键）+ 依赖安装
2. 主题 token 化（docs/prototypes/DESIGN.md → `lib/app/theme/`）
3. miniaudio FFI 三平台打通（M1 验收项）
