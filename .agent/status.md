# 项目现状（交接用）

新 session 先读这份，再按需翻 `AGENTS.md`（工程规则和踩过的坑）、`DESIGN.md`（设计系统）、`PLAN.md`（最初的产品定义和里程碑）。这份只讲「现在到哪了、还欠什么、代码大致怎么组织」，细节以那几份为准。

更新于 2026-11-02，对应 tag `v0.2.0`（`e92fa85`）之后只改了文档。

## 一、项目是什么

- **Melody Keeeys（中文名：旋律键音）**，仓库 `reiy-leo/melody-keeeys`（公开）。菜单栏键盘音效应用：全局监听键盘，按当前音效包给每次按键配音。
- 技术栈：Flutter 桌面 3.47.7 + C 音频引擎（miniaudio）+ 三平台各自的原生键盘钩子（macOS CGEventTap、Windows WH_KEYBOARD_LL、Linux evdev），都在本地插件 `plugins/native_core/`。
- 内置 22 个音效包，每包 6 层采样（alpha / space / enter / modifier / nav / release），全是真实录音，授权见 `assets/sounds/CREDITS.md`。
- 目标平台 macOS、Windows、Linux。**目前只有 macOS 能出包**，Windows / Linux 的 CI 构建一直失败。
- Rei 的开发机是 2018 款 Intel MacBook Pro（最高 macOS 15），用 MacPorts，不用 Homebrew。
- 图标默认用 Lucide；界面支持 9 种语言，默认跟随系统。

## 二、版本和分支

- 当前版本 `0.2.0+5`，tag `v0.2.0`，2026-10-24 发布的第一个正式版，只附 macOS Universal 包（ad-hoc 签名，没公证）。
- 历史 tag：`v0.1.0`、`v0.2.0-alpha.1` 到 `alpha.3`。tag 带 `-` 的自动标成预发布。
- 只有 `main` 一个分支，没有 worktree，直接在 `main` 上开发。
- `v0.2.0` 之后 `main` 上没有新提交。
- **发版前必须先问 Rei**，不要自己打 tag（Rei 2026-10-23）。普通提交可以直接推 `main`。

## 三、已经做完的功能

| 模块 | 现状 | 细节 |
|---|---|---|
| 音频引擎 | C + miniaudio，启动时把 22 包全部解码成 s16@48kHz 常驻（约 6MB），切包只换索引；音高抖动、音量补偿、三档延迟预设 | AGENTS.md「热路径性能约定」 |
| 键盘钩子 | 三平台原生钩子；macOS 用 active tap（不能用 listen-only），没授权时每 2 秒重试 | AGENTS.md「tap 必须是 active tap」 |
| 按键分类 | 键码 → 5 层；防连击（Anti-Ghosting）、修饰键连发、松键音 | `lib/core/hooks/keymap_classifier.dart` |
| macOS 原生宿主 | 菜单栏、钩子、音频、热键、设置读写、开机自启全在 Swift 里常驻；Flutter 只在打开设置窗时启动，关窗就销毁引擎 | AGENTS.md「macOS 原生宿主」 |
| 托盘面板 | macOS 是原生 SwiftUI（`HudView.swift`）；Windows / Linux 还是 Flutter 第二窗口 | AGENTS.md「HUD 定位」「HUD 显示流程」 |
| 辅助功能提醒 | 没授权时托盘面板顶部显示橙色提醒「不开启时打字不会有任何声音」+「去开启权限」按钮；左键改成打开面板；授权后约 2 秒自动恢复 | 提交 `655477f` |
| 设置窗口 | 通用 / 音效 / 菜单栏 / 关于四页；说明文字都收进 tooltip；点了立刻出窗（先画主题底色，Flutter 冷启动 2–3 秒后填内容） | AGENTS.md「说明文案一律进 tooltip」，提交 `bfc8b90`、`b51f3d9` |
| 主题 | 浅色 / 深色 / 跟随系统 | DESIGN.md |
| 托盘图标 | Lucide 图标 7 选 1，默认 keyboard-music | `tool/make_lucide_tray_icons.py` |
| 右键菜单 | 当前音效、声音引擎开关、托盘面板、设置、退出（不再列音效包）；退出立即生效 | 提交 `3ce7027` |
| 启动和关窗 | 启动只进菜单栏，缺权限才弹设置；关设置窗不退出 | AGENTS.md「菜单栏常驻」 |
| 全局热键 | Option+Shift+K 静音，Option+Shift+] 轮换 | `lib/core/system/hotkey_service.dart`，macOS 在 `MelodyHost.swift` |
| 多语言 | zh / en / es / pt / ru / ja / de / fr / id，默认跟随系统，「通用 → 界面语言」可切；Dart 和 Swift 共用一张表 | AGENTS.md「多语言」 |
| 品牌 | 中文名「旋律键音」、新应用图标；macOS 产物 `Melody Keeeys.app`，中文系统里访达显示「旋律键音」 | AGENTS.md「应用名与图标」 |
| 发版流水线 | 推 `v*` tag → 三平台构建 → macOS 成功就建 Release；push `main` 另有只编译不发版的 macOS 检查 | `.github/workflows/` |

