import 'dart:convert';

import 'package:flutter/services.dart';

import 'l10n.dart';

/// A body part of an animal (head, tail, wing...), in the three languages.
class BodyPart {
  const BodyPart({
    required this.id,
    required this.en,
    required this.fr,
    required this.ar,
    required this.frDef,
    required this.arDef,
  });

  final String id;
  final String en;
  final String fr;
  final String ar;

  /// French with its article ("la queue") and Arabic with "al-" ("الذيل").
  final String frDef;
  final String arDef;

  String name(Lang lang) => switch (lang) { Lang.en => en, Lang.fr => fr, Lang.ar => ar };

  factory BodyPart.fromJson(Map<String, dynamic> j) => BodyPart(
        id: j['id'] as String,
        en: j['en'] as String,
        fr: j['fr'] as String,
        ar: j['ar'] as String,
        frDef: j['fr_def'] as String,
        arDef: j['ar_def'] as String,
      );
}

/// One animal in the book. The list lives in assets/ar/animals.json, which
/// the AR page and the page generator (tool/make_pages.py) also read.
class Animal {
  const Animal({
    required this.id,
    required this.page,
    required this.en,
    required this.fr,
    required this.ar,
    required this.frOf,
    required this.arDef,
    required this.factEn,
    required this.factFr,
    required this.factAr,
    required this.color,
    required this.parts,
  });

  final String id;
  final int page;
  final String en;
  final String fr;
  final String ar;

  /// "du renard" / "الثعلب": for building sentences.
  final String frOf;
  final String arDef;
  final String factEn;
  final String factFr;
  final String factAr;
  final Color color;
  final List<BodyPart> parts;

  String get pageAsset => 'assets/ar/pages/$id.jpg';
  String get thumbAsset => 'assets/thumbs/$id.jpg';

  String name(Lang lang) => switch (lang) { Lang.en => en, Lang.fr => fr, Lang.ar => ar };
  String fact(Lang lang) => switch (lang) { Lang.en => factEn, Lang.fr => factFr, Lang.ar => factAr };

  /// "le renard" / "la cigogne", from "du renard" / "de la cigogne".
  String get frDef => frOf.startsWith('du ') ? 'le ${frOf.substring(3)}' : frOf.replaceFirst('de ', '');

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as String,
        page: j['page'] as int,
        en: j['en'] as String,
        fr: j['fr'] as String,
        ar: j['ar'] as String,
        frOf: j['fr_of'] as String,
        arDef: j['ar_def'] as String,
        factEn: j['fact_en'] as String,
        factFr: j['fact_fr'] as String,
        factAr: j['fact_ar'] as String,
        color: Color(int.parse((j['color'] as String).substring(1), radix: 16) | 0xFF000000),
        parts: (j['parts'] as List).map((p) => BodyPart.fromJson(p as Map<String, dynamic>)).toList(),
      );

  static Future<List<Animal>> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString('assets/ar/animals.json');
    return (jsonDecode(text) as List).map((e) => Animal.fromJson(e as Map<String, dynamic>)).toList();
  }
}
