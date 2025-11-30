package com.tqmane.similarityquiz

/**
 * オンラインクイズ用の問題管理
 * ジャンル選択対応
 */
class OnlineQuizManager {

    val scraper = ImageScraper()

    // ジャンル定義
    enum class Genre(val displayName: String, val description: String) {
        ALL("すべて", "全ジャンルからランダム"),
        BIG_CATS("ネコ科大型", "チーター・ヒョウ・ジャガー・ライオン・トラ"),
        DOGS("犬種", "柴犬・秋田犬・ハスキー・マラミュート"),
        WILD_DOGS("犬と野生", "犬とオオカミ"),
        RACCOONS("アライグマ系", "アライグマ・タヌキ"),
        BIRDS("鳥類", "カラス・ワタリガラス"),
        MARINE("海洋動物", "アシカ・アザラシ"),
        REPTILES("爬虫類", "ワニ・クロコダイル"),
        SIMILAR_PEOPLE("似ている人", "似ている一般人・芸能人"),
        CARS("車", "似ている車種"),
        LOGOS("ロゴ", "似ているブランドロゴ")
    }

    data class AnimalPair(
        val id: String,
        val nameJa: String,
        val query: String
    )

    data class SimilarPair(
        val id1: String,
        val id2: String,
        val genre: Genre
    )

    // すべてのアイテム
    private val items = mapOf(
        // ネコ科
        "cheetah" to AnimalPair("cheetah", "チーター", "cheetah face"),
        "leopard" to AnimalPair("leopard", "ヒョウ", "leopard face"),
        "jaguar" to AnimalPair("jaguar", "ジャガー", "jaguar animal face"),
        "lion" to AnimalPair("lion", "ライオン", "lion face"),
        "tiger" to AnimalPair("tiger", "トラ", "tiger face"),
        
        // 犬種
        "shiba" to AnimalPair("shiba", "柴犬", "shiba inu dog"),
        "akita" to AnimalPair("akita", "秋田犬", "akita dog"),
        "husky" to AnimalPair("husky", "ハスキー", "husky dog"),
        "malamute" to AnimalPair("malamute", "マラミュート", "malamute dog"),
        "wolf" to AnimalPair("wolf", "オオカミ", "wolf animal"),
        
        // アライグマ系
        "raccoon" to AnimalPair("raccoon", "アライグマ", "raccoon animal"),
        "tanuki" to AnimalPair("tanuki", "タヌキ", "tanuki raccoon dog"),
        
        // 鳥
        "crow" to AnimalPair("crow", "カラス", "crow bird"),
        "raven" to AnimalPair("raven", "ワタリガラス", "raven bird"),
        
        // 海洋
        "sea_lion" to AnimalPair("sea_lion", "アシカ", "sea lion"),
        "seal" to AnimalPair("seal", "アザラシ", "seal animal"),
        
        // 爬虫類
        "alligator" to AnimalPair("alligator", "ワニ", "alligator"),
        "crocodile" to AnimalPair("crocodile", "クロコダイル", "crocodile"),
        
        // 似ている有名人・双子（同じ人の別写真 vs そっくりさん/双子を見分ける）
        // 双子ペア
        "mary_kate_olsen" to AnimalPair("mary_kate_olsen", "メアリー・ケイト・オルセン", "Mary-Kate Olsen face"),
        "ashley_olsen" to AnimalPair("ashley_olsen", "アシュリー・オルセン", "Ashley Olsen face"),
        "dylan_sprouse" to AnimalPair("dylan_sprouse", "ディラン・スプラウス", "Dylan Sprouse face"),
        "cole_sprouse" to AnimalPair("cole_sprouse", "コール・スプラウス", "Cole Sprouse face"),
        "tia_mowry" to AnimalPair("tia_mowry", "ティア・モウリー", "Tia Mowry face"),
        "tamera_mowry" to AnimalPair("tamera_mowry", "タメラ・モウリー", "Tamera Mowry face"),
        
        // そっくりさんペア（別人だけど似ている）
        "katy_perry" to AnimalPair("katy_perry", "ケイティ・ペリー", "Katy Perry face"),
        "zooey_deschanel" to AnimalPair("zooey_deschanel", "ズーイー・デシャネル", "Zooey Deschanel face"),
        "natalie_portman" to AnimalPair("natalie_portman", "ナタリー・ポートマン", "Natalie Portman face"),
        "keira_knightley" to AnimalPair("keira_knightley", "キーラ・ナイトレイ", "Keira Knightley face"),
        "margot_robbie" to AnimalPair("margot_robbie", "マーゴット・ロビー", "Margot Robbie face"),
        "jaime_pressly" to AnimalPair("jaime_pressly", "ジェイミー・プレスリー", "Jaime Pressly face"),
        "javier_bardem" to AnimalPair("javier_bardem", "ハビエル・バルデム", "Javier Bardem face"),
        "jeffrey_dean_morgan" to AnimalPair("jeffrey_dean_morgan", "ジェフリー・ディーン・モーガン", "Jeffrey Dean Morgan face"),
        "matt_damon" to AnimalPair("matt_damon", "マット・デイモン", "Matt Damon face"),
        "mark_wahlberg" to AnimalPair("mark_wahlberg", "マーク・ウォールバーグ", "Mark Wahlberg face"),
        
        // 車
        "gt86" to AnimalPair("gt86", "トヨタ86", "toyota 86 car"),
        "brz" to AnimalPair("brz", "スバルBRZ", "subaru brz car"),
        "miata" to AnimalPair("miata", "マツダロードスター", "mazda miata mx5"),
        "s2000" to AnimalPair("s2000", "ホンダS2000", "honda s2000"),
        "rx7" to AnimalPair("rx7", "マツダRX-7", "mazda rx7"),
        "supra" to AnimalPair("supra", "トヨタスープラ", "toyota supra a80"),
        
        // ロゴ
        "pepsi" to AnimalPair("pepsi", "ペプシ", "pepsi logo"),
        "korean_air" to AnimalPair("korean_air", "大韓航空", "korean air logo"),
        "carrefour" to AnimalPair("carrefour", "カルフール", "carrefour logo"),
        "chanel" to AnimalPair("chanel", "シャネル", "chanel logo"),
    )