## 四、代码地图

| 路径 | 内容 |
|---|---|
| `lib/main.dart` | 入口。macOS（`kNativeHost`）只跑设置页；Windows / Linux 跑托盘、引擎、HUD 全套 |
| `lib/app/` | 设置窗口壳 `settings_app.dart`、四个设置页 `features/`、主题 `theme/`、生命周期 `app_lifecycle.dart` |
| `lib/core/audio/` | `audio_engine_ffi.dart`（FFI 绑定）、`sound_pack.dart`（22 包元数据）、`sound_engine.dart`（引擎控制；macOS 上是经 `melody/host` 通道的瘦客户端） |
| `lib/core/hooks/` | 三平台键码表和分类 |
| `lib/core/i18n/i18n.dart` | `tr()` |
| `lib/core/settings/` | `AppSettings` 和持久化（加字段要改 `copyWith / toJson / fromJson` 三处） |
| `lib/core/tray/` | Windows / Linux 托盘（tray_manager 0.7） |
| `lib/features/hud/` | Windows / Linux 的 Flutter 托盘面板 |
| `lib/shared/` | 公共组件、debug 截图工具 |
| `plugins/native_core/macos/Classes/` | `MelodyHost.swift`（macOS 常驻宿主，约 1000 行）、`HudView.swift`（原生面板）、`NativeCorePlugin.swift`、`src/`（C 引擎，三平台唯一副本） |
| `plugins/native_core/windows/`、`linux/` | 键盘钩子 |
| `macos/Runner/` | `AppDelegate.swift`、`MainFlutterWindow.swift`（`SettingsWindowHost` 按需建引擎、手动注册插件）、本地化应用名 |
| `assets/sounds/` | 132 个 WAV + `packs.json`（宿主读的清单） |
| `assets/i18n/strings.json` | 生成产物，别手改 |
| `tool/` | `i18n_source.py`（语言源头）、`gen_packs_json.py`、`make_app_icons.py`、音效导入脚本、C 引擎冒烟测试 |
| `test/packs_manifest_test.dart` | 校验 `packs.json` 和 `kBuiltinPacks` 一致 |
| `packaging/windows-setup.iss` | Windows 安装器脚本 |

## 五、开发和验证规矩

1. 改代码前读 `AGENTS.md`，尤其是托盘三个坑、辅助功能授权、HUD 显示流程这几节。
2. 提交前 `flutter analyze`。目前剩一条旧警告：`plugins/native_core/analysis_options.yaml` 引用的 `flutter_lints` 不在依赖里，不是新问题。
3. 用户看得到的文案一律写进 `tool/i18n_source.py`，9 种语言占位符一致，改完跑 `python3 tool/i18n_source.py`。不要在 Dart 或 Swift 里写死文案。
4. 改音效包：同时改 `sound_pack.dart`、`pubspec.yaml`，跑 `python3 tool/gen_packs_json.py`；素材变了把 `sound_engine.dart` 里的 `assetVersion` 加一（现在是 `'7'`，只影响 Windows / Linux）。
5. macOS 新增插件要手动加进 `MainFlutterWindow.swift` 的 `registerPlugins`。
6. 沙箱只能跑 `flutter analyze` 和 `flutter test`，编不了 macOS。macOS 编译看 CI 的「macOS build check」，真机效果要 Rei 本地 build。
7. 沙箱里 `flutter pub get` 会把 `pubspec.lock` 改成国内镜像地址，提交前 `git checkout pubspec.lock`。`dart format` 只格式化自己改过的文件。
8. 提交作者用 `Ryan Lincs <ryan.lincs@outlook.com>`，加 `-c commit.gpgsign=false`。
9. 发版：先问 Rei → 改 `pubspec.yaml` 版本号、关于页版本、`.github/release-notes.md` → 打 tag 推送。新工作流和 tag 不要同一次推。

Rei 本地构建：

```bash
cd /Users/apple/Documents/Playgrounds/melody-keeeys
git pull origin main
flutter clean && flutter pub get
flutter build macos --release
```

CocoaPods 装在 MacPorts 的 ruby33 下（`gem install cocoapods`）。本地重新 build 后，辅助功能授权可能失效，要在系统设置里删掉旧条目再勾一次。

## 六、没做完的事

### 等 Rei 动手

