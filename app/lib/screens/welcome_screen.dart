import 'package:flutter/material.dart';

import '../l10n.dart';
import '../progress.dart';
import 'home_screen.dart';

/// First launch: pick a language and type a first name (kept on the phone).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.progress});
  final Progress progress;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  late Lang _lang = widget.progress.lang;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    if (_name.text.trim().isEmpty) return;
    widget.progress.setProfile(name: _name.text, lang: _lang);
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang);
    final animals = widget.progress.animals.take(7).toList(); // 7 fit across a phone
    return Directionality(
      textDirection: _lang.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
            // the five animals peeking in
            SizedBox(
              height: 86,
              child: Stack(alignment: Alignment.center, children: [
                for (var i = 0; i < animals.length; i++)
                  Transform.translate(
                    offset: Offset((i - (animals.length - 1) / 2) * 46, i.isEven ? 0 : 10),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: animals[i].color,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child:
                          ClipOval(child: Image.asset(animals[i].thumbAsset, width: 62, height: 62, fit: BoxFit.cover)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 26),
            Text(s.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 28),
            Text(s.chooseLanguage, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7A6A5C))),
            const SizedBox(height: 8),
            Row(children: [
              for (final l in Lang.values) ...[
                Expanded(
                  child: ChoiceChip(
                    key: Key('lang-${l.name}'),
                    label: SizedBox(width: double.infinity, child: Text(l.label, textAlign: TextAlign.center)),
                    selected: _lang == l,
                    onSelected: (_) => setState(() => _lang = l),
                    selectedColor: const Color(0xFFFFE3CC),
                    showCheckmark: false,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (l != Lang.values.last) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 24),
            Text(s.yourName, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7A6A5C))),
            const SizedBox(height: 8),
            TextField(
              key: const Key('name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _start(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: s.nameHint,
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('start'),
              onPressed: _name.text.trim().isEmpty ? null : _start,
              style: FilledButton.styleFrom(
                backgroundColor: brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(s.letsGo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}
