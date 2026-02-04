abstract class InferenceEngine {
  String get name;
  Future<void> initialize();
  Future<double> compareImages(String imagePath1, String imagePath2);
  void dispose();
}

class InferenceResult {
  final int questionId;
  final String genre;
  final bool isSameActual;
  final bool isSamePredicted;
  final double similarityScore;
  final int inferenceTimeMs;
  final String imagePath1;
  final String imagePath2;

  InferenceResult({
    required this.questionId,
    required this.genre,
    required this.isSameActual,
    required this.isSamePredicted,
    required this.similarityScore,
    required this.inferenceTimeMs,
    required this.imagePath1,
    required this.imagePath2,
  });

  Map<String, dynamic> toMap() {
    return {
      'Question ID': questionId,
      'Genre': genre,
      'Image1': imagePath1,
      'Image2': imagePath2,
      'Actual': isSameActual ? 'Same' : 'Different',
      'Predicted': isSamePredicted ? 'Same' : 'Different',
      'Correct': isSameActual == isSamePredicted ? 'Yes' : 'No',
      'Score': similarityScore.toStringAsFixed(4),
      'Time (ms)': inferenceTimeMs,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'genre': genre,
      'image1': imagePath1,
      'image2': imagePath2,
      'isSameActual': isSameActual,
      'isSamePredicted': isSamePredicted,
      'similarityScore': similarityScore,
      'inferenceTimeMs': inferenceTimeMs,
    };
  }
}
