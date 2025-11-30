import 'dart:convert';
import 'package:http/http.dart' as http;
import 'image_scraper.dart';

/// 画像ソースの種類
enum ImageSource {
  wikimedia,    // Wikimedia Commons (汎用、著作権フリー)
  inaturalist,  // iNaturalist (動植物専用、高精度)
  bing,         // Bing検索 (人物向け、フォールバック)
}

/// 画像検索サービス（複数ソース対応）
class ImageSearchService {
  final ImageScraper _bingScraper = ImageScraper();
  final http.Client _client = http.Client();
  
  // ジャンルごとの推奨ソース
  static const Map<String, ImageSource> _genreSourceMap = {
    // 動物系 → iNaturalist
    '犬': ImageSource.inaturalist,
    '猫': ImageSource.inaturalist,
    '小型野生猫': ImageSource.inaturalist,
    '鳥': ImageSource.inaturalist,
    '熊': ImageSource.inaturalist,
    '霊長類': ImageSource.inaturalist,
    '魚': ImageSource.inaturalist,
    '蝶': ImageSource.inaturalist,
    'きのこ': ImageSource.inaturalist,
    '昆虫': ImageSource.inaturalist,
    // 人物系 → Bing
    '有名人・双子・そっくりさん': ImageSource.bing,
    // その他 → Wikimedia
    '車': ImageSource.wikimedia,
    'ロゴ': ImageSource.wikimedia,
    '腕時計': ImageSource.wikimedia,
    'スニーカー': ImageSource.wikimedia,
    'バッグ': ImageSource.wikimedia,
    '建物': ImageSource.wikimedia,
  };

  /// ジャンルに基づいて最適なソースから画像を検索
  Future<List<String>> searchImages(String query, {int count = 5, String? genre}) async {
    final source = _getSourceForGenre(genre);
    
    try {
      switch (source) {
        case ImageSource.wikimedia:
          final results = await _searchWikimedia(query, count: count);
          if (results.isNotEmpty) return results;
          // フォールバック
          return await _bingScraper.searchImages(query, count: count);
          
        case ImageSource.inaturalist:
          final results = await _searchINaturalist(query, count: count);
          if (results.isNotEmpty) return results;
          // フォールバック
          return await _searchWikimedia(query, count: count);
          
        case ImageSource.bing:
          return await _bingScraper.searchImages(query, count: count);
      }
    } catch (e) {
      print('ImageSearchService error: $e');
      // 最終フォールバック
      return await _bingScraper.searchImages(query, count: count);
    }
  }

  ImageSource _getSourceForGenre(String? genre) {
    if (genre == null) return ImageSource.wikimedia;
    return _genreSourceMap[genre] ?? ImageSource.wikimedia;
  }

  /// Wikimedia Commons API で画像を検索
  Future<List<String>> _searchWikimedia(String query, {int count = 5}) async {
    try {
      final url = Uri.parse(
        'https://commons.wikimedia.org/w/api.php'
        '?action=query'
        '&generator=search'
        '&gsrnamespace=6'
        '&gsrsearch=$query'
        '&gsrlimit=${count * 2}'
        '&prop=imageinfo'
        '&iiprop=url'
        '&iiurlwidth=800'
        '&format=json'
        '&origin=*'
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      
      if (pages == null) return [];

      final urls = <String>[];
      for (final page in pages.values) {
        final imageInfo = page['imageinfo'] as List?;
        if (imageInfo != null && imageInfo.isNotEmpty) {
          final thumbUrl = imageInfo[0]['thumburl'] as String?;
          final url = imageInfo[0]['url'] as String?;
          if (thumbUrl != null) {
            urls.add(thumbUrl);
          } else if (url != null) {
            urls.add(url);
          }
        }
        if (urls.length >= count) break;
      }

      print('Wikimedia found ${urls.length} images for: $query');
      return urls;
    } catch (e) {
      print('Wikimedia search error: $e');
      return [];
    }
  }

  /// iNaturalist API で画像を検索（動植物に特化）
  Future<List<String>> _searchINaturalist(String query, {int count = 5}) async {
    try {
      // まず種名で検索
      final taxaUrl = Uri.parse(
        'https://api.inaturalist.org/v1/taxa'
        '?q=${Uri.encodeComponent(query)}'
        '&per_page=5'
        '&locale=ja'
      );

      final taxaResponse = await _client.get(taxaUrl).timeout(const Duration(seconds: 10));
      
      if (taxaResponse.statusCode != 200) return [];

      final taxaData = jsonDecode(taxaResponse.body);
      final results = taxaData['results'] as List?;
      
      if (results == null || results.isEmpty) return [];

      // 最も関連性の高い種のIDを取得
      final taxonId = results[0]['id'];
      
      // その種の観察写真を取得
      final obsUrl = Uri.parse(
        'https://api.inaturalist.org/v1/observations'
        '?taxon_id=$taxonId'
        '&photos=true'
        '&quality_grade=research'
        '&per_page=${count * 2}'
        '&order=desc'
        '&order_by=votes'
      );

      final obsResponse = await _client.get(obsUrl).timeout(const Duration(seconds: 10));
      
      if (obsResponse.statusCode != 200) return [];

      final obsData = jsonDecode(obsResponse.body);
      final observations = obsData['results'] as List?;
      
      if (observations == null) return [];

      final urls = <String>[];
      for (final obs in observations) {
        final photos = obs['photos'] as List?;
        if (photos != null && photos.isNotEmpty) {
          // medium サイズの画像URL（500px）
          final photoUrl = photos[0]['url'] as String?;
          if (photoUrl != null) {
            // square を medium に変更
            urls.add(photoUrl.replaceAll('square', 'medium'));
          }
        }
        if (urls.length >= count) break;
      }

      print('iNaturalist found ${urls.length} images for: $query (taxon: $taxonId)');
      return urls;
    } catch (e) {
      print('iNaturalist search error: $e');
      return [];
    }
  }

  /// 使用済みURLをクリア
  void clearUsedUrls() {
    _bingScraper.clearUsedUrls();
  }

  /// リソースを解放
  void dispose() {
    _bingScraper.dispose();
    _client.close();
  }
}
