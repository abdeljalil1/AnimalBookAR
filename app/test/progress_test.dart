import 'package:animal_book_ar/animals.dart';
import 'package:animal_book_ar/l10n.dart';
import 'package:animal_book_ar/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Animal> animals;

  setUpAll(() async => animals = await Animal.load());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts at level 1 with a mission to meet the first animal', () async {
    final p = await Progress.load(animals);
    expect(p.currentLevel, 1);
    expect(p.stars, 0);
    expect(p.unlocked(2), isFalse);
    final m = p.mission;
    expect(m.level, 1);
    expect(m.animal!.id, 'horse');
    expect(const S(Lang.en).meet(m.animal!), 'Meet the horse');
    expect(const S(Lang.fr).meet(m.animal!), 'Découvre le cheval');
    expect(const S(Lang.ar).meet(m.animal!), 'تعرّف على الحصان');
  });

  test('meeting all animals unlocks level 2 and reports it once', () async {
    final p = await Progress.load(animals);
    for (final a in animals.take(4)) {
      expect(p.markMet(a.id)['levelUp'], isNull);
    }
    final last = p.markMet(animals.last.id);
    expect(last['new'], isTrue);
    expect(last['levelUp'], 2);
    expect(p.markMet(animals.last.id)['new'], isFalse); // again: nothing new
    expect(p.unlocked(2), isTrue);
    expect(p.stars, 5);
    final m = p.mission;
    expect(m.level, 2);
    expect(const S(Lang.en).findPart(m.animal!, m.part!), "Find the horse's head");
    expect(const S(Lang.fr).findPart(m.animal!, m.part!), 'Trouve la tête du cheval');
    expect(const S(Lang.ar).findPart(m.animal!, m.part!), 'ابحث عن رأس الحصان');
  });

  test('all parts unlock the quiz; three answers per animal finish it', () async {
    final p = await Progress.load(animals);
    for (final a in animals) {
      p.markMet(a.id);
    }
    Map<String, Object?>? r;
    for (final a in animals) {
      for (final part in a.parts) {
        r = p.markPart(a.id, part.id);
      }
    }
    expect(r!['levelUp'], 3);
    expect(p.mission.quiz, isTrue);
    expect(const S(Lang.fr).quizOf(p.mission.animal!), 'Quiz du cheval');
    for (final a in animals) {
      for (var i = 0; i < quizGoal; i++) {
        r = p.markQuiz(a.id);
      }
      expect(p.markQuiz(a.id)['new'], isFalse); // capped at quizGoal
    }
    expect(r!['levelUp'], 4); // everything done
    expect(p.currentLevel, 4);
    expect(p.stars, animals.length + p.totalParts + animals.length * quizGoal);
  });

  test('progress is saved on the phone', () async {
    final p = await Progress.load(animals);
    await p.setProfile(name: ' Yahia ', lang: Lang.ar);
    p.markMet('fox');
    p.markPart('fox', 'tail');
    p.markQuiz('fox');
    final again = await Progress.load(animals);
    expect(again.name, 'Yahia');
    expect(again.lang, Lang.ar);
    expect(again.met('fox'), isTrue);
    expect(again.partFound('fox', 'tail'), isTrue);
    expect(again.quizScore('fox'), 1);
  });
}
