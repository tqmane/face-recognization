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
        BIG_CATS("ネコ科大型", "チーター・ヒョウ・ジャガー・ライオン・トラ・ピューマ"),
        SMALL_CATS("ネコ科小型", "イエネコの品種"),
        DOGS("犬種", "柴犬・秋田犬・ハスキー・マラミュート等"),
        WILD_DOGS("犬と野生", "犬とオオカミ・キツネ・コヨーテ"),
        RACCOONS("アライグマ系", "アライグマ・タヌキ・レッサーパンダ"),
        BIRDS("鳥類", "カラス・ワタリガラス・鷹・鷲"),
        MARINE("海洋動物", "アシカ・アザラシ・イルカ・シャチ"),
        REPTILES("爬虫類", "ワニ・トカゲ・ヘビ"),
        BEARS("クマ科", "様々なクマ"),
        PRIMATES("霊長類", "類人猿・サル"),
        SIMILAR_PEOPLE("似ている人", "双子・そっくりさん"),
        CARS("車", "似ている車種"),
        LOGOS("ロゴ", "似ているブランドロゴ"),
        INSECTS("昆虫", "似ている虫")
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
        // ネコ科大型
        "cheetah" to AnimalPair("cheetah", "チーター", "cheetah face close up"),
        "leopard" to AnimalPair("leopard", "ヒョウ", "leopard face close up"),
        "jaguar" to AnimalPair("jaguar", "ジャガー", "jaguar animal face"),
        "lion" to AnimalPair("lion", "ライオン", "lion face portrait"),
        "tiger" to AnimalPair("tiger", "トラ", "tiger face close up"),
        "cougar" to AnimalPair("cougar", "ピューマ", "cougar mountain lion face"),
        "snow_leopard" to AnimalPair("snow_leopard", "ユキヒョウ", "snow leopard face"),
        "clouded_leopard" to AnimalPair("clouded_leopard", "ウンピョウ", "clouded leopard face"),
        
        // ネコ科小型（イエネコ）
        "persian_cat" to AnimalPair("persian_cat", "ペルシャ猫", "persian cat face"),
        "british_shorthair" to AnimalPair("british_shorthair", "ブリティッシュショートヘア", "british shorthair cat face"),
        "scottish_fold" to AnimalPair("scottish_fold", "スコティッシュフォールド", "scottish fold cat face"),
        "maine_coon" to AnimalPair("maine_coon", "メインクーン", "maine coon cat face"),
        "ragdoll" to AnimalPair("ragdoll", "ラグドール", "ragdoll cat face"),
        "siamese" to AnimalPair("siamese", "シャム猫", "siamese cat face"),
        "russian_blue" to AnimalPair("russian_blue", "ロシアンブルー", "russian blue cat face"),
        
        // 犬種
        "shiba" to AnimalPair("shiba", "柴犬", "shiba inu dog face"),
        "akita" to AnimalPair("akita", "秋田犬", "akita dog face"),
        "husky" to AnimalPair("husky", "ハスキー", "siberian husky dog face"),
        "malamute" to AnimalPair("malamute", "マラミュート", "alaskan malamute dog face"),
        "samoyed" to AnimalPair("samoyed", "サモエド", "samoyed dog face"),
        "golden_retriever" to AnimalPair("golden_retriever", "ゴールデンレトリバー", "golden retriever dog face"),
        "labrador" to AnimalPair("labrador", "ラブラドール", "labrador retriever dog face"),
        "german_shepherd" to AnimalPair("german_shepherd", "ジャーマンシェパード", "german shepherd dog face"),
        "border_collie" to AnimalPair("border_collie", "ボーダーコリー", "border collie dog face"),
        "australian_shepherd" to AnimalPair("australian_shepherd", "オーストラリアンシェパード", "australian shepherd dog face"),
        "corgi" to AnimalPair("corgi", "コーギー", "welsh corgi dog face"),
        "pomeranian" to AnimalPair("pomeranian", "ポメラニアン", "pomeranian dog face"),
        "chow_chow" to AnimalPair("chow_chow", "チャウチャウ", "chow chow dog face"),
        
        // 野生イヌ科
        "wolf" to AnimalPair("wolf", "オオカミ", "gray wolf face"),
        "fox" to AnimalPair("fox", "キツネ", "red fox face"),
        "arctic_fox" to AnimalPair("arctic_fox", "ホッキョクギツネ", "arctic fox face"),
        "coyote" to AnimalPair("coyote", "コヨーテ", "coyote face"),
        "dingo" to AnimalPair("dingo", "ディンゴ", "dingo face"),
        "jackal" to AnimalPair("jackal", "ジャッカル", "jackal face"),
        
        // アライグマ系
        "raccoon" to AnimalPair("raccoon", "アライグマ", "raccoon face close up"),
        "tanuki" to AnimalPair("tanuki", "タヌキ", "tanuki raccoon dog face"),
        "red_panda" to AnimalPair("red_panda", "レッサーパンダ", "red panda face"),
        "coati" to AnimalPair("coati", "ハナグマ", "coati face"),
        
        // 鳥類
        "crow" to AnimalPair("crow", "カラス", "crow bird face"),
        "raven" to AnimalPair("raven", "ワタリガラス", "raven bird face"),
        "hawk" to AnimalPair("hawk", "タカ", "hawk bird face"),
        "eagle" to AnimalPair("eagle", "ワシ", "eagle bird face"),
        "falcon" to AnimalPair("falcon", "ハヤブサ", "falcon bird face"),
        "owl" to AnimalPair("owl", "フクロウ", "owl bird face"),
        "barn_owl" to AnimalPair("barn_owl", "メンフクロウ", "barn owl face"),
        
        // 海洋動物
        "sea_lion" to AnimalPair("sea_lion", "アシカ", "sea lion face"),
        "seal" to AnimalPair("seal", "アザラシ", "seal animal face"),
        "walrus" to AnimalPair("walrus", "セイウチ", "walrus face"),
        "dolphin" to AnimalPair("dolphin", "イルカ", "dolphin face"),
        "orca" to AnimalPair("orca", "シャチ", "orca killer whale face"),
        "beluga" to AnimalPair("beluga", "シロイルカ", "beluga whale face"),
        "manatee" to AnimalPair("manatee", "マナティー", "manatee face"),
        "dugong" to AnimalPair("dugong", "ジュゴン", "dugong face"),
        
        // 爬虫類
        "alligator" to AnimalPair("alligator", "アリゲーター", "american alligator face"),
        "crocodile" to AnimalPair("crocodile", "クロコダイル", "crocodile face"),
        "caiman" to AnimalPair("caiman", "カイマン", "caiman face"),
        "gharial" to AnimalPair("gharial", "ガビアル", "gharial face"),
        "iguana" to AnimalPair("iguana", "イグアナ", "iguana face"),
        "monitor" to AnimalPair("monitor", "オオトカゲ", "monitor lizard face"),
        "komodo" to AnimalPair("komodo", "コモドドラゴン", "komodo dragon face"),
        "python" to AnimalPair("python", "ニシキヘビ", "python snake face"),
        "boa" to AnimalPair("boa", "ボア", "boa constrictor face"),
        
        // クマ科
        "brown_bear" to AnimalPair("brown_bear", "ヒグマ", "brown bear face"),
        "black_bear" to AnimalPair("black_bear", "ツキノワグマ", "asian black bear face"),
        "polar_bear" to AnimalPair("polar_bear", "ホッキョクグマ", "polar bear face"),
        "panda" to AnimalPair("panda", "パンダ", "giant panda face"),
        "spectacled_bear" to AnimalPair("spectacled_bear", "メガネグマ", "spectacled bear face"),
        "sun_bear" to AnimalPair("sun_bear", "マレーグマ", "sun bear face"),
        
        // 霊長類
        "chimpanzee" to AnimalPair("chimpanzee", "チンパンジー", "chimpanzee face"),
        "bonobo" to AnimalPair("bonobo", "ボノボ", "bonobo face"),
        "gorilla" to AnimalPair("gorilla", "ゴリラ", "gorilla face"),
        "orangutan" to AnimalPair("orangutan", "オランウータン", "orangutan face"),
        "gibbon" to AnimalPair("gibbon", "テナガザル", "gibbon face"),
        "macaque" to AnimalPair("macaque", "ニホンザル", "japanese macaque face"),
        "baboon" to AnimalPair("baboon", "ヒヒ", "baboon face"),
        "mandrill" to AnimalPair("mandrill", "マンドリル", "mandrill face"),
        
        // 昆虫
        "bee" to AnimalPair("bee", "ミツバチ", "honey bee close up"),
        "wasp" to AnimalPair("wasp", "スズメバチ", "wasp close up"),
        "hornet" to AnimalPair("hornet", "オオスズメバチ", "asian giant hornet"),
        "butterfly" to AnimalPair("butterfly", "アゲハチョウ", "swallowtail butterfly"),
        "moth" to AnimalPair("moth", "蛾", "moth close up"),
        "beetle" to AnimalPair("beetle", "カブトムシ", "rhinoceros beetle"),
        "stag_beetle" to AnimalPair("stag_beetle", "クワガタ", "stag beetle"),
        "ladybug" to AnimalPair("ladybug", "テントウムシ", "ladybug close up"),
        "firefly" to AnimalPair("firefly", "ホタル", "firefly beetle"),
        
        // 双子ペア
        "mary_kate_olsen" to AnimalPair("mary_kate_olsen", "メアリー・ケイト・オルセン", "Mary-Kate Olsen face"),
        "ashley_olsen" to AnimalPair("ashley_olsen", "アシュリー・オルセン", "Ashley Olsen face"),
        "dylan_sprouse" to AnimalPair("dylan_sprouse", "ディラン・スプラウス", "Dylan Sprouse face"),
        "cole_sprouse" to AnimalPair("cole_sprouse", "コール・スプラウス", "Cole Sprouse face"),
        "tia_mowry" to AnimalPair("tia_mowry", "ティア・モウリー", "Tia Mowry face"),
        "tamera_mowry" to AnimalPair("tamera_mowry", "タメラ・モウリー", "Tamera Mowry face"),
        "benji_madden" to AnimalPair("benji_madden", "ベンジー・マッデン", "Benji Madden face"),
        "joel_madden" to AnimalPair("joel_madden", "ジョエル・マッデン", "Joel Madden face"),
        
        // そっくりさんペア
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
        "amy_adams" to AnimalPair("amy_adams", "エイミー・アダムス", "Amy Adams face"),
        "isla_fisher" to AnimalPair("isla_fisher", "アイラ・フィッシャー", "Isla Fisher face"),
        "jessica_chastain" to AnimalPair("jessica_chastain", "ジェシカ・チャステイン", "Jessica Chastain face"),
        "bryce_dallas_howard" to AnimalPair("bryce_dallas_howard", "ブライス・ダラス・ハワード", "Bryce Dallas Howard face"),
        "will_ferrell" to AnimalPair("will_ferrell", "ウィル・フェレル", "Will Ferrell face"),
        "chad_smith" to AnimalPair("chad_smith", "チャド・スミス", "Chad Smith drummer face"),
        "henry_cavill" to AnimalPair("henry_cavill", "ヘンリー・カヴィル", "Henry Cavill face"),
        "matt_bomer" to AnimalPair("matt_bomer", "マット・ボマー", "Matt Bomer face"),
        "zach_braff" to AnimalPair("zach_braff", "ザック・ブラフ", "Zach Braff face"),
        "dax_shepard" to AnimalPair("dax_shepard", "ダックス・シェパード", "Dax Shepard face"),
        
        // 車
        "gt86" to AnimalPair("gt86", "トヨタ86", "toyota 86 gt86 car"),
        "brz" to AnimalPair("brz", "スバルBRZ", "subaru brz car"),
        "miata" to AnimalPair("miata", "マツダロードスター", "mazda miata mx5"),
        "s2000" to AnimalPair("s2000", "ホンダS2000", "honda s2000 car"),
        "rx7" to AnimalPair("rx7", "マツダRX-7", "mazda rx7 fd"),
        "supra" to AnimalPair("supra", "トヨタスープラ", "toyota supra a80"),
        "nsx" to AnimalPair("nsx", "ホンダNSX", "honda nsx na1"),
        "gtr" to AnimalPair("gtr", "日産GT-R", "nissan gtr r35"),
        "370z" to AnimalPair("370z", "日産370Z", "nissan 370z"),
        "mustang" to AnimalPair("mustang", "フォードマスタング", "ford mustang gt"),
        "camaro" to AnimalPair("camaro", "シボレーカマロ", "chevrolet camaro"),
        "challenger" to AnimalPair("challenger", "ダッジチャレンジャー", "dodge challenger"),
        
        // ロゴ
        "pepsi" to AnimalPair("pepsi", "ペプシ", "pepsi logo"),
        "korean_air" to AnimalPair("korean_air", "大韓航空", "korean air logo"),
        "carrefour" to AnimalPair("carrefour", "カルフール", "carrefour logo"),
        "chanel" to AnimalPair("chanel", "シャネル", "chanel logo"),
        "gucci" to AnimalPair("gucci", "グッチ", "gucci logo"),
        "starbucks" to AnimalPair("starbucks", "スターバックス", "starbucks logo"),
        "costa" to AnimalPair("costa", "コスタコーヒー", "costa coffee logo"),
        "beats" to AnimalPair("beats", "Beats", "beats by dre logo"),
        "monster" to AnimalPair("monster", "Monster", "monster energy logo"),
    )

    // 似ているペア（ジャンル付き）
    private val similarPairs = listOf(
        // ネコ科大型
        SimilarPair("cheetah", "leopard", Genre.BIG_CATS),
        SimilarPair("jaguar", "leopard", Genre.BIG_CATS),
        SimilarPair("lion", "tiger", Genre.BIG_CATS),
        SimilarPair("cougar", "lion", Genre.BIG_CATS),
        SimilarPair("snow_leopard", "leopard", Genre.BIG_CATS),
        SimilarPair("clouded_leopard", "leopard", Genre.BIG_CATS),
        SimilarPair("jaguar", "cheetah", Genre.BIG_CATS),
        
        // ネコ科小型
        SimilarPair("persian_cat", "british_shorthair", Genre.SMALL_CATS),
        SimilarPair("scottish_fold", "british_shorthair", Genre.SMALL_CATS),
        SimilarPair("maine_coon", "ragdoll", Genre.SMALL_CATS),
        SimilarPair("siamese", "russian_blue", Genre.SMALL_CATS),
        SimilarPair("persian_cat", "ragdoll", Genre.SMALL_CATS),
        
        // 犬種
        SimilarPair("shiba", "akita", Genre.DOGS),
        SimilarPair("husky", "malamute", Genre.DOGS),
        SimilarPair("samoyed", "malamute", Genre.DOGS),
        SimilarPair("golden_retriever", "labrador", Genre.DOGS),
        SimilarPair("german_shepherd", "border_collie", Genre.DOGS),
        SimilarPair("border_collie", "australian_shepherd", Genre.DOGS),
        SimilarPair("pomeranian", "chow_chow", Genre.DOGS),
        SimilarPair("samoyed", "husky", Genre.DOGS),
        SimilarPair("corgi", "shiba", Genre.DOGS),
        
        // 犬と野生
        SimilarPair("wolf", "husky", Genre.WILD_DOGS),
        SimilarPair("wolf", "malamute", Genre.WILD_DOGS),
        SimilarPair("fox", "shiba", Genre.WILD_DOGS),
        SimilarPair("arctic_fox", "samoyed", Genre.WILD_DOGS),
        SimilarPair("coyote", "wolf", Genre.WILD_DOGS),
        SimilarPair("dingo", "shiba", Genre.WILD_DOGS),
        SimilarPair("jackal", "coyote", Genre.WILD_DOGS),
        SimilarPair("wolf", "german_shepherd", Genre.WILD_DOGS),
        
        // アライグマ系
        SimilarPair("raccoon", "tanuki", Genre.RACCOONS),
        SimilarPair("red_panda", "raccoon", Genre.RACCOONS),
        SimilarPair("coati", "raccoon", Genre.RACCOONS),
        SimilarPair("red_panda", "tanuki", Genre.RACCOONS),
        
        // 鳥
        SimilarPair("crow", "raven", Genre.BIRDS),
        SimilarPair("hawk", "eagle", Genre.BIRDS),
        SimilarPair("hawk", "falcon", Genre.BIRDS),
        SimilarPair("eagle", "falcon", Genre.BIRDS),
        SimilarPair("owl", "barn_owl", Genre.BIRDS),
        
        // 海洋
        SimilarPair("sea_lion", "seal", Genre.MARINE),
        SimilarPair("walrus", "seal", Genre.MARINE),
        SimilarPair("dolphin", "orca", Genre.MARINE),
        SimilarPair("dolphin", "beluga", Genre.MARINE),
        SimilarPair("manatee", "dugong", Genre.MARINE),
        SimilarPair("orca", "beluga", Genre.MARINE),
        
        // 爬虫類
        SimilarPair("alligator", "crocodile", Genre.REPTILES),
        SimilarPair("caiman", "alligator", Genre.REPTILES),
        SimilarPair("gharial", "crocodile", Genre.REPTILES),
        SimilarPair("iguana", "monitor", Genre.REPTILES),
        SimilarPair("komodo", "monitor", Genre.REPTILES),
        SimilarPair("python", "boa", Genre.REPTILES),
        
        // クマ科
        SimilarPair("brown_bear", "black_bear", Genre.BEARS),
        SimilarPair("polar_bear", "brown_bear", Genre.BEARS),
        SimilarPair("panda", "spectacled_bear", Genre.BEARS),
        SimilarPair("sun_bear", "black_bear", Genre.BEARS),
        SimilarPair("spectacled_bear", "black_bear", Genre.BEARS),
        
        // 霊長類
        SimilarPair("chimpanzee", "bonobo", Genre.PRIMATES),
        SimilarPair("gorilla", "chimpanzee", Genre.PRIMATES),
        SimilarPair("orangutan", "gorilla", Genre.PRIMATES),
        SimilarPair("gibbon", "orangutan", Genre.PRIMATES),
        SimilarPair("macaque", "baboon", Genre.PRIMATES),
        SimilarPair("baboon", "mandrill", Genre.PRIMATES),
        
        // 昆虫
        SimilarPair("bee", "wasp", Genre.INSECTS),
        SimilarPair("wasp", "hornet", Genre.INSECTS),
        SimilarPair("butterfly", "moth", Genre.INSECTS),
        SimilarPair("beetle", "stag_beetle", Genre.INSECTS),
        SimilarPair("ladybug", "firefly", Genre.INSECTS),
        
        // 似ている人（双子・そっくりさん）
        SimilarPair("mary_kate_olsen", "ashley_olsen", Genre.SIMILAR_PEOPLE),
        SimilarPair("dylan_sprouse", "cole_sprouse", Genre.SIMILAR_PEOPLE),
        SimilarPair("tia_mowry", "tamera_mowry", Genre.SIMILAR_PEOPLE),
        SimilarPair("benji_madden", "joel_madden", Genre.SIMILAR_PEOPLE),
        SimilarPair("katy_perry", "zooey_deschanel", Genre.SIMILAR_PEOPLE),
        SimilarPair("natalie_portman", "keira_knightley", Genre.SIMILAR_PEOPLE),
        SimilarPair("margot_robbie", "jaime_pressly", Genre.SIMILAR_PEOPLE),
        SimilarPair("javier_bardem", "jeffrey_dean_morgan", Genre.SIMILAR_PEOPLE),
        SimilarPair("matt_damon", "mark_wahlberg", Genre.SIMILAR_PEOPLE),
        SimilarPair("amy_adams", "isla_fisher", Genre.SIMILAR_PEOPLE),
        SimilarPair("jessica_chastain", "bryce_dallas_howard", Genre.SIMILAR_PEOPLE),
        SimilarPair("will_ferrell", "chad_smith", Genre.SIMILAR_PEOPLE),
        SimilarPair("henry_cavill", "matt_bomer", Genre.SIMILAR_PEOPLE),
        SimilarPair("zach_braff", "dax_shepard", Genre.SIMILAR_PEOPLE),
        
        // 車
        SimilarPair("gt86", "brz", Genre.CARS),
        SimilarPair("miata", "s2000", Genre.CARS),
        SimilarPair("rx7", "supra", Genre.CARS),
        SimilarPair("nsx", "gtr", Genre.CARS),
        SimilarPair("370z", "supra", Genre.CARS),
        SimilarPair("mustang", "camaro", Genre.CARS),
        SimilarPair("camaro", "challenger", Genre.CARS),
        SimilarPair("mustang", "challenger", Genre.CARS),
        
        // ロゴ
        SimilarPair("pepsi", "korean_air", Genre.LOGOS),
        SimilarPair("gucci", "chanel", Genre.LOGOS),
        SimilarPair("starbucks", "costa", Genre.LOGOS),
        SimilarPair("beats", "monster", Genre.LOGOS),
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
