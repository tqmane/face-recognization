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

  InferenceResult({
    required this.questionId,
    required this.genre,
    required this.isSameActual,
    required this.isSamePredicted,
    required this.similarityScore,
    required this.inferenceTimeMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'Question ID': questionId,
      'Genre': genre,
      'Actual': isSameActual ? 'Same' : 'Different',
      'Predicted': isSamePredicted ? 'Same' : 'Different',
      'Correct': isSameActual == isSamePredicted ? 'Yes' : 'No',
      'Score': similarityScore.toStringAsFixed(4),
      'Time (ms)': inferenceTimeMs,
    };
  }
}
