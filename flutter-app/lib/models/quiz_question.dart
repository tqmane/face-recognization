/// クイズの問題を表すモデルクラス
class QuizQuestion {
  final String image1Url;
  final String image2Url;
  final bool isMatch;
  final String item1Name;
  final String item2Name;
  final String genre;
  final String explanation;

  const QuizQuestion({
    required this.image1Url,
    required this.image2Url,
    required this.isMatch,
    required this.item1Name,
    required this.item2Name,
    required this.genre,
    required this.explanation,
  });

  /// 説明文を生成
  String get description {
    if (isMatch) {
      return '$item1Name（同じ）';
    } else {
      return '$item1Name vs $item2Name';
    }
  }

  /// JSONからQuizQuestionを作成
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      image1Url: json['image1Url'] as String,
      image2Url: json['image2Url'] as String,
      isMatch: json['isMatch'] as bool,
      item1Name: json['item1Name'] as String,
      item2Name: json['item2Name'] as String,
      genre: json['genre'] as String,
      explanation: json['explanation'] as String,
    );
  }

  /// QuizQuestionをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'image1Url': image1Url,
      'image2Url': image2Url,
      'isMatch': isMatch,
      'item1Name': item1Name,
      'item2Name': item2Name,
      'genre': genre,
      'explanation': explanation,
    };
  }

  @override
  String toString() {
    return 'QuizQuestion(genre: $genre, item1: $item1Name, item2: $item2Name, isMatch: $isMatch)';
  }
}
