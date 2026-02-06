import 'package:flutter/material.dart';
import '../services/model_manager.dart';
import '../models/model_info.dart';

/// Download / delete ML models used by TFLite and ONNX engines.
class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  final _manager = ModelManager();
  final _downloadProgress = <String, double>{};
  final _downloading = <String>{};
  final _downloaded = <String, String>{}; // key → local path
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    for (final model in ModelManager.builtInModels) {
      final path = await _manager.getModelPath(model);
      if (path != null) {
        _downloaded[model.key] = path;
      } else {
        _downloaded.remove(model.key);
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _download(ModelInfo model, String format) async {
    setState(() => _downloading.add(model.key));

    try {
      final path = await _manager.downloadModel(
        model,
        preferredFormat: format,
        onProgress: (p) {
          setState(() => _downloadProgress[model.key] = p);
        },
      );
      _downloaded[model.key] = path;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ダウンロードエラー: $e')),
      );
    } finally {
      setState(() {
        _downloading.remove(model.key);
        _downloadProgress.remove(model.key);
      });
    }
  }

  Future<void> _delete(ModelInfo model) async {
    await _manager.deleteModel(model);
    _downloaded.remove(model.key);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('モデル管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: ModelManager.builtInModels.length,
              itemBuilder: (_, i) {
                final model = ModelManager.builtInModels[i];
                final isDownloaded = _downloaded.containsKey(model.key);
                final isDownloading = _downloading.contains(model.key);
                final progress = _downloadProgress[model.key];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (model.isRecommended)
                              Chip(
                                label: const Text('推奨'),
                                backgroundColor: Colors.green.shade100,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('入力サイズ: ${model.inputSize}x${model.inputSize}',
                            style: Theme.of(context).textTheme.bodySmall),

                        if (isDownloaded) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _downloaded[model.key]!,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _delete(model),
                                child: const Text('削除'),
                              ),
                            ],
                          ),
                        ] else if (isDownloading) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 4),
                          Text(progress != null
                              ? '${(progress * 100).toStringAsFixed(0)}%'
                              : 'ダウンロード中...'),
                        ] else ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _download(model, 'tflite'),
                                child: const Text('TFLite'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _download(model, 'onnx'),
                                child: const Text('ONNX'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
