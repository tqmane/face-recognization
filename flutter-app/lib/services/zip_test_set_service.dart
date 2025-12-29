import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ZipTestSetException implements Exception {
  final String userMessage;
  final Object? cause;

  ZipTestSetException(this.userMessage, [this.cause]);

  @override
  String toString() => userMessage;
}

/// ZIPテストセットの情報
class ZipTestSetInfo {
  final String id;
  final String displayName;
  final String description;
  final String zipUrl;
  final String? localPath;
  final bool isDownloaded;
  final int? imageCount;
  
  const ZipTestSetInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.zipUrl,
    this.localPath,
    this.isDownloaded = false,
    this.imageCount,
  });
  
  ZipTestSetInfo copyWith({
    String? localPath,
    bool? isDownloaded,
    int? imageCount,
  }) {
    return ZipTestSetInfo(
      id: id,
      displayName: displayName,
      description: description,
      zipUrl: zipUrl,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      imageCount: imageCount ?? this.imageCount,
    );
  }
}

/// manifest.json の内容
class TestSetManifest {
  final int version;
  final String genre;
  final String displayName;
  final String description;
  final Map<String, TypeInfo> types;
  final List<SimilarPairInfo> similarPairs;
  
  TestSetManifest({
    required this.version,
    required this.genre,
    required this.displayName,
    required this.description,
    required this.types,
    required this.similarPairs,
  });
  
  factory TestSetManifest.fromJson(Map<String, dynamic> json) {
    final typesJson = json['types'] as Map<String, dynamic>? ?? {};
    final types = typesJson.map((key, value) => MapEntry(
      key,
      TypeInfo.fromJson(value as Map<String, dynamic>),
    ));
    
    final pairsJson = json['similar_pairs'] as List<dynamic>? ?? [];
    final pairs = pairsJson.map((p) => SimilarPairInfo.fromJson(p)).toList();
    
    return TestSetManifest(
      version: json['version'] as int? ?? 1,
      genre: json['genre'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      types: types,
      similarPairs: pairs,
    );
  }
}

class TypeInfo {
  final String displayName;
  final int count;
  
  TypeInfo({required this.displayName, required this.count});
  
