import 'dart:math';

/// ジャンル定義
enum Genre {
  all('すべて', '全ジャンルからランダム'),
  bigCats('ネコ科大型', 'チーター・ヒョウ・ジャガー'),
  dogs('犬種', '柴犬・秋田犬・ハスキー'),
  wildDogs('犬と野生', '犬とオオカミ'),
  raccoons('アライグマ系', 'アライグマ・タヌキ'),
  birds('鳥類', 'カラス・ワタリガラス'),
  marine('海洋動物', 'アシカ・アザラシ'),
  reptiles('爬虫類', 'ワニ・クロコダイル'),
  similarPeople('似ている人', '似ている一般人・芸能人'),
  cars('車', '似ている車種'),
  logos('ロゴ', '似ているブランドロゴ');

  final String displayName;
  final String description;

  const Genre(this.displayName, this.description);
}

/// アイテム定義
class AnimalPair {
  final String id;
  final String nameJa;
  final String query;

  const AnimalPair(this.id, this.nameJa, this.query);
}

/// 似ているペア定義
class SimilarPair {
  final String id1;
  final String id2;
  final Genre genre;

  const SimilarPair(this.id1, this.id2, this.genre);
}

/// 問題設定
class QuestionConfig {
  final String query1;
  final String query2;
  final bool isSame;
  final String description;

  QuestionConfig({
    required this.query1,
    required this.query2,
    required this.isSame,
    required this.description,
  });
}

/// クイズ管理クラス
class QuizManager {
  static final Map<String, AnimalPair> _items = {
    // ネコ科
    'cheetah': const AnimalPair('cheetah', 'チーター', 'cheetah face'),
    'leopard': const AnimalPair('leopard', 'ヒョウ', 'leopard face'),
    'jaguar': const AnimalPair('jaguar', 'ジャガー', 'jaguar animal face'),
    'lion': const AnimalPair('lion', 'ライオン', 'lion face'),
    'tiger': const AnimalPair('tiger', 'トラ', 'tiger face'),
    
    // 犬種
    'shiba': const AnimalPair('shiba', '柴犬', 'shiba inu dog'),
    'akita': const AnimalPair('akita', '秋田犬', 'akita dog'),
    'husky': const AnimalPair('husky', 'ハスキー', 'husky dog'),
    'malamute': const AnimalPair('malamute', 'マラミュート', 'malamute dog'),
    'wolf': const AnimalPair('wolf', 'オオカミ', 'wolf animal'),
    
    // アライグマ系
    'raccoon': const AnimalPair('raccoon', 'アライグマ', 'raccoon animal'),
    'tanuki': const AnimalPair('tanuki', 'タヌキ', 'tanuki raccoon dog'),
    
    // 鳥
    'crow': const AnimalPair('crow', 'カラス', 'crow bird'),
    'raven': const AnimalPair('raven', 'ワタリガラス', 'raven bird'),
    
    // 海洋
    'sea_lion': const AnimalPair('sea_lion', 'アシカ', 'sea lion'),
    'seal': const AnimalPair('seal', 'アザラシ', 'seal animal'),
    
    // 爬虫類
    'alligator': const AnimalPair('alligator', 'ワニ', 'alligator'),
    'crocodile': const AnimalPair('crocodile', 'クロコダイル', 'crocodile'),
    
    // 似ている有名人・双子（同じ人の別写真 vs そっくりさん/双子を見分ける）
    // 双子ペア
    'mary_kate_olsen': const AnimalPair('mary_kate_olsen', 'メアリー・ケイト・オルセン', 'Mary-Kate Olsen face'),
    'ashley_olsen': const AnimalPair('ashley_olsen', 'アシュリー・オルセン', 'Ashley Olsen face'),
    'dylan_sprouse': const AnimalPair('dylan_sprouse', 'ディラン・スプラウス', 'Dylan Sprouse face'),
    'cole_sprouse': const AnimalPair('cole_sprouse', 'コール・スプラウス', 'Cole Sprouse face'),
    'tia_mowry': const AnimalPair('tia_mowry', 'ティア・モウリー', 'Tia Mowry face'),
    'tamera_mowry': const AnimalPair('tamera_mowry', 'タメラ・モウリー', 'Tamera Mowry face'),
    
    // そっくりさんペア（別人だけど似ている）
    'katy_perry': const AnimalPair('katy_perry', 'ケイティ・ペリー', 'Katy Perry face'),
    'zooey_deschanel': const AnimalPair('zooey_deschanel', 'ズーイー・デシャネル', 'Zooey Deschanel face'),
    'natalie_portman': const AnimalPair('natalie_portman', 'ナタリー・ポートマン', 'Natalie Portman face'),
    'keira_knightley': const AnimalPair('keira_knightley', 'キーラ・ナイトレイ', 'Keira Knightley face'),
    'margot_robbie': const AnimalPair('margot_robbie', 'マーゴット・ロビー', 'Margot Robbie face'),
    'jaime_pressly': const AnimalPair('jaime_pressly', 'ジェイミー・プレスリー', 'Jaime Pressly face'),
    'javier_bardem': const AnimalPair('javier_bardem', 'ハビエル・バルデム', 'Javier Bardem face'),
    'jeffrey_dean_morgan': const AnimalPair('jeffrey_dean_morgan', 'ジェフリー・ディーン・モーガン', 'Jeffrey Dean Morgan face'),
    'matt_damon': const AnimalPair('matt_damon', 'マット・デイモン', 'Matt Damon face'),
    'mark_wahlberg': const AnimalPair('mark_wahlberg', 'マーク・ウォールバーグ', 'Mark Wahlberg face'),
    
    // 車
    'gt86': const AnimalPair('gt86', 'トヨタ86', 'toyota 86 car'),
    'brz': const AnimalPair('brz', 'スバルBRZ', 'subaru brz car'),
    'miata': const AnimalPair('miata', 'マツダロードスター', 'mazda miata mx5'),
    's2000': const AnimalPair('s2000', 'ホンダS2000', 'honda s2000'),
    
    // ロゴ
    'pepsi': const AnimalPair('pepsi', 'ペプシ', 'pepsi logo'),
    'korean_air': const AnimalPair('korean_air', '大韓航空', 'korean air logo'),
  };

