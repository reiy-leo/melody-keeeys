import 'dart:io';
import 'dart:ui' show Rect;

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
  String? _lastMenuSignature;
  String? _lastIconId;

  /// Screen-space bounds of the tray icon (used to position the HUD).
  Rect? get bounds => _icon?.getBounds();

  String _assetFor(String iconId) => Platform.isMacOS
      ? 'assets/icons/tray_${iconId}_template.png'
      : 'assets/icons/tray_${iconId}_colored.png';

  Future<void> _applyIcon(String iconId) async {
    final icon = _icon;
    if (icon == null || iconId == _lastIconId) return;
    _lastIconId = iconId;
    icon.isIconTemplate = Platform.isMacOS;
    icon.icon = ImageAsset.fromAsset(_assetFor(iconId));
  }

  Future<void> init() async {
    final icon = TrayIcon.create();
    if (icon == null) return;
    _icon = icon;

    await _applyIcon(soundEngine.state.settings.trayIcon);
    icon.setTooltip('Melody Keeeys · 旋律按键');
    icon.addListener(_onTrayEvent);
    icon.setVisible(true);
    rebuildMenu();
  }

  void _onTrayEvent(TrayIconEvent event) {
    if (event is TrayIconClickedEvent) {
      if (soundEngine.state.settings.leftClickAction == TrayLeftClickAction.cycleNext) {
        soundEngine.cyclePack();
      } else {
        appLifecycle.showHud();
      }
    }
    // TrayIconRightClickedEvent: the context menu pops automatically on
    // macOS/Windows. On some Linux appindicator setups only the menu is
    // reachable - acceptable per plan R3.
  }

  /// Rebuild the context menu only when the visible state changed (engine
  /// notifications fire on every keystroke via the keystroke counter).
  void rebuildMenu() {
    final icon = _icon;
    if (icon == null) return;
    final state = soundEngine.state;
    _applyIcon(state.settings.trayIcon);
    final signature =
        '${state.settings.activePackId}|${state.settings.engineEnabled}|${state.settings.leftClickAction}';
    if (signature == _lastMenuSignature) return;
    _lastMenuSignature = signature;

    final menu = Menu.create();
    if (menu == null) return;

    for (var i = 0; i < kBuiltinPacks.length; i++) {
      final pack = kBuiltinPacks[i];
      final item = MenuItem.createWithLabelAndType(
          '${i + 1}. ${pack.name} · ${pack.tag}', MenuItemType.checkbox);
      if (item == null) continue;
      item.state = pack.id == state.settings.activePackId
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      item.addListener((event) {
        if (event is MenuItemClickedEvent) soundEngine.selectPack(pack.id);
      });
      menu.addItem(item);
    }

    menu.addSeparator();

    final engineItem =
        MenuItem.createWithLabelAndType('声音引擎：已开启', MenuItemType.checkbox);
    if (engineItem != null) {
      engineItem.state = state.settings.engineEnabled
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      engineItem.addListener((event) {
        if (event is MenuItemClickedEvent) soundEngine.toggleEngine();
      });
      menu.addItem(engineItem);
    }

    final hudItem = MenuItem.createWithLabelAndType('快速面板 HUD', MenuItemType.normal);
    if (hudItem != null) {
      hudItem.addListener((event) {
        if (event is MenuItemClickedEvent) appLifecycle.showHud();
      });
      menu.addItem(hudItem);
    }

    final settingsItem = MenuItem.createWithLabelAndType('设置…', MenuItemType.normal);
    if (settingsItem != null) {
      settingsItem.addListener((event) {
        if (event is MenuItemClickedEvent) appLifecycle.showSettingsWindow();
      });
      menu.addItem(settingsItem);
    }

    menu.addSeparator();

    final quitItem = MenuItem.createWithLabelAndType('退出 Melody Keeeys', MenuItemType.normal);
    if (quitItem != null) {
      quitItem.addListener((event) {
        if (event is MenuItemClickedEvent) appLifecycle.quit();
      });
      menu.addItem(quitItem);
    }

    icon.setContextMenu(menu);
  }

  void dispose() {
    _icon?.setVisible(false);
    _icon?.dispose();
    _icon = null;
  }
}
