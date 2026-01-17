import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/quiz_question.dart';

class TestSetLoader {
  
  /// ZIPファイルを解凍して問題リストを読み込む
  Future<List<QuizQuestion>> loadFromZip(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final destDir = Directory(p.join(tempDir.path, 'extracted_test_set_${DateTime.now().millisecondsSinceEpoch}'));
    
    // Unzip
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    extractArchiveToDisk(archive, destDir.path);
    
    return _loadFromDirectory(destDir.path);
  }

  /// ディレクトリから問題リストを読み込む
  Future<List<QuizQuestion>> loadFromDirectory(String dirPath) async {
    return _loadFromDirectory(dirPath);
  }

  Future<List<QuizQuestion>> _loadFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $dirPath');
    }

    // Find JSON file
    File? jsonFile;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        jsonFile = entity;
        break;
      }
    }

    if (jsonFile == null) {
      throw Exception('No JSON file found in the test set.');
    }

    final jsonString = await jsonFile.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonString);
    
    final questions = jsonList.map((j) => QuizQuestion.fromJson(j)).toList();

    // Fix image paths to be absolute
    return questions.map((q) {
      // Assuming image URLs in JSON are relative filenames like "cat1.jpg"
      // or local paths. We make them absolute paths in the extracted dir.
      
      // If URLs are actually web URLs, we can't do offline benchmark easily.
      // But assuming "Test Set" implies downloaded content.
      
      String img1 = q.image1Url;
      String img2 = q.image2Url;

      // Handle cases where path might already be full or relative
      if (!File(img1).isAbsolute) {
        img1 = p.join(dirPath, p.basename(img1));
      }
      if (!File(img2).isAbsolute) {
        img2 = p.join(dirPath, p.basename(img2));
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
}
