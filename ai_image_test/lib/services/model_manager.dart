import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/model_info.dart';

/// Downloads and manages ML model files for the inference engines.
class ModelManager {
  static const _modelsDir = 'ai_image_test_models';

  /// Built-in model definitions.
  static final builtInModels = <ModelInfo>[
    ModelInfo(
      key: 'mobilenet_v2',
      name: 'MobileNet V2 (224x224)',
      tfliteUrl:
          'https://github.com/tqmane/face-recognization/releases/download/models-v1/mobilenet_v2_1.0_224_quant.tflite',
      onnxUrl:
          'https://github.com/tqmane/face-recognization/releases/download/models-v1/mobilenet_v2_1.0_224_quant.onnx',
      fileNameInArchive: 'mobilenet_v2_1.0_224_quant',
      inputSize: 224,
      isRecommended: true,
    ),
    ModelInfo(
      key: 'mobilenet_v1',
      name: 'MobileNet V1 (224x224)',
      tfliteUrl:
          'https://github.com/tqmane/face-recognization/releases/download/models-v1/mobilenet_v1_1.0_224_quant.tflite',
      onnxUrl:
          'https://github.com/tqmane/face-recognization/releases/download/models-v1/mobilenet_v1_1.0_224_quant.onnx',
      fileNameInArchive: 'mobilenet_v1_1.0_224_quant',
      inputSize: 224,
    ),
  ];

  /// Returns the directory where model files are stored.
  Future<Directory> get modelDir async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, _modelsDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// List all downloaded model files.
  Future<List<FileSystemEntity>> listDownloaded() async {
    final dir = await modelDir;
    return dir.listSync().where((e) => e is File).toList();
  }

  /// Get the local path for a model, or null if not yet downloaded.
  Future<String?> getModelPath(ModelInfo model, {bool preferOnnx = false}) async {
    final dir = await modelDir;
    // Preferred format first.
    final preferred = preferOnnx ? 'onnx' : 'tflite';
    final fallback = preferOnnx ? 'tflite' : 'onnx';

    final preferredPath = p.join(dir.path, '${model.fileNameInArchive}.$preferred');
    if (await File(preferredPath).exists()) return preferredPath;

    final fallbackPath = p.join(dir.path, '${model.fileNameInArchive}.$fallback');
    if (await File(fallbackPath).exists()) return fallbackPath;

    return null;
  }

  /// Download a model. Returns the local file path.
  /// Tries the [preferredFormat] first; on failure falls back to the other format.
  Future<String> downloadModel(
    ModelInfo model, {
    String preferredFormat = 'tflite',
    void Function(double progress)? onProgress,
  }) async {
    final dir = await modelDir;

    // Build ordered list of (url, extension) to try.
    final attempts = <(String?, String)>[];
    if (preferredFormat == 'onnx') {
      if (model.hasRemoteOnnx) attempts.add((model.onnxUrl, 'onnx'));
      if (model.hasRemoteTflite) attempts.add((model.tfliteUrl, 'tflite'));
    } else {
      if (model.hasRemoteTflite) attempts.add((model.tfliteUrl, 'tflite'));
      if (model.hasRemoteOnnx) attempts.add((model.onnxUrl, 'onnx'));
    }

    if (attempts.isEmpty) {
      throw Exception('${model.name}: ダウンロードURLが設定されていません');
    }

    String? lastError;
    for (final (url, ext) in attempts) {
      if (url == null) continue;
      try {
        final outPath = p.join(dir.path, '${model.fileNameInArchive}.$ext');
        await _downloadFile(url, outPath, onProgress: onProgress);
        debugPrint('ModelManager: Downloaded $ext to $outPath');
        return outPath;
      } catch (e) {
        lastError = e.toString();
        debugPrint('ModelManager: $ext download failed: $e');
      }
    }

    throw Exception('${model.name}: 全フォーマットのダウンロードに失敗しました – $lastError');
  }

  /// Delete a downloaded model.
  Future<void> deleteModel(ModelInfo model) async {
    final dir = await modelDir;
    for (final ext in ['tflite', 'onnx']) {
      final f = File(p.join(dir.path, '${model.fileNameInArchive}.$ext'));
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _downloadFile(
    String url,
    String outPath, {
    void Function(double)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $url');
    }

    final totalBytes = response.contentLength ?? -1;
    int receivedBytes = 0;
    final sink = File(outPath).openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    // Validate file was written.
    final stat = await File(outPath).stat();
    if (stat.size == 0) {
      await File(outPath).delete();
      throw Exception('ダウンロードファイルが空です: $outPath');
    }
  }
}
