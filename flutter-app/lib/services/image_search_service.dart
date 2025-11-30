import 'dart:convert';
import 'package:http/http.dart' as http;
import 'image_scraper.dart';

/// 画像ソースの種類
enum ImageSource {
  wikimedia,    // Wikimedia Commons (汎用、著作権フリー)
  inaturalist,  // iNaturalist (動植物専用、高精度)
  dogApi,       // The Dog API (犬専用、品種別)
  catApi,       // The Cat API (猫専用、品種別)
  gbif,         // GBIF (生物多様性データ、学術用途)
  unsplash,     // Unsplash Source API (高品質写真)
  bing,         // Bing検索 (人物向け、フォールバック)
}

/// 画像検索サービス（複数ソース対応）
/// 
/// ソース別の特徴:
/// - The Dog API: 犬種別の正確な画像（APIキー不要）
/// - The Cat API: 猫種別の正確な画像（APIキー不要）
/// - iNaturalist: 専門家が確認した野生動植物の画像
/// - GBIF: 世界最大の生物多様性データベース
/// - Unsplash: 高品質な写真（風景、物体など）
/// - Wikimedia Commons: 著作権フリーの正確なラベル付き画像
/// - Bing: 人物写真向け（フォールバック）
class ImageSearchService {
  final ImageScraper _bingScraper = ImageScraper();
  final http.Client _client = http.Client();
  
  // ジャンルごとの推奨ソース
  static const Map<String, ImageSource> _genreSourceMap = {
    // 犬 → The Dog API（最も正確）
    '犬': ImageSource.dogApi,
    // 猫 → The Cat API（最も正確）
    '猫': ImageSource.catApi,
    // その他の動物系 → iNaturalist（GBIFをバックアップとして使用）
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
    // 製品・建物系 → Unsplash（高品質）またはWikimedia
    '車': ImageSource.unsplash,
    'ロゴ': ImageSource.wikimedia,
    '腕時計': ImageSource.unsplash,
    'スニーカー': ImageSource.unsplash,
    'バッグ': ImageSource.unsplash,
    '建物': ImageSource.unsplash,
  };

  // 犬種名の英語マッピング
  static const Map<String, String> _dogBreedMap = {
    'Golden Retriever': 'golden retriever',
    'Labrador Retriever': 'labrador',
    'German Shepherd': 'german shepherd',
    'Belgian Malinois': 'malinois',
    'Shiba Inu': 'shiba',
    'Akita Inu': 'akita',
    'Siberian Husky': 'husky',
    'Alaskan Malamute': 'malamute',
    'Border Collie': 'border collie',
    'Australian Shepherd': 'australian shepherd',
    'Poodle': 'poodle',
    'Bichon Frise': 'bichon frise',
    'Maltese': 'maltese',
    'Pomeranian': 'pomeranian',
    'Japanese Spitz': 'japanese spitz',
    'Corgi': 'corgi',
    'Beagle': 'beagle',
    'Dachshund': 'dachshund',
    'French Bulldog': 'french bulldog',
    'Boston Terrier': 'boston terrier',
    'Bernese Mountain Dog': 'bernese',
    'Saint Bernard': 'st. bernard',
  };

  // 猫種名の英語マッピング
  static const Map<String, String> _catBreedMap = {
    'Persian Cat': 'persian',
    'Himalayan Cat': 'himalayan',
    'Scottish Fold': 'scottish fold',
    'British Shorthair': 'british shorthair',
    'Maine Coon': 'maine coon',
    'Norwegian Forest Cat': 'norwegian forest',
    'Russian Blue': 'russian blue',
    'Chartreux': 'chartreux',
    'Siamese Cat': 'siamese',
    'Balinese Cat': 'balinese',
    'Bengal Cat': 'bengal',
    'Egyptian Mau': 'egyptian mau',
    'Ragdoll': 'ragdoll',
    'Birman': 'birman',
    'Abyssinian': 'abyssinian',
    'Somali': 'somali',
    'American Shorthair': 'american shorthair',
    'European Shorthair': 'european burmese',
  };

