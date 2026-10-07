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

/// The 17 built-in packs: the prototype's original 10 plus 7 Tickeys-inspired
/// effects (bubble/typewriter/mechanical/sword/cherry_g80_*/drum).
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
  // Tickeys-inspired set (synthesized approximations, not its audio assets).
  SoundPack(
    id: 'bubble',
    name: '咕噜气泡',
    nameEn: 'Bubble',
    description: '上升水音与回声，清澈的咕噜冒泡质感。',
  ),
  SoundPack(
    id: 'typewriter',
    name: '经典打字机',
    nameEn: 'Typewriter',
    description: '击键闷响与字车铃声，怀旧打字机韵律。',
  ),
  SoundPack(
    id: 'mechanical',
    name: '机械键盘',
    nameEn: 'Mechanical',
    description: '干脆利落的通用机械轴敲击声。',
  ),
  SoundPack(
    id: 'sword',
    name: '利剑出鞘',
    nameEn: 'Sword',
    description: '金属下滑音与泛音共鸣，利落出鞘声。',
  ),
  SoundPack(
    id: 'cherry_g80_3000',
    name: '樱桃 G80-3000',
    nameEn: 'Cherry G80-3000',
    description: '经典樱桃机械手感，清脆扎实的段落声。',
  ),
  SoundPack(
    id: 'cherry_g80_3494',
    name: '樱桃 G80-3494',
    nameEn: 'Cherry G80-3494',
    description: '红轴线性触底，低沉顺滑的闷响。',
  ),
  SoundPack(
    id: 'drum',
    name: '鼓点',
    nameEn: 'Drum',
    description: '下沉鼓声与鼓皮敲击，节拍感十足。',
  ),
];

SoundPack packById(String id) =>
    kBuiltinPacks.firstWhere((p) => p.id == id, orElse: () => kBuiltinPacks.first);
