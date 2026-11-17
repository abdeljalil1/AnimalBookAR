import 'package:flutter/material.dart';

import '../animals.dart';

/// Shows one book page full screen, so a second phone can scan it when there
/// is no printed book at hand.
class PageScreen extends StatelessWidget {
  const PageScreen({super.key, required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${animal.en} page'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(child: Image.asset(animal.pageAsset, fit: BoxFit.contain)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Point another phone with Animal Book AR at this page, or print the book.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
