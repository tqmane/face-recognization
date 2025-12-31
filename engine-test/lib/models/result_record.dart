import '../engine/engine.dart';
import 'manifest.dart';

class ResultRecord {
  ResultRecord({
    required this.runId,
    required this.imageId,
    required this.engine,
    required this.latencyMs,
    required this.predictions,
    this.provider,
    this.inputSize,
    this.preprocess = 'none (match human test)',
    this.label,
    this.meta,
    this.imagePath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  final String runId;
  final String imageId;
  final String engine;
  final String? provider;
  final int latencyMs;
  final List<Prediction> predictions;
  final List<int>? inputSize;
  final String preprocess;
  final String? label;
  final Map<String, dynamic>? meta;
  final String? imagePath;
  final DateTime timestamp;

  factory ResultRecord.fromResult({
    required String runId,
    required TestItem item,
    required InferenceResult result,
    required String engine,
  }) {
    return ResultRecord(
      runId: runId,
      imageId: item.id,
      engine: engine,
      provider: result.provider,
      latencyMs: result.latencyMs,
      predictions: result.predictions,
      inputSize: result.inputSize,
      preprocess: result.note ?? 'none (match human test)',
      label: item.label,
      meta: item.meta,
      imagePath: item.resolvedPath,
    );
  }

  factory ResultRecord.fromJson(Map<String, dynamic> json) {
    final predsRaw = (json['predictions'] as List<dynamic>?) ?? [];
    final predictions = predsRaw
        .whereType<Map<String, dynamic>>()
        .map((p) => Prediction(
              label: p['label'] as String? ?? '',
              score: (p['score'] as num?)?.toDouble() ?? 0,
              extra: p['extra'] as Map<String, dynamic>?,
            ))
        .toList();

    final ts = json['timestamp'] as String?;
    final parsedTs = ts != null ? DateTime.tryParse(ts)?.toUtc() : null;

    return ResultRecord(
      runId: json['runId'] as String? ?? '',
      imageId: json['imageId'] as String? ?? '',
      engine: json['engine'] as String? ?? '',
      provider: json['provider'] as String?,
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? -1,
      predictions: predictions,
      inputSize: (json['inputSize'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      preprocess: json['preprocess'] as String? ?? '',
      label: json['label'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
      imagePath: json['imagePath'] as String?,
      timestamp: parsedTs,
    );
  }

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'imageId': imageId,
        'engine': engine,
        if (provider != null) 'provider': provider,
        'latencyMs': latencyMs,
        'predictions': predictions.map((p) => p.toJson()).toList(),
        'inputSize': inputSize,
        'preprocess': preprocess,
        if (label != null) 'label': label,
        if (meta != null) 'meta': meta,
        if (imagePath != null) 'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
      };
}
