import '../i18n/i18n.dart';

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

  /// Name shown in the current UI language: the Chinese name for zh, the
  /// original English name everywhere else.
  String get displayName => I18n.lang == 'zh' ? name : nameEn;

  /// Secondary tag beside [displayName] (the English name, zh only).
  String? get displayTag => I18n.lang == 'zh' ? nameEn : null;

  /// Description in the current UI language.
  String get displayDescription {
    final text = tr('pack.$id');
    return text == 'pack.$id' ? description : text;
  }

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
    name: '黑墨轴',
    nameEn: 'Gateron Black Ink',
    description: '佳达隆墨轴线性重压，深沉厚实的触底声。',
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
    description: '屈曲弹簧，钢板回响的清亮敲击。',
  ),
  SoundPack(
    id: 'kailh_box_white',
    name: '凯华海军蓝',
    nameEn: 'Kailh Box Navy',
    description: '粗发声杆重段落，厚重响亮的咔嗒声。',
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
    name: '打字机·变奏',
    nameEn: 'Typewriter Alt',
    description: '与经典打字机同一台机器的另一组击键，节奏更轻快。',
  ),
  SoundPack(
    id: 'silent_red',
    name: '墨红轴',
    nameEn: 'Gateron Red Ink',
    description: '佳达隆墨轴线性轻压，顺滑清亮的敲击声。',
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
    description: '经典樱桃 G80 键盘实录，明亮清脆的敲击声。',
  ),
  SoundPack(
    id: 'cherry_g80_3494',
    name: '樱桃 G80-3494',
    nameEn: 'Cherry G80-3494',
    description: '樱桃 G80 键盘实录，比 3000 更低沉短促。',
  ),
  SoundPack(
    id: 'drum',
    name: '鼓点',
    nameEn: 'Drum',
    description: '下沉鼓声与鼓皮敲击，节拍感十足。',
  ),
  // Foley set (CC0 recordings from Freesound, see assets/sounds/CREDITS.md).
  SoundPack(
    id: 'sandpaper',
    name: '砂纸摩擦',
    nameEn: 'Sandpaper',
    description: '粗粝的沙沙摩擦声，颗粒感十足。',
  ),
  SoundPack(
    id: 'chalk',
    name: '粉笔书写',
    nameEn: 'Chalk',
    description: '粉笔划过黑板的细碎刮擦声。',
  ),
  SoundPack(
    id: 'ipad_tap',
    name: 'iPad 点触',
    nameEn: 'iPad Tap',
    description: '手指轻敲玻璃屏幕的清脆点按声。',
  ),
  SoundPack(
    id: 'plastic_bag',
    name: '塑料袋揉搓',
    nameEn: 'Plastic Bag',
    description: '塑料袋窸窣揉搓的皱褶声。',
  ),
  SoundPack(
    id: 'straw_sip',
    name: '吸管喝水',
    nameEn: 'Straw Sip',
    description: '吸管吮吸饮料的咕噜水声。',
  ),
];

SoundPack packById(String id) =>
    kBuiltinPacks.firstWhere((p) => p.id == id, orElse: () => kBuiltinPacks.first);
