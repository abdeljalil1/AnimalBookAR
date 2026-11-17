import 'package:flutter/material.dart';

/// The app's look in one place: colours, card style, section headers and
/// small building blocks shared by the welcome, bookshelf and parents screens.
class AppColors {
  static const brand = Color(0xFFE8702A);
  static const brandDark = Color(0xFFC4561A);
  static const ink = Color(0xFF2B2118);
  static const muted = Color(0xFF7A6A5C);
  static const faint = Color(0xFFA89A8C);
  static const cream = Color(0xFFFFFAF0);
  static const sand = Color(0xFFF4ECE0);
  static const line = Color(0xFFEADFCF);
  static const gold = Color(0xFFF2A60C);
  static const goldBg = Color(0xFFFFF0C2);
  static const green = Color(0xFF2E9E6A);
}

/// A white card with a hairline border and a soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0F2B2118), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "YOUR BOOKS" style label above a group, with an optional action on the end.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.muted)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// A round initial for a child.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 44, this.selected = false});
  final String name;
  final double size;
  final bool selected;

  static const _palette = [
    Color(0xFFE8702A),
    Color(0xFF2F6FD0),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF7E57C2),
    Color(0xFF6B8E23),
  ];

  @override
  Widget build(BuildContext context) {
    final c = _palette[name.isEmpty ? 0 : name.codeUnitAt(0) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: Border.all(color: selected ? AppColors.ink : Colors.white, width: selected ? 3 : 2),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42)),
    );
  }
}

/// The star count chip.
class StarsChip extends StatelessWidget {
  const StarsChip(this.stars, {super.key});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('stars'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: AppColors.goldBg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
        const SizedBox(width: 4),
        Text('$stars', style: const TextStyle(color: Color(0xFF7A4A00), fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }
}

/// A big number with a label and an icon (dashboards).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: c),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
        Text(label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.2)),
      ]),
    );
  }
}

/// A thin rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 8, this.track});
  final double value;
  final Color color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: track ?? color.withOpacity(0.15),
        color: color,
      ),
    );
  }
}
