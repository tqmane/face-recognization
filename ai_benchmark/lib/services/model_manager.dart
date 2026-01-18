import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class ModelItem {
  final String key;
  final String name;
  final String url;
  final String fileNameInArchive; 
  final int inputSize;

  ModelItem({
    required this.key,
    required this.name,
    required this.url,
    required this.fileNameInArchive,
    this.inputSize = 224,
  });
}

class ModelManager {
  static final List<ModelItem> models = [
    ModelItem(
      key: 'mobilenet_v1',
      name: 'MobileNet V1',
      url: 'http://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_02_22/mobilenet_v1_1.0_224_quant.tgz',
      fileNameInArchive: 'mobilenet_v1_1.0_224_quant.tflite',
    ),
    ModelItem(
      key: 'mobilenet_v2',
      name: 'MobileNet V2',
      url: 'http://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/mobilenet_v2_1.0_224_quant.tgz',
      fileNameInArchive: 'mobilenet_v2_1.0_224_quant.tflite',
    ),
    ModelItem(
      key: 'mobilenet_v3',
      name: 'MobileNet V3 (Large)',
      url: 'https://huggingface.co/qualcomm/MobileNet-v3-Large/resolve/main/MobileNet-v3-Large.tflite',
      fileNameInArchive: 'MobileNet-v3-Large.tflite',
    ),
    ModelItem(
      key: 'mobilenet_v4',
      name: 'MobileNet V4 (Medium)',
      url: 'https://huggingface.co/byoussef/MobileNetV4_Conv_Medium_TFLite_256/resolve/main/MobileNetV4_Conv_Medium_256_F32.tflite',
      fileNameInArchive: 'MobileNetV4_Conv_Medium_256_F32.tflite',
      inputSize: 256,
    ),
    ModelItem(
      key: 'inception_v3',
      name: 'Inception V3',
      url: 'http://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/inception_v3_2018_04_27.tgz',
      fileNameInArchive: 'inception_v3.tflite',
      inputSize: 299,
    ),
    ModelItem(
      key: 'squeezenet',
      name: 'SqueezeNet',
      url: 'http://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/squeezenet_2018_04_27.tgz',
      fileNameInArchive: 'squeezenet.tflite',
    ),
    ModelItem(
      key: 'densenet',
      name: 'DenseNet',
      url: 'http://storage.googleapis.com/download.tensorflow.org/models/tflite/model_zoo/upload_20180427/densenet_2018_04_27.tgz',
      fileNameInArchive: 'densenet.tflite',
    ),
  ];

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
    for (var m in models) {
      if (!await isModelDownloaded(m.key)) return false;
    }
    return true;
  }

  Future<void> downloadModel(String key, Function(double) onProgress) async {
    final model = models.firstWhere((m) => m.key == key);
    final saveDir = await _localPath;
    
    // Check if direct download or archive
    bool isDirectTflite = model.url.endsWith('.tflite');
    
    final tempPath = p.join(saveDir, isDirectTflite ? '$key.tflite' : '$key.temp_archive');

    try {
      // 1. Download
      final request = http.Request('GET', Uri.parse(model.url));
      final response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 0;
      
      List<int> bytes = [];
      int downloaded = 0;

      await response.stream.listen((List<int> newBytes) {
        bytes.addAll(newBytes);
        downloaded += newBytes.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }).asFuture();

      // Write to disk
      await File(tempPath).writeAsBytes(bytes);
      onProgress(1.0);

      // 2. Extract (if needed)
      if (isDirectTflite) {
        // Already downloaded to correct path? No, we downloaded to tempPath.
        // If tempPath name is already correct, we are done.
        // Wait, I named tempPath as '$key.tflite' if direct.
        // So we are done!
      } else {
        // Extract archive
        final inputStream = InputFileStream(tempPath);
        final archive = TarDecoder().decodeBuffer(inputStream);

        for (var file in archive) {
          if (file.name.endsWith(model.fileNameInArchive)) {
            final outputFile = File(p.join(saveDir, '$key.tflite'));
            final outputStream = OutputFileStream(outputFile.path);
            file.writeContent(outputStream);
            outputStream.close();
            break;
          }
        }
        
        inputStream.close();
        await File(tempPath).delete();
      }

    } catch (e) {
      print('Download failed: $e');
      throw e;
    }
  }
}