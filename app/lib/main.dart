import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'animals.dart';
import 'l10n.dart';
import 'progress.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final animals = await Animal.load();
  final progress = await Progress.load(animals);
  runApp(AnimalBookApp(progress: progress));
}

class AnimalBookApp extends StatelessWidget {
  const AnimalBookApp({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final lang = progress.lang;
        return MaterialApp(
          title: 'Animal Book AR',
          debugShowCheckedModeBanner: false,
          locale: lang.locale,
          supportedLocales: [for (final l in Lang.values) l.locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: brand),
            scaffoldBackgroundColor: const Color(0xFFFFFAF0),
            // Tajawal first for Arabic (it has Latin too); Poppins otherwise.
            fontFamily: lang == Lang.ar ? 'Tajawal' : 'Poppins',
            fontFamilyFallback: const ['Poppins', 'Tajawal'],
            useMaterial3: true,
          ),
          home: progress.hasProfile ? HomeScreen(progress: progress) : WelcomeScreen(progress: progress),
        );
      },
    );
  }
}
