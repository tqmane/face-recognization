import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'settings_service.dart';

/// 画像スクレイピングサービス
class ImageScraper {
  static const int _targetHeight = 450;
  static const int _maxWidth = 550;
  
  // タイムアウトは設定から取得
  Duration get _timeout => Duration(seconds: SettingsService.instance.downloadTimeout);
  Duration get _imageTimeout => Duration(seconds: SettingsService.instance.downloadTimeout + 5);

  // 除外キーワード（最小限に縮小）
  static const List<String> _excludeKeywords = [
    'AI generated', 'イラスト', 'illustration', 'drawing',
    'anime', 'アニメ', 'manga', '漫画',
  ];

  // 除外ドメイン（イラスト系のみ）
  static const List<String> _excludeDomains = [
    'deviantart.com', 'pixiv.net', 'artstation.com',
  ];
  
  // ランダムオフセットの範囲（多様性向上）
  static const List<int> _randomOffsets = [1, 35, 70, 105, 140];

  final Random _random = Random();
  
  // HTTPクライアント（接続の再利用）
  final http.Client _client = http.Client();

  /// 使用済みURL（このクイズセッション全体で重複を防ぐ）
  final Set<String> _usedUrls = {};
  
  /// 現在の問題で選択中のURL（並列ダウンロード時の重複防止）
  final Set<String> _currentQuestionUrls = {};
  
  /// 画像キャッシュ
  final Map<String, Uint8List> _imageCache = {};
  
  /// キャッシュサイズを設定から取得
  int get _maxCacheSize => SettingsService.instance.cacheSize;

  /// 使用済みURLをクリア
  void clearUsedUrls() {
    _usedUrls.clear();
    _currentQuestionUrls.clear();
  }
  
  /// キャッシュをクリア
  void clearCache() {
    _imageCache.clear();
  }
  
  /// リソースを解放
  void dispose() {
    _client.close();
    _imageCache.clear();
  }

  /// 画像URLを検索（公開API）
  Future<List<String>> searchImages(String query, {int count = 5}) async {
    return await _fetchImageUrls(query, count: count);
  }

  /// Bingから画像URLを取得（未使用のもののみ）
  Future<List<String>> _fetchImageUrls(String query, {int count = 10}) async {
    try {
      // ランダムなオフセットで多様な結果を取得
      final randomOffset = _randomOffsets[_random.nextInt(_randomOffsets.length)];
      // 写真フィルタのみ使用（除外キーワードはドメインチェックで対応）
      final searchUrl = Uri.parse(
        'https://www.bing.com/images/search?q=${Uri.encodeComponent(query)}&form=HDRSC2&first=$randomOffset&count=100&qft=+filterui:photo-photo',
      );

      print('Searching: $searchUrl');

      final response = await _client.get(
        searchUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Upgrade-Insecure-Requests': '1',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        print('Bing search failed: ${response.statusCode}');
        return [];
      }

      print('Response length: ${response.body.length}');

      final document = html_parser.parse(response.body);
      final urls = <String>[];

      // 方法1: murl属性から画像URLを抽出（a.iusc）
      var elements = document.querySelectorAll('a.iusc');
      print('Found a.iusc elements: ${elements.length}');
      
      // 方法2: 代替セレクタを試す
      if (elements.isEmpty) {
        elements = document.querySelectorAll('a[m*="murl"]');
        print('Found a[m*=murl] elements: ${elements.length}');
      }
      
      // 方法3: さらに代替
      if (elements.isEmpty) {
        elements = document.querySelectorAll('.mimg');
        print('Found .mimg elements: ${elements.length}');
      }

      for (final element in elements) {
        final m = element.attributes['m'];
        if (m != null && m.contains('murl')) {
          final match = RegExp(r'"murl":"([^"]+)"').firstMatch(m);
          if (match != null) {
            final url = match.group(1)!.replaceAll(r'\/', '/');
            if (_isValidImageUrl(url)) {
              urls.add(url);
              if (urls.length >= count) break;
            }
          }
        }
      }
      
      // 方法4: HTML全体からmurlを正規表現で抽出（フォールバック）
      if (urls.isEmpty) {
        print('Trying regex fallback...');
        final murlMatches = RegExp(r'"murl":"(https?://[^"]+)"').allMatches(response.body);
        for (final match in murlMatches) {
          final url = match.group(1)!.replaceAll(r'\/', '/');
          if (_isValidImageUrl(url)) {
            urls.add(url);
            if (urls.length >= count) break;
          }
        }
        print('Regex found ${urls.length} URLs');
      }

      print('Total URLs found: ${urls.length}');
      return urls;
    } catch (e) {
      print('Error fetching image URLs: $e');
      return [];
    }
  }
  
