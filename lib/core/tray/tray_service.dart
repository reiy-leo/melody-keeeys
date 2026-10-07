import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint, kDebugMode;
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';

import '../../app/app_lifecycle.dart';
import '../audio/sound_engine.dart';
import '../audio/sound_pack.dart';
import '../settings/settings_model.dart';

/// Menu bar / tray icon behavior: left click cycles the pack (configurable to
/// show the HUD), right click pops the context menu with all packs + settings.
/// Built on the nativeapi TrayIcon API that tray_manager >=0.6 exposes.
class TrayService {
  TrayService._();
  static final TrayService instance = TrayService._();

  TrayIcon? _icon;
  // Hold the menu and items for as long as the icon shows them: nativeapi
  // attaches native finalizers, so a GC'd Dart wrapper frees the native menu
  // and right-click dies silently.
  // ignore: unused_field
  Menu? _menu;
  final List<MenuItem> _menuItems = [];
  String? _lastMenuSignature;
  String? _lastIconId;

  /// Screen-space bounds of the tray icon (used to position the HUD).
  Rect? get bounds => _icon?.getBounds();

  /// Resolves a Flutter asset to a real file path across debug/release and
  /// platforms; nativeapi's ImageAsset.fromAsset only knows the release layout.
  String? _resolvedAssetFile(String asset) {
    final exe = Platform.resolvedExecutable;
    final contents = p.dirname(p.dirname(exe)); // macOS: .../Contents
    final candidates = [
      p.join(contents, 'Frameworks', 'App.framework', 'Resources', 'flutter_assets', asset),
      p.join(contents, 'Frameworks', 'flutter_assets', asset),
      p.join(p.dirname(exe), 'data', 'flutter_assets', asset),
      p.join(p.dirname(exe), 'flutter_assets', asset),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  Image? _loadIconImage(String iconId) {
    final asset = Platform.isMacOS
        ? 'assets/icons/tray_${iconId}_template.png'
        : 'assets/icons/tray_${iconId}_colored.png';
    final file = _resolvedAssetFile(asset);
    if (file != null) {
      final image = Image.fromFile(file);
      if (image != null) return image;
    }
    // Fallback: legacy self-drawn keycap, then Lucide preview size.
    for (final fallback in [
      'assets/icons/tray_template.png',
      'assets/icons/tray_colored.png',
      'assets/icons/tray_256.png',
    ]) {
      final path = _resolvedAssetFile(fallback);
      if (path == null) continue;
      final image = Image.fromFile(path);
      if (image != null) return image;
    }
    return null;
  }

  void _applyIcon(String iconId) {
    final icon = _icon;
    if (icon == null || iconId == _lastIconId) return;
    final image = _loadIconImage(iconId);
    if (image == null) {
      debugPrint('[melody] tray icon "$iconId" failed to load; keeping current');
      return; // keep current icon rather than a default one
    }
    debugPrint('[melody] tray icon "$iconId" loaded (${image.size.width}x${image.size.height})');
    _lastIconId = iconId;
    icon.isIconTemplate = Platform.isMacOS;
    icon.icon = image;
  }

  Future<void> init() async {
    final icon = TrayIcon.create();
    if (icon == null) return;
    _icon = icon;

    _applyIcon(soundEngine.state.settings.trayIcon);
    icon.setTooltip('Melody Keeeys · 旋律按键');
    icon.addListener(_onTrayEvent);
    icon.setVisible(true);
    rebuildMenu();
  }

  void _onTrayEvent(TrayIconEvent event) {
    if (kDebugMode) debugPrint('[melody] tray event: ${event.runtimeType}');
    if (event is TrayIconClickedEvent) {
      if (soundEngine.state.settings.leftClickAction == TrayLeftClickAction.cycleNext) {
        soundEngine.cyclePack();
      } else {
        appLifecycle.showHud();
      }
    }
    // TrayIconRightClickedEvent: the context menu opens via the
    // rightClicked trigger set in rebuildMenu().
  }

  /// Rebuild the context menu only when the visible state changed (engine
  /// notifications fire on every keystroke via the keystroke counter).
  void rebuildMenu() {
    final icon = _icon;
    if (icon == null) return;
    final state = soundEngine.state;
    _applyIcon(state.settings.trayIcon);
    final activePack = packById(state.settings.activePackId);
    icon.setTooltip('Melody Keeeys · 旋律按键 — 正在使用：${activePack.name}');
    final signature =
        '${state.settings.activePackId}|${state.settings.engineEnabled}|${state.settings.leftClickAction}';
    if (signature == _lastMenuSignature) return;
    _lastMenuSignature = signature;

    final menu = Menu.create();
    if (menu == null) return;
    _menu = menu;
    _menuItems.clear();

    void addItem(MenuItem? item, VoidCallback? onSelected) {
      if (item == null) return;
      _menuItems.add(item);
      if (onSelected != null) {
        item.addListener((event) {
          if (event is MenuItemClickedEvent) onSelected();
        });
      }
      menu.addItem(item);
    }

    // Headline: which pack is sounding right now.
    final currentItem = MenuItem.createWithLabelAndType(
        '正在使用：${activePack.name}', MenuItemType.normal);
    if (currentItem != null) {
      currentItem.isEnabled = false;
      addItem(currentItem, null);
    }

    menu.addSeparator();

    for (var i = 0; i < kBuiltinPacks.length; i++) {
      final pack = kBuiltinPacks[i];
      final item = MenuItem.createWithLabelAndType(
          '${i + 1}. ${pack.name}（${pack.nameEn}）', MenuItemType.checkbox);
      item?.state = pack.id == state.settings.activePackId
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      addItem(item, () => soundEngine.selectPack(pack.id));
    }

    menu.addSeparator();

    final engineItem =
        MenuItem.createWithLabelAndType('声音引擎：已开启', MenuItemType.checkbox);
    engineItem?.state = state.settings.engineEnabled
        ? MenuItemState.checked
        : MenuItemState.unchecked;
    addItem(engineItem, soundEngine.toggleEngine);

    addItem(
      MenuItem.createWithLabelAndType('打开托盘面板', MenuItemType.normal),
      appLifecycle.showHud,
    );
    addItem(
      MenuItem.createWithLabelAndType('设置…', MenuItemType.normal),
      appLifecycle.showSettingsWindow,
    );

    menu.addSeparator();

    addItem(
      MenuItem.createWithLabelAndType('退出 Melody Keeeys', MenuItemType.normal),
      appLifecycle.quit,
    );

    icon.setContextMenu(menu);
    // Left click must reach our listener (cycle/HUD); the menu belongs to the
    // right button only.
    icon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
  }

  void dispose() {
    _icon?.setVisible(false);
    _icon?.dispose();
    _icon = null;
    _menu = null;
    _menuItems.clear();
  }
}
