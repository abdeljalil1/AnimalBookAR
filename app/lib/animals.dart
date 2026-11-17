import 'dart:convert';

import 'package:flutter/services.dart';

/// One animal in the book. The list lives in assets/ar/animals.json, which
/// the AR page and the page generator (tool/make_pages.py) also read.
class Animal {
  const Animal({
    required this.id,
    required this.en,
    required this.fr,
    required this.ar,
    required this.factEn,
    required this.color,
  });

  final String id;
  final String en;
  final String fr;
  final String ar;
  final String factEn;
  final Color color;

  String get pageAsset => 'assets/ar/pages/$id.jpg';

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as String,
        en: j['en'] as String,
        fr: j['fr'] as String,
        ar: j['ar'] as String,
        factEn: j['fact_en'] as String,
        color: Color(int.parse((j['color'] as String).substring(1), radix: 16) | 0xFF000000),
      );

  static Future<List<Animal>> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString('assets/ar/animals.json');
    return (jsonDecode(text) as List).map((e) => Animal.fromJson(e as Map<String, dynamic>)).toList();
  }
}
