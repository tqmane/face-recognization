import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/test_image_pair.dart';

/// Loads a test set from a ZIP archive or folder.
///
/// テストセットの構造（flutter-app と同じ形式）:
/// ```
/// test_set/
///   manifest.json        (types / similar_pairs を定義)
///   type_a/
///     img1.jpg
///   type_b/
///     img1.jpg
/// ```
class TestSetLoader {
  final Random _random = Random();

  /// Load from a ZIP file. Extracts to temp and then delegates to [loadFromDirectory].
  Future<List<TestImagePair>> loadFromZip(String zipPath, {int? questionCount}) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final tmp = await getTemporaryDirectory();
    final outDir =
        Directory(p.join(tmp.path, 'test_set_${DateTime.now().millisecondsSinceEpoch}'));
    await outDir.create(recursive: true);

    for (final f in archive) {
      final filePath = p.join(outDir.path, f.name);
      if (f.isFile) {
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(f.content as List<int>);
      }
    }

    // The ZIP may contain a single root folder; detect that.
    final children = outDir.listSync();
    if (children.length == 1 && children.first is Directory) {
      return loadFromDirectory((children.first as Directory).path, questionCount: questionCount);
    }
    return loadFromDirectory(outDir.path, questionCount: questionCount);
  }

  /// Load from a folder on disk.
  /// flutter-app の generateQuestions() と同じロジックで問題を生成する。
  Future<List<TestImagePair>> loadFromDirectory(String dirPath, {int? questionCount}) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) throw Exception('ディレクトリが存在しません: $dirPath');

    // manifest.json を読み込み
    final manifestFile = File(p.join(dirPath, 'manifest.json'));
    Map<String, dynamic>? manifest;
    if (await manifestFile.exists()) {
      try {
        manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        debugPrint('TestSetLoader: manifest.json parse error, ignoring');
      }
    }

    // マニフェストからタイプIDリストを取得（あればそちらを使用）
    Set<String>? manifestTypeIds;
    if (manifest != null && manifest['types'] is Map) {
      manifestTypeIds = (manifest['types'] as Map<String, dynamic>).keys.toSet();
    }

    // 各タイプのサブディレクトリから画像を収集
    final imagesByType = <String, List<String>>{};
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        // マニフェストがあれば、そこに定義されたタイプのみ使用
        if (manifestTypeIds != null && !manifestTypeIds.contains(name)) continue;
        final images = <String>[];
        await for (final f in entity.list()) {
          if (f is File && _isImage(f.path)) images.add(f.path);
        }
        if (images.isNotEmpty) imagesByType[name] = images;
      }
    }

    if (imagesByType.isEmpty) {
      throw Exception('テストセットにサブフォルダが見つかりません: $dirPath');
    }

    final genre = manifest?['genre'] as String? ?? p.basename(dirPath);
    final typeIds = imagesByType.keys.toList();

    // similar_pairs を取得
    final similarPairs = <({String id1, String id2})>[];
    if (manifest != null && manifest['similar_pairs'] is List) {
      for (final sp in manifest['similar_pairs'] as List) {
        if (sp is Map) {
          final id1 = sp['id1'] as String? ?? '';
          final id2 = sp['id2'] as String? ?? '';
          if (id1.isNotEmpty && id2.isNotEmpty) {
            similarPairs.add((id1: id1, id2: id2));
          }
        }
      }
    }

    // 問題数を決定
    final count = questionCount ?? typeIds.length * 3;
    final pairs = <TestImagePair>[];
    int id = 1;

    // タイプが1つしかない場合は全て同種ペアにする
    if (typeIds.length == 1) {
      final onlyType = typeIds.single;
      final images = imagesByType[onlyType]!;
      if (images.length < 2) {
        throw Exception('テストセットの画像が不足しています（同種ペアには2枚以上必要です）');
      }
      for (int i = 0; i < count; i++) {
        final pair = _pickTwoDistinct(images);
        pairs.add(TestImagePair(
          id: id++, genre: genre,
          imagePath1: pair[0], imagePath2: pair[1],
          isSame: true,
        ));
      }
      pairs.shuffle(_random);
      return pairs;
    }

    // 同種ペア数 (約50%)
    final sameTarget = count ~/ 2;
    final typesWithMultipleImages = typeIds.where((t) => (imagesByType[t]?.length ?? 0) >= 2).toList();

    // 同じタイプの問題を生成
    if (typesWithMultipleImages.isNotEmpty) {
      int attempts = 0;
      while (pairs.where((q) => q.isSame).length < sameTarget && attempts < sameTarget * 20) {
        attempts++;
        final typeId = typesWithMultipleImages[_random.nextInt(typesWithMultipleImages.length)];
        final images = imagesByType[typeId]!;
        final pair = _pickTwoDistinct(images);
        pairs.add(TestImagePair(
          id: id++, genre: genre,
          imagePath1: pair[0], imagePath2: pair[1],
          isSame: true,
        ));
      }
    }

    // 異種ペア：similar_pairs を優先的に使用（flutter-app と同じ）
    final usedPairKeys = <String>{};
    final shuffledSimilarPairs = List.of(similarPairs)..shuffle(_random);
    for (final sp in shuffledSimilarPairs) {
      if (pairs.length >= count) break;
      final pairKey = '${sp.id1}-${sp.id2}';
      if (usedPairKeys.contains(pairKey)) continue;

      final images1 = imagesByType[sp.id1];
      final images2 = imagesByType[sp.id2];
      if (images1 == null || images2 == null) continue;

      usedPairKeys.add(pairKey);
      pairs.add(TestImagePair(
        id: id++, genre: genre,
        imagePath1: images1[_random.nextInt(images1.length)],
        imagePath2: images2[_random.nextInt(images2.length)],
        isSame: false,
      ));
    }

    // まだ足りない場合はランダムな異種ペアを追加
    int randomAttempts = 0;
    while (pairs.length < count && randomAttempts < count * 50) {
      randomAttempts++;
      final type1 = typeIds[_random.nextInt(typeIds.length)];
      var type2 = typeIds[_random.nextInt(typeIds.length)];
      while (type2 == type1) {
        type2 = typeIds[_random.nextInt(typeIds.length)];
      }
      final images1 = imagesByType[type1];
      final images2 = imagesByType[type2];
      if (images1 == null || images1.isEmpty || images2 == null || images2.isEmpty) continue;

      pairs.add(TestImagePair(
        id: id++, genre: genre,
        imagePath1: images1[_random.nextInt(images1.length)],
        imagePath2: images2[_random.nextInt(images2.length)],
        isSame: false,
      ));
    }

    // シャッフルして返す（毎回異なる順番）
    pairs.shuffle(_random);
    return pairs.take(count).toList();
  }

  /// 2つの異なる画像を選択
  List<String> _pickTwoDistinct(List<String> images) {
    final idx1 = _random.nextInt(images.length);
    var idx2 = _random.nextInt(images.length);
    while (idx2 == idx1 && images.length > 1) {
      idx2 = _random.nextInt(images.length);
    }
    return [images[idx1], images[idx2]];
  }

  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'}.contains(ext);
  }
}
