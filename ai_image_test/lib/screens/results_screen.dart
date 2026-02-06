import 'dart:io';
import 'package:flutter/material.dart';
import '../services/result_exporter.dart';

/// Shows list of exported result files and allows re-sharing/deleting.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _exporter = ResultExporter();
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _files = await _exporter.listExports();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('過去の結果')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('エクスポートされた結果はありません'))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final file = _files[i];
                    final name = file.uri.pathSegments.last;
                    final stat = file.statSync();
                    final sizeKb = (stat.size / 1024).toStringAsFixed(1);

                    return ListTile(
                      leading: Icon(
                        name.endsWith('.csv')
                            ? Icons.table_chart
                            : Icons.data_object,
                      ),
                      title: Text(name),
                      subtitle: Text('$sizeKb KB · ${stat.modified}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _exporter.shareFile(file),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await _exporter.deleteExport(file);
                              _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
