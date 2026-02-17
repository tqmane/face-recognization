"""
信頼性の高い画像ソースからテストセット用画像をダウンロード

使用API（優先順）:
- iNaturalist: 野生動物（研究グレードの写真）
- GBIF: 生物多様性データ（自然史博物館等の写真）
- The Dog API: 犬種
- The Cat API: 猫種
- Wikimedia Commons: その他（ロゴ等）
- Serper API (Bing/Google): フォールバック検索

出力構造:
  test_sets/
  └── dogs/           # ジャンルフォルダ
      ├── manifest.json
      ├── shiba/      # 種類フォルダ
      │   ├── 001.jpg
      │   └── ...
      ├── akita/
      └── husky/
"""

import os
import json
import time
import hashlib
import requests
import zipfile
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass, field, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import quote, urlparse


# =============================================================================
# 設定
# =============================================================================

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
OUTPUT_DIR = Path("test_sets")
IMAGES_PER_TYPE = 20  # 各種類ごとにダウンロードする画像数

# 並列処理設定
MAX_WORKERS = 5  # 並列ダウンロード数
MAX_RETRIES = 3  # リトライ回数
RETRY_DELAY = 2  # 初期リトライ遅延（秒）
BACKOFF_FACTOR = 2  # 指数バックオフの係数

# API URLs
INATURALIST_API = "https://api.inaturalist.org/v1"
GBIF_API = "https://api.gbif.org/v1"
DOG_API = "https://api.thedogapi.com/v1"
CAT_API = "https://api.thecatapi.com/v1"
WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"

# Serper API (Bing/Google 画像検索) - 必要な場合は設定
# https://serper.dev/ でAPIキーを取得
SERPER_API_KEY = os.environ.get("SERPER_API_KEY", "")


# =============================================================================
# データ定義
# =============================================================================

@dataclass
class ItemInfo:
    id: str
    name_ja: str
    query: str  # Bingフォールバック用
    inaturalist_taxon_id: Optional[int] = None
    gbif_species_key: Optional[int] = None
    dog_api_breed_id: Optional[int] = None
    cat_api_breed_id: Optional[str] = None
    wikimedia_category: Optional[str] = None


@dataclass
class SimilarPair:
    id1: str
    id2: str


@dataclass
class GenreInfo:
    id: str
    display_name: str
    description: str
    items: List[ItemInfo] = field(default_factory=list)
    similar_pairs: List[SimilarPair] = field(default_factory=list)


# iNaturalist taxon_id マッピング
INATURALIST_TAXON_IDS = {
    # ネコ科大型
    "cheetah": 41955, "leopard": 41963, "jaguar": 41970,
    "lion": 41964, "tiger": 41967, "cougar": 42007,
    "snow_leopard": 74831, "clouded_leopard": 41972,
    # 野生イヌ科
    "wolf": 43351, "fox": 42069, "arctic_fox": 42076,
    "coyote": 42050, "dingo": 559543, "jackal": 42039,
    # アライグマ系
    "raccoon": 41663, "tanuki": 42068, "red_panda": 41656, "coati": 41673,
    # 鳥類
    "crow": 8021, "raven": 9083, "hawk": 5067, "eagle": 5305,
    "falcon": 4647, "owl": 19350, "barn_owl": 3442,
    # 海洋動物
    "sea_lion": 41633, "seal": 41631, "walrus": 41620,
    "dolphin": 41479, "orca": 41523, "beluga": 41530,
    "manatee": 41586, "dugong": 41587,
    # 爬虫類
    "alligator": 26163, "crocodile": 26159, "caiman": 26166,
    "gharial": 26172, "iguana": 36383, "monitor": 79437, "komodo": 79439,
    # クマ科
    "brown_bear": 41638, "black_bear": 41647, "polar_bear": 41637,
    "panda": 41650, "spectacled_bear": 41649, "sun_bear": 41648,
    # 霊長類
    "chimpanzee": 417394, "bonobo": 417402, "gorilla": 43571,
    "orangutan": 43576, "gibbon": 43581, "macaque": 43549,
    "baboon": 43531, "mandrill": 43536,
    # 昆虫
    "bee": 47219, "wasp": 52747, "hornet": 322285,
    "butterfly": 47224, "moth": 47157, "beetle": 47208,
    "stag_beetle": 48112, "ladybug": 52748, "firefly": 47945,
}

# GBIF species key マッピング
GBIF_SPECIES_KEYS = {
    "cheetah": 5219404, "leopard": 5219436, "jaguar": 5219426,
    "lion": 5219411, "tiger": 5219446, "cougar": 2435099,
    "snow_leopard": 5219440, "clouded_leopard": 5219395,
    "wolf": 5219173, "fox": 5219243, "arctic_fox": 5219233, "coyote": 5219142,
    "raccoon": 5218786, "red_panda": 5218800,
    "brown_bear": 2433433, "black_bear": 2433398, "polar_bear": 2433451,
    "panda": 5218781,
    "chimpanzee": 5219513, "gorilla": 5219521, "orangutan": 5219531,
}

# Dog API breed_id マッピング（正しいIDに修正）
# https://api.thedogapi.com/v1/breeds から取得
DOG_BREED_IDS = {
    "shiba": 105,      # Shiba Inu
    "akita": 4,        # Akita
    "husky": 248,      # Siberian Husky
    "malamute": 27,    # Alaskan Malamute
    "samoyed": 144,    # Samoyed
    "golden_retriever": 121,    # Golden Retriever
    "labrador": 129,   # Labrador Retriever
    "german_shepherd": 84,      # German Shepherd Dog
    "border_collie": 52,       # Border Collie
    "australian_shepherd": 15, # Australian Shepherd
    "corgi": 69,       # Welsh Corgi Pembroke
    "pomeranian": 143, # Pomeranian
    "chow_chow": 56,   # Chow Chow
}

# Cat API breed_id マッピング（正しいIDに修正）
# https://api.thecatapi.com/v1/breeds から取得
CAT_BREED_IDS = {
    "persian_cat": "pers",      # Persian
    "british_shorthair": "bsho", # British Shorthair
    "scottish_fold": "sfol",    # Scottish Fold
    "maine_coon": "mcoo",       # Maine Coon
    "ragdoll": "ragd",         # Ragdoll
    "siamese": "siam",         # Siamese
    "russian_blue": "rblu",    # Russian Blue
}

