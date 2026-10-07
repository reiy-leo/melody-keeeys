# 音效素材来源与授权

## 内置音效包

| # | 音效包 | 素材来源 | 授权 |
|---|---|---|---|
| 01–10 | 清脆青轴 / 麻将音 / 圣熊猫轴 / 弹簧经典 / 凯华白盒 / 静电容 / 水泡泡 / 电子镭射 / 老式打字机 / 消音红轴 | `tool/make_placeholder_sounds.py` 程序化合成（占位素材，发布前替换） | 本项目自有（CC0 意向） |
| 11 | 咕噜气泡 Bubble | [Tickeys](https://github.com/yingDev/Tickeys) 内置素材（原始出处 Freesound，作者 [Glaneur de sons](https://freesound.org/people/Glaneur%20de%20sons/packs/6686/)） | CC BY 3.0（需署名） |
| 12 | 经典打字机 Typewriter | Tickeys 内置素材（随 MIT 仓库分发） | MIT（Tickeys 项目仓库） |
| 13 | 机械键盘 Mechanical | [Tickeys](https://github.com/yingDev/Tickeys) 内置素材（原始出处 Freesound，作者 [jim-ph](https://freesound.org/people/jim-ph/packs/12363/)） | **CC0（公共领域）** |
| 14 | 利剑出鞘 Sword | Tickeys 内置素材（随 MIT 仓库分发） | MIT（Tickeys 项目仓库） |
| 15 | 樱桃 G80-3000 | Tickeys 内置素材（随 MIT 仓库分发） | MIT（Tickeys 项目仓库） |
| 16 | 樱桃 G80-3494 | Tickeys 内置素材（随 MIT 仓库分发） | MIT（Tickeys 项目仓库） |
| 17 | 鼓点 Drum | [Tickeys](https://github.com/yingDev/Tickeys) 内置素材（原始出处 Freesound，作者 [Veiler](https://freesound.org/people/Veiler/packs/16053/)） | **CC0（公共领域）** |

Tickeys 项目本体：[github.com/yingDev/Tickeys](https://github.com/yingDev/Tickeys)，MIT License，© 2015 YingDev.com。

### 素材导入方式

7 个 Tickeys 音效由 `tool/import_tickeys_sounds.py` 一次性导入，把 Tickeys 的按键音频映射到本项目固定的 6 层结构（alpha/space/enter/modifier/nav/release）：

```bash
git clone --depth 1 https://github.com/yingDev/Tickeys /tmp/tickeys
python3 tool/import_tickeys_sounds.py /tmp/tickeys/Tickeys.app/Contents/Resources/data
```

映射依据 Tickeys 的 `schemes.json`：`36`=回车、`49`=空格、`51`=退格，其余按键从变体池轮询。release 层由真实素材裁剪前 0.10s 并加 0.05s 淡出得到，保持同一素材质感。

> 若后续公开发布：Bubble 素材为 CC BY 3.0，需在应用内「关于」页或文档中保留 "Glaneur de sons (Freesound)" 署名；其余 Tickeys 素材来自 MIT 仓库，随附本说明文件即可满足要求。详细逐文件授权记录见 Tickeys 仓库内的 `data/*/license.txt`。
