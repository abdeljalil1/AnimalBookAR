import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animals.dart';
import 'l10n.dart';

/// The three levels: 1 meet every animal, 2 find every body part,
/// 3 answer [quizGoal] quiz questions per animal. A level unlocks when the
/// one before is done. Stars: one per animal met, part found, quiz answer.
const quizGoal = 3;

/// What the home screen tells the child to do next.
class Mission {
  const Mission({required this.level, required this.animal, this.part});
  final int level; // 1..3, or 4 when everything is done
  final Animal? animal;
  final BodyPart? part;
  bool get quiz => level == 3;
}

/// Saved on the phone (shared_preferences). No account, nothing leaves the device.
class Progress extends ChangeNotifier {
  Progress(this._prefs, this.animals)
      : name = _prefs.getString('name') ?? '',
        lang = Lang.parse(_prefs.getString('lang')),
        _met = (_prefs.getStringList('met') ?? const []).toSet(),
        _parts = (_prefs.getStringList('parts') ?? const []).toSet(),
        _food = (_prefs.getStringList('food') ?? const []).toSet(),
        _quiz = {
          for (final e in _prefs.getStringList('quiz') ?? const <String>[])
            if (e.contains('=')) e.split('=').first: int.tryParse(e.split('=').last) ?? 0,
        };

  static Future<Progress> load(List<Animal> animals) async => Progress(await SharedPreferences.getInstance(), animals);

  final SharedPreferences _prefs;
  final List<Animal> animals;
  String name;
  Lang lang;
  final Set<String> _met;
  final Set<String> _parts; // "fox:tail"
  final Map<String, int> _quiz; // "fox" -> correct answers (max quizGoal)
  final Set<String> _food; // "fox:mouse": foods fed (right ones only)

  bool get hasProfile => name.trim().isNotEmpty;
  S get s => S(lang);

  // ---- reading ----
  bool met(String animal) => _met.contains(animal);
  bool partFound(String animal, String part) => _parts.contains('$animal:$part');
  int partsFound(Animal a) => a.parts.where((p) => partFound(a.id, p.id)).length;
  int quizScore(String animal) => _quiz[animal] ?? 0;

  int get totalParts => animals.fold(0, (n, a) => n + a.parts.length);
  int get partsTotalFound => animals.fold(0, (n, a) => n + partsFound(a));
  int get metCount => animals.where((a) => met(a.id)).length;
  int get quizTotal => animals.fold(0, (n, a) => n + quizScore(a.id));
  int get stars => metCount + partsTotalFound + quizTotal + _food.length;
  bool fed(String animal, String food) => _food.contains('$animal:$food');

  (int done, int total) levelCount(int level) => switch (level) {
        1 => (metCount, animals.length),
        2 => (partsTotalFound, totalParts),
        _ => (quizTotal, animals.length * quizGoal),
      };
  bool levelDone(int level) {
    final (done, total) = levelCount(level);
    return done >= total;
  }

  bool unlocked(int level) => level == 1 || levelDone(level - 1);

  /// The first level not finished yet; 4 when all three are done.
  int get currentLevel => [1, 2, 3].firstWhere((l) => !levelDone(l), orElse: () => 4);

  /// Is this animal finished for this level?
  bool animalDone(Animal a, int level) => switch (level) {
        1 => met(a.id),
        2 => partsFound(a) == a.parts.length,
        _ => quizScore(a.id) >= quizGoal,
      };

  Mission get mission {
    final level = currentLevel;
    if (level == 4) return const Mission(level: 4, animal: null);
    final animal = animals.firstWhere((a) => !animalDone(a, level));
    final part = level == 2 ? animal.parts.firstWhere((p) => !partFound(animal.id, p.id)) : null;
    return Mission(level: level, animal: animal, part: part);
  }

  // ---- writing (called from the AR screen) ----
  /// Returns what the AR page shows: is it new, the stars, a newly unlocked level.
  Map<String, Object?> markMet(String animal) => _change(() => _met.add(animal));

  Map<String, Object?> markPart(String animal, String part) => _change(() => _parts.add('$animal:$part'));

  /// A right food given in the feeding game (a star the first time).
  Map<String, Object?> markFood(String animal, String food) => _change(() => _food.add('$animal:$food'));

  Map<String, Object?> markQuiz(String animal) => _change(() {
        final n = quizScore(animal);
        if (n >= quizGoal) return false;
        _quiz[animal] = n + 1;
        return true;
      });

  Map<String, Object?> _change(bool Function() apply) {
    final levelBefore = currentLevel;
    final isNew = apply();
    if (isNew) {
      _save();
      notifyListeners();
    }
    final levelAfter = currentLevel;
    return {
      'new': isNew,
      'stars': stars,
      'levelUp': levelAfter > levelBefore ? levelAfter : null, // 4 = everything done
    };
  }

  Future<void> setProfile({required String name, required Lang lang}) async {
    this.name = name.trim();
    this.lang = lang;
    await _prefs.setString('name', this.name);
    await _prefs.setString('lang', lang.name);
    notifyListeners();
  }

  Future<void> setLang(Lang lang) async {
    this.lang = lang;
    await _prefs.setString('lang', lang.name);
    notifyListeners();
  }

  void _save() {
    _prefs.setStringList('met', _met.toList());
    _prefs.setStringList('parts', _parts.toList());
    _prefs.setStringList('food', _food.toList());
    _prefs.setStringList('quiz', [for (final e in _quiz.entries) '${e.key}=${e.value}']);
  }

  @visibleForTesting
  Future<void> resetAll() async {
    _met.clear();
    _parts.clear();
    _quiz.clear();
    _food.clear();
    await _prefs.clear();
    name = '';
    notifyListeners();
  }
}
