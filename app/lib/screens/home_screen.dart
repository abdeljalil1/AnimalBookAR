import 'package:flutter/material.dart';

import '../animals.dart';
import 'ar_screen.dart';
import 'page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Animal>> _animals = Animal.load();

  void _openCamera() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Animal>>(
          future: _animals,
          builder: (context, snap) {
            final animals = snap.data ?? const <Animal>[];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverList.list(children: [
                    Text('Animal Book AR',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE8702A),
                        )),
                    const SizedBox(height: 6),
                    Text(
                      'Point the camera at a page of the book and the animal comes to life. '
                      'Hear it, turn it, make it bigger.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('open-camera'),
                      onPressed: _openCamera,
                      icon: const Icon(Icons.photo_camera, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Open the AR camera', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8702A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _HowTo(),
                    const SizedBox(height: 22),
                    Text('Animals in the book',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('No printed book? Tap a page to show it full screen, then point another phone at it.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                    const SizedBox(height: 12),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid.builder(
                    itemCount: animals.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemBuilder: (context, i) => _AnimalCard(animal: animals[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.menu_book, 'Open the book at an animal page'),
      (Icons.photo_camera, 'Point the camera at the whole page'),
      (Icons.touch_app, 'Tap the animal to hear it. Drag to turn it, pinch to zoom'),
      (Icons.center_focus_strong, 'Aim the circle at its head, tail or wings to learn their names'),
      (Icons.back_hand, 'Tap Hold to keep the animal and look around it'),
    ];
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final (icon, text) in steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFE3CC),
                    child: Icon(icon, color: const Color(0xFFE8702A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageScreen(animal: animal)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Image.asset(animal.pageAsset, fit: BoxFit.cover)),
            Container(
              color: animal.color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text(animal.en,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(animal.ar,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
