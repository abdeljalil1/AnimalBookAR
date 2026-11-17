import 'package:flutter_tts/flutter_tts.dart';

import 'l10n.dart';

/// Reads names aloud with the phone's own voice (no recordings, works offline
/// when the language's voice is installed, which is usual for EN/FR/AR).
class Speech {
  Speech._();
  static final instance = Speech._();

  final _tts = FlutterTts();
  Lang? _lang;

  static const _locales = {
    Lang.en: ['en-US', 'en-GB'],
    Lang.fr: ['fr-FR', 'fr-CA'],
    Lang.ar: ['ar-SA', 'ar-EG', 'ar'],
  };

  Future<void> say(String text, Lang lang) async {
    try {
      if (_lang != lang) {
        for (final l in _locales[lang]!) {
          if (await _tts.isLanguageAvailable(l) == true) {
            await _tts.setLanguage(l);
            break;
          }
        }
        await _tts.setSpeechRate(0.42); // a little slow, for children
        await _tts.setPitch(1.1);
        _lang = lang;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // no voice on this phone: stay silent
    }
  }
}
