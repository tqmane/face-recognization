import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class ModelItem {
  final String key;
  final String name;
  final String? url;
  final String fileNameInArchive; 
  final int inputSize;
  final bool isRecommended;

  ModelItem({
    required this.key,
    required this.name,
    this.url,
    required this.fileNameInArchive,
    this.inputSize = 224,
    this.isRecommended = false,
  });

  bool get isRemote => url != null && (url!.startsWith('http://') || url!.startsWith('https://'));

  factory ModelItem.fromJson(Map<String, dynamic> json) {
    return ModelItem(
      key: json['key'] as String,
      name: json['name'] as String,
      url: json['url'] as String?,
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
      'fileNameInArchive': fileNameInArchive,
      'inputSize': inputSize,
      'isRecommended': isRecommended,
    };
  }
}

class ModelManager {
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
      fileNameInArchive: 'mobilenet_v3_small_075_224_embedder.tflite',
      inputSize: 224,
      isRecommended: true,
    ),
    ModelItem(
      key: 'mp_image_embedder_mnv3_large',
      name: 'Image Embedder (MNv3 Large, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_embedder/mobilenet_v3_large_075_224_embedder.tflite',
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
      fileNameInArchive: 'efficientnet_lite0_fp32.tflite',
      inputSize: 224,
      isRecommended: false,
    ),
    ModelItem(
      key: 'mp_image_classifier_enlite2_fp32_2025',
      name: 'Image Classifier (EfficientNet-Lite2 FP32, 2025)',
      url: 'https://storage.googleapis.com/mediapipe-tasks/image_classifier/efficientnet_lite2_fp32.tflite',
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

  Future<File> getModelFile(String key) async {
    final path = await _localPath;
    return File(p.join(path, '$key.tflite'));
  }

  Future<bool> isModelDownloaded(String key) async {
    final file = await getModelFile(key);
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

  Future<void> downloadModel(String key, Function(double) onProgress) async {
    final all = await listModels();
    final model = all.firstWhere((m) => m.key == key);
    if (!model.isRemote) {
      throw Exception('This model has no remote URL (imported locally).');
    }
    final saveDir = await _localPath;

    final uri = Uri.parse(model.url!);
    final urlPath = uri.path.toLowerCase();
    final isDirectTflite = urlPath.endsWith('.tflite');
    final isTarGz = urlPath.endsWith('.tgz') || urlPath.endsWith('.tar.gz');
    final isTar = urlPath.endsWith('.tar');

    final finalModelPath = p.join(saveDir, '$key.tflite');
    final tempPath = p.join(saveDir, isDirectTflite ? '$key.tflite.download' : '$key.temp_archive');

    http.Client? client;
    IOSink? sink;
    try {
      // 1) Download (streaming to disk)
      client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} while downloading ${model.url}');
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
      if (isDirectTflite) {
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
      for (final f in archive) {
        if (f.isFile && f.name.endsWith(model.fileNameInArchive)) {
          target = f;
          break;
        }
      }

      if (target == null) {
        throw Exception('Model file not found in archive: ${model.fileNameInArchive}');
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
}