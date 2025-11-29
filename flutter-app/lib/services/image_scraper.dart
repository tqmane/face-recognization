import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;

/// 画像スクレイピングサービス
class ImageScraper {
  static const int _targetHeight = 450;
  static const int _maxWidth = 550;
  static const Duration _timeout = Duration(seconds: 5);

  final Set<String> _usedUrls = {};

  /// 使用済みURLをクリア
  void clearUsedUrls() {
    _usedUrls.clear();
  }

  /// Bingから画像URLを取得
  Future<List<String>> _fetchImageUrls(String query, {int count = 10}) async {
    try {
      final searchUrl = Uri.parse(
        'https://www.bing.com/images/search?q=${Uri.encodeComponent(query)}&form=HDRSC2&first=1',
      );

      final response = await http.get(
        searchUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final urls = <String>[];

      // murl属性から画像URLを抽出
      final elements = document.querySelectorAll('a.iusc');
      for (final element in elements) {
        final m = element.attributes['m'];
        if (m != null && m.contains('murl')) {
          final match = RegExp(r'"murl":"([^"]+)"').firstMatch(m);
          if (match != null) {
            final url = match.group(1)!.replaceAll(r'\/', '/');
            if (!_usedUrls.contains(url) && 
                (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png'))) {
              urls.add(url);
              if (urls.length >= count) break;
            }
          }
        }
      }

      return urls;
    } catch (e) {
      return [];
    }
  }

  /// 画像をダウンロード
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
        _usedUrls.add(url);
        return response.bodyBytes;
      }
    } catch (e) {
      // 無視
    }
    return null;
  }

  /// クエリから画像を取得
  Future<Uint8List?> _fetchImage(String query) async {
    final urls = await _fetchImageUrls(query, count: 5);
    
    for (final url in urls) {
      final data = await _downloadImage(url);
      if (data != null) {
        return _processImage(data);
      }
    }
    
    return null;
  }

  /// 画像をリサイズ・処理
  Uint8List? _processImage(Uint8List data) {
    try {
      final image = img.decodeImage(data);
      if (image == null) return null;

      // リサイズ
      final ratio = _targetHeight / image.height;
      int newWidth = (image.width * ratio).round();
      int newHeight = _targetHeight;

      if (newWidth > _maxWidth) {
        newWidth = _maxWidth;
        newHeight = (image.height * (_maxWidth / image.width)).round();
      }

      final resized = img.copyResize(image, width: newWidth, height: newHeight);
      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      return null;
    }
  }

  /// 同じ画像を2枚並べた比較画像を作成
  Future<Uint8List?> createSameImage(String query) async {
    final imageData = await _fetchImage(query);
    if (imageData == null) return null;

    return _createComparisonFromData(imageData, imageData);
  }

  /// 異なる2つの画像を並べた比較画像を作成
  Future<Uint8List?> createComparisonImage(String query1, String query2) async {
    final image1 = await _fetchImage(query1);
    final image2 = await _fetchImage(query2);

    if (image1 == null || image2 == null) return null;

    return _createComparisonFromData(image1, image2);
  }

  /// 2つの画像データから比較画像を作成
  Uint8List? _createComparisonFromData(Uint8List data1, Uint8List data2) {
    try {
      final img1 = img.decodeImage(data1);
      final img2 = img.decodeImage(data2);

      if (img1 == null || img2 == null) return null;

      const gap = 20;
      final totalWidth = img1.width + img2.width + gap;
      final maxHeight = img1.height > img2.height ? img1.height : img2.height;

      // 新しいキャンバスを作成
      final result = img.Image(width: totalWidth, height: maxHeight);
      
      // 背景を白で塗りつぶし
      img.fill(result, color: img.ColorRgb8(255, 255, 255));

      // 左側に画像1を配置
      final y1 = (maxHeight - img1.height) ~/ 2;
      img.compositeImage(result, img1, dstX: 0, dstY: y1);

      // 右側に画像2を配置
      final y2 = (maxHeight - img2.height) ~/ 2;
      img.compositeImage(result, img2, dstX: img1.width + gap, dstY: y2);

      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      return null;
    }
  }
}