  /// ジャンルに基づいて最適なソースから画像を検索
  Future<List<String>> searchImages(String query, {int count = 5, String? genre}) async {
    final source = _getSourceForGenre(genre);
    
    try {
      switch (source) {
        case ImageSource.dogApi:
          final results = await _searchDogApi(query, count: count);
          if (results.isNotEmpty) return results;
          return await _searchINaturalist(query, count: count);
          
        case ImageSource.catApi:
          final results = await _searchCatApi(query, count: count);
          if (results.isNotEmpty) return results;
          return await _searchINaturalist(query, count: count);
          
        case ImageSource.wikimedia:
          final results = await _searchWikimedia(query, count: count);
          if (results.isNotEmpty) return results;
          return await _bingScraper.searchImages(query, count: count);
          
        case ImageSource.inaturalist:
          final results = await _searchINaturalist(query, count: count);
          if (results.isNotEmpty) return results;
          // iNaturalistで見つからない場合はGBIFにフォールバック
          final gbifResults = await _searchGBIF(query, count: count);
          if (gbifResults.isNotEmpty) return gbifResults;
          return await _searchWikimedia(query, count: count);
        
        case ImageSource.gbif:
          final results = await _searchGBIF(query, count: count);
          if (results.isNotEmpty) return results;
          return await _searchINaturalist(query, count: count);
        
        case ImageSource.unsplash:
          final results = await _searchUnsplash(query, count: count);
          if (results.isNotEmpty) return results;
          return await _searchWikimedia(query, count: count);
          
        case ImageSource.bing:
          return await _bingScraper.searchImages(query, count: count);
      }
    } catch (e) {
      print('ImageSearchService error: $e');
      return await _bingScraper.searchImages(query, count: count);
    }
  }

  ImageSource _getSourceForGenre(String? genre) {
    if (genre == null) return ImageSource.wikimedia;
    return _genreSourceMap[genre] ?? ImageSource.wikimedia;
  }

  /// The Dog API で犬種別の画像を検索
  /// https://thedogapi.com/ - 無料、APIキー不要
  Future<List<String>> _searchDogApi(String query, {int count = 5}) async {
    try {
      // 犬種名を英語に変換
      final breedName = _dogBreedMap[query]?.toLowerCase() ?? query.toLowerCase();
      
      // まず品種リストを取得して品種IDを探す
      final breedsUrl = Uri.parse('https://api.thedogapi.com/v1/breeds');
      final breedsResponse = await _client.get(breedsUrl).timeout(const Duration(seconds: 10));
      
      if (breedsResponse.statusCode != 200) return [];
      
      final breeds = jsonDecode(breedsResponse.body) as List;
      
      // 品種名で検索
      final matchingBreed = breeds.firstWhere(
        (breed) => (breed['name'] as String).toLowerCase().contains(breedName) ||
                   breedName.contains((breed['name'] as String).toLowerCase()),
        orElse: () => null,
      );
      
      if (matchingBreed == null) {
        print('Dog breed not found: $query ($breedName)');
        return [];
      }
      
      final breedId = matchingBreed['id'];
      
      // 品種IDで画像を取得
      final imagesUrl = Uri.parse(
        'https://api.thedogapi.com/v1/images/search'
        '?breed_ids=$breedId'
        '&limit=${count * 2}'
      );
      
      final imagesResponse = await _client.get(imagesUrl).timeout(const Duration(seconds: 10));
      
      if (imagesResponse.statusCode != 200) return [];
      
      final images = jsonDecode(imagesResponse.body) as List;
      final urls = images
          .map((img) => img['url'] as String?)
          .whereType<String>()
          .take(count)
          .toList();
      
      print('The Dog API found ${urls.length} images for: $query (breed: ${matchingBreed['name']})');
      return urls;
    } catch (e) {
      print('The Dog API error: $e');
      return [];
    }
  }

