import 'package:flutter/material.dart';

/// アプリのローカライゼーション
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ja'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ja'), // 日本語
    Locale('en'), // 英語
    Locale('ko'), // 韓国語
    Locale('ru'), // ロシア語
  ];

  // 言語別の文字列マップ
  static final Map<String, Map<String, String>> _localizedStrings = {
    'ja': {
      // アプリ名
      'appName': '判別クイズ',
      
      // ホーム画面
      'home': 'ホーム',
      'selectTestSet': 'テストセットを選択',
      'noTestSets': 'テストセットがありません',
      'downloadTestSets': 'テストセットをダウンロードしてください',
      'questionCount': '問題数',
      'questions': '問',
      'start': 'スタート',
      
      // テストセット
      'testSets': 'テストセット',
      'downloadTestSet': 'テストセットをダウンロード',
      'downloading': 'ダウンロード中...',
      'downloaded': 'ダウンロード済み',
      'download': 'ダウンロード',
      'delete': '削除',
      'deleteConfirm': '削除しますか？',
      'cancel': 'キャンセル',
      
      // クイズ画面
      'quiz': 'クイズ',
      'score': 'スコア',
      'same': '同じ',
      'different': '違う',
      'correct': '正解！',
      'incorrect': '不正解',
      'imageA': '画像 A',
      'imageB': '画像 B',
      
      // 中断
      'quitQuiz': 'テスト中断',
      'quitQuizMessage': 'テストを中断しますか？\n進捗は保存されません。',
      'quit': '中断する',
      'continue_': '続ける',
      
      // 結果画面
      'result': '結果',
      'excellent': '素晴らしい！',
      'good': 'よくできました！',
      'average': 'まずまず',
      'tryAgain': 'もう一度挑戦！',
      'correctAnswers': '問正解',
      'accuracy': '正答率',
      'time': 'タイム',
      'genre': 'ジャンル',
      'questionResults': '問題ごとの結果',
      'backToHome': 'ホームに戻る',
      'correctAnswer': '正解',
      'yourAnswer': '回答',
      
      // 履歴画面
      'history': '履歴',
      'noHistory': '履歴がありません',
      'playQuizFirst': 'クイズをプレイしてください',
      'deleteHistory': '履歴を削除',
      'deleteHistoryConfirm': 'この履歴を削除しますか？',
      'deleteAllHistory': 'すべての履歴を削除',
      'deleteAllHistoryConfirm': 'すべての履歴を削除しますか？',
      
      // 設定画面
      'settings': '設定',
      'cloudSync': 'クラウド同期',
      'signIn': 'ログイン',
      'signOut': 'ログアウト',
      'signedInAs': 'ログイン中',
      'notSignedIn': '未ログイン',
      'admin': '管理者画面',
      
      // 同期画面
      'syncTitle': 'クラウド同期',
      'syncDescription': 'Googleでログインして履歴を同期',
      'signInWithGoogle': 'Googleでログイン',
      'syncNow': '今すぐ同期',
      'lastSync': '最終同期',
      'never': '未同期',
      
      // 管理者画面
      'adminPanel': '管理者画面',
      'users': 'ユーザー',
      'totalPlays': '総プレイ数',
      'totalQuestions': '総問題数',
      'refresh': '更新',
      'noPermission': 'アクセス権限がありません',
      'notLoggedIn': 'ログインしていません',
      'noData': 'まだデータがありません',
      'uidOverallAverage': 'UID別全回答者平均',
      'genreStats': 'ジャンル別統計',
      'responderStats': '回答者別統計',
      'recentPlays': '最近のプレイ履歴',
      'plays': '回数',
      'avgPoints': '平均点',
      'avgTime': '時間',
      'allResponderAvg': '全回答者平均',
      'yourUid': 'あなたのUID',
      'copyUid': 'コピー',
      'uidCopied': 'UIDをコピーしました',
      'close': '閉じる',
      
      // 回答者名
      'responderName': '回答者名',
      'responderNameHint': '入力しなくても大丈夫です',
      'selectFromHistory': '履歴から選択',
      'selectResponder': '回答者を選択',
      'back': '戻る',
      'unset': '(未設定)',
      
      // エラー
      'error': 'エラー',
      'loadError': '読み込みに失敗しました',
      'networkError': 'ネットワークエラー',
      'ok': 'OK',
    },
    'en': {
      // App name
      'appName': 'Similarity Quiz',
      
      // Home screen
      'home': 'Home',
      'selectTestSet': 'Select Test Set',
      'noTestSets': 'No test sets available',
      'downloadTestSets': 'Please download test sets',
      'questionCount': 'Questions',
      'questions': '',
      'start': 'Start',
      
      // Test sets
      'testSets': 'Test Sets',
      'downloadTestSet': 'Download Test Set',
      'downloading': 'Downloading...',
      'downloaded': 'Downloaded',
      'download': 'Download',
      'delete': 'Delete',
      'deleteConfirm': 'Are you sure you want to delete?',
      'cancel': 'Cancel',
      
      // Quiz screen
      'quiz': 'Quiz',
      'score': 'Score',
      'same': 'Same',
      'different': 'Different',
      'correct': 'Correct!',
      'incorrect': 'Incorrect',
      'imageA': 'Image A',
      'imageB': 'Image B',
      
      // Quit
      'quitQuiz': 'Quit Quiz',
      'quitQuizMessage': 'Are you sure you want to quit?\nProgress will not be saved.',
      'quit': 'Quit',
      'continue_': 'Continue',
      
      // Result screen
      'result': 'Result',
      'excellent': 'Excellent!',
      'good': 'Good job!',
      'average': 'Not bad',
      'tryAgain': 'Try again!',
      'correctAnswers': ' correct',
      'accuracy': 'Accuracy',
      'time': 'Time',
      'genre': 'Genre',
      'questionResults': 'Question Results',
      'backToHome': 'Back to Home',
      'correctAnswer': 'Answer',
      'yourAnswer': 'Your answer',
      
      // History screen
      'history': 'History',
      'noHistory': 'No history',
      'playQuizFirst': 'Play a quiz first',
      'deleteHistory': 'Delete History',
      'deleteHistoryConfirm': 'Delete this history?',
      'deleteAllHistory': 'Delete All History',
      'deleteAllHistoryConfirm': 'Delete all history?',
      
      // Settings screen
      'settings': 'Settings',
      'cloudSync': 'Cloud Sync',
      'signIn': 'Sign In',
      'signOut': 'Sign Out',
      'signedInAs': 'Signed in as',
      'notSignedIn': 'Not signed in',
      'admin': 'Admin Panel',
      
      // Sync screen
      'syncTitle': 'Cloud Sync',
      'syncDescription': 'Sign in with Google to sync history',
      'signInWithGoogle': 'Sign in with Google',
      'syncNow': 'Sync Now',
      'lastSync': 'Last sync',
      'never': 'Never',
      
      // Admin panel
      'adminPanel': 'Admin Panel',
      'users': 'Users',
      'totalPlays': 'Total Plays',
      'totalQuestions': 'Total Questions',
      'refresh': 'Refresh',
      'noPermission': 'Access denied',
      'notLoggedIn': 'Not logged in',
      'noData': 'No data yet',
      'uidOverallAverage': 'UID Overall Average',
      'genreStats': 'Genre Statistics',
      'responderStats': 'Responder Statistics',
      'recentPlays': 'Recent Plays',
      'plays': 'Plays',
      'avgPoints': 'Avg Points',
      'avgTime': 'Time',
      'allResponderAvg': 'All Responder Avg',
      'yourUid': 'Your UID',
      'copyUid': 'Copy',
      'uidCopied': 'UID copied',
      'close': 'Close',
      
      // Responder name
      'responderName': 'Your Name',
      'responderNameHint': 'Optional',
      'selectFromHistory': 'Select from history',
      'selectResponder': 'Select Responder',
      'back': 'Back',
      'unset': '(Unset)',
      
      // Error
      'error': 'Error',
      'loadError': 'Failed to load',
      'networkError': 'Network error',
      'ok': 'OK',
    },
    'ko': {
      // 앱 이름
      'appName': '판별 퀴즈',
      
      // 홈 화면
      'home': '홈',
      'selectTestSet': '테스트 세트 선택',
      'noTestSets': '테스트 세트가 없습니다',
      'downloadTestSets': '테스트 세트를 다운로드하세요',
      'questionCount': '문제 수',
      'questions': '문제',
      'start': '시작',
      
      // 테스트 세트
      'testSets': '테스트 세트',
      'downloadTestSet': '테스트 세트 다운로드',
      'downloading': '다운로드 중...',
      'downloaded': '다운로드 완료',
      'download': '다운로드',
      'delete': '삭제',
      'deleteConfirm': '삭제하시겠습니까?',
      'cancel': '취소',
      
      // 퀴즈 화면
      'quiz': '퀴즈',
      'score': '점수',
      'same': '같음',
      'different': '다름',
      'correct': '정답!',
      'incorrect': '오답',
      'imageA': '이미지 A',
      'imageB': '이미지 B',
      
      // 중단
      'quitQuiz': '퀴즈 중단',
      'quitQuizMessage': '퀴즈를 중단하시겠습니까?\n진행 상황이 저장되지 않습니다.',
      'quit': '중단',
      'continue_': '계속',
      
      // 결과 화면
      'result': '결과',
      'excellent': '훌륭합니다!',
      'good': '잘했습니다!',
      'average': '괜찮아요',
      'tryAgain': '다시 도전!',
      'correctAnswers': '개 정답',
      'accuracy': '정답률',
      'time': '시간',
      'genre': '장르',
      'questionResults': '문제별 결과',
      'backToHome': '홈으로',
      'correctAnswer': '정답',
      'yourAnswer': '내 답',
      
      // 기록 화면
      'history': '기록',
      'noHistory': '기록이 없습니다',
      'playQuizFirst': '퀴즈를 플레이하세요',
      'deleteHistory': '기록 삭제',
      'deleteHistoryConfirm': '이 기록을 삭제하시겠습니까?',
      'deleteAllHistory': '모든 기록 삭제',
      'deleteAllHistoryConfirm': '모든 기록을 삭제하시겠습니까?',
      
      // 설정 화면
      'settings': '설정',
      'cloudSync': '클라우드 동기화',
      'signIn': '로그인',
      'signOut': '로그아웃',
      'signedInAs': '로그인됨',
      'notSignedIn': '로그인되지 않음',
      'admin': '관리자 패널',
      
      // 동기화 화면
      'syncTitle': '클라우드 동기화',
      'syncDescription': 'Google로 로그인하여 기록 동기화',
      'signInWithGoogle': 'Google로 로그인',
      'syncNow': '지금 동기화',
      'lastSync': '마지막 동기화',
      'never': '없음',
      
      // 관리자 패널
      'adminPanel': '관리자 패널',
      'users': '사용자',
      'totalPlays': '총 플레이',
      'totalQuestions': '총 문제',
      'refresh': '새로고침',
      'noPermission': '접근 권한이 없습니다',
      'notLoggedIn': '로그인되지 않음',
      'noData': '데이터가 없습니다',
      'uidOverallAverage': 'UID별 전체 평균',
      'genreStats': '장르별 통계',
      'responderStats': '응답자별 통계',
      'recentPlays': '최근 플레이',
      'plays': '횟수',
      'avgPoints': '평균 점수',
      'avgTime': '시간',
      'allResponderAvg': '전체 응답자 평균',
      'yourUid': '내 UID',
      'copyUid': '복사',
      'uidCopied': 'UID 복사됨',
      'close': '닫기',
      
      // 응답자 이름
      'responderName': '이름',
      'responderNameHint': '선택사항',
      'selectFromHistory': '기록에서 선택',
      'selectResponder': '응답자 선택',
      'back': '뒤로',
      'unset': '(미설정)',
      
      // 오류
      'error': '오류',
      'loadError': '로드 실패',
      'networkError': '네트워크 오류',
      'ok': '확인',
    },
    'ru': {
      // Название приложения
      'appName': 'Викторина',
      
      // Главный экран
      'home': 'Главная',
      'selectTestSet': 'Выберите тест',
      'noTestSets': 'Нет тестов',
      'downloadTestSets': 'Загрузите тесты',
      'questionCount': 'Вопросов',
      'questions': '',
      'start': 'Начать',
      
      // Тесты
      'testSets': 'Тесты',
      'downloadTestSet': 'Загрузить тест',
      'downloading': 'Загрузка...',
      'downloaded': 'Загружено',
      'download': 'Загрузить',
      'delete': 'Удалить',
      'deleteConfirm': 'Вы уверены, что хотите удалить?',
      'cancel': 'Отмена',
      
      // Экран викторины
      'quiz': 'Викторина',
      'score': 'Счёт',
      'same': 'Одинаковые',
      'different': 'Разные',
      'correct': 'Правильно!',
      'incorrect': 'Неправильно',
      'imageA': 'Изображение A',
      'imageB': 'Изображение B',
      
      // Выход
      'quitQuiz': 'Выйти из викторины',
      'quitQuizMessage': 'Вы уверены, что хотите выйти?\nПрогресс не будет сохранён.',
      'quit': 'Выйти',
      'continue_': 'Продолжить',
      
      // Экран результатов
      'result': 'Результат',
      'excellent': 'Отлично!',
      'good': 'Хорошо!',
      'average': 'Неплохо',
      'tryAgain': 'Попробуйте ещё!',
      'correctAnswers': ' правильно',
      'accuracy': 'Точность',
      'time': 'Время',
      'genre': 'Жанр',
      'questionResults': 'Результаты по вопросам',
      'backToHome': 'На главную',
      'correctAnswer': 'Ответ',
      'yourAnswer': 'Ваш ответ',
      
      // История
      'history': 'История',
      'noHistory': 'Нет истории',
      'playQuizFirst': 'Сначала сыграйте в викторину',
      'deleteHistory': 'Удалить историю',
      'deleteHistoryConfirm': 'Удалить эту запись?',
      'deleteAllHistory': 'Удалить всю историю',
      'deleteAllHistoryConfirm': 'Удалить всю историю?',
      
      // Настройки
      'settings': 'Настройки',
      'cloudSync': 'Облачная синхронизация',
      'signIn': 'Войти',
      'signOut': 'Выйти',
      'signedInAs': 'Вы вошли как',
      'notSignedIn': 'Не авторизован',
      'admin': 'Админ-панель',
      
      // Синхронизация
      'syncTitle': 'Облачная синхронизация',
      'syncDescription': 'Войдите через Google для синхронизации',
      'signInWithGoogle': 'Войти через Google',
      'syncNow': 'Синхронизировать',
      'lastSync': 'Последняя синхронизация',
      'never': 'Никогда',
      
      // Админ-панель
      'adminPanel': 'Админ-панель',
      'users': 'Пользователи',
      'totalPlays': 'Всего игр',
      'totalQuestions': 'Всего вопросов',
      'refresh': 'Обновить',
      'noPermission': 'Нет доступа',
      'notLoggedIn': 'Не авторизован',
      'noData': 'Нет данных',
      'uidOverallAverage': 'Общая статистика UID',
      'genreStats': 'Статистика по жанрам',
      'responderStats': 'Статистика по участникам',
      'recentPlays': 'Недавние игры',
      'plays': 'Игры',
      'avgPoints': 'Ср. баллы',
      'avgTime': 'Время',
      'allResponderAvg': 'Общее среднее',
      'yourUid': 'Ваш UID',
      'copyUid': 'Копировать',
      'uidCopied': 'UID скопирован',
      'close': 'Закрыть',
      
      // Имя участника
      'responderName': 'Ваше имя',
      'responderNameHint': 'Необязательно',
      'selectFromHistory': 'Выбрать из истории',
      'selectResponder': 'Выберите участника',
      'back': 'Назад',
      'unset': '(Не задано)',
      
      // Ошибки
      'error': 'Ошибка',
      'loadError': 'Не удалось загрузить',
      'networkError': 'Ошибка сети',
      'ok': 'ОК',
    },
  };

  String get(String key) {
    return _localizedStrings[locale.languageCode]?[key] ??
        _localizedStrings['en']?[key] ??
        key;
  }

  // 便利なゲッター
  String get appName => get('appName');
  String get home => get('home');
  String get selectTestSet => get('selectTestSet');
  String get noTestSets => get('noTestSets');
  String get downloadTestSets => get('downloadTestSets');
  String get questionCount => get('questionCount');
  String get questions => get('questions');
  String get start => get('start');
  String get testSets => get('testSets');
  String get downloadTestSet => get('downloadTestSet');
  String get downloading => get('downloading');
  String get downloaded => get('downloaded');
  String get download => get('download');
  String get delete => get('delete');
  String get deleteConfirm => get('deleteConfirm');
  String get cancel => get('cancel');
  String get quiz => get('quiz');
  String get score => get('score');
  String get same => get('same');
  String get different => get('different');
  String get correct => get('correct');
  String get incorrect => get('incorrect');
  String get imageA => get('imageA');
  String get imageB => get('imageB');
  String get quitQuiz => get('quitQuiz');
  String get quitQuizMessage => get('quitQuizMessage');
  String get quit => get('quit');
  String get continueText => get('continue_');
  String get result => get('result');
  String get excellent => get('excellent');
  String get good => get('good');
  String get average => get('average');
  String get tryAgain => get('tryAgain');
  String get correctAnswers => get('correctAnswers');
  String get accuracy => get('accuracy');
  String get time => get('time');
  String get genre => get('genre');
  String get questionResults => get('questionResults');
  String get backToHome => get('backToHome');
  String get correctAnswer => get('correctAnswer');
  String get yourAnswer => get('yourAnswer');
  String get history => get('history');
  String get noHistory => get('noHistory');
  String get playQuizFirst => get('playQuizFirst');
  String get deleteHistory => get('deleteHistory');
  String get deleteHistoryConfirm => get('deleteHistoryConfirm');
  String get deleteAllHistory => get('deleteAllHistory');
  String get deleteAllHistoryConfirm => get('deleteAllHistoryConfirm');
  String get settings => get('settings');
  String get cloudSync => get('cloudSync');
  String get signIn => get('signIn');
  String get signOut => get('signOut');
  String get signedInAs => get('signedInAs');
  String get notSignedIn => get('notSignedIn');
  String get admin => get('admin');
  String get syncTitle => get('syncTitle');
  String get syncDescription => get('syncDescription');
  String get signInWithGoogle => get('signInWithGoogle');
  String get syncNow => get('syncNow');
  String get lastSync => get('lastSync');
  String get never => get('never');
  String get adminPanel => get('adminPanel');
  String get users => get('users');
  String get totalPlays => get('totalPlays');
  String get totalQuestions => get('totalQuestions');
  String get refresh => get('refresh');
  String get noPermission => get('noPermission');
  String get notLoggedIn => get('notLoggedIn');
  String get noData => get('noData');
  String get uidOverallAverage => get('uidOverallAverage');
  String get genreStats => get('genreStats');
  String get responderStats => get('responderStats');
  String get recentPlays => get('recentPlays');
  String get plays => get('plays');
  String get avgPoints => get('avgPoints');
  String get avgTime => get('avgTime');
  String get allResponderAvg => get('allResponderAvg');
  String get yourUid => get('yourUid');
  String get copyUid => get('copyUid');
  String get uidCopied => get('uidCopied');
  String get close => get('close');
  String get responderName => get('responderName');
  String get responderNameHint => get('responderNameHint');
  String get selectFromHistory => get('selectFromHistory');
  String get selectResponder => get('selectResponder');
  String get back => get('back');
  String get unset => get('unset');
  String get error => get('error');
  String get loadError => get('loadError');
  String get networkError => get('networkError');
  String get ok => get('ok');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ja', 'en', 'ko', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// 拡張メソッドでコンテキストから簡単にアクセス
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
