import 'package:flutter/material.dart';

import '../animals.dart';
import '../progress.dart';

/// Shows one book page full screen, so a second phone can scan it when there
/// is no printed book at hand.
class PageScreen extends StatelessWidget {
  const PageScreen({super.key, required this.animal, required this.progress});
  final Animal animal;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final s = progress.s;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${animal.name(progress.lang)} · ${s.page(animal.page)}'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 4,
              child: Center(child: Image.asset(animal.pageAsset, fit: BoxFit.contain)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.showPageHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ),
        ]),
      ),
    );
  }
}