  /// URLが有効な画像URLかチェック
  bool _isValidImageUrl(String url) {
    // 除外ドメインをチェック
    final isExcludedDomain = _excludeDomains.any(
      (domain) => url.toLowerCase().contains(domain)
    );
    // 使用済みURLと現在選択中のURLを除外
    // 拡張子チェックを緩和（URLにクエリパラメータが含まれる場合も対応）
    final lowerUrl = url.toLowerCase();
    final isImageUrl = lowerUrl.contains('.jpg') || 
                       lowerUrl.contains('.jpeg') || 
                       lowerUrl.contains('.png') || 
                       lowerUrl.contains('.webp') ||
                       lowerUrl.contains('.gif') ||
                       lowerUrl.contains('.bmp') ||
                       lowerUrl.contains('.tiff') ||
                       lowerUrl.contains('image') ||
                       lowerUrl.contains('photo');
    return !_usedUrls.contains(url) && 
           !_currentQuestionUrls.contains(url) &&
           !isExcludedDomain &&
           isImageUrl;
  }

  /// 画像をダウンロード（成功したら使用済みに追加）
  Future<Uint8List?> _downloadImage(String url) async {
    // 既に使用済みならスキップ
    if (_usedUrls.contains(url)) {
      return null;
    }
    
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
          'Connection': 'keep-alive',
          'Referer': 'https://www.bing.com/',
        },
      ).timeout(_imageTimeout);

      if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
        _usedUrls.add(url);
        // キャッシュサイズを制限
        if (_imageCache.length < _maxCacheSize) {
          _imageCache[url] = response.bodyBytes;
        }
        return response.bodyBytes;
      } else {
        print('Download failed: status=${response.statusCode}, size=${response.bodyBytes.length}');
      }
    } catch (e) {
      print('Download error: $e');
    }
    return null;
  }

  /// クエリから画像を取得（img.Imageオブジェクトとして返す）
  Future<img.Image?> _fetchImageAsObject(String query) async {
    final urls = await _fetchImageUrls(query, count: 10);
    
    for (final url in urls) {
      final data = await _downloadImage(url);
      if (data != null) {
        return _processImageAsObject(data);
      }
    }
    
    return null;
  }

  /// 画像をリサイズ・処理（img.Imageオブジェクトとして返す）
  img.Image? _processImageAsObject(Uint8List data) {
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

      return img.copyResize(image, width: newWidth, height: newHeight);
    } catch (e) {
      return null;
    }
  }

  /// 画像をリサイズ・処理（後方互換性のため）
  Uint8List? _processImage(Uint8List data) {
    final image = _processImageAsObject(data);
    if (image == null) return null;
    return Uint8List.fromList(img.encodePng(image));
  }

  /// 同じ画像を2枚並べた比較画像を作成
  /// 注意: 同じ種類の2つの異なる画像を並べる（全く同じ画像ではない）
  Future<Uint8List?> createSameImage(String query) async {
    // 現在の問題用のURL追跡をクリア
    _currentQuestionUrls.clear();
    
    // より多くのURLを取得して選択肢を増やす
    final urls = await _fetchImageUrls(query, count: 20);
    
    // 使用済みURLを除外
    final availableUrls = urls.where((url) => !_usedUrls.contains(url)).toList();
    if (availableUrls.length < 2) return null;
    
    // シャッフルして異なる2つを選ぶ
    final shuffled = availableUrls.toList()..shuffle();
    
    // 2つのURLセットを明確に分離（重複防止）
    final firstSet = shuffled.take(shuffled.length ~/ 2).toList();
    final secondSet = shuffled.skip(shuffled.length ~/ 2).toList();
    
    if (firstSet.isEmpty || secondSet.isEmpty) return null;
    
    img.Image? image1;
    img.Image? image2;
    String? url1;
    
    // 最初の画像を取得
    for (final url in firstSet) {
      if (_usedUrls.contains(url)) continue;
      _currentQuestionUrls.add(url);
      final data = await _downloadImage(url);
      if (data != null) {
        final processed = _processImageAsObject(data);
        if (processed != null) {
          image1 = processed;
          url1 = url;
          break;
        }
      }
    }
    
    if (image1 == null) return null;
    
    // 2番目の画像を取得（別のセットから）
    for (final url in secondSet) {
      if (_usedUrls.contains(url) || url == url1) continue;
      _currentQuestionUrls.add(url);
      final data = await _downloadImage(url);
      if (data != null) {
        final processed = _processImageAsObject(data);
        if (processed != null) {
          image2 = processed;
          break;
        }
      }
    }

    if (image1 == null || image2 == null) return null;
    return _createComparisonFromImages(image1, image2);
  }

  /// 異なる2つの画像を並べた比較画像を作成
  Future<Uint8List?> createComparisonImage(String query1, String query2) async {
    final image1 = await _fetchImageAsObject(query1);
    final image2 = await _fetchImageAsObject(query2);

    if (image1 == null || image2 == null) return null;

    return _createComparisonFromImages(image1, image2);
  }

  /// 2つのimg.Imageオブジェクトから比較画像を作成（最適化版）
  Uint8List? _createComparisonFromImages(img.Image img1, img.Image img2) {
    try {
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
