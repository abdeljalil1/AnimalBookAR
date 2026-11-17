import 'package:animal_book_ar/animals.dart';
import 'package:animal_book_ar/main.dart';
import 'package:animal_book_ar/screens/page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('animals.json lists the five animals with their page images', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final animals = await Animal.load();
    expect(animals.map((a) => a.id), ['horse', 'fox', 'flamingo', 'parrot', 'stork']);
    expect(animals.first.ar, 'حصان');
    expect(animals.first.pageAsset, 'assets/ar/pages/horse.jpg');
  });

  testWidgets('home shows the camera button and every animal; a page opens full screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const AnimalBookApp());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('Open the AR camera'), findsOneWidget);
    for (final name in ['Horse', 'Fox', 'Flamingo', 'Parrot', 'Stork']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Fox'));
    await tester.pumpAndSettle();
    expect(find.byType(PageScreen), findsOneWidget);
    expect(find.text('Fox page'), findsOneWidget);
  });
}
