import 'dart:math';
import '../models/quiz_question.dart';
import 'image_search_service.dart';

enum Genre {
  all('すべて', 'ランダムな問題'),
  cars('車', '似ている車種を判別'),
  logos('ロゴ', '似ているロゴを判別'),
  celebrities('有名人・双子・そっくりさん', '双子やそっくりさんを判別'),
  dogs('犬', '似ている犬種を判別'),
  cats('猫', '似ている猫種を判別'),
  smallCats('小型野生猫', '似ている野生猫を判別'),
  birds('鳥', '似ている鳥を判別'),
  bears('熊', '似ている熊を判別'),
  primates('霊長類', '似ている霊長類を判別'),
  fish('魚', '似ている魚を判別'),
  butterflies('蝶', '似ている蝶を判別'),
  mushrooms('きのこ', '似ているきのこを判別'),
  insects('昆虫', '似ている昆虫を判別'),
  watches('腕時計', '似ている腕時計を判別'),
  sneakers('スニーカー', '似ているスニーカーを判別'),
  bags('バッグ', '似ているバッグを判別'),
  buildings('建物', '似ている建物を判別');

  final String displayName;
  final String description;

  const Genre(this.displayName, this.description);
}

class SimilarPair {
  final String item1;
  final String item2;
  
  const SimilarPair(this.item1, this.item2);
}

/// 問題の設定（画像ダウンロード前）
class QuestionConfig {
  final bool isSame;
  final String query1;
  final String query2;
  final String description;
  final String genre;
  
  const QuestionConfig({
    required this.isSame,
    required this.query1,
    required this.query2,
    required this.description,
    required this.genre,
  });
}

class QuizManager {
  static final QuizManager _instance = QuizManager._internal();
  factory QuizManager() => _instance;
  QuizManager._internal();

  final _random = Random();
  final ImageSearchService _imageService = ImageSearchService();
  
  // Genre display names
  static const Map<Genre, String> genreNames = {
    Genre.cars: '車',
    Genre.logos: 'ロゴ',
    Genre.celebrities: '有名人・双子・そっくりさん',
    Genre.dogs: '犬',
    Genre.cats: '猫',
    Genre.smallCats: '小型野生猫',
    Genre.birds: '鳥',
    Genre.bears: '熊',
    Genre.primates: '霊長類',
    Genre.fish: '魚',
    Genre.butterflies: '蝶',
    Genre.mushrooms: 'きのこ',
    Genre.insects: '昆虫',
    Genre.watches: '腕時計',
    Genre.sneakers: 'スニーカー',
    Genre.bags: 'バッグ',
    Genre.buildings: '建物',
  };
  