# Wikimedia Category マッピング
WIKIMEDIA_CATEGORIES = {
    "persian_cat": "Persian cat",
    "british_shorthair": "British Shorthair",
    "scottish_fold": "Scottish Fold",
    "maine_coon": "Maine Coon",
    "ragdoll": "Ragdoll",
    "siamese": "Siamese cat",
    "russian_blue": "Russian Blue",
    "shiba": "Shiba Inu",
    "akita": "Akita Inu",
    "husky": "Siberian Husky",
    "malamute": "Alaskan Malamute",
    "samoyed": "Samoyed dog",
    "golden_retriever": "Golden Retriever",
    "labrador": "Labrador Retriever",
    "german_shepherd": "German Shepherd Dog",
    "border_collie": "Border Collie",
    "australian_shepherd": "Australian Shepherd",
    "corgi": "Welsh Corgi Pembroke",
    "pomeranian": "Pomeranian dog",
    "chow_chow": "Chow Chow",
    # 野生動物
    "wolf": "Canis lupus",
    "fox": "Vulpes vulpes",
    "arctic_fox": "Vulpes lagopus",
    "coyote": "Canis latrans",
    "dingo": "Canis lupus dingo",
    "jackal": "Canis aureus",
    "raccoon": "Procyon lotor",
    "tanuki": "Nyctereutes procyonoides",
    "red_panda": "Ailurus fulgens",
    "coati": "Nasua",
    "crow": "Corvus",
    "raven": "Corvus corax",
    "hawk": "Accipitrinae",
    "eagle": "Eagle",
    "falcon": "Falcon",
    "owl": "Strigiformes",
    "barn_owl": "Tyto alba",
    "sea_lion": "Otariinae",
    "seal": "Phocidae",
    "walrus": "Odobenus rosmarus",
    "dolphin": "Dolphin",
    "orca": "Orcinus orca",
    "beluga": "Delphinapterus leucas",
    "manatee": "Trichechus",
    "dugong": "Dugong dugon",
    "alligator": "Alligator",
    "crocodile": "Crocodile",
    "caiman": "Caiman",
    "gharial": "Gavialis gangeticus",
    "iguana": "Iguana",
    "monitor": "Varanus",
    "komodo": "Varanus komodoensis",
    "brown_bear": "Ursus arctos",
    "black_bear": "Ursus thibetanus",
    "polar_bear": "Ursus maritimus",
    "panda": "Ailuropoda melanoleuca",
    "spectacled_bear": "Tremarctos ornatus",
    "sun_bear": "Helarctos malayanus",
    "chimpanzee": "Pan troglodytes",
    "bonobo": "Pan paniscus",
    "gorilla": "Gorilla",
    "orangutan": "Pongo",
    "gibbon": "Hylobatidae",
    "macaque": "Macaca",
    "baboon": "Papio",
    "mandrill": "Mandrillus sphinx",
    "bee": "Anthophila",
    "wasp": "Wasp",
    "hornet": "Vespa",
    "butterfly": "Rhopalocera",
    "moth": "Moth",
    "beetle": "Coleoptera",
    "stag_beetle": "Lucanidae",
    "ladybug": "Coccinellidae",
    "firefly": "Lampyridae",
}


def create_item(id: str, name_ja: str, query: str) -> ItemInfo:
    """アイテム情報を作成（API IDを自動設定）"""
    return ItemInfo(
        id=id,
        name_ja=name_ja,
        query=query,
        inaturalist_taxon_id=INATURALIST_TAXON_IDS.get(id),
        gbif_species_key=GBIF_SPECIES_KEYS.get(id),
        dog_api_breed_id=DOG_BREED_IDS.get(id),
        cat_api_breed_id=CAT_BREED_IDS.get(id),
        wikimedia_category=WIKIMEDIA_CATEGORIES.get(id),
    )


