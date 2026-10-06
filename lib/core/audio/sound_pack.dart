/// The five physical key layers a keystroke maps to, plus the optional
/// key-release sample. Mirrors the prototype's "Physical Acoustic Key-Layers".
enum SoundLayer { alpha, space, enter, modifier, nav, release }

extension SoundLayerX on SoundLayer {
  String get assetName => switch (this) {
        SoundLayer.alpha => 'alpha',
        SoundLayer.space => 'space',
        SoundLayer.enter => 'enter',
        SoundLayer.modifier => 'modifier',
        SoundLayer.nav => 'nav',
        SoundLayer.release => 'release',
      };

  /// Per-layer playback gain applied on top of master volume.
  double get baseGain => switch (this) {
        SoundLayer.space => 1.15,
        SoundLayer.enter => 1.2,
        SoundLayer.modifier => 0.65,
        SoundLayer.nav => 0.85,
        SoundLayer.release => 0.4,
        SoundLayer.alpha => 1.0,
      };
}

class SoundPack {
  const SoundPack({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
  });

  final String id;
  final String name;
  final String tag;
  final String description;

  String assetPathFor(SoundLayer layer) => 'sounds/$id/${layer.assetName}.wav';

  SoundPack copyWith({String? tag, String? description}) => SoundPack(
        id: id,
        name: name,
        tag: tag ?? this.tag,
        description: description ?? this.description,
      );
}

/// The 10 built-in packs, ordered as in the prototype's Switch Profiles list.
const List<SoundPack> kBuiltinPacks = [
  SoundPack(
    id: 'cherry_mx_blue',
    name: 'Cherry MX Blue',
    tag: '清脆青轴',
    description: 'Classic Clicky · 60g 触发段落感，高频咔嗒声干净利落。',
  ),
  SoundPack(
    id: 'gateron_oil_king',
    name: 'Gateron Oil King',
    tag: '麻将音HIFI',
    description: 'Deep Linear Thock · 深沉麻将底音，密室共鸣与厚实触底。',
  ),
  SoundPack(
    id: 'holy_panda',
    name: 'Holy Panda',
    tag: '圣熊猫轴',
    description: 'Punchy Clack · 67g 圆润凸点，肉感十足的弹压敲击。',
  ),
  SoundPack(
    id: 'ibm_model_m',
    name: 'IBM Model M',
    tag: '弹簧经典',
    description: 'Buckling Spring · 屈张弹簧，钢板回响的金属铭牌。',
  ),
  SoundPack(
    id: 'kailh_box_white',
    name: 'Kailh Box White',
    tag: '凯华白盒',
    description: 'Click Bar · 独立Click杆，明亮清脆的金属断裂音。',
  ),
  SoundPack(
    id: 'topre_electrostatic',
    name: 'Topre Electrostatic',
    tag: '静电容',
    description: 'Cup Rubber Dome · 软弹枕音，温润厚重的静电容手感。',
  ),
  SoundPack(
    id: 'bubble_pop',
    name: 'Bubble Pop',
    tag: '水泡泡',
    description: 'Hydro Acoustic · 水滴 Q 弹，清新活泼的气泡音。',
  ),
  SoundPack(
    id: 'scifi_laser',
    name: 'Sci-Fi Laser',
    tag: '电子镭射',
    description: 'Synth Pew · 频率调制合成音，赛博感的镭射击发。',
  ),
  SoundPack(
    id: 'typewriter_1930s',
    name: 'Typewriter 1930s',
    tag: '老式打字机',
    description: 'Vintage Strike · 机械铃声与击锤回弹，复古打字机质感。',
  ),
  SoundPack(
    id: 'silent_red',
    name: 'Silent Red',
    tag: '消音红轴',
    description: 'Silicone Dampened · 硅胶消音垫，低分贝轻柔敲击。',
  ),
];

SoundPack packById(String id) =>
    kBuiltinPacks.firstWhere((p) => p.id == id, orElse: () => kBuiltinPacks.first);
