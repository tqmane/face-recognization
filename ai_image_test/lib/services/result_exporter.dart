import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/benchmark_run.dart';

/// Exports benchmark results to JSON and CSV for academic research.
class ResultExporter {
  static const _exportDir = 'ai_image_test_exports';

  /// Returns the exports directory.
  Future<Directory> get exportDir async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, _exportDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  // ──────────────────────────────────────────────
  // JSON export
  // ──────────────────────────────────────────────

  /// Export a single [BenchmarkRun] as pretty-printed JSON.
  Future<File> exportJson(BenchmarkRun run) async {
    final dir = await exportDir;
    final file = File(p.join(dir.path, 'run_${_timestamp()}.json'));
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(run.toJson()));
    return file;
  }

  /// Export multiple runs to a single JSON array.
  Future<File> exportJsonMulti(List<BenchmarkRun> runs) async {
    final dir = await exportDir;
    final file = File(p.join(dir.path, 'runs_${_timestamp()}.json'));
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(runs.map((r) => r.toJson()).toList()));
    return file;
  }

  // ──────────────────────────────────────────────
  // CSV export
  // ──────────────────────────────────────────────

  /// Export a summary CSV with one row per run.
  Future<File> exportSummaryCsv(List<BenchmarkRun> runs) async {
    final dir = await exportDir;
    final file = File(p.join(dir.path, 'summary_${_timestamp()}.csv'));

    final headers = [
      'run_id',
      'timestamp',
      'engine',
      'device',
      'threads',
      'test_set',
      'threshold',
      'total_questions',
      'correct',
      'accuracy',
      'total_time_ms',
      'avg_inference_ms',
    ];

    final rows = <List<dynamic>>[headers];
    for (final run in runs) {
      rows.add([
        run.runId,
        run.timestamp.toIso8601String(),
        run.engineName,
        run.device,
        run.threads,
        run.testSetName,
        run.threshold,
        run.totalQuestions,
        run.correctCount,
        run.accuracy.toStringAsFixed(4),
        run.totalTimeMs,
        run.avgInferenceTimeMs.toStringAsFixed(2),
      ]);
    }

    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file;
  }

  /// Export per-question detail CSV for a single run.
  Future<File> exportDetailCsv(BenchmarkRun run) async {
    final dir = await exportDir;
    final file = File(p.join(dir.path, 'detail_${run.runId}_${_timestamp()}.csv'));

    final headers = [
      'question_id',
      'genre',
      'image1',
      'image2',
      'actual_match',
      'predicted_match',
      'similarity_score',
      'is_correct',
      'inference_time_ms',
    ];

    final rows = <List<dynamic>>[headers];
    for (final r in run.results) {
      rows.add([
        r.questionId,
        r.genre,
        p.basename(r.imagePath1),
        p.basename(r.imagePath2),
        r.actualMatch,
        r.predictedMatch,
        r.similarityScore.toStringAsFixed(6),
        r.isCorrect,
        r.inferenceTimeMs.toStringAsFixed(2),
      ]);
    }

    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file;
  }

  // ──────────────────────────────────────────────
  // Share / list
  // ──────────────────────────────────────────────

  /// Share a file using the system share dialog.
  Future<void> shareFile(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  /// List all exported files.
  Future<List<File>> listExports() async {
    final dir = await exportDir;
    if (!await dir.exists()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Delete an export file.
  Future<void> deleteExport(File file) async {
    if (await file.exists()) await file.delete();
  }
}
