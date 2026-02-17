/// Result of a single image-pair inference.
class InferenceResult {
  final int questionId;
  final String genre;
  final String imagePath1;
  final String imagePath2;
  final bool actualMatch;
  final bool predictedMatch;
  final double similarityScore;
  final double inferenceTimeMs;

  const InferenceResult({
    required this.questionId,
    required this.genre,
    required this.imagePath1,
    required this.imagePath2,
    required this.actualMatch,
    required this.predictedMatch,
    required this.similarityScore,
    required this.inferenceTimeMs,
  });

  bool get isCorrect => actualMatch == predictedMatch;

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'genre': genre,
        'imagePath1': imagePath1,
        'imagePath2': imagePath2,
        'actualMatch': actualMatch,
        'predictedMatch': predictedMatch,
        'isCorrect': isCorrect,
        'similarityScore': similarityScore,
        'inferenceTimeMs': inferenceTimeMs,
      };
}
