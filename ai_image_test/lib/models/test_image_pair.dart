/// A single test question: two images + ground truth.
class TestImagePair {
  final int id;
  final String genre;
  final String imagePath1;
  final String imagePath2;
  final bool isSame; // ground truth: same species?

  const TestImagePair({
    required this.id,
    required this.genre,
    required this.imagePath1,
    required this.imagePath2,
    required this.isSame,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'genre': genre,
        'imagePath1': imagePath1,
        'imagePath2': imagePath2,
        'isSame': isSame,
      };
}
