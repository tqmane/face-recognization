import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Model format types
enum ModelFormat {
  tflite,
  onnx,
}

class ModelItem {
  final String key;
  final String name;
  final String? url;
  final String? onnxUrl; // ONNX version URL for desktop GPU
  final String fileNameInArchive; 
  final int inputSize;
  final bool isRecommended;

  ModelItem({
    required this.key,
    required this.name,
    this.url,
    this.onnxUrl,
    required this.fileNameInArchive,
    this.inputSize = 224,
    this.isRecommended = false,
  });

  bool get isRemote => url != null && (url!.startsWith('http://') || url!.startsWith('https://'));
  bool get hasOnnx => onnxUrl != null && onnxUrl!.isNotEmpty;

  /// Get the preferred format for the current platform
  static ModelFormat get preferredFormat {
    if (Platform.isWindows || Platform.isLinux) {
      return ModelFormat.onnx; // ONNX for desktop GPU (DirectML/CUDA)
    }
    return ModelFormat.tflite; // TFLite for mobile/macOS (Metal)
  }

  /// Check if GPU is available with the preferred format
  static bool get isGpuAvailableOnPlatform {
    // GPU is available on all platforms with appropriate runtime
    return true;
  }

  factory ModelItem.fromJson(Map<String, dynamic> json) {
    return ModelItem(
      key: json['key'] as String,
      name: json['name'] as String,
      url: json['url'] as String?,
      onnxUrl: json['onnxUrl'] as String?,
      fileNameInArchive: json['fileNameInArchive'] as String,
      inputSize: (json['inputSize'] as num?)?.toInt() ?? 224,
      isRecommended: (json['isRecommended'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'url': url,
      'onnxUrl': onnxUrl,
      'fileNameInArchive': fileNameInArchive,
      'inputSize': inputSize,
      'isRecommended': isRecommended,
    };
  }
}

class ModelManager {
  // GitHub Releases base URL for pre-converted models
  static const String _modelsReleaseBase = 
      'https://github.com/tqmane/face-recognization/releases/download/models-v1.0.0';

  // Backward-compatibility: existing UI still references ModelManager.models.
  // Prefer using listModels() for default + custom models.
  static List<ModelItem> get models => defaultModels;

  static final List<ModelItem> defaultModels = [
    // 2025+ (Docs updated 2025-01-13): MediaPipe Tasks Image Embedder models
    // These output embeddings directly, which is ideal for cosine similarity.
    ModelItem(
      key: 'mp_image_embedder_mnv3_small',
      name: 'Image Embedder (MNv3 Small, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_embedder/mobilenet_v3_small_075_224_embedder.tflite',
      onnxUrl: '$_modelsReleaseBase/mobilenet_v3_small_embedder.onnx',
      fileNameInArchive: 'mobilenet_v3_small_075_224_embedder.tflite',
      inputSize: 224,
      isRecommended: true,
    ),
    ModelItem(
      key: 'mp_image_embedder_mnv3_large',
      name: 'Image Embedder (MNv3 Large, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_embedder/mobilenet_v3_large_075_224_embedder.tflite',
      onnxUrl: '$_modelsReleaseBase/mobilenet_v3_large_embedder.onnx',
      fileNameInArchive: 'mobilenet_v3_large_075_224_embedder.tflite',
      inputSize: 224,
      isRecommended: true,
    ),

    // MediaPipe Image Classifier models (doc last updated 2025-01-13).
    // We use the output logits/probabilities vector as an "embedding" for similarity.
    ModelItem(
      key: 'mp_image_classifier_enlite0_fp32_2025',
      name: 'Image Classifier (EfficientNet-Lite0 FP32, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_classifier/efficientnet_lite0_fp32.tflite',
      onnxUrl: '$_modelsReleaseBase/efficientnet_lite0_fp32.onnx',
      fileNameInArchive: 'efficientnet_lite0_fp32.tflite',
      inputSize: 224,
      isRecommended: false,
    ),
    ModelItem(
      key: 'mp_image_classifier_enlite2_fp32_2025',
      name: 'Image Classifier (EfficientNet-Lite2 FP32, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_classifier/efficientnet_lite2_fp32.tflite',
      onnxUrl: '$_modelsReleaseBase/efficientnet_lite2_fp32.onnx',
      fileNameInArchive: 'efficientnet_lite2_fp32.tflite',
      inputSize: 224,
      isRecommended: false,
    ),
    ModelItem(
      key: 'mobilenet_v1',
      name: 'MobileNet V1',
      url: 'https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_02_22/mobilenet_v1_1.0_224_quant.tgz',
      fileNameInArchive: 'mobilenet_v1_1.0_224_quant.tflite',
    ),
    ModelItem(
      key: 'mobilenet_v2',
      name: 'MobileNet V2',
      url: 'https://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/mobilenet_v2_1.0_224_quant.tgz',
      fileNameInArchive: 'mobilenet_v2_1.0_224_quant.tflite',
    ),
    // Note: MobileNet V3 Large - currently unavailable via direct download
    // The Qualcomm HuggingFace model requires authentication/script-based download
    // Consider using MobileNet V2 or V4 as alternatives
    ModelItem(
      key: 'mobilenet_v4',
      name: 'MobileNet V4 (Medium)',
      url: 'https://huggingface.co/byoussef/MobileNetV4_Conv_Medium_TFLite_224/resolve/main/mobilenetv4_conv_medium.e500_r224_in1k_float32.tflite?download=true',
      fileNameInArchive: 'mobilenetv4_conv_medium.e500_r224_in1k_float32.tflite',
      inputSize: 224,
    ),
    ModelItem(
      key: 'inception_v3',
      name: 'Inception V3',
      url: 'https://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/inception_v3_2018_04_27.tgz',
      fileNameInArchive: 'inception_v3.tflite',
      inputSize: 299,
    ),
    ModelItem(
      key: 'squeezenet',
      name: 'SqueezeNet',
      url: 'https://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/squeezenet_2018_04_27.tgz',
      fileNameInArchive: 'squeezenet.tflite',
    ),
    ModelItem(
      key: 'densenet',
      name: 'DenseNet',
      url: 'https://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/densenet_2018_04_27.tgz',
      fileNameInArchive: 'densenet.tflite',
    ),
  ];

  Future<File> _customModelsJsonFile() async {
    final path = await _localPath;
    return File(p.join(path, 'custom_models.json'));
  }

  Future<List<ModelItem>> listCustomModels() async {
    final file = await _customModelsJsonFile();
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => ModelItem.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      // If corrupted, don't crash the app.
      debugPrint('Failed to read custom models: $e');
      return [];
    }
  }

  Future<List<ModelItem>> listModels() async {
    final custom = await listCustomModels();
    // Ensure stable ordering: recommended first, then name.
    final all = <ModelItem>[...defaultModels, ...custom];
    all.sort((a, b) {
      final ra = a.isRecommended ? 1 : 0;
      final rb = b.isRecommended ? 1 : 0;
      if (ra != rb) return rb - ra;
      return a.name.compareTo(b.name);
    });
    return all;
  }

  Future<void> addCustomModel(ModelItem item) async {
    final models = await listCustomModels();
    final existingIndex = models.indexWhere((m) => m.key == item.key);
    if (existingIndex >= 0) {
      models[existingIndex] = item;
    } else {
      models.add(item);
    }

    final file = await _customModelsJsonFile();
    await file.writeAsString(
      jsonEncode(models.map((m) => m.toJson()).toList(growable: false)),
      flush: true,
    );
  }

  Future<void> removeCustomModel(String key) async {
    final models = await listCustomModels();
    models.removeWhere((m) => m.key == key);
    final file = await _customModelsJsonFile();
    await file.writeAsString(
      jsonEncode(models.map((m) => m.toJson()).toList(growable: false)),
      flush: true,
    );
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(directory.path, 'models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// Get the model file for a given key and format
  Future<File> getModelFile(String key, {ModelFormat? format}) async {
    format ??= ModelItem.preferredFormat;
    final path = await _localPath;
    final ext = format == ModelFormat.onnx ? 'onnx' : 'tflite';
    return File(p.join(path, '$key.$ext'));
  }

  /// Get the best available model file (prefers platform-optimal format)
  Future<(File, ModelFormat)?> getBestModelFile(String key) async {
    final preferred = ModelItem.preferredFormat;
    
    // Try preferred format first
    final preferredFile = await getModelFile(key, format: preferred);
    if (await preferredFile.exists()) {
      return (preferredFile, preferred);
    }
    
    // Fallback to other format
    final fallback = preferred == ModelFormat.onnx ? ModelFormat.tflite : ModelFormat.onnx;
    final fallbackFile = await getModelFile(key, format: fallback);
    if (await fallbackFile.exists()) {
      return (fallbackFile, fallback);
    }
    
    return null;
  }

  Future<bool> isModelDownloaded(String key, {ModelFormat? format}) async {
    if (format != null) {
      final file = await getModelFile(key, format: format);
      return await file.exists();
    }
    // Check if any format is available
    final best = await getBestModelFile(key);
    return best != null;
  }

  /// Check if the optimal format for GPU is available
  Future<bool> isOptimalFormatDownloaded(String key) async {
    final file = await getModelFile(key, format: ModelItem.preferredFormat);
    return await file.exists();
  }
  
  Future<bool> areAllModelsDownloaded() async {
    final all = await listModels();
    for (var m in all) {
      if (!await isModelDownloaded(m.key)) return false;
    }
    return true;
  }

  Future<void> importLocalModel({
    required String localTflitePath,
    required ModelItem meta,
  }) async {
    final src = File(localTflitePath);
    if (!await src.exists()) {
      throw Exception('Local model not found: $localTflitePath');
    }
    final dst = await getModelFile(meta.key);
    if (await dst.exists()) {
      await dst.delete();
    }
    await src.copy(dst.path);
    await addCustomModel(meta);
  }

  Future<void> downloadModel(String key, Function(double) onProgress, {ModelFormat? format}) async {
    format ??= ModelItem.preferredFormat;
    
    final all = await listModels();
    final model = all.firstWhere((m) => m.key == key);
    
    // Determine URL based on format
    String? downloadUrl;
    if (format == ModelFormat.onnx && model.hasOnnx) {
      downloadUrl = model.onnxUrl;
    } else if (format == ModelFormat.tflite && model.isRemote) {
      downloadUrl = model.url;
    } else if (model.isRemote) {
      // Fallback to TFLite if ONNX not available
      downloadUrl = model.url;
      format = ModelFormat.tflite;
    }
    
    if (downloadUrl == null) {
      throw Exception('No download URL available for model $key in format $format');
    }
    
    final saveDir = await _localPath;
    final ext = format == ModelFormat.onnx ? 'onnx' : 'tflite';
    final uri = Uri.parse(downloadUrl);
    final urlPath = uri.path.toLowerCase();
    final isDirectModel = urlPath.endsWith('.tflite') || urlPath.endsWith('.onnx');
    final isTarGz = urlPath.endsWith('.tgz') || urlPath.endsWith('.tar.gz');
    final isTar = urlPath.endsWith('.tar');

    final finalModelPath = p.join(saveDir, '$key.$ext');
    final tempPath = p.join(saveDir, isDirectModel ? '$key.$ext.download' : '$key.temp_archive');

    http.Client? client;
    IOSink? sink;
    try {
      // 1) Download (streaming to disk)
      client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}: $downloadUrl へのダウンロード失敗'
          '${response.statusCode == 404 ? "（ファイルがリリースに存在しません）" : ""}'
        );
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
      sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink!.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();
      sink = null;

      // 2) Extract / Move
      if (isDirectModel) {
        final finalFile = File(finalModelPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await File(tempPath).rename(finalModelPath);
        onProgress(1.0);
        return;
      }

      // Archive: tar(.gz) only (as used by TF model zoo)
      final archiveBytes = await File(tempPath).readAsBytes();
      final tarBytes = isTarGz ? GZipDecoder().decodeBytes(archiveBytes) : archiveBytes;
      if (!isTarGz && !isTar) {
        throw Exception('Unsupported archive type: $urlPath');
      }

      final archive = TarDecoder().decodeBytes(tarBytes);
      ArchiveFile? target;
      final targetFileName = format == ModelFormat.onnx 
          ? model.fileNameInArchive.replaceAll('.tflite', '.onnx')
          : model.fileNameInArchive;
      for (final f in archive) {
        if (f.isFile && f.name.endsWith(targetFileName)) {
          target = f;
          break;
        }
      }

      if (target == null) {
        throw Exception('Model file not found in archive: $targetFileName');
      }

      final outFile = File(finalModelPath);
      if (await outFile.exists()) {
        await outFile.delete();
      }
      await outFile.writeAsBytes(target.content as List<int>, flush: true);
      await File(tempPath).delete();
      onProgress(1.0);
    } catch (e) {
      debugPrint('Download failed: $e');
      rethrow;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client?.close();
    }
  }
  
  /// Download model in the optimal format for the current platform.
  /// If the preferred format (e.g. ONNX on Windows) fails, automatically
  /// falls back to the other format (TFLite).
  Future<void> downloadOptimalModel(String key, Function(double) onProgress) async {
    final preferred = ModelItem.preferredFormat;
    try {
      await downloadModel(key, onProgress, format: preferred);
    } catch (e) {
      // If preferred format fails, try fallback format
      final fallback = preferred == ModelFormat.onnx ? ModelFormat.tflite : ModelFormat.onnx;
      debugPrint('Preferred format ($preferred) download failed: $e');
      debugPrint('Trying fallback format: $fallback');

      final all = await listModels();
      final model = all.firstWhere((m) => m.key == key);

      // Check if the fallback format has a URL
      final hasFallbackUrl = fallback == ModelFormat.tflite
          ? model.isRemote
          : model.hasOnnx;

      if (!hasFallbackUrl) {
        // No fallback available, rethrow original error
        throw Exception('$preferred ダウンロード失敗: $e（フォールバック $fallback のURLもありません）');
      }

      try {
        await downloadModel(key, onProgress, format: fallback);
        debugPrint('Fallback download ($fallback) succeeded');
      } catch (fallbackError) {
        throw Exception('$preferred: $e / $fallback: $fallbackError');
      }
    }
  }
}