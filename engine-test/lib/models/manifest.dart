import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class TestManifest {
  TestManifest({required this.items, required this.baseDir, this.meta});

  final List<TestItem> items;
  final Directory baseDir;
  final TestSetMeta? meta;

  static Future<TestManifest> load(String manifestPath) async {
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw ArgumentError('Manifest not found: $manifestPath');
    }
    final baseDir = file.parent;
    final jsonMap =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final rawItems = (jsonMap['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final items =
        rawItems.map((item) => TestItem.fromJson(item, baseDir.path)).toList();
    return TestManifest(items: items, baseDir: baseDir);
  }

  /// ZIP形式の人間テスト用データをそのまま使う。
  /// ZIP内の manifest.json はメタ情報のみで個別画像は列挙されていないため、
  /// 画像ファイルを走査してマニフェストを組み立てる。
  static Future<TestManifest> loadFromZip(String zipPath) async {
    final file = File(zipPath);
    if (!file.existsSync()) {
      throw ArgumentError('Zip not found: $zipPath');
    }
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // manifest.json を読み取る（タイプ名とsimilar_pairsを利用）
    TestSetMeta? meta;
    for (final entry in archive) {
      final normalized = entry.name.replaceAll('\\', '/');
      if (entry.isFile && normalized == 'manifest.json') {
        final content = utf8.decode(entry.content as List<int>);
        final json = jsonDecode(content) as Map<String, dynamic>;
        meta = TestSetMeta.fromJson(json);
        break;
      }
    }

    // 一時ディレクトリに展開（人間テストと同じ条件: 変換なし）
    final tmpDir = await Directory.systemTemp.createTemp('engine_test_zip_');
    final items = <TestItem>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = entry.name.replaceAll('\\', '/');
      if (!_isImageFile(normalized)) continue;

      final outPath = p.join(tmpDir.path, normalized);
      await File(outPath).create(recursive: true);
      await File(outPath).writeAsBytes(entry.content as List<int>);

      final label =
          p.split(normalized).isNotEmpty ? p.split(normalized).first : null;
      items.add(TestItem(
        id: normalized,
        imagePath: normalized,
        resolvedPath: outPath,
        label: label,
        meta: {'source': zipPath},
      ));
    }

    items.sort((a, b) => a.id.compareTo(b.id));
    // manifest.json がなくてもディレクトリ名からタイプ名は推定できる
    meta ??= TestSetMeta.fromLabels(
        items.map((e) => e.label).whereType<String>().toSet());
    return TestManifest(items: items, baseDir: tmpDir, meta: meta);
  }

  /// Flutter/AndroidのZipTestSetServiceと同等の問題生成（同じロジックを簡略移植）。
  List<PairQuestion> generatePairQuestions(int count, {int? seed}) {
    if (count <= 0) {
      throw ArgumentError('count must be > 0');
    }
    final rnd = Random(seed);

    // タイプごとに画像を集約
    final Map<String, List<TestItem>> byType = {};
    for (final item in items) {
      if (item.label == null) continue;
      byType.putIfAbsent(item.label!, () => []).add(item);
    }
    if (byType.isEmpty) {
      throw ArgumentError('No labeled images found in manifest');
    }

    final typeIds = byType.keys.toList();
    final metaTypes = meta?.types ?? {};
    final similarPairs = meta?.similarPairs ?? [];

    List<TestItem> pickTwoDistinct(List<TestItem> list) {
      if (list.length < 2) {
        throw ArgumentError('Not enough images in type');
      }
      final i1 = rnd.nextInt(list.length);
      var i2 = rnd.nextInt(list.length);
      while (i2 == i1) {
        i2 = rnd.nextInt(list.length);
      }
      return [list[i1], list[i2]];
    }

    final questions = <PairQuestion>[];

    if (typeIds.length == 1) {
      // 1種類しかない場合はすべて「同じ」判定
      final onlyType = typeIds.single;
      final imgs = byType[onlyType]!;
      for (int i = 0; i < count; i++) {
        final pair = pickTwoDistinct(imgs);
        questions.add(PairQuestion(
          image1: pair[0],
          image2: pair[1],
          type1: onlyType,
          type2: onlyType,
          type1Display: metaTypes[onlyType],
          type2Display: metaTypes[onlyType],
          isSame: true,
        ));
      }
      return questions;
    }

    final sameTarget = count ~/ 2;
    final typesWithMultiple = typeIds
        .where((t) => (byType[t]?.length ?? 0) >= 2)
        .toList(growable: false);

    // 同じタイプ
    if (typesWithMultiple.isNotEmpty) {
      int attempts = 0;
      while (questions.where((q) => q.isSame).length < sameTarget &&
          attempts < sameTarget * 20) {
        attempts++;
        final typeId = typesWithMultiple[rnd.nextInt(typesWithMultiple.length)];
        final imgs = byType[typeId]!;
        final pair = pickTwoDistinct(imgs);
        questions.add(PairQuestion(
          image1: pair[0],
          image2: pair[1],
          type1: typeId,
          type2: typeId,
          type1Display: metaTypes[typeId],
          type2Display: metaTypes[typeId],
          isSame: true,
        ));
      }
    }

    // similar_pairs を優先して「違うタイプ」
    final usedPairs = <String>{};
    final shuffledPairs = List.of(similarPairs)..shuffle(rnd);
    for (final pair in shuffledPairs) {
      if (questions.length >= count) break;
      final pairKey = '${pair.id1}-${pair.id2}';
      if (usedPairs.contains(pairKey)) continue;
      final imgs1 = byType[pair.id1];
      final imgs2 = byType[pair.id2];
      if (imgs1 == null || imgs2 == null) continue;
      usedPairs.add(pairKey);
      questions.add(PairQuestion(
        image1: imgs1[rnd.nextInt(imgs1.length)],
        image2: imgs2[rnd.nextInt(imgs2.length)],
        type1: pair.id1,
        type2: pair.id2,
        type1Display: metaTypes[pair.id1],
        type2Display: metaTypes[pair.id2],
        isSame: false,
      ));
    }

    // まだ足りなければランダムに違うタイプ
    int randomAttempts = 0;
    while (questions.length < count && randomAttempts < count * 50) {
      randomAttempts++;
      final t1 = typeIds[rnd.nextInt(typeIds.length)];
      var t2 = typeIds[rnd.nextInt(typeIds.length)];
      while (t2 == t1) {
        t2 = typeIds[rnd.nextInt(typeIds.length)];
      }
      final imgs1 = byType[t1];
      final imgs2 = byType[t2];
      if (imgs1 == null || imgs1.isEmpty || imgs2 == null || imgs2.isEmpty) {
        continue;
      }
      questions.add(PairQuestion(
        image1: imgs1[rnd.nextInt(imgs1.length)],
        image2: imgs2[rnd.nextInt(imgs2.length)],
        type1: t1,
        type2: t2,
        type1Display: metaTypes[t1],
        type2Display: metaTypes[t2],
        isSame: false,
      ));
    }

    questions.shuffle(rnd);
    if (questions.length < count) {
      throw ArgumentError(
          'Only generated ${questions.length} questions (requested $count). Reduce question-count or re-download set.');
    }
    return questions.take(count).toList();
  }
}