GENRES: Dict[str, GenreInfo] = {
    "small_cats": GenreInfo(
        id="small_cats",
        display_name="ネコ科小型",
        description="イエネコの品種",
        items=[
            create_item("persian_cat", "ペルシャ猫", "persian cat face"),
            create_item("british_shorthair", "ブリティッシュショートヘア", "british shorthair cat face"),
            create_item("scottish_fold", "スコティッシュフォールド", "scottish fold cat face"),
            create_item("maine_coon", "メインクーン", "maine coon cat face"),
            create_item("ragdoll", "ラグドール", "ragdoll cat face"),
            create_item("siamese", "シャム猫", "siamese cat face"),
            create_item("russian_blue", "ロシアンブルー", "russian blue cat face"),
        ],
        similar_pairs=[
            SimilarPair("persian_cat", "british_shorthair"),
            SimilarPair("scottish_fold", "british_shorthair"),
            SimilarPair("maine_coon", "ragdoll"),
            SimilarPair("siamese", "russian_blue"),
            SimilarPair("persian_cat", "ragdoll"),
        ],
    ),
    "dogs": GenreInfo(
        id="dogs",
        display_name="犬種",
        description="柴犬・秋田犬・ハスキー・マラミュート等",
        items=[
            create_item("shiba", "柴犬", "shiba inu dog face"),
            create_item("akita", "秋田犬", "akita dog face"),
            create_item("husky", "ハスキー", "siberian husky dog face"),
            create_item("malamute", "マラミュート", "alaskan malamute dog face"),
            create_item("samoyed", "サモエド", "samoyed dog face"),
            create_item("golden_retriever", "ゴールデンレトリバー", "golden retriever dog face"),
            create_item("labrador", "ラブラドール", "labrador retriever dog face"),
            create_item("german_shepherd", "ジャーマンシェパード", "german shepherd dog face"),
            create_item("border_collie", "ボーダーコリー", "border collie dog face"),
            create_item("australian_shepherd", "オーストラリアンシェパード", "australian shepherd dog face"),
            create_item("corgi", "コーギー", "welsh corgi dog face"),
            create_item("pomeranian", "ポメラニアン", "pomeranian dog face"),
            create_item("chow_chow", "チャウチャウ", "chow chow dog face"),
        ],
        similar_pairs=[
            SimilarPair("shiba", "akita"),
            SimilarPair("husky", "malamute"),
            SimilarPair("samoyed", "malamute"),
            SimilarPair("golden_retriever", "labrador"),
            SimilarPair("german_shepherd", "border_collie"),
            SimilarPair("border_collie", "australian_shepherd"),
            SimilarPair("pomeranian", "chow_chow"),
            SimilarPair("samoyed", "husky"),
            SimilarPair("corgi", "shiba"),
        ],
    ),
    "wild_dogs": GenreInfo(
        id="wild_dogs",
        display_name="犬と野生",
        description="犬とオオカミ・キツネ・コヨーテ",
        items=[
            create_item("wolf", "オオカミ", "gray wolf face"),
            create_item("fox", "キツネ", "red fox face"),
            create_item("arctic_fox", "ホッキョクギツネ", "arctic fox face"),
            create_item("coyote", "コヨーテ", "coyote face"),
            create_item("dingo", "ディンゴ", "dingo face"),
            create_item("jackal", "ジャッカル", "jackal face"),
            create_item("husky", "ハスキー", "siberian husky dog face"),
            create_item("malamute", "マラミュート", "alaskan malamute dog face"),
            create_item("shiba", "柴犬", "shiba inu dog face"),
            create_item("samoyed", "サモエド", "samoyed dog face"),
            create_item("german_shepherd", "ジャーマンシェパード", "german shepherd dog face"),
        ],
        similar_pairs=[
            SimilarPair("wolf", "husky"),
            SimilarPair("wolf", "malamute"),
            SimilarPair("fox", "shiba"),
            SimilarPair("arctic_fox", "samoyed"),
            SimilarPair("coyote", "wolf"),
            SimilarPair("dingo", "shiba"),
            SimilarPair("jackal", "coyote"),
            SimilarPair("wolf", "german_shepherd"),
        ],
    ),
    "raccoons": GenreInfo(
        id="raccoons",
        display_name="アライグマ系",
        description="アライグマ・タヌキ・レッサーパンダ",
        items=[
            create_item("raccoon", "アライグマ", "raccoon face close up"),
            create_item("tanuki", "タヌキ", "tanuki raccoon dog face"),
            create_item("red_panda", "レッサーパンダ", "red panda face"),
            create_item("coati", "ハナグマ", "coati face"),
        ],
        similar_pairs=[
            SimilarPair("raccoon", "tanuki"),
            SimilarPair("red_panda", "raccoon"),
            SimilarPair("coati", "raccoon"),
            SimilarPair("red_panda", "tanuki"),
        ],
    ),
    "birds": GenreInfo(
        id="birds",
        display_name="鳥類",
        description="カラス・ワタリガラス・鷹・鷲",
        items=[
            create_item("crow", "カラス", "crow bird face"),
            create_item("raven", "ワタリガラス", "raven bird face"),
            create_item("hawk", "タカ", "hawk bird face"),
            create_item("eagle", "ワシ", "eagle bird face"),
            create_item("falcon", "ハヤブサ", "falcon bird face"),
            create_item("owl", "フクロウ", "owl bird face"),
            create_item("barn_owl", "メンフクロウ", "barn owl face"),
        ],
        similar_pairs=[
            SimilarPair("crow", "raven"),
            SimilarPair("hawk", "eagle"),
            SimilarPair("hawk", "falcon"),
            SimilarPair("eagle", "falcon"),
            SimilarPair("owl", "barn_owl"),
        ],
    ),
    "marine": GenreInfo(
        id="marine",
        display_name="海洋動物",
        description="アシカ・アザラシ・イルカ・シャチ",
        items=[
            create_item("sea_lion", "アシカ", "sea lion face"),
            create_item("seal", "アザラシ", "seal animal face"),
            create_item("walrus", "セイウチ", "walrus face"),
            create_item("dolphin", "イルカ", "dolphin face"),
            create_item("orca", "シャチ", "orca killer whale face"),
            create_item("beluga", "シロイルカ", "beluga whale face"),
            create_item("manatee", "マナティー", "manatee face"),
            create_item("dugong", "ジュゴン", "dugong face"),
        ],
        similar_pairs=[
            SimilarPair("sea_lion", "seal"),
            SimilarPair("walrus", "seal"),
            SimilarPair("dolphin", "orca"),
            SimilarPair("dolphin", "beluga"),
            SimilarPair("manatee", "dugong"),
            SimilarPair("orca", "beluga"),
        ],
    ),
    "reptiles": GenreInfo(
        id="reptiles",
        display_name="爬虫類",
        description="ワニ・トカゲ・ヘビ",
        items=[
            create_item("alligator", "アリゲーター", "american alligator face"),
            create_item("crocodile", "クロコダイル", "crocodile face"),
            create_item("caiman", "カイマン", "caiman face"),
            create_item("gharial", "ガビアル", "gharial face"),
            create_item("iguana", "イグアナ", "iguana face"),
            create_item("monitor", "オオトカゲ", "monitor lizard face"),
            create_item("komodo", "コモドドラゴン", "komodo dragon face"),
        ],
        similar_pairs=[
            SimilarPair("alligator", "crocodile"),
            SimilarPair("caiman", "alligator"),
            SimilarPair("gharial", "crocodile"),
            SimilarPair("iguana", "monitor"),
            SimilarPair("komodo", "monitor"),
        ],
    ),
    "bears": GenreInfo(
        id="bears",
        display_name="クマ科",
        description="様々なクマ",
        items=[
            create_item("brown_bear", "ヒグマ", "brown bear face"),
            create_item("black_bear", "ツキノワグマ", "asian black bear face"),
            create_item("polar_bear", "ホッキョクグマ", "polar bear face"),
            create_item("panda", "パンダ", "giant panda face"),
            create_item("spectacled_bear", "メガネグマ", "spectacled bear face"),
            create_item("sun_bear", "マレーグマ", "sun bear face"),
        ],
        similar_pairs=[
            SimilarPair("brown_bear", "black_bear"),
            SimilarPair("polar_bear", "brown_bear"),
            SimilarPair("panda", "spectacled_bear"),
            SimilarPair("sun_bear", "black_bear"),
            SimilarPair("spectacled_bear", "black_bear"),
        ],
    ),
    "primates": GenreInfo(
        id="primates",
        display_name="霊長類",
        description="類人猿・サル",
        items=[
            create_item("chimpanzee", "チンパンジー", "chimpanzee face"),
            create_item("bonobo", "ボノボ", "bonobo face"),
            create_item("gorilla", "ゴリラ", "gorilla face"),
            create_item("orangutan", "オランウータン", "orangutan face"),
            create_item("gibbon", "テナガザル", "gibbon face"),
            create_item("macaque", "ニホンザル", "japanese macaque face"),
            create_item("baboon", "ヒヒ", "baboon face"),
            create_item("mandrill", "マンドリル", "mandrill face"),
        ],
        similar_pairs=[
            SimilarPair("chimpanzee", "bonobo"),
            SimilarPair("gorilla", "chimpanzee"),
            SimilarPair("orangutan", "gorilla"),
            SimilarPair("gibbon", "orangutan"),
            SimilarPair("macaque", "baboon"),
            SimilarPair("baboon", "mandrill"),
        ],
    ),
    "insects": GenreInfo(
        id="insects",
        display_name="昆虫",
        description="似ている虫",
        items=[
            create_item("bee", "ミツバチ", "honey bee close up"),
            create_item("wasp", "スズメバチ", "wasp close up"),
            create_item("hornet", "オオスズメバチ", "asian giant hornet"),
            create_item("butterfly", "アゲハチョウ", "swallowtail butterfly"),
            create_item("moth", "蛾", "moth close up"),
            create_item("beetle", "カブトムシ", "rhinoceros beetle"),
            create_item("stag_beetle", "クワガタ", "stag beetle"),
            create_item("ladybug", "テントウムシ", "ladybug close up"),
            create_item("firefly", "ホタル", "firefly beetle"),
        ],
        similar_pairs=[
            SimilarPair("bee", "wasp"),
            SimilarPair("wasp", "hornet"),
            SimilarPair("butterfly", "moth"),
            SimilarPair("beetle", "stag_beetle"),
            SimilarPair("ladybug", "firefly"),
        ],
    ),
}


# =============================================================================
# ユーティリティ関数
# =============================================================================

def is_valid_image_url(url: str) -> bool:
    """画像URLが有効かチェック（簡易チェック）"""
    lower = url.lower()
    # 無効なURLパターンを除外
    # 注: 'thumb' は Wikimedia の thumburl で使われるので除外しない
    invalid_patterns = ["placeholder", "default", "avatar", "icon", "logo", "watermark", "pixel", "1x1"]
    if any(p in lower for p in invalid_patterns):
        return False
    
    # 画像拡張子を確認（クエリパラメータは無視）
    path = lower.split('?')[0]
    valid_extensions = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp")
    return any(path.endswith(ext) for ext in valid_extensions)


