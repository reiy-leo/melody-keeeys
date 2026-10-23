Melody Keeeys（旋律键音）测试版。

**本版改动**
- 内存优化：关闭设置窗口后彻底释放界面和图形缓冲；菜单栏面板（HUD）闲置 30 秒自动释放，下次点击图标重新打开
- 音效名称按实际录音校准：麻将音 → 黑墨轴（Gateron Black Ink）、凯华白盒 → 凯华海军蓝（Kailh Box Navy）、消音红轴 → 墨红轴（Gateron Red Ink）、老式打字机 → 打字机·变奏
- 修正采样：青轴空格/回车不再与普通键同一声；水泡泡导航键不再与空格重复；iPad 点触去掉约 60ms 起音延迟；吸管喝水修饰键不再只有底噪
- 已保存的音效选择不受改名影响，升级后音效素材会自动刷新

**安装须知**（本版附件以 macOS 为主；Windows/Linux 包若未附上，说明该平台 CI 构建尚未打通）
- macOS（Universal，12+）：未公证的 ad-hoc 签名。首次打开请右键 → 打开，或运行 `xattr -cr "/Applications/Melody Keeeys.app"`；然后在「系统设置 → 隐私与安全性 → 辅助功能」勾选应用。每个新版本需要重新勾选一次。
- Windows（x64）：解压后运行 `melody_keeeys.exe`，SmartScreen 提示时选「仍要运行」。
- Linux（x64）：解压后运行 `bundle/melody_keeeys`；需把用户加入 `input` 组（`sudo usermod -aG input $USER` 后重新登录）。

Alpha 版本，可能有问题，欢迎提 issue。
