import 'package:flutter/material.dart';

import '../books.dart';
import '../cloud.dart';
import '../progress.dart';
import 'home_screen.dart';
import 'parents_screen.dart';

/// The library: one cover per book, with the child's progress in it. Opening
/// a book shows its map (the zoo for animals, the town for vehicles).
class BookshelfScreen extends StatelessWidget {
  const BookshelfScreen({super.key, required this.progress, this.cloud});
  final Progress progress;
  final Cloud? cloud;

  void _open(BuildContext context, Book b) {
    progress.openBook(b.id);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HomeScreen(progress: progress, cloud: cloud)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final s = progress.s;
        final name = progress.name.isEmpty ? s.explorer : progress.name;
        return Scaffold(
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), children: [
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFFFE3CC),
                  child: Text(name.characters.first.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF9A3F12), fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.hello(name), style: const TextStyle(color: Color(0xFF7A6A5C), fontSize: 13)),
                    Text(s.booksTitle,
                        style: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0C2), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF2A60C), size: 20),
                    const SizedBox(width: 3),
                    Text('${progress.stars}',
                        style: const TextStyle(color: Color(0xFF7A4A00), fontWeight: FontWeight.w800)),
                  ]),
                ),
                IconButton(
                  key: const Key('parents'),
                  tooltip: s.parents,
                  onPressed: () => openParents(context, progress, cloud),
                  icon: const Icon(Icons.family_restroom_rounded, color: Color(0xFF5C4A3A)),
                ),
              ]),
              const SizedBox(height: 18),
              Text(s.yourBooks, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 12),
              for (final b in progress.books) ...[
                _BookCover(book: b, progress: progress, onTap: () => _open(context, b)),
                const SizedBox(height: 14),
              ],
              _SoonCover(title: s.heritageBook, icon: Icons.mosque_rounded, soon: s.comingSoon),
            ]),
          ),
        );
      },
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, required this.progress, required this.onTap});
  final Book book;
  final Progress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = progress.s;
    final met = progress.metIn(book);
    final total = book.items.length;
    return Material(
      key: Key('book-${book.id}'),
      color: book.color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // four photos from the book
            SizedBox(
              height: 84,
              child: Row(children: [
                for (final a in book.items.take(4))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(a.thumbAsset, fit: BoxFit.cover, height: 84),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(book.title(progress.lang),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_rounded, color: book.color),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : met / total,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(s.metOf(book.kind, met, total), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SoonCover extends StatelessWidget {
  const _SoonCover({required this.title, required this.icon, required this.soon});
  final String title;
  final IconData icon;
  final String soon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9DD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2D6C4)),
      ),
      child: Row(children: [
        Icon(icon, size: 34, color: const Color(0xFFA89A8C)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A6A5C))),
                Text(soon, style: const TextStyle(fontSize: 12, color: Color(0xFFA89A8C))),
              ]),
        ),
      ]),
    );
  }
}