def is_photo_filename(title: str) -> bool:
    """Wikimediaのファイル名から写真かどうか判定（非写真を除外）
    
    Wikimedia Categoriesには写真以外にも以下が含まれる:
    - SVGアイコン、ロゴ、紋章
    - 地図、図面、グラフ
    - イラスト、漫画
    - スクリーンショット
    これらを除外して実際の動物写真のみ通す。
    """
    lower = title.lower()
    # 除外パターン（非写真コンテンツ）
    reject_patterns = [
        "icon", "logo", "emblem", "coat of arms", "flag",
        "map", "diagram", "chart", "graph", "schema",
        "illustration", "drawing", "sketch", "cartoon", "comic",
        "stamp", "postage", "coin", "medal", "trophy",
        "screenshot", "screen shot",
        "symbol", "sign", "pictogram", "silhouette",
        ".svg", ".gif",
    ]
    return not any(p in lower for p in reject_patterns)


def is_valid_image_content(content: bytes, min_size: int = 500) -> bool:
    """画像コンテンツが有効かチェック"""
    if len(content) < min_size:
        return False
    
    # 画像ファイルのマジックバイトを確認
    magic_bytes = {
        b'\xff\xd8\xff': 'jpeg',
        b'\x89PNG\r\n\x1a\n': 'png',
        b'GIF87a': 'gif',
        b'GIF89a': 'gif',
        b'RIFF': 'webp',  # WebPはRIFF..WEBP
        b'BM': 'bmp',
    }
    
    for magic, fmt in magic_bytes.items():
        if content.startswith(magic):
            return True
    
    # JPEGは最初の2バイトが FF D8
    if content[:2] == b'\xff\xd8':
        return True
    
    return False


def get_retry_delay(retry_count: int) -> float:
    """指数バックオフでリトライ遅延を計算"""
    return RETRY_DELAY * (BACKOFF_FACTOR ** retry_count)


def filter_portrait_image(content: bytes, width: int = 100, height: int = 100) -> bool:
    """画像がポートレート/颜向きかチェック（簡易版）- 缓和版"""
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(content))
        w, h = img.size
        
        # 颜向き画像の条件：
        # 1. 正方形に近い、または縦長の画像
        # 2. 极端な横長（バナー等）は除外
        aspect_ratio = w / h if h > 0 else 1
        
        # アスペクト比チェック - 缓和版 (0.25 ~ 4.0 の間)
        # 动物の場合、橫長もOK（全身写真など）
        if aspect_ratio < 0.25 or aspect_ratio > 4.0:
            return False
        
        # 极端に小さい画像は除外
        if w < 100 or h < 100:
            return False
        
        return True
    except:
        # Pillowがインストールされていない場合はパス
        return True


def suggest_image_classification(item_id: str) -> List[str]:
    """アイテムIDに基づいて期待される画像クラスを返す"""
    # 动物名のマッピング（英語）
    class_mapping = {
        # 猫
        "persian_cat": ["persian cat", "cat"],
        "british_shorthair": ["british shorthair", "cat"],
        "scottish_fold": ["scottish fold", "cat"],
        "maine_coon": ["maine coon", "cat"],
        "ragdoll": ["ragdoll", "cat"],
        "siamese": ["siamese cat", "cat"],
        "russian_blue": ["russian blue", "cat"],
        # 犬
        "shiba": ["shiba inu", "dog"],
        "akita": ["akita", "dog"],
        "husky": ["siberian husky", "husky", "dog"],
        "malamute": ["alaskan malamute", "dog"],
        "samoyed": ["samoyed", "dog"],
        "golden_retriever": ["golden retriever", "dog"],
        "labrador": ["labrador retriever", "dog"],
        "german_shepherd": ["german shepherd", "dog"],
        "border_collie": ["border collie", "dog"],
        "australian_shepherd": ["australian shepherd", "dog"],
        "corgi": ["welsh corgi", "corgi", "dog"],
        "pomeranian": ["pomeranian", "dog"],
        "chow_chow": ["chow chow", "dog"],
        # 野生イヌ科
        "wolf": ["wolf", "gray wolf"],
        "fox": ["red fox", "fox"],
        "arctic_fox": ["arctic fox", "white fox"],
        "coyote": ["coyote"],
        "dingo": ["dingo"],
        "jackal": ["jackal"],
        # アライグマ系
        "raccoon": ["raccoon"],
        "tanuki": ["tanuki", "raccoon dog"],
        "red_panda": ["red panda"],
        "coati": ["coati"],
        # 鳥
        "crow": ["crow", "bird"],
        "raven": ["raven", "bird"],
        "hawk": ["hawk", "bird"],
        "eagle": ["eagle", "bird"],
        "falcon": ["falcon", "bird"],
        "owl": ["owl", "bird"],
        "barn_owl": ["barn owl", "owl", "bird"],
        # 海洋
        "sea_lion": ["sea lion"],
        "seal": ["seal", "harbor seal"],
        "walrus": ["walrus"],
        "dolphin": ["dolphin"],
        "orca": ["orca", "killer whale"],
        "beluga": ["beluga whale"],
        "manatee": ["manatee"],
        "dugong": ["dugong"],
        # 爬虫類
        "alligator": ["alligator", "american alligator"],
        "crocodile": ["crocodile"],
        "caiman": ["caiman"],
        "gharial": ["gharial"],
        "iguana": ["iguana"],
        "monitor": ["monitor lizard"],
        "komodo": ["komodo dragon"],
        # クマ
        "brown_bear": ["brown bear", "grizzly bear"],
        "black_bear": ["black bear", "asian black bear"],
        "polar_bear": ["polar bear"],
        "panda": ["giant panda", "panda"],
        "spectacled_bear": ["spectacled bear"],
        "sun_bear": ["sun bear"],
        # 霊長類
        "chimpanzee": ["chimpanzee", "chimp"],
        "bonobo": ["bonobo"],
        "gorilla": ["gorilla"],
        "orangutan": ["orangutan"],
        "gibbon": ["gibbon"],
        "macaque": ["macaque", "monkey"],
        "baboon": ["baboon"],
        "mandrill": ["mandrill"],
        # 昆虫
        "bee": ["bee", "honey bee"],
        "wasp": ["wasp"],
        "hornet": ["hornet", "giant hornet"],
        "butterfly": ["butterfly"],
        "moth": ["moth"],
        "beetle": ["beetle", "rhinoceros beetle"],
        "stag_beetle": ["stag beetle"],
        "ladybug": ["ladybug", "ladybird"],
        "firefly": ["firefly", "lightning bug"],
    }
    return class_mapping.get(item_id, [item_id])


# =============================================================================
# 画像取得関数（改良版）
# =============================================================================