  factory TypeInfo.fromJson(Map<String, dynamic> json) {
    return TypeInfo(
      displayName: json['display_name'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class SimilarPairInfo {
  final String id1;
  final String id2;
  
  SimilarPairInfo({required this.id1, required this.id2});
  
  factory SimilarPairInfo.fromJson(Map<String, dynamic> json) {
    return SimilarPairInfo(
      id1: json['id1'] as String? ?? '',
      id2: json['id2'] as String? ?? '',
    );
  }
}

/// クイズ用の問題データ
class ZipQuizQuestion {
  final String image1Path;
  final String image2Path;
  final String type1;
  final String type2;
  final String type1DisplayName;
  final String type2DisplayName;
  final bool isSame;
  
  ZipQuizQuestion({
    required this.image1Path,
    required this.image2Path,
    required this.type1,
    required this.type2,
    required this.type1DisplayName,
    required this.type2DisplayName,
    required this.isSame,
  });
  
  String get description {
    if (isSame) {
      return '$type1DisplayName × $type1DisplayName';
    } else {
      return '$type1DisplayName × $type2DisplayName';
    }
  }
}

/// ZIPテストセット管理サービス
class ZipTestSetService {
  static final ZipTestSetService _instance = ZipTestSetService._internal();
  factory ZipTestSetService() => _instance;
  ZipTestSetService._internal();
  
  // GitHub Raw URL のベース
  static const String _baseUrl = 'https://raw.githubusercontent.com/tqmane/face-recognization/main/sets_pics';
  
  // 利用可能なテストセット一覧
  static final List<ZipTestSetInfo> availableTestSets = [
    ZipTestSetInfo(
      id: 'dogs',
      displayName: '犬種',
      description: '柴犬・秋田犬・ハスキーなど似ている犬種',
      zipUrl: '$_baseUrl/dogs.zip',
    ),
    ZipTestSetInfo(
      id: 'small_cats',
      displayName: 'ネコ科',
      description: 'ペルシャ・スコフォ・メインクーンなど',
      zipUrl: '$_baseUrl/small_cats.zip',
    ),
    ZipTestSetInfo(
      id: 'wild_dogs',
      displayName: '犬と野生動物',
      description: 'オオカミ・キツネ・コヨーテなど',
      zipUrl: '$_baseUrl/wild_dogs.zip',
    ),
    ZipTestSetInfo(
      id: 'raccoons',
      displayName: 'アライグマ系',
      description: 'アライグマ・タヌキ・レッサーパンダなど',
      zipUrl: '$_baseUrl/raccoons.zip',
    ),
    ZipTestSetInfo(
      id: 'birds',
      displayName: '鳥類',
      description: 'カラス・ワタリガラス・鷹・鷲など',
      zipUrl: '$_baseUrl/birds.zip',
    ),
    ZipTestSetInfo(
      id: 'marine',
      displayName: '海洋動物',
      description: 'アシカ・アザラシ・イルカ・シャチなど',
      zipUrl: '$_baseUrl/marine.zip',
    ),
    ZipTestSetInfo(
      id: 'reptiles',
      displayName: '爬虫類',
      description: 'ワニ・クロコダイル・イグアナなど',
      zipUrl: '$_baseUrl/reptiles.zip',
    ),
    ZipTestSetInfo(
      id: 'bears',
      displayName: 'クマ科',
      description: 'ヒグマ・ホッキョクグマ・パンダなど',
      zipUrl: '$_baseUrl/bears.zip',
    ),
    ZipTestSetInfo(
      id: 'primates',
      displayName: '霊長類',
      description: 'チンパンジー・ゴリラ・オランウータンなど',
      zipUrl: '$_baseUrl/primates.zip',
    ),
    ZipTestSetInfo(
      id: 'insects',
      displayName: '昆虫',
      description: 'ミツバチ・スズメバチ・蝶・蛾など',
      zipUrl: '$_baseUrl/insects.zip',
    ),
  ];
  
  final Random _random = Random();
  Directory? _cacheDir;

  String _normalizeZipEntryPath(String entryName) {
    final normalized = entryName.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.startsWith('\\')) {
      throw ZipTestSetException('ZIPの内容が不正です（絶対パス）');
    }
    if (normalized.contains(':')) {
      throw ZipTestSetException('ZIPの内容が不正です（ドライブ指定）');
    }

    final parts = normalized.split('/');
    final safeParts = <String>[];
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (safeParts.isEmpty) {
          throw ZipTestSetException('ZIPの内容が不正です（パスの遡り）');
        }
        safeParts.removeLast();
        continue;
      }
      safeParts.add(part);
    }

    if (safeParts.isEmpty) {
      throw ZipTestSetException('ZIPの内容が不正です（空パス）');
    }
    return safeParts.join('/');
  }
  
  /// キャッシュディレクトリを取得
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/test_sets');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }
  
  /// ダウンロード済みテストセット一覧を取得
  Future<List<ZipTestSetInfo>> getDownloadedTestSets() async {
    final dir = await cacheDir;
    final List<ZipTestSetInfo> result = [];
    
    for (final testSet in availableTestSets) {
      final testSetDir = Directory('${dir.path}/${testSet.id}');
      final manifestFile = File('${testSetDir.path}/manifest.json');
      
      if (await manifestFile.exists()) {
        // 画像数をカウント
        int imageCount = 0;
        await for (final entity in testSetDir.list(recursive: true)) {
          if (entity is File && _isImageFile(entity.path)) {
            imageCount++;
          }
        }
        
        result.add(testSet.copyWith(
          localPath: testSetDir.path,
          isDownloaded: true,
          imageCount: imageCount,
        ));
      }
    }
    
    return result;
  }
  
  /// テストセットがダウンロード済みかチェック
  Future<bool> isDownloaded(String testSetId) async {
    final dir = await cacheDir;
    final manifestFile = File('${dir.path}/$testSetId/manifest.json');
    return await manifestFile.exists();
  }
  
  /// テストセットをダウンロード
  Future<void> downloadTestSet(
    ZipTestSetInfo testSet, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await cacheDir;
    final testSetDir = Directory('${dir.path}/${testSet.id}');

    Future<void> cleanup() async {
      if (await testSetDir.exists()) {
        await testSetDir.delete(recursive: true);
      }
    }

    try {
      // 既存のディレクトリを削除
      await cleanup();
      await testSetDir.create(recursive: true);

      // ZIPをダウンロード
      onProgress?.call(0.0);

      http.Response response;
      try {
        response = await http.get(Uri.parse(testSet.zipUrl));
      } on SocketException catch (e) {
        throw ZipTestSetException('ネットワークに接続できませんでした。接続を確認して再試行してください。', e);
      } on HttpException catch (e) {
        throw ZipTestSetException('通信に失敗しました。時間をおいて再試行してください。', e);
      } catch (e) {
        throw ZipTestSetException('ダウンロードに失敗しました。時間をおいて再試行してください。', e);
      }

      if (response.statusCode != 200) {
        throw ZipTestSetException('ダウンロードに失敗しました（${response.statusCode}）。時間をおいて再試行してください。');
      }

      onProgress?.call(0.5);

      // ZIPを解凍
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      if (archive.files.isEmpty) {
        throw ZipTestSetException('ダウンロードしたデータが空でした。時間をおいて再試行してください。');
      }

      final totalFiles = archive.files.length;
      int extractedFiles = 0;

      for (final file in archive.files) {
        final safeRelativePath = _normalizeZipEntryPath(file.name);
        final outPath = '${testSetDir.path}/$safeRelativePath';

        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory(outPath).create(recursive: true);
        }

        extractedFiles++;
        onProgress?.call(0.5 + 0.5 * extractedFiles / totalFiles);
      }

      final manifestFile = File('${testSetDir.path}/manifest.json');
      if (!await manifestFile.exists()) {
        throw ZipTestSetException('テストセットの形式が不正です（manifest.json が見つかりません）。');
      }

      onProgress?.call(1.0);
    } catch (e) {
      await cleanup();
      if (e is ZipTestSetException) rethrow;
      throw ZipTestSetException('ダウンロード処理に失敗しました。時間をおいて再試行してください。', e);
    }
  }
  
