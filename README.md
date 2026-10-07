# Melody Keeeys · 旋律按键

跨平台键盘音效应用 —— 让每一次敲击都有声音。macOS / Windows / Linux 菜单栏（托盘）常驻，全局监听键盘，按当前音效包实时播放对应按键音。

> 实施计划见 [PLAN.md](PLAN.md)；Google Stitch 原型与设计系统归档在 [docs/prototypes/](docs/prototypes/)。

## 功能（当前进度）

- **M1 音频内核** ✅ miniaudio + dart:ffi，17 个内置音效包 × 6 层采样（alpha/space/enter/modifier/nav/release），内存预解码、复音播放、音高抖动、音量补偿、三档延迟预设
- **M2 全局监听与托盘** ✅ macOS CGEventTap / Windows WH_KEYBOARD_LL / Linux evdev；键码→5 层分类、Anti-Ghosting 抑制窗口、修饰键连发、松键音；托盘左键轮换音效（听觉确认）、右键菜单选择音效/设置/退出
- **M3 设置窗口** ✅ 侧边栏四页（通用 / 音效 / 菜单栏 / 关于），设置持久化，开机自启，静默启动，全局热键（静音、轮换）
- **主题** ✅ 浅色 / 深色 / 跟随系统三态，通用页切换即时生效，HUD 跟随；双色板 ThemeExtension（见 [DESIGN.md](DESIGN.md)）
- **托盘图标** ✅ Lucide 图标 7 选 1（keyboard / keyboard-music / command / line-squiggle / gamepad-directional / tv / balloon，默认 keyboard-music），菜单栏页选择即时生效
- **M4 HUD 与打包** ✅ 托盘 HUD 弹窗（第二窗口，失焦自动隐藏）、Windows Inno Setup 脚本；⏳ 智能静音应用名单（二期）、应用图标打磨、macOS 公证

## 各平台构建

```bash
flutter pub get
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d linux     # Linux
```

### 平台要求

| 平台 | 要求 |
|---|---|
| macOS 10.15+ | 首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中勾选应用（应用内有一键引导；应用用开发证书签名，辅助功能授权跨重新构建保持有效） |
| Windows 10+ | 无需管理员权限 |
| Linux | 需要 `libgtk-3-dev libx11-dev libxi-dev` 构建依赖；运行时需将用户加入 `input` 组（`sudo usermod -aG input $USER` 后重新登录） |

> 本机（Intel macOS）构建注意：CocoaPods 需通过 `brew install ruby` + `gem install cocoapods` 安装，构建前把 `/usr/local/lib/ruby/gems/4.0.0/bin` 加入 PATH，详见 [AGENTS.md](AGENTS.md)。

### 打包

```bash
# macOS
flutter build macos --release        # 产物 build/macos/Build/Products/Release/
# Windows（先构建，再用 Inno Setup 编译安装器）
flutter build windows --release
iscc packaging/windows-setup.iss
# Linux
flutter build linux --release        # 产物 build/linux/x64/release/bundle/
```

## 架构速览

```
lib/
  main.dart            # 入口：托盘、引擎、窗口、HUD 第二窗口
  app/                 # 主题 token（docs/prototypes/DESIGN.md）+ 设置窗口四页
  core/
    audio/             # miniaudio FFI 封装、音效包模型、引擎控制器
    hooks/             # 键码 → 5 层分类器（三平台码表）
    tray/              # 托盘服务（nativeapi TrayIcon）
    settings/          # 设置模型与持久化
    system/            # 全局热键
  features/hud/        # 托盘 HUD 弹窗
plugins/native_core/   # 本地插件：C 音频引擎 + 三平台键盘钩子
assets/sounds/         # 占位音效（tool/make_placeholder_sounds.py 生成）
```

- **音频**：`plugins/native_core/macos/Classes/src/audio_engine.c`（miniaudio 单头库）编译为独立动态库，Dart 通过 `dart:ffi` 调用；槽位 = 包序号 × 6 + 层序号。
- **键盘钩子**：原生层只上报 `{code, down, repeat, ts}`，分类与调参全部在 Dart（`lib/core/hooks/keymap_classifier.dart`）。
- **音效素材**：前 10 包为程序化合成占位音（发布前替换为 CC0 录音或自录素材）；11-17 包为 Tickeys 真实素材（授权与来源见 [assets/sounds/CREDITS.md](assets/sounds/CREDITS.md)）。

## 重新生成资产

```bash
python3 tool/make_placeholder_sounds.py    # 占位音效（前 10 包；Tickeys 7 包用 import_tickeys_sounds.py）
python3 tool/make_lucide_tray_icons.py     # Lucide 托盘图标（7 图标 × 3 变体）
python3 tool/make_tray_icons.py            # 旧版自绘图标（about 页 256px 仍在用）
```

> AI 代理请阅读 [AGENTS.md](AGENTS.md)；设计系统实现细节见 [DESIGN.md](DESIGN.md)。
