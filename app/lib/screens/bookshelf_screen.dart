import 'package:flutter/material.dart';

import '../books.dart';
import '../cloud.dart';
import '../progress.dart';
import '../ui.dart';
import 'home_screen.dart';
import 'parents_screen.dart';

/// The library: the child's greeting and stars, a card to continue the last
/// book, three numbers, and the books as a grid of covers.
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
        final c = progress.child;
        return Scaffold(
          backgroundColor: AppColors.cream,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
              Row(children: [
                Avatar(name: name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.hello(name), style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
                    Text(s.booksTitle,
                        style: const TextStyle(
                            color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                  ]),
                ),
                StarsChip(progress.stars),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('parents'),
                  tooltip: s.parents,
                  onPressed: () => openParents(context, progress, cloud),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white, side: const BorderSide(color: AppColors.line)),
                  icon: const Icon(Icons.family_restroom_rounded, color: AppColors.muted),
                ),
              ]),
              const SizedBox(height: 18),
              _ContinueCard(progress: progress, onTap: () => _open(context, progress.book)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: StatTile(
                        icon: Icons.star_rounded,
                        value: '${progress.stars}',
                        label: s.statStars,
                        color: AppColors.gold)),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        icon: Icons.explore_rounded,
                        value: '${progress.metAll}',
                        label: s.statDiscovered,
                        color: const Color(0xFF2F6FD0))),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        icon: Icons.timer_rounded,
                        value: '${(c.playSeconds / 60).round()}',
                        label: s.statMinutes,
                        color: AppColors.green)),
              ]),
              SectionLabel(s.yourBooks),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
                children: [
                  for (final b in progress.books)
                    _BookCover(book: b, progress: progress, onTap: () => _open(context, b)),
                  _SoonCover(title: s.heritageBook, soon: s.comingSoon),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// The book the child was last in, with its next mission.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.progress, required this.onTap});
  final Progress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = progress.s;
    final b = progress.book;
    final m = progress.mission;
    final a = m.animal;
    final title = switch (m.level) {
      1 => s.meet(a!, kind: b.kind),
      2 => s.findPart(a!, m.part!, kind: b.kind),
      3 => s.quizOf(a!),
      _ => s.allDone,
    };
    return Material(
      key: const Key('continue'),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      color: b.color,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [b.color, Color.lerp(b.color, Colors.black, 0.22)!],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.continueLearning.toUpperCase()} · ${b.title(progress.lang)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 10),
                ProgressBar(
                  value: b.items.isEmpty ? 0 : progress.metIn(b) / b.items.length,
                  color: Colors.white,
                  track: Colors.white.withOpacity(0.25),
                  height: 6,
                ),
                const SizedBox(height: 6),
                Text(s.metOf(b.kind, progress.metIn(b), b.items.length),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 14),
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: a == null
                    ? const CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.goldBg,
                        child: Icon(Icons.emoji_events_rounded, size: 36, color: AppColors.gold))
                    : ClipOval(child: Image.asset(a.thumbAsset, width: 68, height: 68, fit: BoxFit.cover)),
              ),
              PositionedDirectional(
                end: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: b.color, width: 2),
                  ),
                  child: Icon(Icons.play_arrow_rounded, size: 18, color: b.color),
                ),
              ),
            ]),
          ]),
        ),
      ),
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
    final done = total > 0 && met == total;
    return AppCard(
      key: Key('book-${book.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // four pictures from the book, on its colour
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: book.color, borderRadius: BorderRadius.circular(15)),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final a in book.items.take(4))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(a.thumbAsset, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(book.title(progress.lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
              ),
              if (done) const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
            ]),
            const SizedBox(height: 8),
            ProgressBar(value: total == 0 ? 0 : met / total, color: book.color, height: 6),
            const SizedBox(height: 5),
            Text(s.metOf(book.kind, met, total), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

class _SoonCover extends StatelessWidget {
  const _SoonCover({required this.title, required this.soon});
  final String title;
  final String soon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.mosque_rounded, size: 34, color: AppColors.faint),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted, fontSize: 15)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child:
              Text(soon, style: const TextStyle(fontSize: 11.5, color: AppColors.faint, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
