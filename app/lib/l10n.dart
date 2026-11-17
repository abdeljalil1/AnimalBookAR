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

  // Parents' page
  String get parents => _t('Parents', 'Parents', 'الأولياء');
  String get forParents => _t('For parents', 'Pour les parents', 'للأولياء');
  String gateQuestion(int a, int b) =>
      _t('Grown-ups only: $a + $b = ?', 'Réservé aux adultes : $a + $b = ?', 'للكبار فقط: $a + $b = ؟');
  String get account => _t('Account', 'Compte', 'الحساب');
  String get syncPitch => _t(
      'Sign in to keep progress safe and use it on several phones or tablets.',
      'Connectez-vous pour sauvegarder la progression et l\'utiliser sur plusieurs appareils.',
      'سجّل الدخول لحفظ التقدّم واستخدامه على عدة أجهزة.');
  String get continueGoogle => _t('Continue with Google', 'Continuer avec Google', 'المتابعة باستخدام Google');
  String get useEmail => _t('Use an email', 'Utiliser un e-mail', 'استخدام بريد إلكتروني');
  String get email => _t('Email', 'E-mail', 'البريد الإلكتروني');
  String get password =>
      _t('Password (6+ characters)', 'Mot de passe (6 caractères min.)', 'كلمة المرور (6 أحرف على الأقل)');
  String get signIn => _t('Sign in', 'Se connecter', 'تسجيل الدخول');
  String get createAccount => _t('Create account', 'Créer un compte', 'إنشاء حساب');
  String get forgotPassword => _t('Forgot password?', 'Mot de passe oublié ?', 'نسيت كلمة المرور؟');
  String get resetSent => _t('Check your email to reset the password.',
      'Vérifiez vos e-mails pour réinitialiser le mot de passe.', 'تفقّد بريدك لإعادة تعيين كلمة المرور.');
  String signedInAs(String who) => _t('Signed in as $who', 'Connecté : $who', 'تم تسجيل الدخول: $who');
  String get synced => _t('Progress is synced', 'Progression synchronisée', 'تمت مزامنة التقدّم');
  String get syncingNow => _t('Syncing…', 'Synchronisation…', 'جارٍ المزامنة…');
  String get signOut => _t('Sign out', 'Se déconnecter', 'تسجيل الخروج');
  String get cloudOff => _t(
      'Accounts are not available right now (no connection).',
      'Les comptes ne sont pas disponibles pour le moment (pas de connexion).',
      'الحسابات غير متاحة حاليًا (لا يوجد اتصال).');
  String authError(String code) => switch (code) {
        'invalid-email' =>
          _t('That email address is not valid.', 'Cette adresse e-mail n\'est pas valide.', 'عنوان البريد غير صالح.'),
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          _t('Wrong email or password.', 'E-mail ou mot de passe incorrect.', 'البريد أو كلمة المرور غير صحيحة.'),
        'email-already-in-use' => _t('An account already uses this email. Sign in instead.',
            'Un compte utilise déjà cet e-mail. Connectez-vous.', 'هذا البريد مستخدم. سجّل الدخول بدلًا من ذلك.'),
        'weak-password' =>
          _t('Choose a longer password.', 'Choisissez un mot de passe plus long.', 'اختر كلمة مرور أطول.'),
        'network-request-failed' =>
          _t('No internet connection.', 'Pas de connexion Internet.', 'لا يوجد اتصال بالإنترنت.'),
        _ => _t('That didn\'t work. Try again.', 'Ça n\'a pas marché. Réessayez.', 'لم ينجح ذلك. حاول مرة أخرى.'),
      };
  String get children => _t('Children', 'Enfants', 'الأطفال');
  String get addChild => _t('Add a child', 'Ajouter un enfant', 'إضافة طفل');
  String get rename => _t('Rename', 'Renommer', 'إعادة التسمية');
  String get resetProgress => _t('Start over', 'Recommencer', 'البدء من جديد');
  String get delete => _t('Delete', 'Supprimer', 'حذف');
  String get cancel => _t('Cancel', 'Annuler', 'إلغاء');
  String get save => _t('Save', 'Enregistrer', 'حفظ');
  String confirmDelete(String name) =>
      _t('Delete $name and all their progress?', 'Supprimer $name et toute sa progression ?', 'حذف $name وكل تقدّمه؟');
  String confirmReset(String name) => _t('Erase all of $name\'s progress on this phone?',
      'Effacer toute la progression de $name sur ce téléphone ?', 'مسح كل تقدّم $name على هذا الهاتف؟');
  String progressOf(String name) => _t('$name\'s progress', 'Progression de $name', 'تقدّم $name');
  String get statAnimals => _t('Animals met', 'Animaux découverts', 'حيوانات تعرّف عليها');
  String get statParts => _t('Body parts found', 'Parties du corps trouvées', 'أجزاء جسم وجدها');
  String get statQuiz => _t('Quiz answers', 'Réponses au quiz', 'إجابات الاختبار');
  String get statWords => _t('Words learned (×3 languages)', 'Mots appris (×3 langues)', 'كلمات تعلّمها (×3 لغات)');
  String get statFood => _t('Foods given', 'Aliments donnés', 'أطعمة قدّمها');
  String get statGames => _t('Games won', 'Jeux gagnés', 'ألعاب فاز بها');
  String get statTime => _t('Time in the camera', 'Temps avec la caméra', 'الوقت مع الكاميرا');
  String minutes(int m) => _t('$m min', '$m min', '$m دقيقة');

  // Games
  String get games => _t('Games', 'Jeux', 'ألعاب');
  String get memoryGame => _t('Memory', 'Mémoire', 'الذاكرة');
  String get memoryHint =>
      _t('Match each animal to its name', 'Associe chaque animal à son nom', 'طابق كل حيوان مع اسمه');
  String get soundQuiz => _t('Sound quiz', 'Quiz des sons', 'اختبار الأصوات');
  String get soundQuizHint => _t('Who makes this sound?', 'Qui fait ce bruit ?', 'من يصدر هذا الصوت؟');
  String movesWin(int moves) => _t('Bravo! You found all the pairs in $moves moves.',
      'Bravo ! Tu as trouvé toutes les paires en $moves coups.', 'أحسنت! وجدت كل الأزواج في $moves محاولة.');
  String get playAgainBtn => _t('Play again', 'Rejouer', 'العب مجددًا');
  String get namesIn => _t('Names in', 'Noms en', 'الأسماء بـ');
}