  static final List<SimilarPair> _similarPairs = [
    // ネコ科
    const SimilarPair('cheetah', 'leopard', Genre.bigCats),
    const SimilarPair('jaguar', 'leopard', Genre.bigCats),
    const SimilarPair('lion', 'tiger', Genre.bigCats),
    
    // 犬種
    const SimilarPair('shiba', 'akita', Genre.dogs),
    const SimilarPair('husky', 'malamute', Genre.dogs),
    
    // 犬と野生
    const SimilarPair('wolf', 'husky', Genre.wildDogs),
    const SimilarPair('wolf', 'malamute', Genre.wildDogs),
    
    // アライグマ系
    const SimilarPair('raccoon', 'tanuki', Genre.raccoons),
    
    // 鳥
    const SimilarPair('crow', 'raven', Genre.birds),
    
    // 海洋
    const SimilarPair('sea_lion', 'seal', Genre.marine),
    
    // 爬虫類
    const SimilarPair('alligator', 'crocodile', Genre.reptiles),
    
    // 似ている人（双子・そっくりさん）- これらは「違う」が正解
    // 双子
    const SimilarPair('mary_kate_olsen', 'ashley_olsen', Genre.similarPeople),
    const SimilarPair('dylan_sprouse', 'cole_sprouse', Genre.similarPeople),
    const SimilarPair('tia_mowry', 'tamera_mowry', Genre.similarPeople),
    // そっくりさん
    const SimilarPair('katy_perry', 'zooey_deschanel', Genre.similarPeople),
    const SimilarPair('natalie_portman', 'keira_knightley', Genre.similarPeople),
    const SimilarPair('margot_robbie', 'jaime_pressly', Genre.similarPeople),
    const SimilarPair('javier_bardem', 'jeffrey_dean_morgan', Genre.similarPeople),
    const SimilarPair('matt_damon', 'mark_wahlberg', Genre.similarPeople),
    
    // 車
    const SimilarPair('gt86', 'brz', Genre.cars),
    const SimilarPair('miata', 's2000', Genre.cars),
    
    // ロゴ
    const SimilarPair('pepsi', 'korean_air', Genre.logos),
  ];

  final Random _random = Random();

  /// ジャンルに属するペアを取得
  List<SimilarPair> _getPairsForGenre(Genre genre) {
    if (genre == Genre.all) return _similarPairs;
    return _similarPairs.where((p) => p.genre == genre).toList();
  }

  /// ジャンルに属するアイテムを取得
  List<AnimalPair> _getItemsForGenre(Genre genre) {
    final pairs = _getPairsForGenre(genre);
    final ids = pairs.expand((p) => [p.id1, p.id2]).toSet();
    return ids.map((id) => _items[id]!).toList();
  }

  /// ランダムな問題を生成
  QuestionConfig generateQuestion(Genre genre) {
    final pairs = _getPairsForGenre(genre);
    final items = _getItemsForGenre(genre);

    if (pairs.isEmpty || items.isEmpty) {
      return generateQuestion(Genre.all);
    }

    final isSame = _random.nextBool();

    if (isSame) {
      final item = items[_random.nextInt(items.length)];
      return QuestionConfig(
        query1: item.query,
        query2: item.query,
        isSame: true,
        description: '${item.nameJa} × ${item.nameJa}',
      );
    } else {
      final pair = pairs[_random.nextInt(pairs.length)];
      final item1 = _items[pair.id1]!;
      final item2 = _items[pair.id2]!;
      return QuestionConfig(
        query1: item1.query,
        query2: item2.query,
        isSame: false,
        description: '${item1.nameJa} × ${item2.nameJa}',
      );
    }
  }
}
