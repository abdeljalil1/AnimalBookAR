import 'package:flutter/widgets.dart';

import 'animals.dart';

/// The app's languages. Animal and body-part names always come in all three.
enum Lang {
  en('EN', 'English'),
  fr('FR', 'Français'),
  ar('ع', 'العربية');

  const Lang(this.short, this.label);
  final String short;
  final String label;

  Locale get locale => Locale(name);
  bool get rtl => this == Lang.ar;

  static Lang parse(String? s) => Lang.values.firstWhere((l) => l.name == s, orElse: () => Lang.en);
}

/// UI text. Kept in one place so a translator can check it easily.
class S {
  const S(this.lang);
  final Lang lang;

  String _t(String en, String fr, String ar) => switch (lang) { Lang.en => en, Lang.fr => fr, Lang.ar => ar };

  String get appTitle => _t('Animal Book', 'Le livre des animaux', 'كتاب الحيوانات');
  String hello(String name) => _t('Hello, $name', 'Bonjour, $name', 'مرحبًا يا $name');
  String get explorer => _t('explorer', 'explorateur', 'مستكشف');
  String get nextMission => _t('Next mission', 'Prochaine mission', 'المهمة التالية');
  String get go => _t('Go', 'Go', 'هيا');
  String get scanBook => _t('Scan your book', 'Scanner ton livre', 'امسح كتابك');
  String get language => _t('Language', 'Langue', 'اللغة');
  String get zoo => _t('ZOO', 'ZOO', 'حديقة الحيوانات');

  String levelName(int level) => switch (level) {
        1 => _t('Meet', 'Découvrir', 'تعرّف'),
        2 => _t('Body parts', 'Le corps', 'أجزاء الجسم'),
        _ => _t('Quiz', 'Quiz', 'اختبار'),
      };
  String levelTitle(int level) => _t('Level $level', 'Niveau $level', 'المستوى $level');
  String finishFirst(int level) =>
      _t('Finish level $level first', 'Termine d\'abord le niveau $level', 'أكمل المستوى $level أولًا');
  String levelProgress(int level, int done, int total) => switch (level) {
        1 => _t('$done of $total animals', '$done sur $total animaux', '$done من $total حيوانات'),
        2 => _t('$done of $total parts', '$done sur $total parties', '$done من $total أجزاء'),
        _ => _t('$done of $total answers', '$done sur $total réponses', '$done من $total إجابات'),
      };

  // Missions
  String meet(Animal a) => _t('Meet the ${a.en.toLowerCase()}', 'Découvre ${a.frDef}', 'تعرّف على ${a.arDef}');
  String findPart(Animal a, BodyPart p) => _t('Find the ${a.en.toLowerCase()}\'s ${p.en.toLowerCase()}',
      'Trouve ${p.frDef} ${a.frOf}', 'ابحث عن ${p.ar} ${a.arDef}');
  String quizOf(Animal a) => _t('${a.en} quiz', 'Quiz ${a.frOf}', 'اختبار ${a.arDef}');
  String openPage(int page) =>
      _t('Open your book at page $page', 'Ouvre ton livre à la page $page', 'افتح كتابك على الصفحة $page');
  String get answer3 => _t('Answer 3 questions', 'Réponds à 3 questions', 'أجب عن 3 أسئلة');
  String get allDone => _t('You did it!', 'Bravo, tout est fini !', 'أحسنت! أكملت كل شيء');
  String get playAgain => _t('Play again any time', 'Rejoue quand tu veux', 'العب مرة أخرى متى شئت');

  // Animal sheet
  String get bodyParts => _t('Body parts', 'Les parties du corps', 'أجزاء الجسم');
  String found(int done, int total) => _t('$done of $total found', '$done sur $total trouvées', 'وجدت $done من $total');
  String page(int n) => _t('Page $n', 'Page $n', 'الصفحة $n');
  String get showPage => _t('Show page', 'Voir la page', 'عرض الصفحة');
  String get scan => _t('Scan', 'Scanner', 'امسح');
  String get startQuiz => _t('Start quiz', 'Faire le quiz', 'ابدأ الاختبار');
  String quizScore(int n) => _t('Quiz: $n of 3', 'Quiz : $n sur 3', 'الاختبار: $n من 3');
  String get notMet =>
      _t('Not met yet: scan its page', 'Pas encore découvert : scanne sa page', 'لم تتعرف عليه بعد: امسح صفحته');
  String get showPageHint => _t(
      'Point another phone with Animal Book AR at this page, or print the book.',
      'Pointe un autre téléphone avec Animal Book AR vers cette page, ou imprime le livre.',
      'وجّه هاتفًا آخر فيه التطبيق نحو هذه الصفحة، أو اطبع الكتاب.');

  // Welcome
  String get welcomeTitle => _t('Welcome to the zoo!', 'Bienvenue au zoo !', 'مرحبًا بك في الحديقة!');
  String get chooseLanguage => _t('Choose your language', 'Choisis ta langue', 'اختر لغتك');
  String get yourName => _t('What\'s your name?', 'Comment t\'appelles-tu ?', 'ما اسمك؟');
  String get nameHint => _t('Your first name', 'Ton prénom', 'اسمك');
  String get letsGo => _t('Let\'s go', 'C\'est parti', 'هيا بنا');

  // AR screen
  String get needCamera => _t('Animal Book AR needs the camera to see the book.',
      'Animal Book AR a besoin de la caméra pour voir le livre.', 'يحتاج التطبيق إلى الكاميرا لرؤية الكتاب.');
  String get tryAgain => _t('Try again', 'Réessayer', 'حاول مرة أخرى');
  String get openSettings => _t('Open settings', 'Ouvrir les réglages', 'فتح الإعدادات');
  String get back => _t('Back', 'Retour', 'رجوع');
}