- **贴 Windows / Linux 的构建日志**。CI 从 alpha.1 起就在 build 步骤失败，日志要登录才能看，我们拿不到。
- **实测 macOS 常驻内存**。原生宿主改造后预计 20–30MB（原来约 120MB），一直没拿到实测数字。
- **重拍 README 截图**。现在的截图是 tooltip 改造前的，托盘面板也换成原生了。
- **看一下德 / 俄 / 法文布局**，以及翻译有没有错（AI 翻的，没有母语校对）。

### 等 Rei 拍板

- **macOS 公证**：要 Apple Developer Program 付费账号，以及是否值得做。
- **智能静音名单**（Zoom、游戏、DAW 在前台时自动静音）：设置页现在只有一张「即将推出」的卡片。做不做、先做哪个平台。
- **「打字机·变奏」换录音**：现在和「经典打字机」是同一台机器的录音，2026-10-23 问过要不要换，Rei 没回。
- **自定义音效包导入**：PLAN 里 M3 写了，但没实现。
- **Windows / Linux 还要不要继续跟**：macOS 换成原生宿主后，三平台的代码已经分成两套架构。

### 我们能做的

- 收拾过时的文档（见第八节）。
- 在沙箱里试着 `flutter build linux` 复现 Linux CI 的失败（沙箱是 aarch64，CI 是 x64，结果仅供参考）。
- `plugins/native_core/analysis_options.yaml` 那条旧警告：去掉 `flutter_lints` 引用或补依赖。
- 关于页的版本号现在是手写的（`about_page.dart`），可以改成从 `pubspec` 读取。

## 七、写了但没真机验证的

这些 CI 都编译通过了，但 Rei 还没在本机确认：

- 原生宿主的常驻内存，以及长时间运行稳不稳。
- 设置窗点了立刻出窗（`b51f3d9`），以及卡住超过 4 秒自动重建引擎（`bfc8b90`）。
- 退出立即生效（`3ce7027`）。
- 开机自启（原生宿主里改走 SMAppService，macOS 13+）。
- 原生宿主里的全局热键。
- 9 种语言切换是否即时、托盘面板和右键菜单是否同步，长文案会不会挤。
- 辅助功能提醒：Rei 确认过「没声音是权限没开」，但提醒横幅本身还没反馈。
- Windows / Linux：所有 2026-10-22 之后的改动都没在这两个平台上跑过。

## 八、文档里待确认的点

2026-11-02 已按审核清理过 AGENTS.md、README、PLAN 里的过时内容（构建环境改成 MacPorts、收尾清单、README 平台要求和架构、PLAN 的右键菜单和静默启动等）。还剩两处要问 Rei：

- `AGENTS.md`「辅助功能授权稳定性」说用 Apple Development 证书签名（team `EHBQV2H8YV`）后重建不掉授权，但 2026-10-24 Rei 本地重建后还是掉了，可能这台机器上没有那张证书。已在原文标「待确认」。
- `AGENTS.md`「已知环境问题」里 1Password SSH agent 故障、origin 切 HTTPS，是 2026-10-07 Rei 本机的情况，现在还在不在不清楚，已标出。

## 九、仓库外的东西

| 东西 | 在哪 |
|---|---|
| 沙箱里的仓库 | `/workspace/projects/c70d74dc-3c40-4b74-8532-e623287b9467/repo` |
| Rei 本机的仓库 | `/Users/apple/Documents/Playgrounds/melody-keeeys` |
| 沙箱 Flutter | `/workspace/work/flutter`（3.47.7，aarch64 Linux）。跑命令前设 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn PUB_HOSTED_URL=https://pub.flutter-io.cn`（`storage.googleapis.com` 在沙箱里 403）。丢了就重装：从 `https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz` 下载，用 Python `lzma` 解压后 `tar x -C /workspace/work`，删掉 `bin/cache`。别解到 `/tmp`（内存盘，会 OOM） |
| 推送用的 deploy key | `/workspace/.keys/melody-keeeys_deploy`（有写权限），通过 `/workspace/.keys/pyssh.py` 推，需要 `pip install paramiko`：`GIT_SSH_COMMAND="python3 /workspace/.keys/pyssh.py -i /workspace/.keys/melody-keeeys_deploy"`，remote `git@github.com:reiy-leo/melody-keeeys.git` |
| GitHub connector | 只读（看 CI 运行和 Release），推不了；目前已断开，要看 CI 结果得重新连 |
| CI | GitHub Actions：`macos-check.yml`（push `main` 时编译 macOS，产物作为 artifact）、`release.yml`（推 tag 时发版） |
| 音效素材来源 | kbsim、Tickeys、Kenney、Freesound，导入时克隆到 `/tmp`，用完就没了，重新导入按 `CREDITS.md` 再克隆 |
| 部署 | 没有网站，也没有服务器 |
