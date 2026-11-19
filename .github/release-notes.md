Melody Keeeys（旋律键音）v0.2.1-alpha.2 测试版，主要修 Windows 托盘面板。

**这一版改了什么**
- Windows 托盘面板里的按钮点了没反应：原因是同时开了两个实例、连点托盘叠出两个面板。现在只允许运行一个实例，面板也只会有一个
- Windows 托盘面板点别处就收起，不再一直挂在桌面上
- Windows 托盘面板四个角都是圆角，之前上面两个角是直角
- Windows 下界面字体跟着语言走：中文用微软雅黑 UI，日文用 Yu Gothic UI，其他语言用 Segoe UI Variable

**安装须知**
- Windows（x64）：解压后运行 `melody_keeeys.exe`，SmartScreen 提示时选「仍要运行」。
- macOS（Universal，12+）：未公证的 ad-hoc 签名。第一次打开请右键 → 打开，或运行 `xattr -cr "/Applications/Melody Keeeys.app"`；再到「系统设置 → 隐私与安全性 → 辅助功能」勾选应用。
- Linux 这一版还没有安装包，CI 构建仍在修。

---

**English** — Melody Keeeys v0.2.1-alpha.2: Windows tray panel fixes. Only one app instance runs and the tray no longer stacks duplicate panels, so buttons in the panel respond again. The panel now closes when you click elsewhere and has all four corners rounded. On Windows the UI font follows the language (Microsoft YaHei UI, Yu Gothic UI, Segoe UI Variable). No Linux build yet.
