"""
信頼性の高い画像ソースからテストセット用画像をダウンロード

使用API（優先順）:
- iNaturalist: 野生動物（研究グレードの写真）
- GBIF: 生物多様性データ（自然史博物館等の写真）
- The Dog API: 犬種
- The Cat API: 猫種
- Unsplash: 高品質写真（車、風景等）
- Wikimedia Commons: その他（ロゴ等）

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


# =============================================================================
# 設定
# =============================================================================

USER_AGENT = "SimilarityQuiz/1.0 (Educational Research App - Japanese High School)"
OUTPUT_DIR = Path("test_sets")
IMAGES_PER_TYPE = 20  # 各種類ごとにダウンロードする画像数

# API URLs
INATURALIST_API = "https://api.inaturalist.org/v1"
GBIF_API = "https://api.gbif.org/v1"
DOG_API = "https://api.thedogapi.com/v1"
CAT_API = "https://api.thecatapi.com/v1"
WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"


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

# Dog API breed_id マッピング
DOG_BREED_IDS = {
    "shiba": 136, "akita": 5, "husky": 141, "malamute": 5,
    "samoyed": 130, "golden_retriever": 63, "labrador": 82,
    "german_shepherd": 60, "border_collie": 37,
    "australian_shepherd": 13, "corgi": 180, "pomeranian": 109, "chow_chow": 48,
}

# Cat API breed_id マッピング
CAT_BREED_IDS = {
    "persian_cat": "pers", "british_shorthair": "bsho",
    "scottish_fold": "sfol", "maine_coon": "mcoo",
    "ragdoll": "ragd", "siamese": "siam", "russian_blue": "rblu",
}


# =============================================================================
# ジャンル定義（android-appと同じ）
# =============================================================================

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
# 画像取得関数
# =============================================================================

def fetch_from_inaturalist(taxon_id: int, max_results: int = 30) -> List[str]:
    """iNaturalist APIから画像URLを取得"""
    urls = []
    try:
        url = f"{INATURALIST_API}/observations?taxon_id={taxon_id}&photos=true&quality_grade=research&per_page={max_results}&order=desc&order_by=votes"
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            for obs in data.get("results", []):
                for photo in obs.get("photos", []):
                    photo_url = photo.get("url", "").replace("square", "medium")
                    if photo_url and is_valid_image_url(photo_url):
                        urls.append(photo_url)
    except Exception as e:
        print(f"  iNaturalist error for taxon_id={taxon_id}: {e}")
    
    return urls


def fetch_from_gbif(species_key: int, max_results: int = 30) -> List[str]:
    """GBIF APIから画像URLを取得"""
    urls = []
    try:
        url = f"{GBIF_API}/occurrence/search?speciesKey={species_key}&mediaType=StillImage&limit={max_results}"
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            for occ in data.get("results", []):
                for media in occ.get("media", []):
                    photo_url = media.get("identifier", "")
                    if photo_url and is_valid_image_url(photo_url):
                        urls.append(photo_url)
    except Exception as e:
        print(f"  GBIF error for species_key={species_key}: {e}")
    
    return urls


def fetch_from_dog_api(breed_id: int, max_results: int = 20) -> List[str]:
    """The Dog APIから画像URLを取得"""
    urls = []
    try:
        url = f"{DOG_API}/images/search?breed_ids={breed_id}&limit={max_results}"
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            for item in data:
                photo_url = item.get("url", "")
                if photo_url and is_valid_image_url(photo_url):
                    urls.append(photo_url)
    except Exception as e:
        print(f"  Dog API error for breed_id={breed_id}: {e}")
    
    return urls


def fetch_from_cat_api(breed_id: str, max_results: int = 20) -> List[str]:
    """The Cat APIから画像URLを取得"""
    urls = []
    try:
        url = f"{CAT_API}/images/search?breed_ids={breed_id}&limit={max_results}"
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            for item in data:
                photo_url = item.get("url", "")
                if photo_url and is_valid_image_url(photo_url):
                    urls.append(photo_url)
    except Exception as e:
        print(f"  Cat API error for breed_id={breed_id}: {e}")
    
    return urls


def fetch_from_wikimedia(search_term: str, max_results: int = 20) -> List[str]:
    """Wikimedia Commonsから画像URLを取得"""
    urls = []
    try:
        url = f"{WIKIMEDIA_API}?action=query&generator=search&gsrsearch={search_term}&gsrlimit={max_results}&prop=imageinfo&iiprop=url&iiurlwidth=800&format=json"
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            pages = data.get("query", {}).get("pages", {})
            for page in pages.values():
                for info in page.get("imageinfo", []):
                    photo_url = info.get("thumburl") or info.get("url", "")
                    if photo_url and is_valid_image_url(photo_url):
                        urls.append(photo_url)
    except Exception as e:
        print(f"  Wikimedia error for '{search_term}': {e}")
    
    return urls


def is_valid_image_url(url: str) -> bool:
    """画像URLが有効かチェック"""
    lower = url.lower()
    return ((".jpg" in lower or ".jpeg" in lower or ".png" in lower or ".webp" in lower)
            and "placeholder" not in lower and "default" not in lower)


def get_image_urls(item: ItemInfo, max_results: int = 30) -> List[str]:
    """アイテムから画像URLを取得（複数APIを試行）"""
    urls = []
    
    # 1. iNaturalist
    if item.inaturalist_taxon_id:
        print(f"    Trying iNaturalist (taxon_id={item.inaturalist_taxon_id})...")
        urls.extend(fetch_from_inaturalist(item.inaturalist_taxon_id, max_results))
    
    # 2. GBIF
    if len(urls) < max_results // 2 and item.gbif_species_key:
        print(f"    Trying GBIF (species_key={item.gbif_species_key})...")
        urls.extend(fetch_from_gbif(item.gbif_species_key, max_results))
    
    # 3. Dog API
    if len(urls) < max_results // 2 and item.dog_api_breed_id:
        print(f"    Trying Dog API (breed_id={item.dog_api_breed_id})...")
        urls.extend(fetch_from_dog_api(item.dog_api_breed_id, max_results))
    
    # 4. Cat API
    if len(urls) < max_results // 2 and item.cat_api_breed_id:
        print(f"    Trying Cat API (breed_id={item.cat_api_breed_id})...")
        urls.extend(fetch_from_cat_api(item.cat_api_breed_id, max_results))
    
    # 5. Wikimedia（フォールバック）
    if len(urls) < max_results // 2:
        print(f"    Trying Wikimedia (query='{item.query}')...")
        urls.extend(fetch_from_wikimedia(item.query, max_results))
    
    # 重複を除去
    seen = set()
    unique_urls = []
    for url in urls:
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)
    
    return unique_urls[:max_results]


def download_image(url: str, save_path: Path) -> bool:
    """画像をダウンロードして保存"""
    try:
        response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=15)
        if response.status_code == 200 and len(response.content) > 1000:
            # 画像形式を確認
            content_type = response.headers.get("content-type", "")
            if "image" in content_type or is_valid_image_url(url):
                save_path.write_bytes(response.content)
                return True
    except Exception as e:
        print(f"    Download failed: {e}")
    return False


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
        existing = list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png"))
        if len(existing) >= images_per_type:
            print(f"    Already have {len(existing)} images, skipping")
            manifest["types"][item.id] = {
                "display_name": item.name_ja,
                "count": len(existing),
            }
            continue
        
        # 画像URLを取得
        urls = get_image_urls(item, max_results=images_per_type * 2)
        print(f"    Found {len(urls)} URLs")
        
        if not urls:
            print(f"    WARNING: No URLs found!")
            manifest["types"][item.id] = {
                "display_name": item.name_ja,
                "count": 0,
            }
            continue
        
        # ダウンロード
        downloaded = len(existing)
        for i, url in enumerate(urls):
            if downloaded >= images_per_type:
                break
            
            save_path = item_dir / f"{downloaded + 1:03d}.jpg"
            if download_image(url, save_path):
                downloaded += 1
                print(f"    Downloaded: {save_path.name}")
            
            time.sleep(0.3)  # レート制限対策
        
        manifest["types"][item.id] = {
            "display_name": item.name_ja,
            "count": downloaded,
        }
        print(f"    Total: {downloaded} images")
    
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
            count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")))
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
        existing_files = sorted(item_dir.glob("*.jpg")) + sorted(item_dir.glob("*.png"))
        current_count = len(existing_files)
        
        if current_count >= target_count:
            print(f"\n  [{item.id}] {item.name_ja}: {current_count}枚 → スキップ")
            continue
        
        needed = target_count - current_count
        print(f"\n  [{item.id}] {item.name_ja}: {current_count}枚 → {needed}枚不足")
        
        # 既存のファイル名から次の番号を決定
        max_num = 0
        for f in existing_files:
            try:
                num = int(f.stem)
                max_num = max(max_num, num)
            except ValueError:
                pass
        
        # 画像URLを取得（多めに取得）
        urls = get_image_urls(item, max_results=needed * 3)
        print(f"    Found {len(urls)} URLs")
        
        if not urls:
            print(f"    WARNING: No URLs found!")
            continue
        
        # 既存の画像のハッシュを取得（重複防止）
        existing_hashes = set()
        for f in existing_files:
            try:
                existing_hashes.add(hashlib.md5(f.read_bytes()).hexdigest()[:16])
            except:
                pass
        
        # ダウンロード
        downloaded = 0
        next_num = max_num + 1
        
        for url in urls:
            if downloaded >= needed:
                break
            
            # 一時的にダウンロードしてハッシュチェック
            try:
                response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=15)
                if response.status_code != 200 or len(response.content) < 1000:
                    continue
                
                # 重複チェック
                content_hash = hashlib.md5(response.content).hexdigest()[:16]
                if content_hash in existing_hashes:
                    print(f"    スキップ（重複）: {url[:50]}...")
                    continue
                
                # 保存
                save_path = item_dir / f"{next_num:03d}.jpg"
                save_path.write_bytes(response.content)
                existing_hashes.add(content_hash)
                
                downloaded += 1
                next_num += 1
                print(f"    Downloaded: {save_path.name}")
                
            except Exception as e:
                print(f"    Error: {e}")
            
            time.sleep(0.3)
        
        print(f"    補填完了: +{downloaded}枚 (計 {current_count + downloaded}枚)")
    
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
            count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")))
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
    """利用可能なジャンル一覧を表示（番号付き）"""
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
            return genre_list[idx][0]  # genre_id を返す
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
            image_count += len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")))
    
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
                    if img_file.suffix.lower() in ['.jpg', '.jpeg', '.png']:
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
    print("  テストセット画像ダウンローダー")
    print("  (iNaturalist / GBIF / Dog API / Cat API / Wikimedia)")
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
