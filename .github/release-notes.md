Melody Keeeys（旋律按键）测试版。

**本版改动**
- 设置界面的说明文字收进悬停提示（标题旁的 `?`），界面更干净
- 采样常驻内存约减半（f32 → s16），托盘面板不再另起一个音频引擎
- 按键不再触发整个界面重建；切换音效包立即出声

**安装须知**
- macOS（Universal，12+）：未公证的 ad-hoc 签名。首次打开请右键 → 打开，或运行 `xattr -cr melody_keeeys.app`；然后在「系统设置 → 隐私与安全性 → 辅助功能」勾选应用。每个新版本需要重新勾选一次。
- Windows（x64）：解压后运行 `melody_keeeys.exe`，SmartScreen 提示时选「仍要运行」。
- Linux（x64）：解压后运行 `bundle/melody_keeeys`；需把用户加入 `input` 组（`sudo usermod -aG input $USER` 后重新登录）。

Alpha 版本，可能有问题，欢迎提 issue。