  // All items for each genre - massively expanded
  static const Map<Genre, List<String>> _items = {
    Genre.cars: [
      'Toyota Camry', 'Honda Accord', 'Toyota Corolla', 'Honda Civic',
      'BMW 3 Series', 'Mercedes C-Class', 'Audi A4', 'Lexus IS',
      'Porsche 911', 'Chevrolet Corvette', 'Nissan GT-R',
      'Ford Mustang', 'Chevrolet Camaro', 'Dodge Challenger',
      'Nissan Z', 'Toyota Supra', 'Mazda MX-5',
      'Range Rover', 'Porsche Cayenne', 'BMW X5',
      'Lamborghini Huracan', 'Ferrari 488', 'McLaren 720S',
    ],
    Genre.logos: [
      'Apple', 'Samsung', 'Pepsi', 'Coca-Cola',
      'Nike', 'Adidas', 'Puma', 'Reebok',
      'McDonald\'s', 'Burger King', 'Wendy\'s', 'KFC',
      'Starbucks', 'Dunkin',
      'Gucci', 'Chanel', 'Louis Vuitton', 'Prada',
      'LG', 'Renault', 'Bentley', 'Aston Martin',
      'Target', 'Pinterest', 'Spotify', 'Beats',
    ],
    Genre.celebrities: [
      // Famous identical twins
      'Mary-Kate Olsen', 'Ashley Olsen',
      'Dylan Sprouse', 'Cole Sprouse',
      'Tia Mowry', 'Tamera Mowry',
      'Bella Hadid', 'Gigi Hadid',
      // Japanese twins
      'Manakanana Mana', 'Manakanana Kana',
      'Takahashi sisters Miriya', 'Takahashi sisters Hikaru',
      // Celebrity lookalikes
      'Keira Knightley', 'Natalie Portman',
      'Zooey Deschanel', 'Katy Perry',
      'Jessica Chastain', 'Bryce Dallas Howard',
      'Amy Adams', 'Isla Fisher',
      'Margot Robbie', 'Jaime Pressly',
      'Javier Bardem', 'Jeffrey Dean Morgan',
      'Matt Damon', 'Mark Wahlberg',
      'Mila Kunis', 'Sarah Hyland',
      'Selena Gomez', 'Lucy Hale',
      'Will Ferrell', 'Chad Smith',
      'Daniel Radcliffe', 'Elijah Wood',
      'Logan Lerman', 'young Tom Cruise',
      'Henry Cavill', 'Matt Bomer',
      'Leighton Meester', 'Minka Kelly',
      'Nina Dobrev', 'Victoria Justice',
      // Japanese celebrity lookalikes
      'Aragaki Yui', 'Fukuda Saki',
      'Satomi Ishihara', 'Arimura Kasumi',
      'Yamada Takayuki', 'Oguri Shun',
    ],
    Genre.dogs: [
      'Golden Retriever', 'Labrador Retriever',
      'German Shepherd', 'Belgian Malinois',
      'Shiba Inu', 'Akita Inu',
      'Siberian Husky', 'Alaskan Malamute',
      'Border Collie', 'Australian Shepherd',
      'Poodle', 'Bichon Frise', 'Maltese',
      'Pomeranian', 'Japanese Spitz',
      'Corgi', 'Beagle', 'Dachshund',
      'French Bulldog', 'Boston Terrier',
      'Bernese Mountain Dog', 'Saint Bernard',
    ],
    Genre.cats: [
      'Persian Cat', 'Himalayan Cat',
      'Scottish Fold', 'British Shorthair',
      'Maine Coon', 'Norwegian Forest Cat',
      'Russian Blue', 'Chartreux',
      'Siamese Cat', 'Balinese Cat',
      'Bengal Cat', 'Egyptian Mau',
      'Ragdoll', 'Birman',
      'Abyssinian', 'Somali',
      'American Shorthair', 'European Shorthair',
    ],
    Genre.smallCats: [
      'Ocelot', 'Margay', 'Oncilla',
      'Serval', 'Caracal', 'African Golden Cat',
      'Lynx', 'Bobcat',
      'Sand Cat', 'Pallas Cat', 'Black-footed Cat',
      'Leopard Cat', 'Fishing Cat', 'Rusty-spotted Cat',
      'Jaguarundi', 'Jungle Cat',
    ],
    Genre.birds: [
      'Cardinal', 'Scarlet Tanager',
      'Blue Jay', 'Bluebird',
      'Bald Eagle', 'Golden Eagle',
      'Peregrine Falcon', 'Gyrfalcon',
      'Great Horned Owl', 'Snowy Owl', 'Barn Owl',
      'Flamingo', 'Roseate Spoonbill',
      'Hummingbird', 'Sunbird',
      'Peacock', 'Pheasant',
      'Crow', 'Raven', 'Rook',
      'Sparrow', 'Finch', 'Wren',
      'Penguin Emperor', 'Penguin King', 'Penguin Adelie',
    ],
    Genre.bears: [
      'Brown Bear', 'Grizzly Bear', 'Kodiak Bear',
      'Black Bear', 'Asian Black Bear',
      'Polar Bear', 'Spirit Bear',
      'Sun Bear', 'Sloth Bear',
      'Spectacled Bear', 'Giant Panda', 'Red Panda',
    ],
    Genre.primates: [
      'Chimpanzee', 'Bonobo',
      'Gorilla Mountain', 'Gorilla Lowland',
      'Orangutan Bornean', 'Orangutan Sumatran',
      'Gibbon', 'Siamang',
      'Mandrill', 'Baboon',
      'Capuchin', 'Spider Monkey', 'Howler Monkey',
      'Japanese Macaque', 'Rhesus Macaque',
      'Lemur Ring-tailed', 'Lemur Red Ruffed',
    ],
    Genre.fish: [
      'Betta Fish', 'Guppy', 'Molly', 'Platy',
      'Neon Tetra', 'Cardinal Tetra',
      'Goldfish', 'Koi',
      'Clownfish', 'Damselfish',
      'Angelfish Freshwater', 'Angelfish Marine',
      'Discus', 'Oscar',
      'Blue Tang', 'Yellow Tang',
      'Mandarin Fish', 'Lionfish',
      'Tuna', 'Mackerel', 'Salmon', 'Trout',
    ],
    Genre.butterflies: [
      'Monarch Butterfly', 'Viceroy Butterfly',
      'Swallowtail Tiger', 'Swallowtail Zebra', 'Swallowtail Spicebush',
      'Blue Morpho', 'Blue Clipper',
      'Painted Lady', 'Red Admiral',
      'Peacock Butterfly', 'Buckeye Butterfly',
      'Glasswing Butterfly', 'Clearwing Moth',
      'Atlas Moth', 'Luna Moth', 'Polyphemus Moth',
    ],
    Genre.mushrooms: [
      'Button Mushroom', 'Cremini Mushroom', 'Portobello Mushroom',
      'Shiitake', 'Maitake', 'Enoki',
      'Oyster Mushroom', 'King Trumpet Mushroom',
      'Chanterelle', 'False Chanterelle',
      'Morel', 'False Morel',
      'Fly Agaric', 'Panther Cap',
      'Puffball Giant', 'Puffball Common',
      'Lion\'s Mane', 'Bear\'s Head Tooth',
    ],
    Genre.insects: [
      'Ladybug', 'Asian Lady Beetle',
      'Honeybee', 'Bumblebee', 'Carpenter Bee',
      'Yellowjacket', 'Paper Wasp', 'Hornet',
      'Dragonfly', 'Damselfly',
      'Grasshopper', 'Cricket', 'Katydid',
      'Praying Mantis', 'Stick Insect',
      'Rhinoceros Beetle', 'Stag Beetle', 'Hercules Beetle',
      'Firefly', 'Click Beetle',
      'Cicada', 'Leafhopper',
    ],
    Genre.watches: [
      'Rolex Submariner', 'Omega Seamaster', 'Tudor Black Bay',
      'Rolex Daytona', 'Omega Speedmaster', 'TAG Heuer Carrera',
      'Patek Philippe Nautilus', 'Audemars Piguet Royal Oak', 'Vacheron Constantin Overseas',
      'Casio G-Shock', 'Citizen Eco-Drive', 'Seiko Prospex',
      'Apple Watch', 'Samsung Galaxy Watch', 'Garmin Fenix',
    ],
    Genre.sneakers: [
      'Nike Air Jordan 1', 'Nike Dunk Low', 'Nike Air Force 1',
      'Adidas Stan Smith', 'Adidas Superstar', 'Adidas Gazelle',
      'New Balance 574', 'New Balance 990', 'New Balance 550',
      'Converse Chuck Taylor', 'Vans Old Skool', 'Vans Sk8-Hi',
      'Nike Air Max 90', 'Nike Air Max 1', 'Adidas Ultraboost',
      'Reebok Classic', 'Puma Suede', 'Asics Gel-Lyte',
    ],
    Genre.bags: [
      'Louis Vuitton Speedy', 'Louis Vuitton Neverfull', 'Louis Vuitton Keepall',
      'Chanel Classic Flap', 'Chanel Boy Bag', 'Chanel 2.55',
      'Hermes Birkin', 'Hermes Kelly', 'Hermes Constance',
      'Gucci GG Marmont', 'Gucci Dionysus', 'Gucci Jackie',
      'Prada Galleria', 'Prada Re-Edition', 'Dior Lady Dior',
      'Celine Luggage', 'Celine Triomphe', 'Bottega Veneta Pouch',
    ],
    Genre.buildings: [
      'Empire State Building', 'Chrysler Building',
      'Eiffel Tower', 'Tokyo Tower', 'CN Tower',
      'Big Ben', 'Elizabeth Tower',
      'Colosseum Rome', 'Colosseum Macau',
      'White House', 'Capitol Building',
      'Sydney Opera House', 'Walt Disney Concert Hall',
      'Burj Khalifa', 'Shanghai Tower', 'Taipei 101',
      'Sagrada Familia', 'Notre Dame Paris', 'Cologne Cathedral',
    ],
  };

