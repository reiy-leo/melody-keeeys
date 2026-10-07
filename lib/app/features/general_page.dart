import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_lifecycle.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/audio/sound_engine.dart';
import '../../core/settings/settings_model.dart';
import '../../shared/widgets/app_widgets.dart';

/// 通用 tab: engine core, launch behavior, hotkeys, trigger shaping, test zone.
class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  State<GeneralPage> createState() => _GeneralPageState();
}

class _GeneralPageState extends State<GeneralPage> with WidgetsBindingObserver {
  final _focus = FocusNode();
  String? _permissionError;
  /// Which System Settings pane the banner's 打开设置 should open.
  String _permissionPane = 'accessibility';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from System Settings after ticking the permission checkbox.
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final detail = await KeyHookChannel.instance.permissionDetail();
    final ax = detail['accessibility'] ?? false;
    if (!mounted) return;
    // The tap is an active pass-through tap, which macOS covers with the
    // Accessibility grant alone; Input Monitoring is not required.
    final granted = Platform.isMacOS ? ax : await KeyHookChannel.instance.isPermissionGranted();
    setState(() {
      _permissionError = granted ? null : _permissionIssue();
      _permissionPane = 'accessibility';
    });
    // The hook only gets one attempt at launch; retry once TCC is granted,
    // otherwise the banner would clear but keys would still stay silent.
    if (granted && !soundEngine.state.hookRunning) {
      await soundEngine.startHook();
    }
  }

  String? _permissionIssue() {
    if (Platform.isMacOS) {
      return '需要「辅助功能」权限才能监听全局键盘。请前往 系统设置 → 隐私与安全性 → 辅助功能，勾选 Melody Keeeys 后重试。';
    }
    if (Platform.isLinux) {
      return '需要读取 /dev/input 设备（input 用户组）。执行 sudo usermod -aG input \$USER 并重新登录后重试。';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: soundEngine,
      builder: (context, _) {
        final state = soundEngine.state;
        final settings = state.settings;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_permissionError != null) _PermissionBanner(message: _permissionError!, onOpen: () async {
                await KeyHookChannel.instance.openPermissionSettings(which: _permissionPane);
              }, onRetry: _checkPermission),
              SectionCard(
                icon: Icons.settings_input_component,
                title: '系统与启动',
                badge: '核心配置',
                subtitle: '引擎状态 ${state.latencyMs?.toStringAsFixed(1) ?? '--'}ms · 引擎 ${state.engineVersion}',
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.power_settings_new,
                      title: '声音引擎',
                      subtitle: '关闭后全局按键将不再播放音效',
                      trailing: Switch(
                        value: settings.engineEnabled,
                        onChanged: (v) => soundEngine.updateSettings(settings.copyWith(engineEnabled: v)),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.rocket_launch,
                      title: '开机自动启动',
                      subtitle: '登录后自动在后台启动 Melody Keeeys',
                      trailing: Switch(
                        value: settings.launchAtLogin,
                        onChanged: (v) async {
                          await soundEngine.updateSettings(settings.copyWith(launchAtLogin: v));
                          await appLifecycle.setLaunchAtLogin(v);
                        },
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.visibility_off,
                      title: '启动时以托盘菜单静默运行',
                      subtitle: '跳过主配置中心窗口，仅在系统菜单栏驻留',
                      trailing: Switch(
                        value: settings.silentStart,
                        onChanged: (v) => soundEngine.updateSettings(settings.copyWith(silentStart: v)),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.brightness_6,
                      title: '外观主题',
                      subtitle: '浅色 / 深色 / 跟随系统',
                      trailing: _UiThemePicker(current: settings.uiTheme),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.keyboard_command_key,
                title: '全局热键映射',
                badge: '系统级',
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_off,
                      title: '全局静音 / 恢复输出',
                      subtitle: '随时一键切断物理键盘声音',
                      trailing: MetricChip(label: settings.muteHotkey, color: context.colors.primary),
                    ),
                    SettingsRow(
                      icon: Icons.swap_horiz,
                      title: '快速轮换下一个按键声音包',
                      subtitle: '在已加载的轴体音效配置中随时轮换',
                      trailing: MetricChip(label: settings.cycleHotkey, color: context.colors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.bolt,
                title: '触发防冲突与按键响应',
                badge: '声学抑制',
                child: Column(
                  children: [
                    AppSlider(
                      label: '连击抑制窗口',
                      value: settings.antiGhostingMs.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      valueText: '${settings.antiGhostingMs} ms',
                      onChanged: (v) => soundEngine.updateSettings(
                          settings.copyWith(antiGhostingMs: v.round())),
                    ),
                    SettingsRow(
                      icon: Icons.repeat,
                      title: '修饰键长按连发声',
                      subtitle: '长按 Shift / Control 等修饰键时持续循环修饰键行程音',
                      trailing: Switch(
                        value: settings.modifierAutoRepeat,
                        onChanged: (v) =>
                            soundEngine.updateSettings(settings.copyWith(modifierAutoRepeat: v)),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.keyboard_return,
                      title: '松键上行程音',
                      subtitle: '模拟轴体弹起时的回弹声',
                      trailing: Switch(
                        value: settings.keyReleaseSound,
                        onChanged: (v) =>
                            soundEngine.updateSettings(settings.copyWith(keyReleaseSound: v)),
                      ),
                    ),
                    if (settings.keyReleaseSound)
                      AppSlider(
                        label: '回弹音量',
                        value: settings.keyReleaseGain,
                        min: 0.1,
                        max: 1.0,
                        valueText: '${(settings.keyReleaseGain * 100).round()}%',
                        accent: context.colors.secondary,
                        onChanged: (v) =>
                            soundEngine.updateSettings(settings.copyWith(keyReleaseGain: v)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AcousticTestZone(
                focus: _focus,
                keystrokeCount: state.keystrokeCount,
                onReset: () {/* counter resets with engine restart */},
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                icon: Icons.do_not_disturb_on,
                title: '智能静音与防干扰应用列表',
                badge: '即将推出',
                subtitle: '目标进程获得操作系统焦点时自动切断声音输出',
                trailing: const SizedBox.shrink(),
                child: Text('该功能将在后续版本提供：会议、游戏与 DAW 独占混音场景自动静音。',
                    style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Spacer(),
                  PillButton(
                    label: '恢复默认出厂设置',
                    icon: Icons.restart_alt,
                    danger: true,
                    onPressed: () async {
                      await soundEngine.resetToDefaults();
                      await appLifecycle.setLaunchAtLogin(
                          soundEngine.state.settings.launchAtLogin);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Light / dark / system three-way segmented picker (pill style).
class _UiThemePicker extends StatelessWidget {
  const _UiThemePicker({required this.current});

  final UiTheme current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.containerHighest,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in UiTheme.values) ...[
            InkWell(
              onTap: () => soundEngine
                  .updateSettings(soundEngine.state.settings.copyWith(uiTheme: mode)),
              borderRadius: AppRadii.pill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: current == mode
                      ? context.colors.primary
                      : Colors.transparent,
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (mode) {
                        UiTheme.light => Icons.light_mode,
                        UiTheme.dark => Icons.dark_mode,
                        UiTheme.system => Icons.settings_suggest,
                      },
                      size: 13,
                      color: current == mode
                          ? context.colors.onPrimary
                          : context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mode.label,
                      style: AppText.labelMd.copyWith(
                        color: current == mode
                            ? context.colors.onPrimary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (mode != UiTheme.values.last) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {  const _PermissionBanner({
    required this.message,
    required this.onOpen,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.container,
        borderRadius: AppRadii.md,
        border: Border.all(color: context.colors.secondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: context.colors.secondary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: AppText.bodyMd)),
          const SizedBox(width: AppSpacing.md),
          PillButton(label: '打开设置', icon: Icons.open_in_new, onPressed: onOpen),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: BorderSide(color: context.colors.outlineVariant),
            ),
            child: const Text('重新检查'),
          ),
        ],
      ),
    );
  }
}

class _AcousticTestZone extends StatelessWidget {
  const _AcousticTestZone({
    required this.focus,
    required this.keystrokeCount,
    required this.onReset,
  });

  final FocusNode focus;
  final int keystrokeCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.containerLow,
        borderRadius: AppRadii.lg,
        border: Border.all(color: context.colors.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, size: 18, color: context.colors.tertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('声学测试跳线', style: AppText.titleLg),
              const Spacer(),
              MetricChip(label: '累计敲击 $keystrokeCount'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            focusNode: focus,
            style: AppText.bodyLg,
            decoration: InputDecoration(
              hintText: '在此区域敲击键盘或输入文字，实时试听当前音效包的敲击响应…',
              hintStyle: AppText.bodyMd.copyWith(color: context.colors.outline),
              filled: true,
              fillColor: context.colors.container,
              border: OutlineInputBorder(borderRadius: AppRadii.md, borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('提示：全局钩子运行时，在应用外打字也会发声；此输入框仅用于快速试音。',
              style: AppText.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
