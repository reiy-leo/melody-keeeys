# 音效素材来源与授权

所有 17 个内置音效包均使用**真实录音素材**（非合成），并已统一做响度归一化（RMS 对齐，峰值限幅）。

## 01-10：原型音效包（真实录音）

| # | 音效包 | 素材来源 | 授权 |
|---|---|---|---|
| 01 | 清脆青轴 Cherry MX Blue | [kbsim](https://github.com/tplai/kbsim) `mxblue/` | MIT (c) Thomas Lai |
| 02 | 麻将音 Gateron Oil King | [kbsim](https://github.com/tplai/kbsim) `blackink/` | MIT (c) Thomas Lai |
| 03 | 圣熊猫轴 Holy Panda | [kbsim](https://github.com/tplai/kbsim) `holypanda/` | MIT (c) Thomas Lai |
| 04 | 弹簧经典 IBM Model M | [kbsim](https://github.com/tplai/kbsim) `buckling/` | MIT (c) Thomas Lai |
| 05 | 凯华白盒 Kailh Box White | [kbsim](https://github.com/tplai/kbsim) `boxnavy/` | MIT (c) Thomas Lai |
| 06 | 静电容 Topre Electrostatic | [kbsim](https://github.com/tplai/kbsim) `topre/` | MIT (c) Thomas Lai |
| 07 | 水泡泡 Bubble Pop | [Tickeys](https://github.com/yingDev/Tickeys) `bubble/`（Freesound: Glaneur de sons） | CC BY 3.0（需署名） |
| 08 | 电子镭射 Sci-Fi Laser | [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | **CC0（公共领域）** |
| 09 | 老式打字机 Typewriter 1930s | [Tickeys](https://github.com/yingDev/Tickeys) `typewriter/` | MIT（随仓库分发） |
| 10 | 消音红轴 Silent Red | [kbsim](https://github.com/tplai/kbsim) `redink/` | MIT (c) Thomas Lai |

## 11-17：Tickeys 效果包（真实录音）

| # | 音效包 | 素材来源 | 授权 |
|---|---|---|---|
| 11 | 咕噜气泡 Bubble | Tickeys `bubble/`（Freesound: [Glaneur de sons](https://freesound.org/people/Glaneur%20de%20sons/packs/6686/)） | CC BY 3.0（需署名） |
| 12 | 经典打字机 Typewriter | Tickeys `typewriter/` | MIT（随仓库分发） |
| 13 | 机械键盘 Mechanical | Tickeys `mechanical/`（Freesound: [jim-ph](https://freesound.org/people/jim-ph/packs/12363/)） | **CC0（公共领域）** |
| 14 | 利剑出鞘 Sword | Tickeys `sword/` | MIT（随仓库分发） |
| 15 | 樱桃 G80-3000 | Tickeys `Cherry_G80_3000/` | MIT（随仓库分发） |
| 16 | 樱桃 G80-3494 | Tickeys `Cherry_G80_3494/` | MIT（随仓库分发） |
| 17 | 鼓点 Drum | Tickeys `drum/`（Freesound: [Veiler](https://freesound.org/people/Veiler/packs/16053/)） | **CC0（公共领域）** |

## 18-22：拟音特效包（Freesound CC0 真实录音）

由 `tool/import_foley_sounds.py` 从长录音中切分生成（每层选取不同的时间段，避免连击重复感；自动锚点定位 + 高通滤波 + 响度归一化）。

| # | 音效包 | 素材来源（Freesound，均为 CC0 1.0） |
|---|---|---|
| 18 | 砂纸摩擦 Sandpaper | [#726831](https://freesound.org/s/726831/) 砂纸打磨录音（取 6-17s 摩擦段） |
| 19 | 粉笔书写 Chalk | [#378400](https://freesound.org/s/378400/) 粉笔黑板书写（500Hz 高通滤除隆隆声） |
| 20 | iPad 点触 iPad Tap | [#531501](https://freesound.org/s/531501/) 触屏点按拟音（锚定 8 个点按瞬态） |
| 21 | 塑料袋揉搓 Plastic Bag | [#405014](https://freesound.org/s/405014/) 塑料袋揉搓（取 10-36s 高质感段） |
| 22 | 吸管喝水 Straw Sip | [#699625](https://freesound.org/s/699625/) 吸管吮吸（取 4-23s 段） |

## 第三方项目

- [kbsim](https://github.com/tplai/kbsim) — MIT License, Copyright (c) Thomas Lai
- [Tickeys](https://github.com/yingDev/Tickeys) — MIT License, Copyright (c) 2015 YingDev.com
- [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) — CC0 1.0, Kenney (www.kenney.nl)

## 导入方式

```bash
# 克隆素材源
git clone --depth 1 https://github.com/tplai/kbsim /tmp/kbsim
git clone --depth 1 https://github.com/yingDev/Tickeys /tmp/tickeys
curl -L -o /tmp/kenney_scifi.zip "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip"
unzip -q /tmp/kenney_scifi.zip -d /tmp/kenney_scifi

# 01-10（kbsim 真实键盘录音 + Kenney 激光 + Tickeys 打字机/气泡）
python3 tool/import_real_sounds.py \
    --kbsim /tmp/kbsim/src/assets/audio \
    --kenney /tmp/kenney_scifi/Audio \
    --tickeys /tmp/tickeys/Tickeys.app/Contents/Resources/data

# 11-17（Tickeys 效果包）
python3 tool/import_tickeys_sounds.py /tmp/tickeys/Tickeys.app/Contents/Resources/data

# 18-22（拟音特效：从 Freesound 下载 mp3 到 /tmp/newfx，见下方链接）
python3 tool/import_foley_sounds.py --src /tmp/newfx
```

三个脚本都会把源素材转成 48 kHz 16-bit WAV、映射到本项目 6 层结构（alpha/space/enter/modifier/nav/release），并做响度归一化（RMS 目标 2500，峰值上限 32000）。release 层由真实素材裁剪前 0.10s + 0.05s 淡出得到。

**新增/变更素材后**需提升 `lib/core/audio/sound_engine.dart` 中 `_extractAssets` 的 `assetVersion`，已安装实例才会刷新 WAV。

> 公开发布注意事项：Bubble / 咕噜气泡 / 水泡泡 使用了 CC BY 3.0 素材（Glaneur de sons，Freesound），需在应用内「关于」页或随附文档保留署名；kbsim 与 Tickeys 素材为 MIT，随附本说明文件即满足要求；Kenney 素材为 CC0，无强制要求（建议署名）。
