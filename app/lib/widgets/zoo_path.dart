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
            child: CustomPaint(painter: _ZooPainter(gateText: progress.s.zoo, ids: [for (final a in animals) a.id])),
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
  _ZooPainter({required this.gateText, required this.ids});

  final String gateText;
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
    canvas.drawRRect(bg, Paint()..color = _grass);
    canvas.save();
    canvas.clipRRect(bg);
    final patch = Paint()..color = _grassLight;
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
          ..color = _sandEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 44
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = _sand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 37
          ..strokeCap = StrokeCap.round);
    // footprints along the middle
    final dots = Paint()..color = _sandEdge.withOpacity(0.8);
    final samples = <Offset>[];
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        final t = m.getTangentForOffset(d);
        if (t != null) samples.add(t.position);
      }
      for (var d = 20.0; d < m.length; d += 24) {
        final t = m.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 2.2, dots);
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
      switch (ids[i]) {
        case 'horse' || 'sheep' || 'llama':
          _hay(canvas, o);
        case 'fox':
          _rocks(canvas, o);
        case 'flamingo':
          _pond(canvas, o);
        case 'parrot':
          _roundTree(canvas, o + const Offset(0, -20), 34);
        case 'stork':
          _nest(canvas, o);
        case 'cow':
          _trough(canvas, o);
        case 'zebra':
          _acacia(canvas, o + const Offset(0, -10));
        case 'dog':
          _kennel(canvas, o);
        default:
          _roundTree(canvas, o, 24);
      }
    }

    // fences around the enclosures (the lower arc)
    for (final s in spots) {
      _fence(canvas, s, 58);
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
    final post = Paint()..color = _wood;
    final cap = Paint()..color = _woodDark;
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
    c.drawRRect(sign, Paint()..color = const Color(0xFF8B5A2B));
    c.drawRRect(
        sign.deflate(4),
        Paint()
          ..color = const Color(0xFFB07A44)
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

  @override
  bool shouldRepaint(covariant _ZooPainter old) => old.gateText != gateText || old.ids.join() != ids.join();
}
