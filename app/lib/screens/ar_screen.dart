import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ar_server.dart';
import '../l10n.dart';
import '../progress.dart';

/// The AR camera. Image tracking, 3D and sound run in a web page
/// (assets/ar/index.html: MindAR + three.js) inside a WebView, served from
/// the app bundle by [ArAssetServer]. This screen handles the camera
/// permission, the WebView and app lifecycle, and records progress (animals
/// met, body parts found, quiz answers) from the page's events.
class ArScreen extends StatefulWidget {
  const ArScreen({super.key, required this.progress, this.quiz = false});
  final Progress progress;
  final bool quiz; // level 3: the page asks "Find the tail!"

  @override
  State<ArScreen> createState() => _ArScreenState();
}

enum _Status { starting, ready, denied }

class _ArScreenState extends State<ArScreen> with WidgetsBindingObserver {
  final _server = ArAssetServer();
  InAppWebViewController? _web;
  Uri? _url;
  _Status _status = _Status.starting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    setState(() => _status = _Status.starting);
    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _status = _Status.denied);
      return;
    }
    _url ??= await _server.start();
    if (!mounted) return;
    setState(() => _status = _Status.ready);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final web = _web;
    if (web == null) return;
    // Release the camera in the background; take it back on return.
    if (state == AppLifecycleState.paused) {
      web.evaluateJavascript(source: 'window.arPause && window.arPause()');
    } else if (state == AppLifecycleState.resumed) {
      web.evaluateJavascript(source: 'window.arResume && window.arResume()');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.close();
    super.dispose();
  }

  /// Events from the AR page. The returned map goes back to the page, which
  /// uses it for "+1 star" toasts and "Level 2 unlocked" celebrations.
  Object? _onArEvent(List<dynamic> args) {
    final event = args.isNotEmpty && args.first is Map ? args.first as Map : const {};
    if (kDebugMode) debugPrint('AR event: $event');
    final p = widget.progress;
    final animal = event['animal'] as String? ?? event['id'] as String?;
    switch (event['type']) {
      case 'found':
        HapticFeedback.mediumImpact();
        return animal == null ? null : p.markMet(animal);
      case 'part':
        HapticFeedback.selectionClick(); // a body part was selected
        final part = event['id'] as String?;
        return animal == null || part == null ? null : p.markPart(animal, part);
      case 'quiz':
        HapticFeedback.heavyImpact(); // right answer
        return animal == null ? null : p.markQuiz(animal);
      case 'hold':
        HapticFeedback.mediumImpact();
    }
    return null;
  }

  Uri get _pageUrl => _url!.replace(queryParameters: {
        'lang': widget.progress.lang.name,
        if (widget.quiz) 'mode': 'quiz',
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Every child is positioned, so the Stack fills the screen. (A plain
      // child would make the Stack shrink to that child's size.)
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  key: const Key('ar-back'),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: widget.progress.s.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.starting:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case _Status.denied:
        return _PermissionMessage(onRetry: _start, s: widget.progress.s);
      case _Status.ready:
        return InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_pageUrl.toString())),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false, // the animal's sound plays when its page is found
            allowsInlineMediaPlayback: true, // iOS: camera video inside the page
            supportZoom: false,
            disableContextMenu: true,
            disableLongPressContextMenuOnLinks: true,
            // Android: embed the real WebView (steadier with live camera video).
            useHybridComposition: true,
            isInspectable: kDebugMode,
          ),
          onWebViewCreated: (controller) {
            _web = controller;
            controller.addJavaScriptHandler(handlerName: 'arEvent', callback: _onArEvent);
          },
          onPermissionRequest: (controller, request) async {
            // Only our own page, and only the camera and (iOS) the gyroscope
            // that Hold uses to look around.
            final ours = request.origin.host == '127.0.0.1';
            final allowed = request.resources.every(
                (r) => r == PermissionResourceType.CAMERA || r == PermissionResourceType.DEVICE_ORIENTATION_AND_MOTION);
            return PermissionResponse(
              resources: request.resources,
              action: ours && allowed ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
            );
          },
          onConsoleMessage: (controller, message) {
            if (kDebugMode) debugPrint('AR page: ${message.message}');
          },
        );
    }
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({required this.onRetry, required this.s});
  final VoidCallback onRetry;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              s.needCamera,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: Text(s.tryAgain)),
            TextButton(
              onPressed: openAppSettings,
              child: Text(s.openSettings, style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