class TestItem {
  TestItem({
    required this.id,
    required this.imagePath,
    required this.resolvedPath,
    this.label,
    this.meta,
  });

  final String id;
  final String imagePath;
  final String resolvedPath;
  final String? label;
  final Map<String, dynamic>? meta;

  factory TestItem.fromJson(Map<String, dynamic> json, String baseDir) {
    final path = json['path'] as String? ?? '';
    final resolved = _resolvePath(path, baseDir);
    return TestItem(
      id: json['id'] as String? ?? path,
      imagePath: path,
      resolvedPath: resolved,
      label: json['label'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

String _resolvePath(String path, String baseDir) {
  if (path.isEmpty) return path;
  final file = File(path);
  if (file.isAbsolute) return file.path;
  return File('$baseDir/$path').absolute.path;
}

bool _isImageFile(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

class TestSetMeta {
  TestSetMeta({
    required this.types,
    required this.similarPairs,
  });

  final Map<String, String> types;
  final List<SimilarPair> similarPairs;

  factory TestSetMeta.fromLabels(Set<String> labels) {
    final map = {for (final l in labels) l: l};
    return TestSetMeta(types: map, similarPairs: const []);
  }

  factory TestSetMeta.fromJson(Map<String, dynamic> json) {
    final typesJson = json['types'] as Map<String, dynamic>? ?? {};
    final types = <String, String>{};
    typesJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        types[key] = (value['display_name'] as String?) ?? key;
      }
    });
    final pairsJson = json['similar_pairs'] as List<dynamic>? ?? [];
    final pairs = pairsJson
        .whereType<Map<String, dynamic>>()
        .map((e) => SimilarPair(
              id1: e['id1'] as String? ?? '',
              id2: e['id2'] as String? ?? '',
            ))
        .where((p) => p.id1.isNotEmpty && p.id2.isNotEmpty)
        .toList();
    return TestSetMeta(types: types, similarPairs: pairs);
  }
}

class SimilarPair {
  SimilarPair({required this.id1, required this.id2});
  final String id1;
  final String id2;
}

class PairQuestion {
  PairQuestion({
    required this.image1,
    required this.image2,
    required this.type1,
    required this.type2,
    required this.isSame,
    this.type1Display,
    this.type2Display,
  });

  final TestItem image1;
  final TestItem image2;
  final String type1;
  final String type2;
  final bool isSame;
  final String? type1Display;
  final String? type2Display;
}
