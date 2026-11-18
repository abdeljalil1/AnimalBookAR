import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../animals.dart';
import '../progress.dart';

/// The zoo map on the home screen: an entrance gate, grass, trees, a sandy
/// path and one fenced enclosure per animal, each with a little scene (hay
/// for the horse, rocks for the fox, a pond for the flamingo, a big tree for
/// the parrot, a nest for the stork). Drawn in code at a 360-wide design size
/// and scaled to the screen.
class ZooPath extends StatelessWidget {
  const ZooPath({
    super.key,
    required this.progress,
    required this.level,
    required this.onTap,
    this.highlight,
  });

  final Progress progress;
  final int level; // which level's progress the signs show (1..3)
  final String? highlight; // the mission animal, drawn bigger with a pulse
  final void Function(Animal) onTap;

  static const designWidth = 360.0;
  static const _step = 152.0; // between enclosures

  /// Enclosure centres for [n] animals, zig-zagging down, in design units.
  static List<Offset> spotsFor(int n) => [for (var i = 0; i < n; i++) Offset(i.isEven ? 108 : 252, 220 + i * _step)];
  static double heightFor(int n) => 220 + (n - 1) * _step + 140;

  /// Enclosure centres, in design units, in book order.

  @override
  Widget build(BuildContext context) {
    final animals = progress.animals;
    return LayoutBuilder(builder: (context, c) {
      final k = c.maxWidth / designWidth;
      return SizedBox(
        width: c.maxWidth,
        height: heightFor(animals.length) * k,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: CustomPaint(
                painter: _ZooPainter(
              gateText: switch (progress.book.map) {
                'town' => progress.s.town,
                'park' => progress.book.title(progress.lang).toUpperCase(),
                _ => progress.s.zoo,
              },
              ids: [for (final a in animals) a.id],
              town: progress.book.map == 'town',
              park: progress.book.map == 'park',
              colors: [for (final a in animals) a.color],
              labels: [for (final a in animals) a.letter ?? ''],
              palms: progress.book.kind == 'heritage',
            )),
          ),
          for (var i = 0; i < animals.length; i++)
            Positioned(
              left: spotsFor(animals.length)[i].dx * k - 60,
              top: spotsFor(animals.length)[i].dy * k - 52,
              width: 120,
              child: _AnimalStop(
                animal: animals[i],
                progress: progress,
                level: level,
                current: animals[i].id == highlight,
                onTap: () => onTap(animals[i]),
              ),
            ),
        ]),
      );
    });
  }
}

/// A round photo in its enclosure, with a wooden sign showing the progress.
class _AnimalStop extends StatefulWidget {
  const _AnimalStop({
    required this.animal,
    required this.progress,
    required this.level,
    required this.current,
    required this.onTap,
  });

  final Animal animal;
  final Progress progress;
  final int level;
  final bool current;
  final VoidCallback onTap;

  @override
  State<_AnimalStop> createState() => _AnimalStopState();
}

