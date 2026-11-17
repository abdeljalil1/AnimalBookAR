import 'dart:convert';
import 'dart:io';

import 'package:animal_book_ar/ar_server.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test replaces HttpClient with a mock that fails every request;
  // this test talks to a real local server, so use the real client.
  HttpOverrides.global = null;
  late ArAssetServer server;
  late Uri page;
  late HttpClient client;

  setUp(() async {
    client = HttpClient();
    server = ArAssetServer();
    page = await server.start();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  Future<(HttpClientResponse, List<int>)> get(String path, {String? range}) async {
    final req = await client.getUrl(page.resolve(path));
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final res = await req.close();
    final body = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    return (res, body);
  }

  test('serves the AR page from 127.0.0.1 with the right types', () async {
    expect(page.host, '127.0.0.1');
    final (res, body) = await get('index.html');
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'text/html');
    expect(utf8.decode(body), contains('ar.js'));

    final (js, _) = await get('vendor/mindar/mindar-image-three.prod.js');
    expect(js.headers.contentType?.mimeType, 'text/javascript'); // module scripts need a JS type
    final (glb, glbBody) = await get('models/Fox.glb');
    expect(glb.headers.contentType?.mimeType, 'model/gltf-binary');
    expect(ascii.decode(glbBody.sublist(0, 4)), 'glTF');
  });

  test('answers byte ranges (iOS needs them to play audio)', () async {
    final whole = await rootBundle.load('assets/ar/sounds/horse.m4a');
    final (res, body) = await get('sounds/horse.m4a', range: 'bytes=0-1');
    expect(res.statusCode, 206);
    expect(res.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-1/${whole.lengthInBytes}');
    expect(body.length, 2);

    final (tail, tailBody) = await get('sounds/horse.m4a', range: 'bytes=-100');
    expect(tail.statusCode, 206);
    expect(tailBody.length, 100);
  });

  test('returns 404 for missing files and path tricks', () async {
    expect((await get('nope.js')).$1.statusCode, 404);
    expect((await get('../pubspec.yaml')).$1.statusCode, 404);
  });

  test('content types by extension', () {
    expect(ArAssetServer.contentTypeFor('a/b.css'), startsWith('text/css'));
    expect(ArAssetServer.contentTypeFor('targets.mind'), 'application/octet-stream');
    expect(ArAssetServer.contentTypeFor('noext'), 'application/octet-stream');
  });
}
