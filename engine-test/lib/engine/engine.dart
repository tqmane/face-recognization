import 'dart:typed_data';

class Prediction {
  Prediction({required this.label, required this.score, this.extra});

  final String label;
  final double score;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
        'label': label,
        'score': score,
        if (extra != null) 'extra': extra,
      };
}

class InferenceResult {
  InferenceResult({
    required this.predictions,
    required this.latencyMs,
    this.provider,
    this.inputSize,
    this.note,
  });

  final List<Prediction> predictions;
  final int latencyMs;
  final String? provider;
  final List<int>? inputSize;
  final String? note;
}

abstract class InferenceEngine {
  String get name;
  Future<InferenceResult> infer(Uint8List imageBytes);
}