class _AnimalStopState extends State<_AnimalStop> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.current) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimalStop old) {
    super.didUpdateWidget(old);
    if (widget.current && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.current && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    final p = widget.progress;
    final lang = p.lang;
    final met = p.met(a.id);
    final done = p.animalDone(a, widget.level);
    final size = widget.current ? 86.0 : 70.0;
    final ring = done ? const Color(0xFF2E9E6A) : (widget.current ? a.color : const Color(0xFFFFFFFF));

    final (score, total) = switch (widget.level) {
      1 => (met ? 1 : 0, 1),
      2 => (p.partsFound(a), a.parts.length),
      _ => (p.quizScore(a.id), quizGoal),
    };

    Widget photo = ClipOval(child: Image.asset(a.thumbAsset, width: size, height: size, fit: BoxFit.cover));
    if (!met) {
      // not met yet: a grey photo with a question mark
      photo = Stack(alignment: Alignment.center, children: [
        ColorFiltered(colorFilter: const ColorFilter.matrix(_greyscale), child: photo),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.35)),
        ),
        Text('?', style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: Colors.white)),
      ]);
    }

    return Semantics(
      button: true,
      label: a.name(lang),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (widget.current)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Container(
                    width: size + 8 + 18 * _pulse.value,
                    height: size + 8 + 18 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.color.withOpacity(0.35 * (1 - _pulse.value)),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ring,
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: photo,
              ),
              if (done)
                Positioned(
                  right: 10,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E9E6A)),
                    child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 2),
          // the wooden sign
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5A2B),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF6E4520), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(a.name(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFFFF4DC), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              if (widget.level > 1 && met) ...[
                const SizedBox(width: 6),
                Text('$score/$total',
                    style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w800, fontSize: 11)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

const _greyscale = <double>[
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0.33, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0,
];

// ---------------------------------------------------------------------------

class _ZooPainter extends CustomPainter {
  _ZooPainter({
    required this.gateText,
    required this.ids,
    this.town = false,
    this.park = false,
    this.colors = const [],
    this.labels = const [],
    this.palms = false,
  });

  final String gateText;
  final bool town; // vehicles: roads and buildings instead of paths and enclosures
  final bool park; // letters and colours: a garden path, a toy block or paint pot by each stop
  final List<Color> colors; // each item's colour (paint pots)
  final List<String> labels; // each item's letter (toy blocks)
  final bool palms; // the Algeria book: a date palm by each stop
  final List<String> ids; // animal ids in path order, for their scenes

  static const _grass = Color(0xFFCDE8B0);
  static const _grassLight = Color(0xFFDDF1C6);
  static const _sand = Color(0xFFF2E3C2);
  static const _sandEdge = Color(0xFFDDC48F);
  static const _wood = Color(0xFF9A6A3A);
  static const _woodDark = Color(0xFF6E4520);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / ZooPath.designWidth;
    canvas.save();
    canvas.scale(k);
    const w = ZooPath.designWidth;
    final h = ZooPath.heightFor(ids.length);
    final spots = ZooPath.spotsFor(ids.length);
    // each animal's scene sits in the other column, level with its enclosure
    final scenePos = [for (final s in spots) Offset(s.dx < w / 2 ? s.dx + 150 : s.dx - 150, s.dy - 8)];

    // grass with lighter patches
    final bg = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(28));
    canvas.drawRRect(bg, Paint()..color = town ? const Color(0xFFD5E3C6) : _grass);
    canvas.save();
    canvas.clipRRect(bg);
    final patch = Paint()..color = town ? const Color(0xFFE3ECD6) : _grassLight;
    for (var y = 120.0, left = true; y < h; y += 140, left = !left) {
      canvas.drawOval(Rect.fromCenter(center: Offset(left ? 60 : 300, y), width: 150, height: 70), patch);
    }

    // the sandy path: gate -> each enclosure -> exit
    final path = Path()..moveTo(w / 2, 96);
    var prev = const Offset(w / 2, 96);
    for (final p in [...spots, Offset(w / 2, h + 10)]) {
      final dy = (p.dy - prev.dy) / 2;
      path.cubicTo(prev.dx, prev.dy + dy, p.dx, p.dy - dy, p.dx, p.dy);
      prev = p;
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = town ? const Color(0xFF5E6670) : _sandEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = town ? 48 : 44
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = town ? const Color(0xFF7A838E) : _sand
          ..style = PaintingStyle.stroke
          ..strokeWidth = town ? 41 : 37
          ..strokeCap = StrokeCap.round);
    // footprints along the middle (zoo), a dashed white line (town)
    final dots = Paint()..color = _sandEdge.withOpacity(0.8);
    final dash = Paint()
      ..color = const Color(0xFFF4F4F4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final samples = <Offset>[];
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        final t = m.getTangentForOffset(d);
        if (t != null) samples.add(t.position);
      }
      if (town) {
        for (var d = 30.0; d + 12 < m.length; d += 28) {
          final a = m.getTangentForOffset(d), b = m.getTangentForOffset(d + 12);
          if (a != null && b != null) canvas.drawLine(a.position, b.position, dash);
        }
      } else {
        for (var d = 20.0; d < m.length; d += 24) {
          final t = m.getTangentForOffset(d);
          if (t != null) canvas.drawCircle(t.position, 2.2, dots);
        }
      }
    }

    // keep decorations off the path and the enclosures
    bool free(Offset o, double r) {
      for (final s in samples) {
        if ((s - o).distance < r + 24) return false;
      }
      for (final s in spots) {
        if ((s - o).distance < r + 62) return false;
      }
      return o.dy > 120 || (o.dx < 90 || o.dx > 270);
    }

    // a little scene for each animal
    for (var i = 0; i < ids.length; i++) {
      final o = scenePos[i];
      if (town) {
        _townBuilding(canvas, ids[i], o);
        continue;
      }
      if (park) {
        if (palms) {
          _palm(canvas, o + const Offset(0, -16));
        } else if (labels.length > i && labels[i].isNotEmpty) {
          _block(canvas, o, labels[i], colors[i]);
        } else if (colors.length > i) {
          _paintPot(canvas, o, colors[i]);
        }
        continue;
      }
      switch (ids[i]) {
        case 'horse' || 'sheep' || 'llama':
          _hay(canvas, o);
        case 'fox' || 'lion':
          _rocks(canvas, o);
        case 'flamingo' || 'elephant':
          _pond(canvas, o);
        case 'camel':
          _palm(canvas, o + const Offset(0, -16));
        case 'parrot':
          _roundTree(canvas, o + const Offset(0, -20), 34);
        case 'stork':
          _nest(canvas, o);
        case 'cow':
          _trough(canvas, o);
        case 'zebra' || 'giraffe':
          _acacia(canvas, o + const Offset(0, -10));
        case 'dog':
          _kennel(canvas, o);
        default:
          _roundTree(canvas, o, 24);
      }
    }

    // fences around the enclosures (the lower arc)
    for (final s in spots) {
      if (town) {
        _parking(canvas, s);
      } else if (!park) {
        _fence(canvas, s, 58);
      }
    }

    // trees and flowers wherever there is room (fixed seed: same zoo every time)
    final rnd = math.Random(7);
    final trees = <Offset>[];
    final treeCount = (h / 44).round();
    for (var i = 0; i < 400 && trees.length < treeCount; i++) {
      final o = Offset(14 + rnd.nextDouble() * (w - 28), 110 + rnd.nextDouble() * (h - 130));
      if (!free(o, 22) || trees.any((t) => (t - o).distance < 46)) continue;
      if (scenePos.any((p) => (p - o).distance < 70)) continue; // keep scenes clear
      trees.add(o);
    }
    trees.sort((a, b) => a.dy.compareTo(b.dy)); // back to front
    for (var i = 0; i < trees.length; i++) {
      if (i % 3 == 1) {
        _pine(canvas, trees[i], 18 + (i % 4) * 2.0);
      } else {
        _roundTree(canvas, trees[i], 18 + (i % 5) * 2.0);
      }
    }
    final flowerColors = [const Color(0xFFF7A1C4), const Color(0xFFFFD166), const Color(0xFFFFFFFF)];
    for (var i = 0; i < (h / 13).round(); i++) {
      final o = Offset(rnd.nextDouble() * w, 110 + rnd.nextDouble() * (h - 110));
      if (!free(o, 4)) continue;
      canvas.drawCircle(o, 2.6, Paint()..color = flowerColors[i % 3]);
      canvas.drawCircle(o, 1, Paint()..color = const Color(0xFFE9A23B));
    }
    canvas.restore(); // clip

    _gate(canvas, const Offset(w / 2, 58));
    canvas.restore(); // scale
  }

  // ---- pieces ----
  void _shadow(Canvas c, Offset o, double rx, double ry) =>
      c.drawOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2), Paint()..color = const Color(0x22000000));

  void _roundTree(Canvas c, Offset o, double r) {
    _shadow(c, o + Offset(0, r * 0.9), r * 0.9, r * 0.28);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: o + Offset(0, r * 0.55), width: r * 0.32, height: r * 0.9),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFF8A5A2E));
    final dark = Paint()..color = const Color(0xFF4E9E55);
    final mid = Paint()..color = const Color(0xFF66B862);
    final light = Paint()..color = const Color(0xFF8ED07A);
    c.drawCircle(o + Offset(-r * 0.45, 0), r * 0.62, dark);
    c.drawCircle(o + Offset(r * 0.45, r * 0.05), r * 0.6, dark);
    c.drawCircle(o + Offset(0, -r * 0.35), r * 0.7, mid);
    c.drawCircle(o + Offset(-r * 0.22, -r * 0.5), r * 0.32, light);
  }

  void _pine(Canvas c, Offset o, double r) {
    _shadow(c, o + Offset(0, r * 0.95), r * 0.7, r * 0.22);
    c.drawRect(Rect.fromCenter(center: o + Offset(0, r * 0.75), width: r * 0.25, height: r * 0.5),
        Paint()..color = const Color(0xFF7A4E27));
    for (var i = 0; i < 3; i++) {
      final top = o.dy - r * 1.1 + i * r * 0.5;
      final half = r * (0.5 + i * 0.22);
      final tri = Path()
        ..moveTo(o.dx, top)
        ..lineTo(o.dx + half, top + r * 0.75)
        ..lineTo(o.dx - half, top + r * 0.75)
        ..close();
      c.drawPath(tri, Paint()..color = i.isEven ? const Color(0xFF3D8B57) : const Color(0xFF4FA066));
    }
  }

  void _fence(Canvas c, Offset center, double r) {
    final rail = Paint()
      ..color = _wood
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final rect = Rect.fromCircle(center: center + const Offset(0, 6), radius: r);
    c.drawArc(rect, math.pi * 0.08, math.pi * 0.84, false, rail);
    c.drawArc(rect.inflate(-5), math.pi * 0.08, math.pi * 0.84, false, rail..strokeWidth = 1.8);
    final post = Paint()..color = _woodDark;
    for (var a = math.pi * 0.08; a <= math.pi * 0.93; a += math.pi * 0.12) {
      final p = rect.center + Offset(math.cos(a), math.sin(a)) * (r - 2);
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 4.5, height: 13), const Radius.circular(2)), post);
    }
  }

  void _hay(Canvas c, Offset o) {
    _shadow(c, o + const Offset(0, 12), 22, 6);
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 42, height: 26), const Radius.circular(7));
    c.drawRRect(body, Paint()..color = const Color(0xFFE9C46A));
    final line = Paint()
      ..color = const Color(0xFFC9A04A)
      ..strokeWidth = 1.5;
    for (final y in [-5.0, 0.0, 5.0]) {
      c.drawLine(o + Offset(-17, y), o + Offset(17, y), line);
    }
    c.drawLine(o + const Offset(-9, -13), o + const Offset(-9, 13), line..color = const Color(0xFFB5452F));
    c.drawLine(o + const Offset(9, -13), o + const Offset(9, 13), line);
  }

  void _rocks(Canvas c, Offset o) {
    _shadow(c, o + const Offset(4, 14), 30, 6);
    c.drawOval(Rect.fromCenter(center: o, width: 46, height: 30), Paint()..color = const Color(0xFFA9A397));
    c.drawOval(Rect.fromCenter(center: o + const Offset(20, 6), width: 28, height: 20),
        Paint()..color = const Color(0xFFBDB8AD));
    c.drawOval(Rect.fromCenter(center: o + const Offset(-4, 5), width: 16, height: 10),
        Paint()..color = const Color(0xFF5E584E)); // den
    c.drawOval(Rect.fromCenter(center: o + const Offset(-8, -6), width: 14, height: 6),
        Paint()..color = const Color(0x55FFFFFF));
  }

  void _pond(Canvas c, Offset o) {
    c.drawOval(Rect.fromCenter(center: o, width: 112, height: 56), Paint()..color = const Color(0xFF9BCFA0));
    c.drawOval(Rect.fromCenter(center: o, width: 102, height: 48), Paint()..color = const Color(0xFF7CC4E4));
    c.drawOval(Rect.fromCenter(center: o + const Offset(-14, -8), width: 40, height: 10),
        Paint()..color = const Color(0x66FFFFFF));
    final pad = Paint()..color = const Color(0xFF4FA066);
    c.drawCircle(o + const Offset(24, 8), 7, pad);
    c.drawCircle(o + const Offset(-30, 10), 5.5, pad);
    c.drawCircle(o + const Offset(25, 7), 2, Paint()..color = const Color(0xFFF7A1C4));
  }

  void _nest(Canvas c, Offset o) {
    _shadow(c, o + const Offset(0, 40), 10, 4);
    c.drawRect(Rect.fromCenter(center: o + const Offset(0, 14), width: 6, height: 52),
        Paint()..color = const Color(0xFF7A4E27));
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -12), width: 38, height: 16),
        Paint()..color = const Color(0xFF8B6B3D));
    final twig = Paint()
      ..color = const Color(0xFF5E4423)
      ..strokeWidth = 1.4;
    for (var i = -3; i <= 3; i++) {
      c.drawLine(o + Offset(i * 5.0 - 3, -17), o + Offset(i * 5.0 + 4, -7), twig);
    }
    c.drawOval(Rect.fromCenter(center: o + const Offset(-5, -18), width: 8, height: 6), Paint()..color = Colors.white);
    c.drawOval(Rect.fromCenter(center: o + const Offset(5, -18), width: 8, height: 6), Paint()..color = Colors.white);
  }

  void _trough(Canvas c, Offset o) {
    _shadow(c, o + const Offset(0, 14), 30, 6);
    final wood = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 58, height: 24), const Radius.circular(5));
    c.drawRRect(wood, Paint()..color = const Color(0xFF8A5A2E));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: o + const Offset(0, -3), width: 50, height: 12), const Radius.circular(4)),
        Paint()..color = const Color(0xFF7CC4E4));
    c.drawOval(Rect.fromCenter(center: o + const Offset(-10, -5), width: 16, height: 4),
        Paint()..color = const Color(0x66FFFFFF));
  }

  void _acacia(Canvas c, Offset o) {
    _shadow(c, o + const Offset(0, 34), 30, 7);
    final trunk = Paint()
      ..color = const Color(0xFF7A4E27)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    c.drawLine(o + const Offset(0, 34), o + const Offset(0, 0), trunk);
    c.drawLine(o, o + const Offset(-14, -10), trunk..strokeWidth = 4);
    c.drawLine(o, o + const Offset(14, -10), trunk);
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -16), width: 78, height: 20),
        Paint()..color = const Color(0xFF6F9E3E));
    c.drawOval(Rect.fromCenter(center: o + const Offset(-6, -20), width: 46, height: 10),
        Paint()..color = const Color(0xFF8DBA55));
  }

  void _palm(Canvas c, Offset o) {
    // a little sand dune and a date palm
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 40), width: 90, height: 22),
        Paint()..color = const Color(0xFFEBD3A0));
    final trunk = Path()
      ..moveTo(o.dx - 4, o.dy + 40)
      ..quadraticBezierTo(o.dx - 2, o.dy + 10, o.dx + 4, o.dy - 18)
      ..lineTo(o.dx + 9, o.dy - 17)
      ..quadraticBezierTo(o.dx + 4, o.dy + 10, o.dx + 5, o.dy + 40)
      ..close();
    c.drawPath(trunk, Paint()..color = const Color(0xFF9A6A3A));
    final leaf = Paint()..color = const Color(0xFF4FA066);
    for (final a in [-2.6, -2.0, -1.2, -0.6, 0.0]) {
      final tip = o + const Offset(6, -18) + Offset(math.cos(a), math.sin(a) * 0.6) * 32;
      final path = Path()
        ..moveTo(o.dx + 6, o.dy - 18)
        ..quadraticBezierTo((o.dx + 6 + tip.dx) / 2, o.dy - 34, tip.dx, tip.dy)
        ..quadraticBezierTo((o.dx + 6 + tip.dx) / 2, o.dy - 22, o.dx + 6, o.dy - 18);
      c.drawPath(path, leaf);
    }
    for (final d in [const Offset(2, -14), const Offset(9, -13), const Offset(5, -10)]) {
      c.drawCircle(o + d, 3, Paint()..color = const Color(0xFF7A3E1D)); // dates
    }
  }

  void _kennel(Canvas c, Offset o) {
    _shadow(c, o + const Offset(0, 18), 28, 6);
    c.drawRect(Rect.fromCenter(center: o + const Offset(0, 4), width: 46, height: 28),
        Paint()..color = const Color(0xFFC98A12));
    final roof = Path()
      ..moveTo(o.dx - 30, o.dy - 8)
      ..lineTo(o.dx, o.dy - 30)
      ..lineTo(o.dx + 30, o.dy - 8)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFB5452F));
    c.drawRRect(
        RRect.fromRectAndCorners(Rect.fromCenter(center: o + const Offset(0, 10), width: 18, height: 18),
            topLeft: const Radius.circular(9), topRight: const Radius.circular(9)),
        Paint()..color = const Color(0xFF4A3420));
    c.drawCircle(o + const Offset(20, 16), 4, Paint()..color = const Color(0xFFF2F2F2)); // bowl
  }

  void _gate(Canvas c, Offset o) {
    final post = Paint()..color = town ? const Color(0xFF9AA3AD) : _wood;
    final cap = Paint()..color = town ? const Color(0xFF6B7480) : _woodDark;
    for (final dx in [-78.0, 78.0]) {
      final p = o + Offset(dx, 6);
      _shadow(c, p + const Offset(0, 36), 14, 4);
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 18, height: 72), const Radius.circular(4)), post);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p + const Offset(0, -38), width: 24, height: 9), const Radius.circular(3)),
          cap);
      _roundTree(c, p + Offset(dx > 0 ? 34 : -34, 20), 20);
    }
    // the arch sign
    final sign = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o + const Offset(0, -20), width: 190, height: 40), const Radius.circular(12));
    c.drawRRect(sign.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
    c.drawRRect(sign, Paint()..color = town ? const Color(0xFF2F6FD0) : const Color(0xFF8B5A2B));
    c.drawRRect(
        sign.deflate(4),
        Paint()
          ..color = town ? const Color(0xFFFFFFFF) : const Color(0xFFB07A44)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Shrinks to fit ("حديقة الحيوانات" is longer than "ZOO"); no letter
    // spacing for Arabic, it would break the joined letters.
    final latin = RegExp(r'^[\x00-\x7F]*$').hasMatch(gateText);
    TextPainter label(double size) => TextPainter(
          text: TextSpan(
            text: gateText,
            style: TextStyle(
                color: const Color(0xFFFFF4DC),
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: latin ? 2 : 0,
                fontFamily: latin ? 'Poppins' : 'Tajawal',
                fontFamilyFallback: const ['Tajawal', 'Poppins']),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
    var tp = label(22);
    if (tp.width > 170) tp = label(22 * 170 / tp.width);
    tp.paint(c, o + Offset(-tp.width / 2, -20 - tp.height / 2));
    // leaves on the sign
    for (final dx in [-92.0, 92.0]) {
      c.drawCircle(o + Offset(dx, -30), 10, Paint()..color = const Color(0xFF66B862));
      c.drawCircle(o + Offset(dx * 0.93, -38), 7, Paint()..color = const Color(0xFF8ED07A));
    }
  }

  // ---- park pieces ----
  void _block(Canvas c, Offset o, String letter, Color color) {
    _shadow(c, o + const Offset(4, 22), 26, 6);
    final side = Path()
      ..moveTo(o.dx + 20, o.dy - 20)
      ..lineTo(o.dx + 30, o.dy - 28)
      ..lineTo(o.dx + 30, o.dy + 12)
      ..lineTo(o.dx + 20, o.dy + 20)
      ..close();
    c.drawPath(side, Paint()..color = Color.lerp(color, Colors.black, 0.35)!);
    final top = Path()
      ..moveTo(o.dx - 20, o.dy - 20)
      ..lineTo(o.dx - 10, o.dy - 28)
      ..lineTo(o.dx + 30, o.dy - 28)
      ..lineTo(o.dx + 20, o.dy - 20)
      ..close();
    c.drawPath(top, Paint()..color = Color.lerp(color, Colors.white, 0.35)!);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 40, height: 40), const Radius.circular(4)),
        Paint()..color = color);
    final latin = RegExp(r'^[\x00-\x7F]*$').hasMatch(letter);
    final tp = TextPainter(
      text: TextSpan(
          text: latin ? letter.substring(0, 1) : letter,
          style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: latin ? 'Poppins' : 'Tajawal',
              height: 1.1)),
      textDirection: latin ? TextDirection.ltr : TextDirection.rtl,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2 - (latin ? 0 : 3)));
  }

  void _paintPot(Canvas c, Offset o, Color color) {
    _shadow(c, o + const Offset(0, 20), 26, 6);
    // a splash on the grass, then the pot
    final splash = Paint()..color = color.withOpacity(0.55);
    for (final d in [const Offset(-26, 14), const Offset(24, 18), const Offset(-8, 22), const Offset(30, 2)]) {
      c.drawCircle(o + d, 7, splash);
    }
    c.drawOval(Rect.fromCenter(center: o + const Offset(4, 18), width: 58, height: 16), splash);
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o + const Offset(0, 2), width: 36, height: 34), const Radius.circular(6));
    c.drawRRect(body, Paint()..color = const Color(0xFFB9BEC4));
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -15), width: 36, height: 12),
        Paint()..color = const Color(0xFF8E959C));
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, -15), width: 30, height: 9), Paint()..color = color);
    c.drawRect(Rect.fromCenter(center: o + const Offset(0, 4), width: 36, height: 10), Paint()..color = color);
  }

  // ---- town pieces ----
  void _parking(Canvas c, Offset center) {
    // a round paved stop with a kerb, like a little roundabout
    final r = Rect.fromCircle(center: center + const Offset(0, 6), radius: 56);
    c.drawArc(
        r,
        math.pi * 0.08,
        math.pi * 0.84,
        false,
        Paint()
          ..color = const Color(0xFFB9BEC4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    final stripe = Paint()
      ..color = const Color(0xFFE04F3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    for (var a = math.pi * 0.08; a < math.pi * 0.9; a += math.pi * 0.16) {
      c.drawArc(r, a, math.pi * 0.06, false, stripe);
    }
  }

  void _house(Canvas c, Offset o,
      {required double w,
      required double h,
      required Color wall,
      required Color roof,
      bool flat = false,
      int windows = 2,
      Color? door}) {
    _shadow(c, o + Offset(0, h / 2 + 4), w * 0.55, 6);
    final body = Rect.fromCenter(center: o, width: w, height: h);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), Paint()..color = wall);
    if (flat) {
      c.drawRect(Rect.fromLTWH(body.left - 3, body.top - 6, w + 6, 7), Paint()..color = roof);
    } else {
      final p = Path()
        ..moveTo(body.left - 6, body.top + 1)
        ..lineTo(o.dx, body.top - h * 0.5)
        ..lineTo(body.right + 6, body.top + 1)
        ..close();
      c.drawPath(p, Paint()..color = roof);
    }
    final glass = Paint()..color = const Color(0xFFBFE3F5);
    for (var i = 0; i < windows; i++) {
      final x = body.left + w * (i + 0.5) / windows;
      c.drawRect(Rect.fromCenter(center: Offset(x, body.top + h * 0.3), width: 9, height: 8), glass);
    }
    if (door != null) {
      c.drawRect(Rect.fromLTWH(o.dx - 6, body.bottom - 14, 12, 14), Paint()..color = door);
    }
  }

  void _text(Canvas c, String t, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _townBuilding(Canvas c, String id, Offset o) {
    switch (id) {
      case 'firetruck': // fire station: red, two big doors
        _house(c, o,
            w: 66, h: 38, wall: const Color(0xFFD9473A), roof: const Color(0xFF8E2A22), flat: true, windows: 0);
        for (final dx in [-15.0, 15.0]) {
          c.drawRect(Rect.fromCenter(center: o + Offset(dx, 6), width: 24, height: 24),
              Paint()..color = const Color(0xFFF2D3CF));
          for (var y = -3.0; y < 18; y += 5) {
            c.drawLine(o + Offset(dx - 12, y), o + Offset(dx + 12, y), Paint()..color = const Color(0xFFC9A9A4));
          }
        }
        c.drawCircle(o + const Offset(0, -15), 5, Paint()..color = const Color(0xFFFFD166));
      case 'police': // police station: blue, flat, a light on top
        _house(c, o,
            w: 62,
            h: 36,
            wall: const Color(0xFF3E6FB8),
            roof: const Color(0xFF223F6B),
            flat: true,
            windows: 3,
            door: const Color(0xFF223F6B));
        c.drawRect(Rect.fromCenter(center: o + const Offset(0, -26), width: 10, height: 7),
            Paint()..color = const Color(0xFF5BB4FF));
      case 'ambulance': // hospital: white, red cross / H
        _house(c, o,
            w: 60,
            h: 46,
            wall: const Color(0xFFF6F6F6),
            roof: const Color(0xFFB9BEC4),
            flat: true,
            windows: 3,
            door: const Color(0xFF9BC3E0));
        c.drawCircle(o + const Offset(0, -2), 9, Paint()..color = const Color(0xFFE04F3F));
        _text(c, 'H', o + const Offset(0, -2), 12, Colors.white);
      case 'bus': // school: yellow with a clock and a flag
        _house(c, o,
            w: 64,
            h: 36,
            wall: const Color(0xFFF2C14E),
            roof: const Color(0xFFB5452F),
            windows: 3,
            door: const Color(0xFF8A5A2E));
        c.drawCircle(o + const Offset(0, -26), 6, Paint()..color = Colors.white);
        c.drawLine(o + const Offset(0, -26), o + const Offset(0, -30), Paint()..color = const Color(0xFF333333));
        c.drawLine(o + const Offset(0, -26), o + const Offset(3, -26), Paint()..color = const Color(0xFF333333));
      case 'tractor': // farm: red barn and a little field
        for (var i = 0; i < 4; i++) {
          c.drawRect(Rect.fromLTWH(o.dx - 52, o.dy + 22 + i * 5.0, 104, 3), Paint()..color = const Color(0xFFB98A4E));
        }
        _house(c, o, w: 48, h: 36, wall: const Color(0xFFB5452F), roof: const Color(0xFF6E2A1F), windows: 0);
        final x = Paint()
          ..color = Colors.white
          ..strokeWidth = 2;
        c.drawRect(Rect.fromCenter(center: o + const Offset(0, 6), width: 18, height: 22),
            Paint()..color = const Color(0xFF6E2A1F));
        c.drawLine(o + const Offset(-9, -5), o + const Offset(9, 17), x);
        c.drawLine(o + const Offset(9, -5), o + const Offset(-9, 17), x);
      case 'taxi': // taxi stand: a sign and a shelter
        _house(c, o,
            w: 54, h: 26, wall: const Color(0xFFF7F1E1), roof: const Color(0xFF333333), flat: true, windows: 2);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: o + const Offset(0, -24), width: 40, height: 14), const Radius.circular(3)),
            Paint()..color = const Color(0xFFFFC928));
        _text(c, 'TAXI', o + const Offset(0, -24), 9, const Color(0xFF222222));
      case 'truck': // warehouse with boxes
        _house(c, o, w: 70, h: 36, wall: const Color(0xFF9AA3AD), roof: const Color(0xFF5E6670), windows: 0);
        c.drawRect(Rect.fromCenter(center: o + const Offset(-8, 6), width: 30, height: 24),
            Paint()..color = const Color(0xFF6B7480));
        for (final d in [const Offset(26, 14), const Offset(38, 14), const Offset(32, 4)]) {
          c.drawRect(Rect.fromCenter(center: o + d, width: 11, height: 10), Paint()..color = const Color(0xFFC98A4E));
        }
      case 'motorcycle': // petrol station: canopy and a pump
        c.drawRect(Rect.fromCenter(center: o + const Offset(0, -16), width: 70, height: 9),
            Paint()..color = const Color(0xFF2E9E6A));
        for (final dx in [-30.0, 30.0]) {
          c.drawRect(Rect.fromCenter(center: o + Offset(dx, 4), width: 4, height: 32),
              Paint()..color = const Color(0xFFB9BEC4));
        }
        _shadow(c, o + const Offset(0, 22), 30, 5);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: o + const Offset(0, 8), width: 16, height: 24), const Radius.circular(3)),
            Paint()..color = const Color(0xFFE04F3F));
        c.drawRect(
            Rect.fromCenter(center: o + const Offset(0, 2), width: 10, height: 6), Paint()..color = Colors.white);
      default: // car: a house with a garage
        _house(c, o + const Offset(-10, 0),
            w: 42,
            h: 34,
            wall: const Color(0xFFF4E3C3),
            roof: const Color(0xFFB5452F),
            windows: 2,
            door: const Color(0xFF8A5A2E));
        c.drawRect(Rect.fromCenter(center: o + const Offset(24, 6), width: 26, height: 22),
            Paint()..color = const Color(0xFFE9D3AB));
        c.drawRect(Rect.fromCenter(center: o + const Offset(24, 9), width: 20, height: 16),
            Paint()..color = const Color(0xFFB9BEC4));
    }
  }

  @override
  bool shouldRepaint(covariant _ZooPainter old) =>
      old.gateText != gateText ||
      old.town != town ||
      old.park != park ||
      old.palms != palms ||
      old.ids.join() != ids.join();
}