    // 似ているペア（ジャンル付き）
    private val similarPairs = listOf(
        // ネコ科
        SimilarPair("cheetah", "leopard", Genre.BIG_CATS),
        SimilarPair("jaguar", "leopard", Genre.BIG_CATS),
        SimilarPair("lion", "tiger", Genre.BIG_CATS),
        
        // 犬種
        SimilarPair("shiba", "akita", Genre.DOGS),
        SimilarPair("husky", "malamute", Genre.DOGS),
        
        // 犬と野生
        SimilarPair("wolf", "husky", Genre.WILD_DOGS),
        SimilarPair("wolf", "malamute", Genre.WILD_DOGS),
        
        // アライグマ系
        SimilarPair("raccoon", "tanuki", Genre.RACCOONS),
        
        // 鳥
        SimilarPair("crow", "raven", Genre.BIRDS),
        
        // 海洋
        SimilarPair("sea_lion", "seal", Genre.MARINE),
        
        // 爬虫類
        SimilarPair("alligator", "crocodile", Genre.REPTILES),
        
        // 似ている人（双子・そっくりさん）- これらは「違う」が正解
        // 双子
        SimilarPair("mary_kate_olsen", "ashley_olsen", Genre.SIMILAR_PEOPLE),
        SimilarPair("dylan_sprouse", "cole_sprouse", Genre.SIMILAR_PEOPLE),
        SimilarPair("tia_mowry", "tamera_mowry", Genre.SIMILAR_PEOPLE),
        // そっくりさん
        SimilarPair("katy_perry", "zooey_deschanel", Genre.SIMILAR_PEOPLE),
        SimilarPair("natalie_portman", "keira_knightley", Genre.SIMILAR_PEOPLE),
        SimilarPair("margot_robbie", "jaime_pressly", Genre.SIMILAR_PEOPLE),
        SimilarPair("javier_bardem", "jeffrey_dean_morgan", Genre.SIMILAR_PEOPLE),
        SimilarPair("matt_damon", "mark_wahlberg", Genre.SIMILAR_PEOPLE),
        
        // 車
        SimilarPair("gt86", "brz", Genre.CARS),
        SimilarPair("miata", "s2000", Genre.CARS),
        SimilarPair("rx7", "supra", Genre.CARS),
        
        // ロゴ
        SimilarPair("pepsi", "korean_air", Genre.LOGOS),
    )

    /**
     * 利用可能なジャンル一覧を取得
     */
    fun getAvailableGenres(): List<Genre> = Genre.values().toList()

    /**
     * ジャンルに属するペアを取得
     */
    private fun getPairsForGenre(genre: Genre): List<SimilarPair> {
        return if (genre == Genre.ALL) {
            similarPairs
        } else {
            similarPairs.filter { it.genre == genre }
        }
    }

    /**
     * ジャンルに属するアイテムを取得
     */
    private fun getItemsForGenre(genre: Genre): List<AnimalPair> {
        val pairs = getPairsForGenre(genre)
        val ids = pairs.flatMap { listOf(it.id1, it.id2) }.toSet()
        return ids.mapNotNull { items[it] }
    }

    /**
     * 指定ジャンルからランダムな問題を生成
     */
    fun generateRandomQuestion(genre: Genre = Genre.ALL): QuestionConfig {
        val pairs = getPairsForGenre(genre)
        val genreItems = getItemsForGenre(genre)
        
        if (pairs.isEmpty() || genreItems.isEmpty()) {
            // フォールバック
            return generateRandomQuestion(Genre.ALL)
        }
        
        val isSame = kotlin.random.Random.nextBoolean()
        
        return if (isSame) {
            val item = genreItems.random()
            QuestionConfig(
                query1 = item.query,
                query2 = item.query,
                isSame = true,
                description = "${item.nameJa} × ${item.nameJa}"
            )
        } else {
            val pair = pairs.random()
            val item1 = items[pair.id1]!!
            val item2 = items[pair.id2]!!
            QuestionConfig(
                query1 = item1.query,
                query2 = item2.query,
                isSame = false,
                description = "${item1.nameJa} × ${item2.nameJa}"
            )
        }
    }

    data class QuestionConfig(
        val query1: String,
        val query2: String,
        val isSame: Boolean,
        val description: String
    )
}
