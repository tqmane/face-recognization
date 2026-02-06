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
/// Supported structure:
/// ```
/// test_set/
///   manifest.json  (optional)
///   type_a/
///     img1.jpg
///   type_b/
///     img1.jpg
/// ```
class TestSetLoader {
  /// Load from a ZIP file. Extracts to temp and then delegates to [loadFromDirectory].
  Future<List<TestImagePair>> loadFromZip(String zipPath) async {
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
      return loadFromDirectory((children.first as Directory).path);
    }
    return loadFromDirectory(outDir.path);
  }

  /// Load from a folder on disk.
  Future<List<TestImagePair>> loadFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) throw Exception('ディレクトリが存在しません: $dirPath');

    // Read manifest if present.
    final manifestFile = File(p.join(dirPath, 'manifest.json'));
    Map<String, dynamic>? manifest;
    if (await manifestFile.exists()) {
      try {
        manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        debugPrint('TestSetLoader: manifest.json parse error, ignoring');
      }
    }

    // Find type subdirectories (each subfolder = one species/type).
    final typeDirs = <String, List<String>>{};
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final images = <String>[];
        await for (final f in entity.list()) {
          if (f is File && _isImage(f.path)) images.add(f.path);
        }
        if (images.isNotEmpty) typeDirs[name] = images;
      }
    }

    if (typeDirs.isEmpty) {
      throw Exception('テストセットにサブフォルダが見つかりません: $dirPath');
    }

    final genre = manifest?['genre'] as String? ?? p.basename(dirPath);
    final types = typeDirs.keys.toList();
    final rng = Random(42); // deterministic for reproducibility
    final pairs = <TestImagePair>[];
    int id = 1;

    // Build similar_pairs set from manifest (if available).
    final similarPairs = <(String, String)>{};
    if (manifest != null && manifest['similar_pairs'] is List) {
      for (final sp in manifest['similar_pairs'] as List) {
        if (sp is Map) {
          similarPairs.add((sp['id1'] as String, sp['id2'] as String));
        }
      }
    }

    // Generate pairs: ~50% same, ~50% different.
    final pairCount = types.length * 3; // scale with number of types

    // Same-type pairs.
    for (int i = 0; i < pairCount && i < types.length * 2; i++) {
      final t = types[rng.nextInt(types.length)];
      final imgs = typeDirs[t]!;
      if (imgs.length < 2) continue;
      final a = imgs[rng.nextInt(imgs.length)];
      String b;
      do {
        b = imgs[rng.nextInt(imgs.length)];
      } while (b == a && imgs.length > 1);
      pairs.add(TestImagePair(
          id: id++, genre: genre, imagePath1: a, imagePath2: b, isSame: true));
    }

    // Different-type pairs (prefer similar_pairs).
    final diffTargets = <(String, String)>[];
    for (final sp in similarPairs) {
      if (typeDirs.containsKey(sp.$1) && typeDirs.containsKey(sp.$2)) {
        diffTargets.add(sp);
      }
    }
    // Pad with random pairs if needed.
    while (diffTargets.length < pairCount) {
      final a = types[rng.nextInt(types.length)];
      String b;
      do {
        b = types[rng.nextInt(types.length)];
      } while (b == a && types.length > 1);
      diffTargets.add((a, b));
    }

    for (int i = 0; i < pairCount && i < diffTargets.length; i++) {
      final (ta, tb) = diffTargets[i];
      final imgsA = typeDirs[ta]!;
      final imgsB = typeDirs[tb]!;
      pairs.add(TestImagePair(
        id: id++,
        genre: genre,
        imagePath1: imgsA[rng.nextInt(imgsA.length)],
        imagePath2: imgsB[rng.nextInt(imgsB.length)],
        isSame: false,
      ));
    }

    pairs.shuffle(rng);
    return pairs;
  }

  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'}.contains(ext);
  }
}