  // Similar pairs that are challenging to distinguish (includes twins, same person contexts, and lookalikes)
  static const List<SimilarPair> _similarPairs = [
    // Cars
    SimilarPair('Toyota Camry', 'Honda Accord'),
    SimilarPair('Toyota Corolla', 'Honda Civic'),
    SimilarPair('BMW 3 Series', 'Mercedes C-Class'),
    SimilarPair('Audi A4', 'Lexus IS'),
    SimilarPair('Ford Mustang', 'Chevrolet Camaro'),
    SimilarPair('Nissan Z', 'Toyota Supra'),
    SimilarPair('Porsche Cayenne', 'Range Rover'),
    SimilarPair('Lamborghini Huracan', 'Ferrari 488'),
    
    // Logos
    SimilarPair('Pepsi', 'Coca-Cola'),
    SimilarPair('Nike', 'Adidas'),
    SimilarPair('McDonald\'s', 'Burger King'),
    SimilarPair('Starbucks', 'Dunkin'),
    SimilarPair('Gucci', 'Chanel'),
    SimilarPair('LG', 'Renault'),
    SimilarPair('Target', 'Pinterest'),
    SimilarPair('Spotify', 'Beats'),
    
    // Celebrities - Identical Twins (different people)
    SimilarPair('Mary-Kate Olsen', 'Ashley Olsen'),
    SimilarPair('Dylan Sprouse', 'Cole Sprouse'),
    SimilarPair('Tia Mowry', 'Tamera Mowry'),
    SimilarPair('Bella Hadid', 'Gigi Hadid'),
    SimilarPair('Manakanana Mana', 'Manakanana Kana'),
    
    // Celebrities - Lookalikes (different people)
    SimilarPair('Keira Knightley', 'Natalie Portman'),
    SimilarPair('Zooey Deschanel', 'Katy Perry'),
    SimilarPair('Jessica Chastain', 'Bryce Dallas Howard'),
    SimilarPair('Amy Adams', 'Isla Fisher'),
    SimilarPair('Margot Robbie', 'Jaime Pressly'),
    SimilarPair('Javier Bardem', 'Jeffrey Dean Morgan'),
    SimilarPair('Matt Damon', 'Mark Wahlberg'),
    SimilarPair('Mila Kunis', 'Sarah Hyland'),
    SimilarPair('Selena Gomez', 'Lucy Hale'),
    SimilarPair('Will Ferrell', 'Chad Smith'),
    SimilarPair('Daniel Radcliffe', 'Elijah Wood'),
    SimilarPair('Henry Cavill', 'Matt Bomer'),
    SimilarPair('Leighton Meester', 'Minka Kelly'),
    SimilarPair('Nina Dobrev', 'Victoria Justice'),
    SimilarPair('Aragaki Yui', 'Fukuda Saki'),
    SimilarPair('Satomi Ishihara', 'Arimura Kasumi'),
    
    // Dogs
    SimilarPair('Golden Retriever', 'Labrador Retriever'),
    SimilarPair('German Shepherd', 'Belgian Malinois'),
    SimilarPair('Shiba Inu', 'Akita Inu'),
    SimilarPair('Siberian Husky', 'Alaskan Malamute'),
    SimilarPair('Border Collie', 'Australian Shepherd'),
    SimilarPair('Poodle', 'Bichon Frise'),
    SimilarPair('Pomeranian', 'Japanese Spitz'),
    SimilarPair('French Bulldog', 'Boston Terrier'),
    
    // Cats
    SimilarPair('Persian Cat', 'Himalayan Cat'),
    SimilarPair('Scottish Fold', 'British Shorthair'),
    SimilarPair('Maine Coon', 'Norwegian Forest Cat'),
    SimilarPair('Russian Blue', 'Chartreux'),
    SimilarPair('Siamese Cat', 'Balinese Cat'),
    SimilarPair('Ragdoll', 'Birman'),
    SimilarPair('Abyssinian', 'Somali'),
    
    // Small Cats
    SimilarPair('Ocelot', 'Margay'),
    SimilarPair('Serval', 'Caracal'),
    SimilarPair('Lynx', 'Bobcat'),
    SimilarPair('Sand Cat', 'Pallas Cat'),
    SimilarPair('Leopard Cat', 'Fishing Cat'),
    
    // Birds
    SimilarPair('Cardinal', 'Scarlet Tanager'),
    SimilarPair('Bald Eagle', 'Golden Eagle'),
    SimilarPair('Peregrine Falcon', 'Gyrfalcon'),
    SimilarPair('Great Horned Owl', 'Snowy Owl'),
    SimilarPair('Flamingo', 'Roseate Spoonbill'),
    SimilarPair('Crow', 'Raven'),
    SimilarPair('Penguin Emperor', 'Penguin King'),
    
    // Bears
    SimilarPair('Brown Bear', 'Grizzly Bear'),
    SimilarPair('Black Bear', 'Asian Black Bear'),
    SimilarPair('Sun Bear', 'Sloth Bear'),
    SimilarPair('Giant Panda', 'Red Panda'),
    
    // Primates
    SimilarPair('Chimpanzee', 'Bonobo'),
    SimilarPair('Gorilla Mountain', 'Gorilla Lowland'),
    SimilarPair('Orangutan Bornean', 'Orangutan Sumatran'),
    SimilarPair('Gibbon', 'Siamang'),
    SimilarPair('Mandrill', 'Baboon'),
    SimilarPair('Japanese Macaque', 'Rhesus Macaque'),
    
    // Fish
    SimilarPair('Neon Tetra', 'Cardinal Tetra'),
    SimilarPair('Goldfish', 'Koi'),
    SimilarPair('Clownfish', 'Damselfish'),
    SimilarPair('Blue Tang', 'Yellow Tang'),
    SimilarPair('Tuna', 'Mackerel'),
    SimilarPair('Salmon', 'Trout'),
    
    // Butterflies
    SimilarPair('Monarch Butterfly', 'Viceroy Butterfly'),
    SimilarPair('Swallowtail Tiger', 'Swallowtail Zebra'),
    SimilarPair('Blue Morpho', 'Blue Clipper'),
    SimilarPair('Painted Lady', 'Red Admiral'),
    SimilarPair('Atlas Moth', 'Luna Moth'),
    
    // Mushrooms
    SimilarPair('Button Mushroom', 'Cremini Mushroom'),
    SimilarPair('Chanterelle', 'False Chanterelle'),
    SimilarPair('Morel', 'False Morel'),
    SimilarPair('Fly Agaric', 'Panther Cap'),
    SimilarPair('Lion\'s Mane', 'Bear\'s Head Tooth'),
    
    // Insects
    SimilarPair('Ladybug', 'Asian Lady Beetle'),
    SimilarPair('Honeybee', 'Bumblebee'),
    SimilarPair('Yellowjacket', 'Paper Wasp'),
    SimilarPair('Dragonfly', 'Damselfly'),
    SimilarPair('Grasshopper', 'Cricket'),
    SimilarPair('Rhinoceros Beetle', 'Stag Beetle'),
    
    // Watches
    SimilarPair('Rolex Submariner', 'Omega Seamaster'),
    SimilarPair('Rolex Daytona', 'Omega Speedmaster'),
    SimilarPair('Patek Philippe Nautilus', 'Audemars Piguet Royal Oak'),
    SimilarPair('Casio G-Shock', 'Seiko Prospex'),
    
    // Sneakers
    SimilarPair('Nike Air Jordan 1', 'Nike Dunk Low'),
    SimilarPair('Adidas Stan Smith', 'Adidas Superstar'),
    SimilarPair('New Balance 574', 'New Balance 990'),
    SimilarPair('Converse Chuck Taylor', 'Vans Old Skool'),
    SimilarPair('Nike Air Max 90', 'Nike Air Max 1'),
    
    // Bags
    SimilarPair('Louis Vuitton Speedy', 'Louis Vuitton Neverfull'),
    SimilarPair('Chanel Classic Flap', 'Chanel 2.55'),
    SimilarPair('Hermes Birkin', 'Hermes Kelly'),
    SimilarPair('Gucci GG Marmont', 'Gucci Dionysus'),
    
    // Buildings
    SimilarPair('Empire State Building', 'Chrysler Building'),
    SimilarPair('Eiffel Tower', 'Tokyo Tower'),
    SimilarPair('Big Ben', 'Elizabeth Tower'),
    SimilarPair('Burj Khalifa', 'Shanghai Tower'),
    SimilarPair('Sydney Opera House', 'Walt Disney Concert Hall'),
  ];

