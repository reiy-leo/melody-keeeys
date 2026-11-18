Melody Keeeys（旋律键音）v0.2.1-alpha.1 测试版，主要是 Windows 版第一次能用。

**这一版改了什么**
- Windows 版终于能出包了：之前音频引擎在 MSVC 下编不过，CI 一直失败
- Windows 托盘左键能打开托盘面板了：之前面板窗口没注册插件，点了没反应；修好后又碰到首次点击闪退，一并修了
- Windows 设置窗口恢复系统标题栏，有关闭按钮，也能拖动；关闭只是收回托盘，不会退出
- Windows 高分屏下托盘面板贴着托盘图标弹出，不再跑偏
- 换了新的应用图标

**安装须知**
- Windows（x64）：解压后运行 `melody_keeeys.exe`，SmartScreen 提示时选「仍要运行」。
- macOS（Universal，12+）：未公证的 ad-hoc 签名。第一次打开请右键 → 打开，或运行 `xattr -cr "/Applications/Melody Keeeys.app"`；再到「系统设置 → 隐私与安全性 → 辅助功能」勾选应用。
- Linux 这一版还没有安装包，CI 构建仍在修。

---

**English** — Melody Keeeys v0.2.1-alpha.1: the first working Windows build. Left-clicking the tray icon opens the tray panel, the settings window has a normal title bar with a close button, and the panel sits next to the tray icon on high-DPI screens. New app icon. No Linux build yet.
