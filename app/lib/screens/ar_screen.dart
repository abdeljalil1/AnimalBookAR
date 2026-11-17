import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ar_server.dart';

/// The AR camera. Image tracking, 3D and sound run in a web page
/// (assets/ar/index.html: MindAR + three.js) inside a WebView, served from
/// the app bundle by [ArAssetServer]. This screen handles the camera
/// permission, the WebView and app lifecycle.
class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

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

  void _onArEvent(List<dynamic> args) {
    final event = args.isNotEmpty && args.first is Map ? args.first as Map : const {};
    if (event['type'] == 'found') HapticFeedback.mediumImpact();
    if (kDebugMode) debugPrint('AR event: $event');
  }

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
                  tooltip: 'Back',
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
        return _PermissionMessage(onRetry: _start);
      case _Status.ready:
        return InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_url.toString())),
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
            // Only our own page may use the camera, and only the camera.
            final ours = request.origin.host == '127.0.0.1';
            final cameraOnly = request.resources.every((r) => r == PermissionResourceType.CAMERA);
            return PermissionResponse(
              resources: request.resources,
              action: ours && cameraOnly ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
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
  const _PermissionMessage({required this.onRetry});
  final VoidCallback onRetry;

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
            const Text(
              'Animal Book AR needs the camera to see the book.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            const TextButton(
              onPressed: openAppSettings,
              child: Text('Open settings', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
