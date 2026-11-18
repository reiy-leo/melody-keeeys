import 'dart:io';

/// Opt-in diagnostics for release builds, where debugPrint goes nowhere:
/// set MK_DIAG=1 before launch and lines land in %TEMP%\melody-keeeys.log
/// (or $TMPDIR/melody-keeeys.log).
final bool _enabled = Platform.environment['MK_DIAG'] == '1';

void diag(String message) {
  if (!_enabled) return;
  try {
    File('${Directory.systemTemp.path}${Platform.pathSeparator}melody-keeeys.log')
        .writeAsStringSync(
      '${DateTime.now().toIso8601String()} [$pid] $message\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}
