import 'dart:io';

import 'package:flutter/services.dart';

/// Serves the AR web page (assets/ar) from the app bundle on 127.0.0.1.
///
/// The camera API only works in a "secure context", and 127.0.0.1 counts as
/// one, so the AR page is loaded from here rather than from a file:// URL.
/// Supports byte ranges because iOS will not play audio without them.
class ArAssetServer {
  ArAssetServer({this.root = 'assets/ar/', AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final String root;
  final AssetBundle _bundle;
  HttpServer? _server;

  static const _types = <String, String>{
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'glb': 'model/gltf-binary',
    'm4a': 'audio/mp4',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'mind': 'application/octet-stream',
  };

  static String contentTypeFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return _types[ext] ?? 'application/octet-stream';
  }

  /// Starts the server on a free port and returns the AR page's URL.
  Future<Uri> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return Uri.parse('http://127.0.0.1:${server.port}/index.html');
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      var path = Uri.decodeComponent(req.uri.path);
      if (path == '/' || path.isEmpty) path = '/index.html';
      if (path.contains('..') || req.method != 'GET') {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final ByteData data;
      try {
        data = await _bundle.load('$root${path.substring(1)}');
      } catch (_) {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      res.headers.set(HttpHeaders.contentTypeHeader, contentTypeFor(path));
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      final range = _parseRange(req.headers.value(HttpHeaders.rangeHeader), bytes.length);
      if (range == null) {
        res.contentLength = bytes.length;
        res.add(bytes);
      } else {
        final (start, end) = range;
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${bytes.length}');
        res.contentLength = end - start + 1;
        res.add(Uint8List.sublistView(bytes, start, end + 1));
      }
    } finally {
      await res.close();
    }
  }

  /// Parses `bytes=a-b`, `bytes=a-` and `bytes=-n`; null means "whole file".
  static (int, int)? _parseRange(String? header, int length) {
    if (header == null || length == 0) return null;
    final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (m == null) return null;
    final a = m.group(1)!, b = m.group(2)!;
    int start, end;
    if (a.isEmpty) {
      if (b.isEmpty) return null;
      final n = int.parse(b);
      start = length - (n > length ? length : n);
      end = length - 1;
    } else {
      start = int.parse(a);
      end = b.isEmpty ? length - 1 : int.parse(b);
    }
    if (start > end || start >= length) return null;
    if (end >= length) end = length - 1;
    return (start, end);
  }
}
