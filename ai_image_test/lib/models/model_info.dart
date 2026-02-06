/// Model metadata.
class ModelInfo {
  final String key;
  final String name;
  final String? tfliteUrl;
  final String? onnxUrl;
  final String fileNameInArchive;
  final int inputSize;
  final bool isRecommended;

  const ModelInfo({
    required this.key,
    required this.name,
    this.tfliteUrl,
    this.onnxUrl,
    required this.fileNameInArchive,
    this.inputSize = 224,
    this.isRecommended = false,
  });

  bool get hasRemoteTflite =>
      tfliteUrl != null && tfliteUrl!.startsWith('http');
  bool get hasRemoteOnnx =>
      onnxUrl != null && onnxUrl!.startsWith('http');

  factory ModelInfo.fromJson(Map<String, dynamic> j) => ModelInfo(
        key: j['key'] as String,
        name: j['name'] as String,
        tfliteUrl: j['url'] as String?,
        onnxUrl: j['onnxUrl'] as String?,
        fileNameInArchive: j['fileNameInArchive'] as String,
        inputSize: (j['inputSize'] as num?)?.toInt() ?? 224,
        isRecommended: (j['isRecommended'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'url': tfliteUrl,
        'onnxUrl': onnxUrl,
        'fileNameInArchive': fileNameInArchive,
        'inputSize': inputSize,
        'isRecommended': isRecommended,
      };
}