def fetch_from_inaturalist(taxon_id: int, max_results: int = 50) -> List[str]:
    """iNaturalist APIから画像URLを取得"""
    urls = []
    try:
        # 写真付きでquality_grade=research（研究グレード）のみ取得
        url = f"{INATURALIST_API}/observations"
        params = {
            "taxon_id": taxon_id,
            "photos": "true",
            "quality_grade": "research",
            "per_page": min(max_results, 200),
            "order": "desc",
            "order_by": "votes",
        }
        
        response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            for obs in data.get("results", []):
                for photo in obs.get("photos", []):
                    # より大きな画像サイズを選択（square < medium < large < original）
                    photo_url = photo.get("url", "").replace("square", "large")
                    if photo_url and is_valid_image_url(photo_url):
                        urls.append(photo_url)
                        
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ iNaturalist error for taxon_id={taxon_id}: {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ iNaturalist JSON error: {e}")
    
    return urls


def fetch_from_gbif(species_key: int, max_results: int = 50) -> List[str]:
    """GBIF APIから画像URLを取得"""
    urls = []
    try:
        url = f"{GBIF_API}/occurrence/search"
        params = {
            "speciesKey": species_key,
            "mediaType": "StillImage",
            "limit": min(max_results, 200),
        }
        
        response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            for occ in data.get("results", []):
                for media in occ.get("media", []):
                    photo_url = media.get("identifier", "")
                    if photo_url and is_valid_image_url(photo_url):
                        urls.append(photo_url)
                        
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ GBIF error for species_key={species_key}: {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ GBIF JSON error: {e}")
    
    return urls


def fetch_from_dog_api(breed_id: int, expected_breed: str, max_results: int = 10) -> List[str]:
    """The Dog APIから画像URLを取得（品種検証付き・1ページのみ）
    
    無料プランでは pagination で無関係な画像が返されるため、
    1ページのみ取得し、レスポンスの breeds 情報で品種を検証する。
    """
    urls = []
    try:
        url = f"{DOG_API}/images/search"
        params = {
            "breed_ids": breed_id,
            "limit": min(max_results, 25),
        }
        
        response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            expected_lower = expected_breed.lower()
            
            for item in data:
                photo_url = item.get("url", "")
                if not photo_url or not is_valid_image_url(photo_url):
                    continue
                
                # 品種情報が含まれている場合、検証する
                breeds = item.get("breeds", [])
                if breeds:
                    breed_name = breeds[0].get("name", "").lower()
                    # 品種名が期待値と一致するかチェック
                    if expected_lower in breed_name or breed_name in expected_lower:
                        urls.append(photo_url)
                    else:
                        print(f"      ⚠ 品種不一致 skip: expected={expected_breed}, got={breeds[0].get('name')}")
                else:
                    # 品種情報なし → 信頼できないためスキップ
                    pass
                    
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ Dog API error for breed_id={breed_id}: {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ Dog API JSON error: {e}")
    
    return urls[:max_results]


def fetch_from_cat_api(breed_id: str, expected_breed: str, max_results: int = 10) -> List[str]:
    """The Cat APIから画像URLを取得（品種検証付き・1ページのみ）"""
    urls = []
    try:
        url = f"{CAT_API}/images/search"
        params = {
            "breed_ids": breed_id,
            "limit": min(max_results, 25),
        }
        
        response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            expected_lower = expected_breed.lower()
            
            for item in data:
                photo_url = item.get("url", "")
                if not photo_url or not is_valid_image_url(photo_url):
                    continue
                
                # 品種情報が含まれている場合、検証する
                breeds = item.get("breeds", [])
                if breeds:
                    breed_name = breeds[0].get("name", "").lower()
                    if expected_lower in breed_name or breed_name in expected_lower:
                        urls.append(photo_url)
                    else:
                        print(f"      ⚠ 品種不一致 skip: expected={expected_breed}, got={breeds[0].get('name')}")
                else:
                    pass
                    
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ Cat API error for breed_id={breed_id}: {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ Cat API JSON error: {e}")
    
    return urls[:max_results]


# Dog/Cat API 品種名マッピング（APIレスポンスと照合用）
DOG_BREED_EXPECTED_NAMES = {
    "shiba": "shiba inu",
    "akita": "akita",
    "husky": "siberian husky",
    "malamute": "alaskan malamute",
    "samoyed": "samoyed",
    "golden_retriever": "golden retriever",
    "labrador": "labrador retriever",
    "german_shepherd": "german shepherd",
    "border_collie": "border collie",
    "australian_shepherd": "australian shepherd",
    "corgi": "pembroke welsh corgi",
    "pomeranian": "pomeranian",
    "chow_chow": "chow chow",
}

CAT_BREED_EXPECTED_NAMES = {
    "persian_cat": "persian",
    "british_shorthair": "british shorthair",
    "scottish_fold": "scottish fold",
    "maine_coon": "maine coon",
    "ragdoll": "ragdoll",
    "siamese": "siamese",
    "russian_blue": "russian blue",
}


def fetch_from_wikimedia_category(category: str, max_results: int = 50) -> List[str]:
    """Wikimedia Commonsのカテゴリから画像URLを取得（写真のみフィルタリング）
    
    寸法・MIME・ファイル名でフィルタリングし、
    実際の動物写真のみを返す。
    """
    urls = []
    continue_token = None
    
    try:
        url = f"{WIKIMEDIA_API}"
        
        while len(urls) < max_results:
            params = {
                "action": "query",
                "generator": "categorymembers",
                "gcmtitle": f"Category:{category}",
                "gcmtype": "file",
                "gcmlimit": 50,  # APIの最大値を使って効率化
                "prop": "imageinfo",
                "iiprop": "url|size|mime",  # サイズとMIME情報を取得
                "iiurlwidth": 800,
                "format": "json",
            }
            
            if continue_token:
                params.update(continue_token)
            
            response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
            
            if response.status_code == 200:
                data = response.json()
                pages = data.get("query", {}).get("pages", {})
                
                if not pages:
                    break
                    
                for page in pages.values():
                    title = page.get("title", "")
                    
                    # ファイル名で非写真コンテンツを除外
                    if not is_photo_filename(title):
                        continue
                    
                    for info in page.get("imageinfo", []):
                        mime = info.get("mime", "")
                        width = info.get("width", 0)
                        height = info.get("height", 0)
                        
                        # JPEG/PNG写真のみ（SVG, GIF等は除外）
                        if mime not in ("image/jpeg", "image/png"):
                            continue
                        
                        # 最低寸法チェック（400x300以上で実際の写真と判定）
                        if width < 400 or height < 300:
                            continue
                        
                        photo_url = info.get("thumburl") or info.get("url", "")
                        if photo_url:
                            urls.append(photo_url)
                
                if "continue" in data:
                    continue_token = data["continue"]
                else:
                    break
            else:
                break
                
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ Wikimedia Category error for '{category}': {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ Wikimedia JSON error: {e}")
    
    return urls[:max_results]


def fetch_from_wikimedia_search(search_term: str, max_results: int = 30) -> List[str]:
    """Wikimedia Commonsから画像URLを取得（テキスト検索、写真フィルタリング付き）"""
    urls = []
    continue_token = None
    
    try:
        url = f"{WIKIMEDIA_API}"
        
        while len(urls) < max_results:
            params = {
                "action": "query",
                "generator": "search",
                "gsrsearch": search_term,
                "gsrlimit": 50,
                "prop": "imageinfo",
                "iiprop": "url|size|mime",
                "iiurlwidth": 800,
                "format": "json",
            }

            if continue_token:
                params.update(continue_token)
            
            response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
            
            if response.status_code == 200:
                data = response.json()
                pages = data.get("query", {}).get("pages", {})
                
                if not pages:
                    break
                    
                for page in pages.values():
                    title = page.get("title", "")
                    if not is_photo_filename(title):
                        continue
                    
                    for info in page.get("imageinfo", []):
                        mime = info.get("mime", "")
                        width = info.get("width", 0)
                        height = info.get("height", 0)
                        
                        if mime not in ("image/jpeg", "image/png"):
                            continue
                        if width < 400 or height < 300:
                            continue
                        
                        photo_url = info.get("thumburl") or info.get("url", "")
                        if photo_url:
                            urls.append(photo_url)
                
                if "continue" in data:
                    continue_token = data["continue"]
                else:
                    break
            else:
                break
                        
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ Wikimedia Search error for '{search_term}': {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ Wikimedia JSON error: {e}")
    
    return urls[:max_results]


def fetch_from_flickr(search_term: str, max_results: int = 30) -> List[str]:
    """Flickrからクリエイティブコモンズ画像のURLを取得"""
    urls = []
    try:
        url = "https://www.flickr.com/services/rest/"
        params = {
            "method": "flickr.photos.search",
            "api_key": "5c0c78c507116987fe0a3a4f6380e0a8",
            "text": search_term,
            "safe_search": 1,
            "content_type": 1,
            "extras": "url_l,url_m",
            "per_page": min(max_results, 50),
            "format": "json",
            "nojsoncallback": 1,
        }
        
        response = requests.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            for photo in data.get("photos", {}).get("photo", []):
                photo_url = photo.get("url_l") or photo.get("url_m", "")
                if photo_url and is_valid_image_url(photo_url):
                    urls.append(photo_url)
                    
    except requests.exceptions.RequestException as e:
        print(f"    ⚠ Flickr error: {e}")
    except json.JSONDecodeError as e:
        print(f"    ⚠ Flickr JSON error: {e}")
    
    return urls


def get_image_urls(item: ItemInfo, max_results: int = 50) -> List[str]:
    """アイテムから画像URLを取得（正確性重視版）
    
    優先順位（正確性の高い順）:
    1. Wikimedia Category  - 分類学カテゴリから直接取得（最も正確）
    2. iNaturalist         - 研究グレード写真（taxon_idで種レベル指定）
    3. GBIF                - 生物多様性データ（species_keyで種レベル指定）
    4. Dog/Cat API         - 品種検証付き（breed名チェック、1ページのみ）
    5. Wikimedia Search    - テキスト検索（フォールバック）
    6. Flickr              - テキスト検索（最終手段）
    """
    urls = []
    sources_tried = []
    
    # 1. Wikimedia Category（最も正確・大量に取得可能）
    if item.wikimedia_category:
        print(f"    → Wikimedia Category ('{item.wikimedia_category}')...")
        cat_urls = fetch_from_wikimedia_category(item.wikimedia_category, max_results)
        urls.extend(cat_urls)
        sources_tried.append(f"Wikimedia Category({len(cat_urls)})")
        time.sleep(0.3)
    
    # 2. iNaturalist（研究グレード・分類学的に正確）
    if len(urls) < max_results and item.inaturalist_taxon_id:
        print(f"    → iNaturalist (taxon_id={item.inaturalist_taxon_id})...")
        inat_urls = fetch_from_inaturalist(item.inaturalist_taxon_id, max_results)
        urls.extend(inat_urls)
        sources_tried.append(f"iNaturalist({len(inat_urls)})")
        time.sleep(0.3)
    
    # 3. GBIF（生物多様性データベース）
    if len(urls) < max_results and item.gbif_species_key:
        print(f"    → GBIF (species_key={item.gbif_species_key})...")
        gbif_urls = fetch_from_gbif(item.gbif_species_key, max_results)
        urls.extend(gbif_urls)
        sources_tried.append(f"GBIF({len(gbif_urls)})")
        time.sleep(0.3)
    
    # 4. Dog/Cat API（品種検証付き・1ページのみ）
    if len(urls) < max_results and item.dog_api_breed_id:
        expected_name = DOG_BREED_EXPECTED_NAMES.get(item.id, item.id)
        print(f"    → Dog API (breed_id={item.dog_api_breed_id}, expect='{expected_name}')...")
        dog_urls = fetch_from_dog_api(item.dog_api_breed_id, expected_name, max_results=10)
        urls.extend(dog_urls)
        sources_tried.append(f"Dog API({len(dog_urls)})")
        time.sleep(0.3)
    
    if len(urls) < max_results and item.cat_api_breed_id:
        expected_name = CAT_BREED_EXPECTED_NAMES.get(item.id, item.id)
        print(f"    → Cat API (breed_id={item.cat_api_breed_id}, expect='{expected_name}')...")
        cat_urls = fetch_from_cat_api(item.cat_api_breed_id, expected_name, max_results=10)
        urls.extend(cat_urls)
        sources_tried.append(f"Cat API({len(cat_urls)})")
        time.sleep(0.3)
    
    # 5. Wikimedia Search（テキスト検索フォールバック）
    if len(urls) < max_results:
        print(f"    → Wikimedia Search (query='{item.query}')...")
        wm_urls = fetch_from_wikimedia_search(item.query, max_results)
        urls.extend(wm_urls)
        sources_tried.append(f"Wikimedia Search({len(wm_urls)})")
        time.sleep(0.3)
    
    # 6. Flickr（最終手段）
    if len(urls) < max_results:
        print(f"    → Flickr (query='{item.query}')...")
        fl_urls = fetch_from_flickr(item.query, max_results)
        urls.extend(fl_urls)
        sources_tried.append(f"Flickr({len(fl_urls)})")
        time.sleep(0.3)
    
    print(f"    取得URL数: {len(urls)} (ソース: {', '.join(sources_tried)})")
    
    # 重複を除去
    seen = set()
    unique_urls = []
    for url in urls:
        parsed = urlparse(url)
        normalized = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
        
        if normalized not in seen:
            seen.add(normalized)
            unique_urls.append(url)
    
    return unique_urls[:max_results]





# =============================================================================
# ダウンロード関数（改良版）
# =============================================================================

def download_image(url: str, save_path: Path, retry_count: int = 0) -> bool:
    """画像をダウンロードして保存（HEAD不要・GETのみ）
    
    Wikimediaのレート制限(429)対策でHEADリクエストを廃止。
    直接GETでダウンロードし、コンテンツを検証する。
    """
    try:
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=30)
        
        if response.status_code == 429:
            # レート制限: 長めに待機してリトライ
            if retry_count < MAX_RETRIES:
                delay = max(5.0, get_retry_delay(retry_count))
                print(f"      ⚠ Rate limited (429), waiting {delay:.0f}s...")
                time.sleep(delay)
                return download_image(url, save_path, retry_count + 1)
            return False
        
        if response.status_code != 200:
            if retry_count < MAX_RETRIES:
                delay = get_retry_delay(retry_count)
                time.sleep(delay)
                return download_image(url, save_path, retry_count + 1)
            return False
        
        content = response.content
        
        # コンテンツ検証（最小5KB = 実際の写真）
        if not is_valid_image_content(content, min_size=5000):
            return False
        
        # 保存
        save_path.write_bytes(content)
        return True
        
    except requests.exceptions.Timeout:
        if retry_count < MAX_RETRIES:
            time.sleep(get_retry_delay(retry_count))
            return download_image(url, save_path, retry_count + 1)
    except requests.exceptions.RequestException:
        pass
    except IOError:
        pass
    
    return False


def download_images_sequential(urls: List[str], save_dir: Path, prefix: str = "", existing_hashes: set = None) -> List[Path]:
    """順次ダウンロード（レート制限対策・各画像間に遅延）
    
    Wikimediaのレート制限を避けるため、並列ではなく順次ダウンロード。
    各画像間に0.5秒の遅延を入れる。
    """
    downloaded_paths = []
    used_hashes = existing_hashes.copy() if existing_hashes else set()
    
    for i, url in enumerate(urls):
        ext = Path(urlparse(url).path).suffix or ".jpg"
        if not ext.startswith("."):
            ext = ".jpg"
        # 拡張子の正規化
        if ext.lower() not in (".jpg", ".jpeg", ".png", ".webp"):
            ext = ".jpg"
        save_path = save_dir / f"{prefix}{i+1:03d}{ext}"
        
        if download_image(url, save_path):
            # ダウンロードした画像のハッシュを確認（重複防止）
            try:
                content = save_path.read_bytes()
                content_hash = hashlib.md5(content).hexdigest()[:16]
                if content_hash in used_hashes:
                    save_path.unlink()
                    continue
                used_hashes.add(content_hash)
            except:
                pass
            downloaded_paths.append(save_path)
        
        # レート制限対策: 各ダウンロード間に0.5秒待機
        time.sleep(0.5)
    
    return downloaded_paths


# =============================================================================
# メイン処理
# =============================================================================

def download_genre(genre_id: str, images_per_type: int = IMAGES_PER_TYPE):
    """指定ジャンルの画像をダウンロード"""
    if genre_id not in GENRES:
        print(f"Unknown genre: {genre_id}")
        print(f"Available genres: {', '.join(GENRES.keys())}")
        return
    
    genre = GENRES[genre_id]
    genre_dir = OUTPUT_DIR / genre_id
    genre_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"\n{'='*60}")
    print(f"ジャンル: {genre.display_name} ({genre_id})")
    print(f"説明: {genre.description}")
    print(f"アイテム数: {len(genre.items)}")
    print(f"目標画像数: 各タイプ {images_per_type} 枚")
    print(f"{'='*60}")
    
    manifest = {
        "version": 1,
        "genre": genre_id,
        "display_name": genre.display_name,
        "description": genre.description,
        "types": {},
        "similar_pairs": [{"id1": p.id1, "id2": p.id2} for p in genre.similar_pairs],
    }
    
    for item in genre.items:
        item_dir = genre_dir / item.id
        item_dir.mkdir(exist_ok=True)
        
        print(f"\n  [{item.id}] {item.name_ja}")
        
        # 既存の画像を確認
        existing = list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp"))
        if len(existing) >= images_per_type:
            print(f"    ✓ Already have {len(existing)} images, skipping")
            manifest["types"][item.id] = {
                "display_name": item.name_ja,
                "count": len(existing),
            }
            continue
        
        # 画像URLを取得（目標枚数の2倍まで取得してフィルタリング用に確保）
        needed = images_per_type - len(existing)
        urls = get_image_urls(item, max_results=needed * 2)
        
        if not urls:
            print(f"    ✗ WARNING: No URLs found!")
            manifest["types"][item.id] = {
                "display_name": item.name_ja,
                "count": len(existing),
            }
            continue
        
        # 既存の画像のハッシュを取得（重複防止）
        existing_hashes = set()
        for f in existing:
            try:
                existing_hashes.add(hashlib.md5(f.read_bytes()).hexdigest()[:16])
            except:
                pass
        
        # 目標枚数分だけダウンロード
        download_count = min(len(urls), needed)
        print(f"    Downloading up to {download_count} images (目標: {images_per_type}枚)...")
        downloaded = download_images_sequential(urls[:download_count], item_dir, prefix="", existing_hashes=existing_hashes)
        
        # ダウンロード結果を確認
        final_count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
        
        manifest["types"][item.id] = {
            "display_name": item.name_ja,
            "count": final_count,
        }
        print(f"    ✓ Total: {final_count} images downloaded")
        
        # APIレート制限対策
        time.sleep(1)
    
    # manifest.jsonを保存
    manifest_path = genre_dir / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    
    print(f"\n✓ manifest.json saved: {manifest_path}")
    print(f"✓ Genre '{genre_id}' complete!")


def show_genre_stats(genre_id: str):
    """ジャンルの画像統計を表示"""
    if genre_id not in GENRES:
        print(f"Unknown genre: {genre_id}")
        return
    
    genre = GENRES[genre_id]
    genre_dir = OUTPUT_DIR / genre_id
    
    if not genre_dir.exists():
        print(f"ジャンルフォルダが存在しません: {genre_dir}")
        return
    
    print(f"\n{'='*60}")
    print(f"ジャンル: {genre.display_name} ({genre_id})")
    print(f"{'='*60}")
    
    total_images = 0
    min_count = float('inf')
    max_count = 0
    
    for item in genre.items:
        item_dir = genre_dir / item.id
        if item_dir.exists():
            count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
        else:
            count = 0
        
        total_images += count
        min_count = min(min_count, count)
        max_count = max(max_count, count)
        
        status = "✓" if count >= 10 else "△" if count > 0 else "✗"
        print(f"  {status} {item.id:20} : {count:3} 枚  ({item.name_ja})")
    
    print(f"{'='*60}")
    print(f"合計: {total_images} 枚")
    print(f"最小: {min_count if min_count != float('inf') else 0} 枚, 最大: {max_count} 枚")
    
    return min_count if min_count != float('inf') else 0


def refill_genre(genre_id: str, target_count: int):
    """ジャンルの画像を目標枚数まで補填ダウンロード"""
    if genre_id not in GENRES:
        print(f"Unknown genre: {genre_id}")
        return
    
    genre = GENRES[genre_id]
    genre_dir = OUTPUT_DIR / genre_id
    
    if not genre_dir.exists():
        print(f"ジャンルフォルダが存在しません。先にダウンロードを実行してください。")
        return
    
    print(f"\n{'='*60}")
    print(f"補填ダウンロード: {genre.display_name} ({genre_id})")
    print(f"目標枚数: 各タイプ {target_count} 枚")
    print(f"{'='*60}")
    
    for item in genre.items:
        item_dir = genre_dir / item.id
        item_dir.mkdir(exist_ok=True)
        
        # 既存の画像を確認
        existing_files = sorted(item_dir.glob("*.jpg")) + sorted(item_dir.glob("*.png")) + sorted(item_dir.glob("*.webp"))
        current_count = len(existing_files)
        
        if current_count >= target_count:
            print(f"\n  [{item.id}] {item.name_ja}: {current_count}枚 → スキップ")
            continue
        
        needed = target_count - current_count
        print(f"\n  [{item.id}] {item.name_ja}: {current_count}枚 → {needed}枚不足")
        
        # 既存のファイルのハッシュを取得
        existing_hashes = set()
        for f in existing_files:
            try:
                existing_hashes.add(hashlib.md5(f.read_bytes()).hexdigest()[:16])
            except:
                pass
        
        # 画像URLを取得（多めに取得）
        urls = get_image_urls(item, max_results=needed * 3)
        
        if not urls:
            print(f"    WARNING: No URLs found!")
            continue
        
        # 重複を除外
        filtered_urls = []
        for url in urls:
            try:
                response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=5, stream=True)
                if response.status_code == 200:
                    content = response.content
                    content_hash = hashlib.md5(content).hexdigest()[:16]
                    if content_hash not in existing_hashes:
                        filtered_urls.append(url)
                        existing_hashes.add(content_hash)
            except:
                pass
        
        # 並列ダウンロード
        print(f"    Downloading {len(filtered_urls)} images...")
        downloaded = download_images_sequential(filtered_urls[:needed * 2], item_dir, prefix="")
        
        final_count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
        print(f"    補填完了: +{final_count - current_count}枚 (計 {final_count}枚)")
        
        time.sleep(1)
    
    # manifest.jsonを更新
    update_manifest(genre_id)
    print(f"\n✓ 補填ダウンロード完了!")


def update_manifest(genre_id: str):
    """manifest.jsonを現在の状態に更新"""
    if genre_id not in GENRES:
        return
    
    genre = GENRES[genre_id]
    genre_dir = OUTPUT_DIR / genre_id
    
    manifest = {
        "version": 1,
        "genre": genre_id,
        "display_name": genre.display_name,
        "description": genre.description,
        "types": {},
        "similar_pairs": [{"id1": p.id1, "id2": p.id2} for p in genre.similar_pairs],
    }
    
    for item in genre.items:
        item_dir = genre_dir / item.id
        if item_dir.exists():
            count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
        else:
            count = 0
        
        manifest["types"][item.id] = {
            "display_name": item.name_ja,
            "count": count,
        }
    
    manifest_path = genre_dir / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)


def list_genres():
    """利用可能なジャンル一覧を表示"""
    print("\n利用可能なジャンル:")
    print("-" * 50)
    genre_list = list(GENRES.items())
    for i, (genre_id, genre) in enumerate(genre_list, 1):
        print(f"  {i:2}. {genre_id:15} - {genre.display_name} ({len(genre.items)} types)")
    print("-" * 50)
    return genre_list


def select_genre():
    """番号またはIDでジャンルを選択"""
    genre_list = list_genres()
    selection = input("\nジャンル番号またはIDを入力: ").strip()
    
    # 番号で選択
    if selection.isdigit():
        idx = int(selection) - 1
        if 0 <= idx < len(genre_list):
            return genre_list[idx][0]
        else:
            print(f"無効な番号です（1-{len(genre_list)}の範囲で入力してください）")
            return None
    # IDで選択
    elif selection in GENRES:
        return selection
    else:
        print(f"無効な選択です: {selection}")
        return None


def download_all_genres(images_per_type: int = IMAGES_PER_TYPE):
    """全ジャンルをダウンロード"""
    for genre_id in GENRES.keys():
        download_genre(genre_id, images_per_type)


def create_genre_zip(genre_id: str) -> Optional[Path]:
    """ジャンルフォルダからZIPファイルを作成"""
    if genre_id not in GENRES:
        print(f"Unknown genre: {genre_id}")
        return None
    
    genre = GENRES[genre_id]
    genre_dir = OUTPUT_DIR / genre_id
    
    if not genre_dir.exists():
        print(f"ジャンルフォルダが存在しません: {genre_dir}")
        print("先にダウンロードを実行してください")
        return None
    
    # 画像数をカウント
    image_count = 0
    for item_dir in genre_dir.iterdir():
        if item_dir.is_dir():
            image_count += len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
    
    if image_count == 0:
        print(f"画像がありません: {genre_dir}")
        return None
    
    # ZIPファイル名
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_name = f"{genre_id}_{timestamp}.zip"
    zip_path = OUTPUT_DIR / zip_name
    
    print(f"\nZIP作成中: {zip_name}")
    print(f"  画像数: {image_count}")
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        # manifest.jsonを追加
        manifest_path = genre_dir / "manifest.json"
        if manifest_path.exists():
            zf.write(manifest_path, "manifest.json")
        
        # 各タイプのフォルダと画像を追加
        for item_dir in sorted(genre_dir.iterdir()):
            if item_dir.is_dir():
                item_id = item_dir.name
                for img_file in sorted(item_dir.glob("*")):
                    if img_file.suffix.lower() in ['.jpg', '.jpeg', '.png', '.webp']:
                        arcname = f"{item_id}/{img_file.name}"
                        zf.write(img_file, arcname)
                        print(f"    追加: {arcname}")
    
    print(f"\n✓ ZIP作成完了: {zip_path}")
    print(f"  サイズ: {zip_path.stat().st_size / 1024 / 1024:.2f} MB")
    
    return zip_path


def create_all_genre_zips():
    """全ジャンルのZIPを作成"""
    for genre_id in GENRES.keys():
        genre_dir = OUTPUT_DIR / genre_id
        if genre_dir.exists():
            create_genre_zip(genre_id)
        else:
            print(f"スキップ（未ダウンロード）: {genre_id}")


def main():
    """メイン関数"""
    print("="*60)
    print("  テストセット画像ダウンローダー（改良版）")
    print("  iNaturalist / GBIF / Dog API / Cat API / Wikimedia / Flickr")
    print("="*60)
    
    OUTPUT_DIR.mkdir(exist_ok=True)
    
    while True:
        print("\n【メニュー】")
        print("1. ジャンル一覧を表示")
        print("2. 特定のジャンルをダウンロード")
        print("3. 全ジャンルをダウンロード")
        print("4. 統計を表示（画像枚数確認）")
        print("5. 補填ダウンロード（不足分を追加）")
        print("6. 特定のジャンルをZIP化")
        print("7. 全ジャンルをZIP化")
        print("0. 終了")
        
        choice = input("\n番号を入力: ").strip()
        
        if choice == "1":
            list_genres()
        elif choice == "2":
            genre_id = select_genre()
            if genre_id:
                num = input(f"各タイプの画像数 (デフォルト: {IMAGES_PER_TYPE}): ").strip()
                num = int(num) if num else IMAGES_PER_TYPE
                download_genre(genre_id, num)
        elif choice == "3":
            num = input(f"各タイプの画像数 (デフォルト: {IMAGES_PER_TYPE}): ").strip()
            num = int(num) if num else IMAGES_PER_TYPE
            download_all_genres(num)
        elif choice == "4":
            genre_id = select_genre()
            if genre_id:
                show_genre_stats(genre_id)
        elif choice == "5":
            genre_id = select_genre()
            if genre_id:
                # 現在の状態を表示
                min_count = show_genre_stats(genre_id)
                print(f"\n現在の最小枚数: {min_count}枚")
                target = input(f"目標枚数を入力 (デフォルト: {IMAGES_PER_TYPE}): ").strip()
                target = int(target) if target else IMAGES_PER_TYPE
                refill_genre(genre_id, target)
        elif choice == "6":
            genre_id = select_genre()
            if genre_id:
                create_genre_zip(genre_id)
        elif choice == "7":
            create_all_genre_zips()
        elif choice == "0":
            print("終了します")
            break
        else:
            print("無効な選択です")


if __name__ == "__main__":
    main()
