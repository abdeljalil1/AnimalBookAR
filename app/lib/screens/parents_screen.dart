import 'dart:math';

import 'package:flutter/material.dart';

import '../cloud.dart';
import '../progress.dart';
import 'home_screen.dart' show brand, ink;

/// Asks a small sum children usually can't do yet, then opens [ParentsScreen].
Future<void> openParents(BuildContext context, Progress progress, Cloud? cloud) async {
  final s = progress.s;
  final r = Random();
  final a = 6 + r.nextInt(7), b = 5 + r.nextInt(8);
  final answers = {a + b, a + b + 1 + r.nextInt(3), a + b - 1 - r.nextInt(3)}.toList()..shuffle();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.forParents),
      content: Text(s.gateQuestion(a, b), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      actions: [
        for (final n in answers)
          FilledButton.tonal(
            key: Key('gate-$n'),
            onPressed: () => Navigator.of(ctx).pop(n == a + b),
            child: Text('$n', style: const TextStyle(fontSize: 18)),
          ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ParentsScreen(progress: progress, cloud: cloud)));
  }
}

class ParentsScreen extends StatelessWidget {
  const ParentsScreen({super.key, required this.progress, required this.cloud});
  final Progress progress;
  final Cloud? cloud;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([progress, if (cloud != null) cloud!]),
      builder: (context, _) {
        final s = progress.s;
        return Scaffold(
          appBar: AppBar(title: Text(s.parents), backgroundColor: const Color(0xFFFFFAF0)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            _Section(title: s.account, child: _AccountCard(progress: progress, cloud: cloud)),
            _Section(title: s.children, child: _ChildrenCard(progress: progress)),
            _Section(title: s.progressOf(progress.name), child: _StatsCard(progress: progress)),
          ]),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.progress, required this.cloud});
  final Progress progress;
  final Cloud? cloud;

  @override
  Widget build(BuildContext context) {
    final s = progress.s;
    final c = cloud;
    if (c == null) return Text(s.cloudOff);
    final user = c.user;
    final error = c.lastError;
    if (user != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF2E9E6A)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(s.signedInAs(user.email ?? user.displayName ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          if (c.syncing) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!c.syncing) const Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF2E9E6A)),
          const SizedBox(width: 6),
          Text(c.syncing ? s.syncingNow : s.synced, style: const TextStyle(color: Color(0xFF7A6A5C))),
        ]),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.authError(error), style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: c.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(s.signOut)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.syncPitch, style: const TextStyle(color: Color(0xFF4A3C30))),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('google-sign-in'),
        onPressed: c.signInWithGoogle,
        icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
        label: Text(s.continueGoogle),
        style: FilledButton.styleFrom(backgroundColor: brand, padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('email-sign-in'),
        onPressed: () => showDialog<void>(context: context, builder: (_) => _EmailDialog(progress: progress, cloud: c)),
        icon: const Icon(Icons.mail_outline_rounded),
        label: Text(s.useEmail),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
      if (error != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(s.authError(error), style: const TextStyle(color: Colors.red))),
    ]);
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.progress, required this.cloud});
  final Progress progress;
  final Cloud cloud;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() call, {String? success}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    await call();
    if (!mounted) return;
    final err = widget.cloud.lastError;
    setState(() {
      _busy = false;
      _message = err != null ? widget.progress.s.authError(err) : success;
    });
    if (err == null && success == null && widget.cloud.user != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.progress.s;
    final c = widget.cloud;
    return AlertDialog(
      title: Text(s.useEmail),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(labelText: s.email)),
        TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: s.password)),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message!)),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
      ]),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _run(() => c.resetPassword(_email.text), success: s.resetSent),
          child: Text(s.forgotPassword),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(() => c.createAccount(_email.text, _password.text)),
          child: Text(s.createAccount),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _run(() => c.signInWithEmail(_email.text, _password.text)),
          child: Text(s.signIn),
        ),
      ],
    );
  }
}

class _ChildrenCard extends StatelessWidget {
  const _ChildrenCard({required this.progress});
  final Progress progress;

  Future<String?> _askName(BuildContext context, {String initial = ''}) {
    final s = progress.s;
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.yourName),
        content:
            TextField(controller: ctrl, autofocus: true, maxLength: 20, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: Text(s.save)),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String text) async {
    final s = progress.s;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(text),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.delete)),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final s = p.s;
    return Column(children: [
      for (final c in p.children)
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => p.switchChild(c.id),
          leading: CircleAvatar(
            backgroundColor: c.id == p.child.id ? brand : const Color(0xFFFFE3CC),
            child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase(),
                style: TextStyle(
                    color: c.id == p.child.id ? Colors.white : const Color(0xFF9A3F12), fontWeight: FontWeight.w800)),
          ),
          title: Text(c.name, style: TextStyle(fontWeight: c.id == p.child.id ? FontWeight.w800 : FontWeight.w600)),
          subtitle: Row(children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF2A60C)),
            Text(' ${p.starsOf(c)}'),
          ]),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final n = await _askName(context, initial: c.name);
                if (n != null && n.isNotEmpty) p.renameChild(c.id, n);
              } else if (v == 'reset') {
                if (context.mounted && await _confirm(context, s.confirmReset(c.name))) p.resetChild(c.id);
              } else if (v == 'delete') {
                if (context.mounted && await _confirm(context, s.confirmDelete(c.name))) p.deleteChild(c.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(s.rename)),
              PopupMenuItem(value: 'reset', child: Text(s.resetProgress)),
              if (p.children.length > 1) PopupMenuItem(value: 'delete', child: Text(s.delete)),
            ],
          ),
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        key: const Key('add-child'),
        onPressed: () async {
          final n = await _askName(context);
          if (n != null && n.isNotEmpty) p.addChild(n);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(s.addChild),
      ),
    ]);
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final s = p.s;
    final c = p.child;
    final tiles = [
      (
        p.book.vehicles ? Icons.directions_car_rounded : Icons.pets_rounded,
        p.book.vehicles ? s.statVehicles : s.statAnimals,
        '${p.metCount} / ${p.animals.length}'
      ),
      (Icons.touch_app_rounded, s.statParts, '${p.partsTotalFound} / ${p.totalParts}'),
      (Icons.quiz_rounded, s.statQuiz, '${p.quizTotal} / ${p.animals.length * quizGoal}'),
      (Icons.translate_rounded, s.statWords, '${p.wordsLearned}'),
      (Icons.restaurant_rounded, s.statFood, '${c.food.length}'),
      (Icons.emoji_events_rounded, s.statGames, '${c.memoryWins + c.soundCorrect}'),
      (Icons.timer_rounded, s.statTime, s.minutes((c.playSeconds / 60).round())),
      (Icons.star_rounded, '★', '${p.stars}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (icon, label, value) in tiles)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF6E9), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, color: brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child:
                            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: ink)),
                      ),
                      Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7A6A5C))),
                    ]),
              ),
            ]),
          ),
      ],
    );
  }
}
