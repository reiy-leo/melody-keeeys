import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Debug-only screenshot helper.
///
/// Polls for a request file; when it appears, renders the wrapped subtree to
/// a PNG and writes it to [outputPath]. Because the image comes from Flutter's
/// own render tree, no macOS screen-recording permission is involved — this is
/// how README screenshots are captured in CI-less environments.
///
/// Only mounted when `kDebugMode` is true (see main.dart / hud_window.dart).
class ScreenshotHost extends StatefulWidget {
  const ScreenshotHost({
    super.key,
    required this.child,
    this.requestPath = '/tmp/melody_shot_req',
    this.outputPath = '/tmp/melody_shot.png',
  });

  final Widget child;
  final String requestPath;
  final String outputPath;

  @override
  State<ScreenshotHost> createState() => _ScreenshotHostState();
}

class _ScreenshotHostState extends State<ScreenshotHost> {
  final _boundaryKey = GlobalKey();
  Timer? _timer;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_capturing) return;
    final request = File(widget.requestPath);
    if (!request.existsSync()) return;
    _capturing = true;
    try {
      // The file's content is the destination path (defaults when empty).
      final requested = request.readAsStringSync().trim();
      final output = requested.isEmpty ? widget.outputPath : requested;
      request.deleteSync();
      // Let a triggered navigation settle before rendering.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _capture(output);
    } finally {
      _capturing = false;
    }
  }

  Future<void> _capture(String output) async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File(output);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    debugPrint('[screenshot] wrote $output');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _boundaryKey, child: widget.child);
  }
}
