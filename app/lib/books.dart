import 'dart:convert';

import 'package:flutter/services.dart';

import 'animals.dart';
import 'l10n.dart';

/// A book in the library (assets/ar/books.json): its items (animals,
/// vehicles...), where its pages and thumbnails are, and which map the home
/// screen draws for it. The AR page reads the same file.
class Book {
  const Book({
    required this.id,
    required this.en,
    required this.fr,
    required this.ar,
    required this.kind,
    required this.map,
    required this.color,
    required this.items,
    this.levels = 3,
    this.games = const ['memory', 'sound'],
  });

  final String id;
  final String en;
  final String fr;
  final String ar;
  final String kind; // animals | vehicles | letters | colors | heritage
  final String map; // zoo | town | park
  final Color color;
  final List<Animal> items;

  /// 3 (meet, parts, quiz) or 1 (meet only: the letter books).
  final int levels;

  /// The game tiles on the home screen: memory, sound, helps, find, mix.
  final List<String> games;

  bool get vehicles => kind == 'vehicles';
  bool get letters => kind == 'letters';
  bool get colors => kind == 'colors';
  String title(Lang lang) => switch (lang) { Lang.en => en, Lang.fr => fr, Lang.ar => ar };

  static Future<List<Book>> loadAll([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final list = jsonDecode(await b.loadString('assets/ar/books.json')) as List;
    final books = <Book>[];
    for (final e in list.cast<Map<String, dynamic>>()) {
      final items = (jsonDecode(await b.loadString('assets/ar/${e['data']}')) as List)
          .map((i) => Animal.fromJson(i as Map<String, dynamic>,
              pagesDir: e['pagesDir'] as String, thumbsDir: e['thumbsDir'] as String))
          .toList();
      books.add(Book(
        id: e['id'] as String,
        en: e['en'] as String,
        fr: e['fr'] as String,
        ar: e['ar'] as String,
        kind: e['kind'] as String,
        map: e['map'] as String,
        color: Color(int.parse((e['color'] as String).substring(1), radix: 16) | 0xFF000000),
        items: items,
        levels: (e['levels'] as int?) ?? 3,
        games: ((e['games'] as List?) ?? const ['memory', 'sound']).cast<String>(),
      ));
    }
    return books;
  }

  /// A single-book library (used by tests and as a fallback).
  factory Book.animalsOnly(List<Animal> animals) => Book(
      id: 'animals',
      en: 'Animals',
      fr: 'Les animaux',
      ar: 'الحيوانات',
      kind: 'animals',
      map: 'zoo',
      color: const Color(0xFFE8702A),
      items: animals);
}
