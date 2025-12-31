import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const String _baseUrl =
    'https://raw.githubusercontent.com/tqmane/face-recognization/main/sets_pics';

/// flutter-app / android-app が参照するのと同じテストセット一覧。
const Map<String, String> availableSetZips = {
  'dogs': '$_baseUrl/dogs.zip',
  'small_cats': '$_baseUrl/small_cats.zip',
  'wild_dogs': '$_baseUrl/wild_dogs.zip',
  'raccoons': '$_baseUrl/raccoons.zip',
  'birds': '$_baseUrl/birds.zip',
  'marine': '$_baseUrl/marine.zip',
  'reptiles': '$_baseUrl/reptiles.zip',
  'bears': '$_baseUrl/bears.zip',
  'primates': '$_baseUrl/primates.zip',
  'insects': '$_baseUrl/insects.zip',
};

/// 同じセットを何度もダウンロードしないよう、一時キャッシュに保存。
Future<String> downloadTestSetZip(String setId) async {
  final url = availableSetZips[setId];
  if (url == null) {
    throw ArgumentError('Unknown set-id: $setId');
  }

  final cacheDir =
      Directory(p.join(Directory.systemTemp.path, 'engine_test_sets'));
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }
  final zipPath = p.join(cacheDir.path, '$setId.zip');
  final zipFile = File(zipPath);

  if (zipFile.existsSync()) {
    return zipFile.path;
  }

  final response = await http.get(Uri.parse(url));
  if (response.statusCode >= 400) {
    throw Exception('Failed to download $setId from $url '
        '(${response.statusCode})');
  }
  await zipFile.writeAsBytes(response.bodyBytes);
  return zipFile.path;
}
