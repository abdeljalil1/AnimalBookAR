import 'package:animal_book_ar/animals.dart';
import 'package:animal_book_ar/main.dart';
import 'package:animal_book_ar/progress.dart';
import 'package:animal_book_ar/screens/animal_sheet.dart';
import 'package:animal_book_ar/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Progress> _progress(WidgetTester tester, Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return (await tester.runAsync(() async => Progress.load(await Animal.load())))!;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // images
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('first launch asks for a name, then shows the zoo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = await _progress(tester, {});
    await tester.pumpWidget(AnimalBookApp(progress: p));
    await _settle(tester);

    expect(find.text('Welcome to the zoo!'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name')), 'Yahia');
    await tester.pump();
    await tester.tap(find.byKey(const Key('start')));
    await _settle(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hello, Yahia'), findsOneWidget);
    expect(find.text('Meet the horse'), findsOneWidget); // the first mission
    expect(find.text('Open your book at page 1'), findsOneWidget);
  });

  testWidgets('home shows the levels, the path and an animal sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = await _progress(tester, {
      'name': 'Yahia',
      'met': ['horse', 'fox', 'flamingo', 'parrot', 'stork'],
      'parts': ['fox:head', 'fox:ear'],
    });
    await tester.pumpWidget(AnimalBookApp(progress: p));
    await _settle(tester);

    expect(find.text("Find the horse's head"), findsOneWidget); // level 2 mission
    expect(find.text('2 of 27 parts'), findsOneWidget);
    for (final name in ['Horse', 'Fox', 'Flamingo', 'Parrot', 'Stork']) {
      expect(find.text(name), findsOneWidget); // the zoo signs
    }
    expect(find.text('2/6'), findsOneWidget); // fox sign: 2 of 6 parts

    // level 3 is locked
    await tester.tap(find.byKey(const Key('level-3')));
    await tester.pump();
    expect(find.text('Finish level 2 first'), findsOneWidget);

    await tester.tap(find.text('Fox'));
    await _settle(tester);
    expect(find.byType(AnimalSheet), findsOneWidget);
    expect(find.text('2 of 6 found'), findsOneWidget);
    expect(find.text('Head'), findsOneWidget);
    expect(find.text('?'), findsNWidgets(4)); // parts not found yet stay a mystery
  });

  testWidgets('switching to Arabic lays the app out right to left', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = await _progress(tester, {'name': 'Yahia', 'lang': 'ar'});
    await tester.pumpWidget(AnimalBookApp(progress: p));
    await _settle(tester);

    expect(find.text('تعرّف على الحصان'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('mission')))), TextDirection.rtl);
  });
}