  /// テストセットを削除
  Future<void> deleteTestSet(String testSetId) async {
    final dir = await cacheDir;
    final testSetDir = Directory('${dir.path}/$testSetId');
    if (await testSetDir.exists()) {
      await testSetDir.delete(recursive: true);
    }
  }
  
  /// manifest.json を読み込み
  Future<TestSetManifest?> loadManifest(String testSetId) async {
    final dir = await cacheDir;
    final manifestFile = File('${dir.path}/$testSetId/manifest.json');
    
    if (!await manifestFile.exists()) return null;
    
    final content = await manifestFile.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return TestSetManifest.fromJson(json);
  }
  
  /// クイズ問題を生成
  Future<List<ZipQuizQuestion>> generateQuestions(
    String testSetId,
    int count,
  ) async {
    final dir = await cacheDir;
    final testSetDir = Directory('${dir.path}/$testSetId');
    final manifest = await loadManifest(testSetId);
    
    if (manifest == null) {
      throw ZipTestSetException('テストセットが見つかりません。ダウンロードし直してください。');
    }
    
    // 各タイプの画像パスを収集
    final Map<String, List<String>> imagesByType = {};
    
    for (final typeId in manifest.types.keys) {
      final typeDir = Directory('${testSetDir.path}/$typeId');
      if (await typeDir.exists()) {
        final images = <String>[];
        await for (final entity in typeDir.list()) {
          if (entity is File && _isImageFile(entity.path)) {
            images.add(entity.path);
          }
        }
        if (images.isNotEmpty) {
          imagesByType[typeId] = images;
        }
      }
    }
    
    if (imagesByType.isEmpty) {
      throw ZipTestSetException('画像が見つかりません。ダウンロードし直してください。');
    }

    final typeIds = imagesByType.keys.toList();

    List<String> pickTwoDistinct(List<String> images) {
      if (images.length < 2) {
        throw ZipTestSetException('同じ種類の問題を作る画像が不足しています。');
      }
      final idx1 = _random.nextInt(images.length);
      var idx2 = _random.nextInt(images.length);
      while (idx2 == idx1) {
        idx2 = _random.nextInt(images.length);
      }
      return [images[idx1], images[idx2]];
    }

    // 問題を生成
    final questions = <ZipQuizQuestion>[];

    final sameTarget = count ~/ 2;
    final typesWithMultipleImages = typeIds.where((t) => (imagesByType[t]?.length ?? 0) >= 2).toList();

    if (typeIds.length == 1) {
      final onlyType = typeIds.single;
      final images = imagesByType[onlyType]!;
      if (images.length < 2) {
        throw ZipTestSetException('テストセットの画像が不足しています。ダウンロードし直してください。');
      }
      for (int i = 0; i < count; i++) {
        final pair = pickTwoDistinct(images);
        questions.add(ZipQuizQuestion(
          image1Path: pair[0],
          image2Path: pair[1],
          type1: onlyType,
          type2: onlyType,
          type1DisplayName: manifest.types[onlyType]?.displayName ?? onlyType,
          type2DisplayName: manifest.types[onlyType]?.displayName ?? onlyType,
          isSame: true,
        ));
      }
      return questions;
    }

    // 同じタイプの問題（可能な範囲で）
    if (typesWithMultipleImages.isNotEmpty) {
      int attempts = 0;
      while (questions.where((q) => q.isSame).length < sameTarget && attempts < sameTarget * 20) {
        attempts++;
        final typeId = typesWithMultipleImages[_random.nextInt(typesWithMultipleImages.length)];
        final images = imagesByType[typeId]!;
        final pair = pickTwoDistinct(images);
        questions.add(ZipQuizQuestion(
          image1Path: pair[0],
          image2Path: pair[1],
          type1: typeId,
          type2: typeId,
          type1DisplayName: manifest.types[typeId]?.displayName ?? typeId,
          type2DisplayName: manifest.types[typeId]?.displayName ?? typeId,
          isSame: true,
        ));
      }
    }
    
    // 違うタイプの問題（similar_pairsを優先）
    final usedPairs = <String>{};
    
    // similar_pairsから優先的に出題
    final shuffledPairs = List.of(manifest.similarPairs)..shuffle(_random);
    for (final pair in shuffledPairs) {
      if (questions.length >= count) break;
      
      final pairKey = '${pair.id1}-${pair.id2}';
      if (usedPairs.contains(pairKey)) continue;
      
      final images1 = imagesByType[pair.id1];
      final images2 = imagesByType[pair.id2];
      if (images1 == null || images2 == null) continue;
      
      usedPairs.add(pairKey);
      questions.add(ZipQuizQuestion(
        image1Path: images1[_random.nextInt(images1.length)],
        image2Path: images2[_random.nextInt(images2.length)],
        type1: pair.id1,
        type2: pair.id2,
        type1DisplayName: manifest.types[pair.id1]?.displayName ?? pair.id1,
        type2DisplayName: manifest.types[pair.id2]?.displayName ?? pair.id2,
        isSame: false,
      ));
    }
    
    // まだ足りない場合はランダムなペアを追加
    int randomAttempts = 0;
    while (questions.length < count && randomAttempts < count * 50) {
      randomAttempts++;
      final type1 = typeIds[_random.nextInt(typeIds.length)];
      var type2 = typeIds[_random.nextInt(typeIds.length)];
      while (type2 == type1) {
        type2 = typeIds[_random.nextInt(typeIds.length)];
      }

      final images1 = imagesByType[type1];
      final images2 = imagesByType[type2];
      if (images1 == null || images1.isEmpty || images2 == null || images2.isEmpty) continue;

      questions.add(ZipQuizQuestion(
        image1Path: images1[_random.nextInt(images1.length)],
        image2Path: images2[_random.nextInt(images2.length)],
        type1: type1,
        type2: type2,
        type1DisplayName: manifest.types[type1]?.displayName ?? type1,
        type2DisplayName: manifest.types[type2]?.displayName ?? type2,
        isSame: false,
      ));
    }
    
    // シャッフル
    questions.shuffle(_random);
    
    if (questions.length < count) {
      throw ZipTestSetException('問題を${count}問分作れませんでした（${questions.length}問）。問題数を減らすか、テストセットをダウンロードし直してください。');
    }
    return questions.take(count).toList();
  }
  
  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || 
           lower.endsWith('.jpeg') || 
           lower.endsWith('.png') ||
           lower.endsWith('.webp');
  }
}