  // Track used questions to avoid duplicates within a quiz
  final Set<String> _usedQuestions = {};
  
  // Reset for a new quiz
  void resetQuiz() {
    _usedQuestions.clear();
  }
  
  // Get genre display name
  String getGenreName(Genre genre) {
    return genre.displayName;
  }

  /// 問題設定を同期的に生成（画像ダウンロード前の設定）
  QuestionConfig generateQuestion({Genre? genre}) {
    // allの場合またはnullの場合はランダムなジャンルを選択
    final selectedGenre = (genre == null || genre == Genre.all)
        ? _getRandomGenre()
        : genre;
    
    final genreItems = _items[selectedGenre]!;
    final genrePairs = _getGenrePairs(selectedGenre);
    
    final isSame = _random.nextBool();
    
    if (isSame) {
      // 同じアイテムの異なる画像
      final item = genreItems[_random.nextInt(genreItems.length)];
      return QuestionConfig(
        isSame: true,
        query1: item,
        query2: item,
        description: '$item（同じ）',
        genre: selectedGenre.displayName,
      );
    } else {
      // 似ているが異なるアイテム
      if (genrePairs.isNotEmpty) {
        final pair = genrePairs[_random.nextInt(genrePairs.length)];
        return QuestionConfig(
          isSame: false,
          query1: pair.item1,
          query2: pair.item2,
          description: '${pair.item1} vs ${pair.item2}',
          genre: selectedGenre.displayName,
        );
      } else {
        // ペアがない場合はランダムに2つ選択
        final items = genreItems.toList()..shuffle();
        return QuestionConfig(
          isSame: false,
          query1: items[0],
          query2: items[1],
          description: '${items[0]} vs ${items[1]}',
          genre: selectedGenre.displayName,
        );
      }
    }
  }
  
