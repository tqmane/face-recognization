import 'image_scraper.dart';

/// 画像検索サービス（ImageScraperのラッパー）
class ImageSearchService {
  final ImageScraper _scraper = ImageScraper();

  /// 画像を検索してURLリストを取得
  Future<List<String>> searchImages(String query, {int count = 5}) async {
    try {
      return await _scraper.searchImages(query, count: count);
    } catch (e) {
      print('ImageSearchService error: $e');
      return [];
    }
  }

  /// 使用済みURLをクリア
  void clearUsedUrls() {
    _scraper.clearUsedUrls();
  }

  /// リソースを解放
  void dispose() {
    _scraper.dispose();
  }
}
