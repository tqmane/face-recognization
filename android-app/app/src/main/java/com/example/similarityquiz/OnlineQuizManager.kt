package com.example.similarityquiz

/**
 * オンラインクイズ用の問題管理
 * リアルタイムで画像を取得してクイズを生成
 */
class OnlineQuizManager {

    val scraper = ImageScraper()

    // 動物ペアの定義（Pythonツールと同じ）
    data class AnimalPair(
        val id: String,
        val nameJa: String,
        val query: String
    )

    val animals = mapOf(
        "cheetah" to AnimalPair("cheetah", "チーター", "cheetah face close up"),
        "leopard" to AnimalPair("leopard", "ヒョウ", "leopard face close up"),
        "jaguar" to AnimalPair("jaguar", "ジャガー", "jaguar face close up"),
        "shiba" to AnimalPair("shiba", "柴犬", "shiba inu face"),
        "akita" to AnimalPair("akita", "秋田犬", "akita dog face"),
        "husky" to AnimalPair("husky", "ハスキー", "siberian husky face"),
        "malamute" to AnimalPair("malamute", "マラミュート", "alaskan malamute face"),
        "wolf" to AnimalPair("wolf", "オオカミ", "wolf face close up"),
        "raccoon" to AnimalPair("raccoon", "アライグマ", "raccoon face close up"),
        "tanuki" to AnimalPair("tanuki", "タヌキ", "tanuki face japanese raccoon dog"),
        "crow" to AnimalPair("crow", "カラス", "crow bird close up"),
        "raven" to AnimalPair("raven", "ワタリガラス", "raven bird close up"),
        "sea_lion" to AnimalPair("sea_lion", "アシカ", "sea lion face"),
        "seal" to AnimalPair("seal", "アザラシ", "seal face close up"),
        "lion" to AnimalPair("lion", "ライオン", "lion face close up"),
        "tiger" to AnimalPair("tiger", "トラ", "tiger face close up"),
        "alligator" to AnimalPair("alligator", "ワニ", "alligator face"),
        "crocodile" to AnimalPair("crocodile", "クロコダイル", "crocodile face"),
    )

    // 似ているペア
    val similarPairs = listOf(
        Pair("cheetah", "leopard"),
        Pair("jaguar", "leopard"),
        Pair("shiba", "akita"),
        Pair("husky", "malamute"),
        Pair("wolf", "husky"),
        Pair("raccoon", "tanuki"),
        Pair("crow", "raven"),
        Pair("sea_lion", "seal"),
        Pair("lion", "tiger"),
        Pair("alligator", "crocodile"),
    )

    /**
     * ランダムな問題を生成
     * @return Pair<問題情報, 正解（true=同じ, false=違う）>
     */
    fun generateRandomQuestion(): QuestionConfig {
        val isSame = kotlin.random.Random.nextBoolean()
        
        return if (isSame) {
            // 同じもの同士
            val animal = animals.values.random()
            QuestionConfig(
                query1 = animal.query,
                query2 = animal.query,
                isSame = true,
                description = "${animal.nameJa} × ${animal.nameJa}"
            )
        } else {
            // 違うもの同士（似ているペアから選択）
            val pair = similarPairs.random()
            val animal1 = animals[pair.first]!!
            val animal2 = animals[pair.second]!!
            QuestionConfig(
                query1 = animal1.query,
                query2 = animal2.query,
                isSame = false,
                description = "${animal1.nameJa} × ${animal2.nameJa}"
            )
        }
    }

    /**
     * 特定のペアから問題を生成
     */
    fun generateQuestionFromPair(pairIndex: Int, isSame: Boolean): QuestionConfig {
        val pair = similarPairs[pairIndex]
        val animal1 = animals[pair.first]!!
        val animal2 = animals[pair.second]!!
        
        return if (isSame) {
            // どちらかの動物で「同じもの」問題
            val animal = if (kotlin.random.Random.nextBoolean()) animal1 else animal2
            QuestionConfig(
                query1 = animal.query,
                query2 = animal.query,
                isSame = true,
                description = "${animal.nameJa} × ${animal.nameJa}"
            )
        } else {
            QuestionConfig(
                query1 = animal1.query,
                query2 = animal2.query,
                isSame = false,
                description = "${animal1.nameJa} × ${animal2.nameJa}"
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
