import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'quiz_manager.dart';
import 'image_scraper.dart';

/// テストセット情報
class TestSetInfo {
  final String id;
  final String genreName;
  final int questionCount;
  final DateTime createdAt;
  final String dirPath;

  TestSetInfo({
    required this.id,
    required this.genreName,
    required this.questionCount,
    required this.createdAt,
    required this.dirPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'genreName': genreName,
    'questionCount': questionCount,
    'createdAt': createdAt.toIso8601String(),
    'dirPath': dirPath,
  };

  factory TestSetInfo.fromJson(Map<String, dynamic> json) => TestSetInfo(
    id: json['id'],
    genreName: json['genreName'],
    questionCount: json['questionCount'],
    createdAt: DateTime.parse(json['createdAt']),
    dirPath: json['dirPath'],
  );
}

/// 保存された問題
class SavedQuestion {
  final int index;
  final bool isSame;
  final String description;
  final String imagePath;

  SavedQuestion({
    required this.index,
    required this.isSame,
    required this.description,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'isSame': isSame,
    'description': description,
    'imagePath': imagePath,
  };

  factory SavedQuestion.fromJson(Map<String, dynamic> json) => SavedQuestion(
    index: json['index'],
    isSame: json['isSame'],
    description: json['description'],
    imagePath: json['imagePath'],
  );
}

/// テストセット管理
class TestSetManager {
  static const String _testSetDir = 'test_sets';
  static const String _metadataFile = 'metadata.json';
  static const String _questionsFile = 'questions.json';

  final QuizManager _quizManager = QuizManager();
  final ImageScraper _scraper = ImageScraper();

  /// テストセットの保存先ディレクトリを取得
  Future<Directory> _getTestSetsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_testSetDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 利用可能なテストセット一覧を取得
  Future<List<TestSetInfo>> getAvailableTestSets() async {
    final baseDir = await _getTestSetsDir();
    final List<TestSetInfo> testSets = [];

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final metadataFile = File('${entity.path}/$_metadataFile');
        if (await metadataFile.exists()) {
          try {
            final content = await metadataFile.readAsString();
            final json = jsonDecode(content);
            testSets.add(TestSetInfo.fromJson(json));
          } catch (e) {
            // 無視
          }
        }
      }
    }

    testSets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return testSets;
  }

  /// テストセットを作成
  Future<int> createTestSet({
    required Genre genre,
    required int totalQuestions,
    required Function(int current, int total) onProgress,
  }) async {
    _scraper.clearUsedUrls();

    final baseDir = await _getTestSetsDir();
    final timestamp = DateTime.now();
    final setId = '${genre.name}_${timestamp.millisecondsSinceEpoch}';
    final setDir = Directory('${baseDir.path}/$setId');
    await setDir.create();

    final configs = List.generate(
      totalQuestions * 3,
      (_) => _quizManager.generateQuestion(genre),
    );

    int successCount = 0;
    int configIndex = 0;
    final savedQuestions = <SavedQuestion>[];

    while (successCount < totalQuestions && configIndex < configs.length) {
      final config = configs[configIndex];
      configIndex++;

      try {
        final imageData = config.isSame
            ? await _scraper.createSameImage(config.query1)
            : await _scraper.createComparisonImage(config.query1, config.query2);

        if (imageData != null) {
          final imagePath = 'question_$successCount.png';
          final imageFile = File('${setDir.path}/$imagePath');
          await imageFile.writeAsBytes(imageData);

          savedQuestions.add(SavedQuestion(
            index: successCount,
            isSame: config.isSame,
            description: config.description,
            imagePath: imagePath,
          ));

          successCount++;
          onProgress(successCount, totalQuestions);
        }
      } catch (e) {
        // 無視
      }
    }

    if (successCount > 0) {
      // メタデータ保存
      final metadata = TestSetInfo(
        id: setId,
        genreName: genre.displayName,
        questionCount: successCount,
        createdAt: timestamp,
        dirPath: setDir.path,
      );

      final metadataFile = File('${setDir.path}/$_metadataFile');
      await metadataFile.writeAsString(jsonEncode(metadata.toJson()));

      // 問題データ保存
      final questionsFile = File('${setDir.path}/$_questionsFile');
      await questionsFile.writeAsString(
        jsonEncode(savedQuestions.map((q) => q.toJson()).toList()),
      );
    } else {
      // 失敗時はディレクトリ削除
      await setDir.delete(recursive: true);
    }

    return successCount;
  }

  /// テストセットから問題を読み込み
  Future<List<SavedQuestion>> loadTestSet(TestSetInfo testSet) async {
    final questionsFile = File('${testSet.dirPath}/$_questionsFile');
    if (!await questionsFile.exists()) return [];

    try {
      final content = await questionsFile.readAsString();
      final List<dynamic> json = jsonDecode(content);
      return json.map((q) => SavedQuestion.fromJson(q)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 問題の画像を読み込み
  Future<Uint8List?> loadQuestionImage(TestSetInfo testSet, SavedQuestion question) async {
    final imageFile = File('${testSet.dirPath}/${question.imagePath}');
    if (await imageFile.exists()) {
      return await imageFile.readAsBytes();
    }
    return null;
  }

  /// テストセットを削除
  Future<bool> deleteTestSet(TestSetInfo testSet) async {
    try {
      final dir = Directory(testSet.dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
