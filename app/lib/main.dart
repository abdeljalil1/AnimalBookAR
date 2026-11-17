import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AnimalBookApp());
}

class AnimalBookApp extends StatelessWidget {
  const AnimalBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animal Book AR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8702A)),
        scaffoldBackgroundColor: const Color(0xFFFFFAF0),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
