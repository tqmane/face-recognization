import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:engine_test/engine/engine.dart';
import 'package:engine_test/engine/mock_engine.dart';
import 'package:engine_test/firebase_sync.dart';
import 'package:engine_test/models/manifest.dart';
import 'package:engine_test/models/result_record.dart';
import 'package:engine_test/test_sets.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('mode',
        allowed: ['run', 'fetch'],
        defaultsTo: 'run',
        help: 'run: inference & upload, fetch: download existing results')
    ..addOption(
      'manifest',
      abbr: 'm',
      help: 'Path to manifest JSON (required in run mode).',
    )
    ..addOption(
      'zip',
      help: 'Path to human-test zip (e.g., sets_pics/small_cats.zip). Used instead of manifest.',
    )
    ..addOption(
      'set-id',
      help:
          'Download and use human-test zip by id (dogs, small_cats, wild_dogs, raccoons, birds, marine, reptiles, bears, primates, insects).',
    )
    ..addOption('engine',
        abbr: 'e',
        help: 'Engine name to run (mock or custom).',
        defaultsTo: 'mock')
    ..addOption('run-id',
        help: 'Run identifier. Default: utc timestamp.',
        defaultsTo: _defaultRunId())
    ..addOption('database-url',
        help: 'Firebase RTDB URL (fallback: FIREBASE_DATABASE_URL).',
        defaultsTo: Platform.environment['FIREBASE_DATABASE_URL'])
    ..addOption('id-token',
        help: 'Firebase ID token (fallback: FIREBASE_ID_TOKEN).',
        defaultsTo: Platform.environment['FIREBASE_ID_TOKEN'])
    ..addFlag('upload',
        help: 'Upload to Firebase RTDB.', defaultsTo: true, negatable: true)
    ..addOption('output',
        help: 'Optional local JSON output path for results.',
        defaultsTo: null)
    ..addOption('image-id',
        help: 'Fetch single imageId when mode=fetch.', defaultsTo: null)
    ..addOption('question-count',
        help: 'Use same pairing logic as Flutter/Android (5/10/15/20). 0 = disabled.',
        defaultsTo: '0')
    ..addOption('seed',
        help: 'Optional random seed for deterministic question generation.',
        defaultsTo: null)
    ..addFlag('verbose', defaultsTo: false);

  final args = parser.parse(arguments);
  final mode = args['mode'] as String;
  final manifestPath = args['manifest'] as String?;
  final engineName = args['engine'] as String;
  final runId = args['run-id'] as String;
  final dbUrl = args['database-url'] as String?;
  final idToken = args['id-token'] as String?;
  var upload = args['upload'] as bool;
  final verbose = args['verbose'] as bool;
  final imageId = args['image-id'] as String?;
  final zipPath = args['zip'] as String?;
  final setId = args['set-id'] as String?;
  final questionCount = int.tryParse(args['question-count'] as String? ?? '0') ?? 0;
  final seed = args['seed'] != null ? int.tryParse(args['seed'] as String) : null;

  if (mode == 'fetch') {
    if (!args.wasParsed('run-id')) {
      _fail('--run-id is required in fetch mode');
    }
    if (dbUrl == null || idToken == null) {
      _fail('fetch mode requires database-url and id-token');
    }
    final sync = FirebaseSync(databaseUrl: dbUrl, idToken: idToken);
    final records = await sync.fetchRun(runId, imageId: imageId);
    if (records.isEmpty) {
      stdout.writeln('No records found for runId=$runId'
          '${imageId != null ? ' imageId=$imageId' : ''}.');
    } else {
      stdout.writeln(
          'Fetched ${records.length} record(s) for runId=$runId${imageId != null ? ' imageId=$imageId' : ''}.');
      if (verbose) {
        for (final record in records) {
          final preds = record.predictions
              .map((p) => '${p.label}:${p.score.toStringAsFixed(2)}')
              .join(', ');
          stdout.writeln(
              '- ${record.imageId}: $preds (${record.latencyMs}ms, engine=${record.engine}${record.provider != null ? '/${record.provider}' : ''})');
        }
      }
    }

    final outputPath = args['output'] as String?;
    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(jsonEncode(
          records.map((record) => record.toJson()).toList()));
      stdout.writeln('Saved results to $outputPath');
    }
    return;
  }

  // run mode
  if ((manifestPath == null || !args.wasParsed('manifest')) &&
      (zipPath == null || !args.wasParsed('zip')) &&
      (setId == null || !args.wasParsed('set-id'))) {
    _fail('run mode requires --manifest or --zip or --set-id');
  }

  String? zipToUse = zipPath;
  if (setId != null) {
    stdout.writeln('Downloading set "$setId" from shared test sets ...');
    zipToUse = await downloadTestSetZip(setId);
    stdout.writeln('Downloaded to $zipToUse');
  }

  final manifest = zipToUse != null
      ? await TestManifest.loadFromZip(zipToUse)
      : await TestManifest.load(manifestPath!);
  final engine = _resolveEngine(engineName);

  FirebaseSync? sync;
  if (upload && dbUrl != null && idToken != null) {
    sync = FirebaseSync(databaseUrl: dbUrl, idToken: idToken);
  } else if (upload) {
    stdout.writeln(
        '[warn] Upload requested but database-url or id-token missing; skipping upload.');
    upload = false;
  }

  final results = <ResultRecord>[];

  if (questionCount > 0) {
    final questions =
        manifest.generatePairQuestions(questionCount, seed: seed);
    stdout.writeln(
        'Running ${questions.length} question(s) with engine "$engineName" (runId=$runId) ...');

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      final bytes1 = await File(q.image1.resolvedPath).readAsBytes();
      final res1 = await engine.infer(bytes1);
      final record1 = ResultRecord(
        runId: runId,
        imageId: 'q${i + 1}_1',
        engine: engine.name,
        provider: res1.provider,
        latencyMs: res1.latencyMs,
        predictions: res1.predictions,
        inputSize: res1.inputSize,
        preprocess: res1.note ?? 'none (match human test)',
        label: q.type1,
        meta: {
          'questionIndex': i + 1,
          'isSame': q.isSame,
          'type1': q.type1,
          'type2': q.type2,
          'position': 1,
          if (q.type1Display != null) 'type1Display': q.type1Display,
          if (q.type2Display != null) 'type2Display': q.type2Display,
        },
        imagePath: q.image1.resolvedPath,
      );

      final bytes2 = await File(q.image2.resolvedPath).readAsBytes();
      final res2 = await engine.infer(bytes2);
      final record2 = ResultRecord(
        runId: runId,
        imageId: 'q${i + 1}_2',
        engine: engine.name,
        provider: res2.provider,
        latencyMs: res2.latencyMs,
        predictions: res2.predictions,
        inputSize: res2.inputSize,
        preprocess: res2.note ?? 'none (match human test)',
        label: q.type2,
        meta: {
          'questionIndex': i + 1,
          'isSame': q.isSame,
          'type1': q.type1,
          'type2': q.type2,
          'position': 2,
          if (q.type1Display != null) 'type1Display': q.type1Display,
          if (q.type2Display != null) 'type2Display': q.type2Display,
        },
        imagePath: q.image2.resolvedPath,
      );

      for (final record in [record1, record2]) {
        results.add(record);
        if (upload && sync != null) {
          await sync.uploadResult(runId, record);
        }
      }

      if (verbose) {
        stdout.writeln(
            '- Q${i + 1}: ${q.type1} vs ${q.type2} (isSame=${q.isSame})');
        stdout.writeln(
            '  * img1 ${record1.predictions.map((p) => '${p.label}:${p.score.toStringAsFixed(2)}').join(', ')} (${record1.latencyMs}ms)');
        stdout.writeln(
            '  * img2 ${record2.predictions.map((p) => '${p.label}:${p.score.toStringAsFixed(2)}').join(', ')} (${record2.latencyMs}ms)');
      }
    }
  } else {
    stdout.writeln(
        'Running ${manifest.items.length} item(s) with engine "$engineName" (runId=$runId) ...');

    for (final item in manifest.items) {
      final bytes = await File(item.resolvedPath).readAsBytes();
      final inference = await engine.infer(bytes);
      final record = ResultRecord.fromResult(
        runId: runId,
        item: item,
        result: inference,
        engine: engine.name,
      );

      results.add(record);
      if (upload && sync != null) {
        await sync.uploadResult(runId, record);
      }

      if (verbose) {
        stdout.writeln(
            '- ${item.id}: ${record.predictions.map((p) => '${p.label}:${p.score.toStringAsFixed(2)}').join(', ')} (${record.latencyMs}ms)');
      }
    }
  }

  stdout.writeln('Done. Processed ${results.length} item(s).');

  final outputPath = args['output'] as String?;
  if (outputPath != null) {
    final file = File(outputPath);
    await file.writeAsString(jsonEncode(
        results.map((record) => record.toJson()).toList()));
    stdout.writeln('Saved results to $outputPath');
  }
}

InferenceEngine _resolveEngine(String name) {
  switch (name) {
    case 'mock':
      return MockEngine();
    default:
      throw ArgumentError('Unknown engine: $name');
  }
}

String _defaultRunId() {
  return DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
}

Never _fail(String message) {
  stderr.writeln('[error] $message');
  exit(64);
}
