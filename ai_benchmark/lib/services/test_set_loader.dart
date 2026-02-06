import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/quiz_question.dart';

class TestSetLoader {

  /// ZIPファイルを解凍して問題リストを読み込む
  Future<List<QuizQuestion>> loadFromZip(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final destDir = Directory(
      p.join(tempDir.path,
          'extracted_test_set_${DateTime.now().millisecondsSinceEpoch}'),
    );

    // Unzip
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    extractArchiveToDisk(archive, destDir.path);
    inputStream.close();

    return _loadFromDirectory(destDir.path);
  }

  /// ディレクトリから問題リストを読み込む
  Future<List<QuizQuestion>> loadFromDirectory(String dirPath) async {
    return _loadFromDirectory(dirPath);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<List<QuizQuestion>> _loadFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $dirPath');
    }

    // manifest.json を探す
    final manifestFile = File(p.join(dirPath, 'manifest.json'));

    // ① manifest.json が存在する → ツールで作成されたテストセット
    if (await manifestFile.exists()) {
      return _loadFromManifest(dirPath, manifestFile);
    }

    // ② quiz_questions.json 等（従来の配列形式）を探す
    File? jsonFile;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        jsonFile = entity;
        break;
      }
    }

    if (jsonFile == null) {
      throw Exception('テストセット内にJSONファイルが見つかりません。');
    }

    return _loadLegacyQuizJson(dirPath, jsonFile);
  }

  /// manifest.json（メタデータ形式）からクイズペアを自動生成する。
  ///
  /// manifest 構造:
  /// ```json
  /// {
  ///   "genre": "small_cats",
  ///   "display_name": "ネコ科小型",
  ///   "types": { "persian_cat": {"display_name":"ペルシャ猫","count":10}, ... },
  ///   "similar_pairs": [ {"id1":"persian_cat","id2":"british_shorthair"}, ... ]
  /// }
  /// ```
  Future<List<QuizQuestion>> _loadFromManifest(
    String dirPath,
    File manifestFile,
  ) async {
    final manifest = await _readJsonFile(manifestFile);

    final genre = (manifest['display_name'] ?? manifest['genre'] ?? '') as String;
    final typesRaw = manifest['types'];
    final similarPairsRaw = manifest['similar_pairs'] as List<dynamic>? ?? [];

    // types を Map<String, String> (id → display_name) へ変換
    // version 1: types は Map, version 2: types は List
    final Map<String, String> typeNames = {};
    if (typesRaw is Map) {
      for (final entry in typesRaw.entries) {
        typeNames[entry.key as String] =
            (entry.value as Map)['display_name'] as String? ?? entry.key as String;
      }
    } else if (typesRaw is List) {
      for (final t in typesRaw) {
        final m = t as Map<String, dynamic>;
        typeNames[m['id'] as String] = m['display_name'] as String? ?? m['id'] as String;
      }
    }

    // ディレクトリ内の画像を type ごとに収集
    final Map<String, List<String>> imagesByType = {};
    for (final typeId in typeNames.keys) {
      final typeDir = Directory(p.join(dirPath, typeId));
      if (!await typeDir.exists()) continue;
      final images = <String>[];
      await for (final f in typeDir.list()) {
        if (f is File) {
          final ext = p.extension(f.path).toLowerCase();
          if (ext == '.jpg' || ext == '.jpeg' || ext == '.png') {
            images.add(f.path);
          }
        }
      }
      images.sort();
      if (images.isNotEmpty) {
        imagesByType[typeId] = images;
      }
    }

    if (imagesByType.isEmpty) {
      throw Exception('テストセット内に画像が見つかりません。');
    }

    final rng = Random(42); // 再現性のために固定シード
    final questions = <QuizQuestion>[];

    // ---- isMatch=true: 同じtype内のペア ----
    for (final entry in imagesByType.entries) {
      final typeId = entry.key;
      final imgs = entry.value;
      if (imgs.length < 2) continue;

      // 最大5ペアを生成
      final pairs = _pickRandomPairs(imgs, 5, rng);
      for (final pair in pairs) {
        questions.add(QuizQuestion(
          image1Url: pair.$1,
          image2Url: pair.$2,
          isMatch: true,
          item1Name: typeNames[typeId] ?? typeId,
          item2Name: typeNames[typeId] ?? typeId,
          genre: genre,
          explanation: '同じ${typeNames[typeId] ?? typeId}の画像',
        ));
      }
    }

    // ---- isMatch=false: similar_pairs（似ているが異なるtype）のペア ----
    for (final sp in similarPairsRaw) {
      final id1 = sp['id1'] as String;
      final id2 = sp['id2'] as String;
      final imgs1 = imagesByType[id1];
      final imgs2 = imagesByType[id2];
      if (imgs1 == null || imgs2 == null) continue;

      // 最大5ペアを生成
      final count = min(5, min(imgs1.length, imgs2.length));
      final shuffled1 = List<String>.from(imgs1)..shuffle(rng);
      final shuffled2 = List<String>.from(imgs2)..shuffle(rng);
      for (int i = 0; i < count; i++) {
        questions.add(QuizQuestion(
          image1Url: shuffled1[i],
          image2Url: shuffled2[i],
          isMatch: false,
          item1Name: typeNames[id1] ?? id1,
          item2Name: typeNames[id2] ?? id2,
          genre: genre,
          explanation: '${typeNames[id1] ?? id1}と${typeNames[id2] ?? id2}は似ていますが異なる種です',
        ));
      }
    }

    // similar_pairs が空 or 少ない場合、ランダムな異なるtypeペアで補完
    if (questions.where((q) => !q.isMatch).length < 5) {
      final typeIds = imagesByType.keys.toList()..shuffle(rng);
      for (int i = 0; i < typeIds.length && questions.where((q) => !q.isMatch).length < 10; i++) {
        for (int j = i + 1; j < typeIds.length && questions.where((q) => !q.isMatch).length < 10; j++) {
          final imgs1 = imagesByType[typeIds[i]]!;
          final imgs2 = imagesByType[typeIds[j]]!;
          questions.add(QuizQuestion(
            image1Url: imgs1[rng.nextInt(imgs1.length)],
            image2Url: imgs2[rng.nextInt(imgs2.length)],
            isMatch: false,
            item1Name: typeNames[typeIds[i]] ?? typeIds[i],
            item2Name: typeNames[typeIds[j]] ?? typeIds[j],
            genre: genre,
            explanation: '${typeNames[typeIds[i]] ?? typeIds[i]}と${typeNames[typeIds[j]] ?? typeIds[j]}',
          ));
        }
      }
    }

    questions.shuffle(rng);
    debugPrint('TestSetLoader: manifest から ${questions.length} 問を生成 '
        '(match=${questions.where((q) => q.isMatch).length}, '
        'diff=${questions.where((q) => !q.isMatch).length})');
    return questions;
  }

  /// 従来の QuizQuestion JSON 配列形式を読み込む（後方互換）
  Future<List<QuizQuestion>> _loadLegacyQuizJson(
    String dirPath,
    File jsonFile,
  ) async {
    final data = await _readJsonFile(jsonFile);

    // ファイルがそのまま配列か、もしくはルートオブジェクトかをチェック
    List<dynamic> jsonList;
    if (data is List) {
      jsonList = data;
    } else if (data is Map && data.containsKey('questions')) {
      jsonList = data['questions'] as List<dynamic>;
    } else {
      throw Exception('テストセットJSON形式が不明です: ${p.basename(jsonFile.path)}');
    }

    final questions = jsonList.map((j) => QuizQuestion.fromJson(j as Map<String, dynamic>)).toList();

    // 相対パスを絶対パスに変換
    return questions.map((q) {
      String img1 = q.image1Url;
      String img2 = q.image2Url;

      if (!File(img1).isAbsolute) {
        img1 = p.join(dirPath, img1);
      }
      if (!File(img2).isAbsolute) {
        img2 = p.join(dirPath, img2);
      }

      return QuizQuestion(
        image1Url: img1,
        image2Url: img2,
        isMatch: q.isMatch,
        item1Name: q.item1Name,
        item2Name: q.item2Name,
        genre: q.genre,
        explanation: q.explanation,
      );
    }).toList();
  }

  /// JSONファイルを堅牢に読み込む（UTF-8 BOM・Latin-1 フォールバック対応）
  Future<dynamic> _readJsonFile(File file) async {
    final bytes = await file.readAsBytes();

    // BOM (EF BB BF) をスキップ
    int offset = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      offset = 3;
    }

    String jsonString;
    try {
      jsonString = utf8.decode(bytes.sublist(offset));
    } catch (_) {
      // UTF-8 デコード失敗 → Latin-1 で読み直し
      debugPrint('UTF-8 decode failed for ${file.path}, trying latin1');
      jsonString = latin1.decode(bytes.sublist(offset));
    }

    return jsonDecode(jsonString);
  }

  /// リストから最大 [count] 個のランダムペアを選ぶ
  List<(String, String)> _pickRandomPairs(List<String> items, int count, Random rng) {
    final pairs = <(String, String)>[];
    final indices = List<int>.generate(items.length, (i) => i)..shuffle(rng);
    for (int i = 0; i + 1 < indices.length && pairs.length < count; i += 2) {
      pairs.add((items[indices[i]], items[indices[i + 1]]));
    }
    return pairs;
  }
}
