Melody Keeeys（旋律键音）v0.2.0 正式版。

**本版亮点**
- 多语言界面：简体中文、English、Español、Português、Русский、日本語、Deutsch、Français、Bahasa Indonesia，默认跟随系统，可在「通用 → 界面语言」切换
- macOS 原生菜单栏宿主：常驻时不再运行 Flutter 引擎，内存大幅下降；设置窗口按需打开、关闭即释放
- 设置窗口点击即显示；退出不再卡顿
- 未开启辅助功能权限时，托盘面板顶部会明确提醒「打字不会有任何声音」，一键跳转系统设置，勾选后约 2 秒自动生效，无需重启
- 新名称「旋律键音」与新应用图标；macOS 按系统语言显示应用名
- 右键菜单精简；托盘面板「正在使用」在浅色模式下更清晰

**安装须知**（附件以 macOS 为主；Windows/Linux 包若未附上，说明该平台 CI 构建尚未打通）
- macOS（Universal，12+）：未公证的 ad-hoc 签名。首次打开请右键 → 打开，或运行 `xattr -cr "/Applications/Melody Keeeys.app"`；然后在「系统设置 → 隐私与安全性 → 辅助功能」勾选应用。从旧版升级请先删掉列表里旧的条目再重新添加。
- Windows（x64）：解压后运行 `melody_keeeys.exe`，SmartScreen 提示时选「仍要运行」。
- Linux（x64）：解压后运行 `bundle/melody_keeeys`；需把用户加入 `input` 组（`sudo usermod -aG input $USER` 后重新登录）。

---

**English** — Melody Keeeys v0.2.0: 9 UI languages (follows your system), a native macOS menu-bar host with much lower memory use, an instant settings window, and a clear warning in the tray panel when Accessibility permission is off. macOS build is ad-hoc signed (not notarized): right-click → Open on first launch, then enable it under System Settings → Privacy & Security → Accessibility.