  /// The Cat API で猫種別の画像を検索
  /// https://thecatapi.com/ - 無料、APIキー不要
  Future<List<String>> _searchCatApi(String query, {int count = 5}) async {
    try {
      // 猫種名を英語に変換
      final breedName = _catBreedMap[query]?.toLowerCase() ?? query.toLowerCase();
      
      // まず品種リストを取得して品種IDを探す
      final breedsUrl = Uri.parse('https://api.thecatapi.com/v1/breeds');
      final breedsResponse = await _client.get(breedsUrl).timeout(const Duration(seconds: 10));
      
      if (breedsResponse.statusCode != 200) return [];
      
      final breeds = jsonDecode(breedsResponse.body) as List;
      
      // 品種名で検索
      final matchingBreed = breeds.firstWhere(
        (breed) => (breed['name'] as String).toLowerCase().contains(breedName) ||
                   breedName.contains((breed['name'] as String).toLowerCase()),
        orElse: () => null,
      );
      
      if (matchingBreed == null) {
        print('Cat breed not found: $query ($breedName)');
        return [];
      }
      
      final breedId = matchingBreed['id'];
      
      // 品種IDで画像を取得
      final imagesUrl = Uri.parse(
        'https://api.thecatapi.com/v1/images/search'
        '?breed_ids=$breedId'
        '&limit=${count * 2}'
      );
      
      final imagesResponse = await _client.get(imagesUrl).timeout(const Duration(seconds: 10));
      
      if (imagesResponse.statusCode != 200) return [];
      
      final images = jsonDecode(imagesResponse.body) as List;
      final urls = images
          .map((img) => img['url'] as String?)
          .whereType<String>()
          .take(count)
          .toList();
      
      print('The Cat API found ${urls.length} images for: $query (breed: ${matchingBreed['name']})');
      return urls;
    } catch (e) {
      print('The Cat API error: $e');
      return [];
    }
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
          final imgUrl = imageInfo[0]['url'] as String?;
          if (thumbUrl != null) {
            urls.add(thumbUrl);
          } else if (imgUrl != null) {
            urls.add(imgUrl);
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

      final taxonId = results[0]['id'];
      
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
          final photoUrl = photos[0]['url'] as String?;
          if (photoUrl != null) {
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

  // GBIF species keys マッピング（学名 → speciesKey）
  static const Map<String, int> _gbifSpeciesKeys = {
    // 犬種（Canis lupus familiarisの亜種として）
    'Golden Retriever': 5219173,
    'German Shepherd': 5219173,
    'Labrador Retriever': 5219173,
    // 猫種
    'Persian Cat': 2435035,
    'Siamese Cat': 2435035,
    // 熊
    'Grizzly Bear': 2433433,
    'Polar Bear': 2433451,
    'Brown Bear': 2433433,
    'Black Bear': 2433464,
    'Sun Bear': 2433481,
    'Sloth Bear': 2433491,
    // 霊長類
    'Chimpanzee': 5219533,
    'Bonobo': 5219537,
    'Gorilla': 5219521,
    'Orangutan': 5219504,
    // 鳥類
    'Bald Eagle': 2480455,
    'Golden Eagle': 2480486,
    'Peregrine Falcon': 2481047,
    'Snowy Owl': 2498247,
    'Great Horned Owl': 2498176,
    // 大型猫
    'Lion': 5219404,
    'Tiger': 5219436,
    'Leopard': 5219392,
    'Jaguar': 5219426,
    'Cheetah': 5219323,
    'Snow Leopard': 5219401,
    // 小型野生猫
    'Ocelot': 5219351,
    'Caracal': 5219327,
    'Serval': 5219362,
    'Bobcat': 2435098,
    'Lynx': 2435087,
    // 海洋哺乳類
    'Bottlenose Dolphin': 2440483,
    'Orca': 2440526,
    'Humpback Whale': 2440716,
    'Blue Whale': 2440693,
    // 蝶
    'Monarch Butterfly': 1920506,
    'Swallowtail Butterfly': 1920374,
    'Blue Morpho': 1920791,
    'Painted Lady': 1898286,
    // 魚類
    'Clownfish': 2394335,
    'Betta Fish': 2359839,
    'Goldfish': 2363100,
    'Koi': 4286942,
    // きのこ
    'Fly Agaric': 5259648,
    'Shiitake': 2542568,
    'Chanterelle': 5259393,
  };

  /// GBIF API で画像を検索
  /// https://www.gbif.org/developer/occurrence - 世界最大の生物多様性データベース
  Future<List<String>> _searchGBIF(String query, {int count = 5}) async {
    try {
      // まずspeciesKeyを取得（マッピングがあれば使用、なければ検索）
      int? speciesKey = _gbifSpeciesKeys[query];
      
      if (speciesKey == null) {
        // 種名で検索してspeciesKeyを取得
        final searchUrl = Uri.parse(
          'https://api.gbif.org/v1/species/search'
          '?q=${Uri.encodeComponent(query)}'
          '&limit=5'
        );
        
        final searchResponse = await _client.get(searchUrl).timeout(const Duration(seconds: 10));
        if (searchResponse.statusCode != 200) return [];
        
        final searchData = jsonDecode(searchResponse.body);
        final results = searchData['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          speciesKey = results[0]['key'] as int?;
        }
      }
      
      if (speciesKey == null) {
        print('GBIF species not found: $query');
        return [];
      }
      
      // speciesKeyを使って観測データ（画像付き）を取得
      final occurrenceUrl = Uri.parse(
        'https://api.gbif.org/v1/occurrence/search'
        '?taxonKey=$speciesKey'
        '&mediaType=StillImage'
        '&limit=${count * 3}'
      );
      
      final occurrenceResponse = await _client.get(occurrenceUrl).timeout(const Duration(seconds: 15));
      if (occurrenceResponse.statusCode != 200) return [];
      
      final occurrenceData = jsonDecode(occurrenceResponse.body);
      final occurrences = occurrenceData['results'] as List?;
      
      if (occurrences == null) return [];
      
      final urls = <String>[];
      for (final occurrence in occurrences) {
        final media = occurrence['media'] as List?;
        if (media != null) {
          for (final m in media) {
            final identifier = m['identifier'] as String?;
            if (identifier != null && 
                (identifier.endsWith('.jpg') || 
                 identifier.endsWith('.jpeg') || 
                 identifier.endsWith('.png') ||
                 identifier.contains('inaturalist') ||
                 identifier.contains('flickr'))) {
              urls.add(identifier);
              if (urls.length >= count) break;
            }
          }
        }
        if (urls.length >= count) break;
      }
      
      print('GBIF found ${urls.length} images for: $query (speciesKey: $speciesKey)');
      return urls;
    } catch (e) {
      print('GBIF search error: $e');
      return [];
    }
  }

  /// Unsplash Source API で画像を検索
  /// https://unsplash.com/developers - 高品質な写真
  Future<List<String>> _searchUnsplash(String query, {int count = 5}) async {
    try {
      // Unsplash Source APIはシンプルなURLベースのAPI
      // 注意: 本番環境ではAccess Keyが必要
      final urls = <String>[];
      
      // 異なるsigを使って複数の画像を取得
      for (int i = 0; i < count; i++) {
        // Unsplash Source APIの形式
        final imageUrl = 'https://source.unsplash.com/800x600/?${Uri.encodeComponent(query)}&sig=$i';
        urls.add(imageUrl);
      }
      
      print('Unsplash generated ${urls.length} image URLs for: $query');
      return urls;
    } catch (e) {
      print('Unsplash search error: $e');
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