  // Generate celebrity question (same person vs twins/lookalikes)
  Future<QuizQuestion?> _generateCelebrityQuestion() async {
    final isSamePerson = _random.nextBool();
    
    if (isSamePerson) {
      // Same person, different photos
      final items = _items[Genre.celebrities]!;
      String person;
      String questionKey;
      
      do {
        person = items[_random.nextInt(items.length)];
        questionKey = 'celeb_same_$person';
      } while (_usedQuestions.contains(questionKey) && _usedQuestions.length < items.length);
      
      if (_usedQuestions.contains(questionKey)) return null;
      _usedQuestions.add(questionKey);
      
      // Get two different images of the same person
      final images = await _imageService.searchImages('$person portrait photo', count: 10);
      if (images.length < 2) return null;
      
      // Shuffle and pick two different images
      images.shuffle();
      
      return QuizQuestion(
        image1Url: images[0],
        image2Url: images[1],
        isMatch: true, // Same person = match
        item1Name: person,
        item2Name: person,
        genre: getGenreName(Genre.celebrities),
        explanation: 'どちらも$personの写真です（同一人物の異なる写真）',
      );
    } else {
      // Twins or lookalikes (different people)
      final celebrityPairs = _similarPairs.where((pair) {
        final items = _items[Genre.celebrities]!;
        return items.contains(pair.item1) && items.contains(pair.item2);
      }).toList();
      
      if (celebrityPairs.isEmpty) return null;
      
      SimilarPair pair;
      String questionKey;
      
      do {
        pair = celebrityPairs[_random.nextInt(celebrityPairs.length)];
        questionKey = 'celeb_diff_${pair.item1}_${pair.item2}';
      } while (_usedQuestions.contains(questionKey) && _usedQuestions.length < celebrityPairs.length);
      
      if (_usedQuestions.contains(questionKey)) return null;
      _usedQuestions.add(questionKey);
      
      final image1 = await _imageService.searchImages('${pair.item1} portrait photo', count: 5);
      final image2 = await _imageService.searchImages('${pair.item2} portrait photo', count: 5);
      
      if (image1.isEmpty || image2.isEmpty) return null;
      
      return QuizQuestion(
        image1Url: image1[_random.nextInt(image1.length)],
        image2Url: image2[_random.nextInt(image2.length)],
        isMatch: false, // Different people = no match
        item1Name: pair.item1,
        item2Name: pair.item2,
        genre: getGenreName(Genre.celebrities),
        explanation: '左は${pair.item1}、右は${pair.item2}です（双子/そっくりさんで別人です）',
      );
    }
  }
  
