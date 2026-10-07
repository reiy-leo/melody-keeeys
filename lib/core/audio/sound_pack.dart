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
    required this.nameEn,
    required this.description,
  });

  final String id;

  /// Chinese display name — the primary label across all UI surfaces.
  final String name;

  /// Original (English) product name, shown as a subdued secondary label.
  final String nameEn;

  /// Chinese-only one-line description.
  final String description;

  String assetPathFor(SoundLayer layer) => 'sounds/$id/${layer.assetName}.wav';
}

/// The 10 built-in packs, ordered as in the prototype's Switch Profiles list.
const List<SoundPack> kBuiltinPacks = [
  SoundPack(
    id: 'cherry_mx_blue',
    name: '清脆青轴',
    nameEn: 'Cherry MX Blue',
    description: '经典青轴脆响，60g 触发段落感，高频咔嗒声干净利落。',
  ),
  SoundPack(
    id: 'gateron_oil_king',
    name: '麻将音',
    nameEn: 'Gateron Oil King',
    description: '深沉麻将底音，密室共鸣与厚实触底。',
  ),
  SoundPack(
    id: 'holy_panda',
    name: '圣熊猫轴',
    nameEn: 'Holy Panda',
    description: '67g 圆润凸点，肉感十足的弹压敲击。',
  ),
  SoundPack(
    id: 'ibm_model_m',
    name: '弹簧经典',
    nameEn: 'IBM Model M',
    description: '屈张弹簧，钢板回响的金属铭牌。',
  ),
  SoundPack(
    id: 'kailh_box_white',
    name: '凯华白盒',
    nameEn: 'Kailh Box White',
    description: '独立发声杆，明亮清脆的金属断裂音。',
  ),
  SoundPack(
    id: 'topre_electrostatic',
    name: '静电容',
    nameEn: 'Topre Electrostatic',
    description: '软弹枕音，温润厚重的静电容手感。',
  ),
  SoundPack(
    id: 'bubble_pop',
    name: '水泡泡',
    nameEn: 'Bubble Pop',
    description: '水滴 Q 弹，清新活泼的气泡音。',
  ),
  SoundPack(
    id: 'scifi_laser',
    name: '电子镭射',
    nameEn: 'Sci-Fi Laser',
    description: '频率调制合成音，赛博感的镭射击发。',
  ),
  SoundPack(
    id: 'typewriter_1930s',
    name: '老式打字机',
    nameEn: 'Typewriter 1930s',
    description: '机械铃声与击锤回弹，复古打字机质感。',
  ),
  SoundPack(
    id: 'silent_red',
    name: '消音红轴',
    nameEn: 'Silent Red',
    description: '硅胶消音垫，低分贝轻柔敲击。',
  ),
];

SoundPack packById(String id) =>
    kBuiltinPacks.firstWhere((p) => p.id == id, orElse: () => kBuiltinPacks.first);
