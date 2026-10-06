# DESIGN.md — Melody Keeeys 设计系统（实现版）

本文档描述**已实现**的设计系统。Stitch 原始设计稿与色板推导见 [docs/prototypes/DESIGN.md](docs/prototypes/DESIGN.md)。

## 主题

支持三态：**浅色 / 深色 / 跟随系统**（`UiTheme`，默认跟随系统），在「通用 → 外观主题」切换，即时生效并持久化；托盘 HUD 弹窗跟随主窗口实时联动。

- 色板：`lib/app/theme/app_colors.dart`，`AppColors extends ThemeExtension`，`AppColors.dark` / `AppColors.light` 两套实例，组件统一用 `context.colors.xxx` 解析。
- ThemeData：`lib/app/theme/app_theme.dart` 的 `buildAppTheme(Brightness)`，同时注册 ColorScheme 与扩展；**所有文字样式显式绑定 `onSurface`**。

## 色板 token

| Token | 深色 | 浅色 | 用途 |
|---|---|---|---|
| `surfaceDim` | `#0C0B12` | `#F2F0F9` | 窗口沟槽 |
| `surface` | `#12111A` | `#FBFAFE` | 画布底 |
| `containerLow` | `#1A1826` | `#F3F1FA` | 侧边栏 / 分组底 |
| `container` | `#232034` | `#ECE9F6` | 卡片 / 交互行 |
| `containerHigh` | `#2C2941` | `#E4E1F0` | 悬停 / HUD 底 |
| `containerHighest` | `#36324E` | `#DAD6EA` | 滑杆槽 / 徽章底 |
| `onSurface` | `#E5E0EE` | `#1A1827` | 主文字 |
| `onSurfaceVariant` | `#CAC4D4` | `#494562` | 次要文字 |
| `primary` | `#A78BFA` | `#6D4AD6` | Electric Lavender，主操作（浅色加深保对比） |
| `onPrimary` | `#12111A` | `#FFFFFF` | 主色上的文字 |
| `primaryContainer` | `#4F319C` | `#E7DEFF` | 标签徽章底 |
| `secondary` | `#F472B6` | `#C2297F` | Neon Pink，音高/次强调 |
| `tertiary` | `#38BDF8` | `#0C7FA6` | Acoustic Cyan，延迟/实时指标 |
| `error` | `#FFB4AB` | `#BA1A1A` | 错误 |
| `success` | `#4ADE80` | `#1B8A3F` | 运行状态点 |
| `ghostBorder` | white 6% | black 8% | 卡片 1px 幽灵描边 |
| `hoverLayer` | white 8% | black 4% | 悬停状态层 |

## 形状 / 间距 / 字体

- 圆角：`AppRadii` — sm 8（图标底）、md 16（键帽容器/行）、lg 20（Section 卡/HUD）、xl 32（大卡）、pill 999（按钮/导航/芯片）。
- 间距：`AppSpacing` 4/8/12/16/24/32。
- 字体：Space Grotesk（标题/标签/数字，400-700）+ Plus Jakarta Sans（正文，400-700），TTF 打包于 `assets/fonts/`（勿用 google_fonts 运行时下载）。文字样式见 `AppText`，样式不带颜色（颜色由主题注入）。

## 布局

设置窗口（默认 1020×700，隐藏原生标题栏，`LSUIElement` 应用）：

```
┌──────────┬──────────────────────────────┐
│ ●●●      │ 🎹 Melody Keeeys·旋律按键  芯片×3│ ← 顶栏（右列），可拖拽
│ 通用      ├──────────────────────────────┤
│ 音效      │                              │
│ 菜单栏    │        内容列（4 页）          │
│ …spacer  │                              │
│ 引擎状态  │                              │
│ 关于      │                              │
└──────────┴──────────────────────────────┘
```

- 侧边栏全高贯通；macOS 红绿灯落在其顶部，与导航图标列对齐（图标中心 x≈26 对齐第一颗灯），tabs 紧贴红绿灯下方（顶部留 34px）。
- 状态芯片（延迟 / 钩子 / 音量 dB）靠右。

## 组件（lib/shared/widgets/app_widgets.dart）

- `SectionCard`：图标章 + 标题 + 可选徽章/副标题 + 内容，containerLow 底 + 幽灵描边 + lg 圆角。
- `SettingsRow`：图标 + 标题/副标题 + trailing 控件。
- `AppSlider`：标签行（左标题右 mono 值徽章）+ 8px 轨道滑杆，`accent` 可选（默认 primary）。
- `PillButton`：胶囊主按钮（danger 变体灰底红字）。
- `MetricChip`：mono 等宽读数芯片（延迟、热键、dB）。
- 选择器模式：胶囊分段三态（外观主题）与描边卡片网格（托盘图标、左键行为）。

## 托盘图标

Lucide 图标 7 选 1（`kTrayIcons`，默认 `keyboard-music`）：keyboard、keyboard-music、command、line-squiggle、gamepad-directional、tv、balloon。由 `tool/make_lucide_tray_icons.py` 生成三变体：`tray_<id>_template.png`（44px 黑，macOS template 自动适配菜单栏深浅）、`tray_<id>_colored.png`（32px 薰衣草，Win/Linux）、`tray_<id>_preview.png`（72px，设置页预览）。换图标即时生效。

## HUD 弹窗

340×560 无边框置顶窗，定位在托盘图标正下（macOS）/正上（Windows 任务栏）；失焦自动隐藏。结构：TRAY HUD 头 → 引擎开关条（延迟徽章）→ 当前音效卡（CURRENT 描边 + Strike 试听）→ 10 包列表（序号/名称/中文标签/试听）→ 打开设置。主题跟随主窗口推送。