  // Generate question for other genres
  Future<QuizQuestion?> _generateGenreQuestion(Genre? genre) async {
    // Select a random genre if not specified
    final selectedGenre = genre ?? _getRandomGenre();
    final genreItems = _items[selectedGenre]!;
    final genrePairs = _getGenrePairs(selectedGenre);
    
    // Decide if this will be a "same" or "different" question
    final isSame = _random.nextBool();
    
    if (isSame) {
      // Same item, different images
      String item;
      String questionKey;
      
      do {
        item = genreItems[_random.nextInt(genreItems.length)];
        questionKey = '${selectedGenre}_same_$item';
      } while (_usedQuestions.contains(questionKey) && _usedQuestions.length < genreItems.length);
      
      if (_usedQuestions.contains(questionKey)) return null;
      _usedQuestions.add(questionKey);
      
      final images = await _imageService.searchImages(item, count: 10);
      if (images.length < 2) return null;
      
      images.shuffle();
      
      return QuizQuestion(
        image1Url: images[0],
        image2Url: images[1],
        isMatch: true,
        item1Name: item,
        item2Name: item,
        genre: getGenreName(selectedGenre),
        explanation: 'どちらも$itemです',
      );
    } else {
      // Different but similar items
      if (genrePairs.isEmpty) {
        // No similar pairs defined, use random different items
        final items = genreItems.toList()..shuffle();
        if (items.length < 2) return null;
        
        final item1 = items[0];
        final item2 = items[1];
        final questionKey = '${selectedGenre}_diff_${item1}_$item2';
        
        if (_usedQuestions.contains(questionKey)) return null;
        _usedQuestions.add(questionKey);
        
        final image1 = await _imageService.searchImages(item1, count: 3);
        final image2 = await _imageService.searchImages(item2, count: 3);
        
        if (image1.isEmpty || image2.isEmpty) return null;
        
        return QuizQuestion(
          image1Url: image1[_random.nextInt(image1.length)],
          image2Url: image2[_random.nextInt(image2.length)],
          isMatch: false,
          item1Name: item1,
          item2Name: item2,
          genre: getGenreName(selectedGenre),
          explanation: '左は$item1、右は$item2です',
        );
      }
      
      // Use a similar pair
      SimilarPair pair;
      String questionKey;
      
      do {
        pair = genrePairs[_random.nextInt(genrePairs.length)];
        questionKey = '${selectedGenre}_pair_${pair.item1}_${pair.item2}';
      } while (_usedQuestions.contains(questionKey) && _usedQuestions.length < genrePairs.length);
      
      if (_usedQuestions.contains(questionKey)) return null;
      _usedQuestions.add(questionKey);
      
      final image1 = await _imageService.searchImages(pair.item1, count: 3);
      final image2 = await _imageService.searchImages(pair.item2, count: 3);
      
      if (image1.isEmpty || image2.isEmpty) return null;
      
      return QuizQuestion(
        image1Url: image1[_random.nextInt(image1.length)],
        image2Url: image2[_random.nextInt(image2.length)],
        isMatch: false,
        item1Name: pair.item1,
        item2Name: pair.item2,
        genre: getGenreName(selectedGenre),
        explanation: '左は${pair.item1}、右は${pair.item2}です',
      );
    }
  }
  
  Genre _getRandomGenre() {
    // allを除外した実際のジャンルからランダムに選択
    final genres = Genre.values.where((g) => g != Genre.all).toList();
    return genres[_random.nextInt(genres.length)];
  }
  
  List<SimilarPair> _getGenrePairs(Genre genre) {
    final genreItems = _items[genre];
    if (genreItems == null) return [];
    return _similarPairs.where((pair) {
      return genreItems.contains(pair.item1) && genreItems.contains(pair.item2);
    }).toList();
  }
  
  // Get available genres
  List<Genre> getAvailableGenres() {
    return Genre.values.toList();
  }
  
  // Get items for a genre
  List<String> getGenreItems(Genre genre) {
    return _items[genre] ?? [];
  }
}
