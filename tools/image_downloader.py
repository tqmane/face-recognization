"""
画像ダウンローダー - 判別テスト用
似たものの画像を収集するツール

フォルダ構造:
  downloaded_images/
  ├── same/          # 同じもの（チーター×チーター など）
  ├── different/     # 違うもの（チーター×ヒョウ など）
  ├── twins/         # 双子（一緒に写っている）
  └── similar_people/# 似ている人（一緒に写っている）
"""

import tempfile
import shutil
import random
from pathlib import Path
from PIL import Image


def create_folders():
    """画像を保存するフォルダを作成"""
    categories = [
        "same",
        "different",
        "twins",
        "similar_people",
        "temp_a",
        "temp_b",
    ]
    
    base_path = Path("downloaded_images")
    base_path.mkdir(exist_ok=True)
    
    for category in categories:
        (base_path / category).mkdir(exist_ok=True)
    
    print("✓ フォルダを作成しました")
    return base_path


def combine_images_side_by_side(img1_path, img2_path, output_path):
    """2枚の画像を横に並べて1枚の比較画像を作成"""
    try:
        img1 = Image.open(img1_path)
        img2 = Image.open(img2_path)
        
        target_height = 400
        
        ratio1 = target_height / img1.height
        ratio2 = target_height / img2.height
        
        new_size1 = (int(img1.width * ratio1), target_height)
        new_size2 = (int(img2.width * ratio2), target_height)
        
        img1 = img1.resize(new_size1, Image.Resampling.LANCZOS)
        img2 = img2.resize(new_size2, Image.Resampling.LANCZOS)
        
        gap = 20
        combined_width = img1.width + gap + img2.width
        combined_height = target_height
        
        combined = Image.new('RGB', (combined_width, combined_height), (255, 255, 255))
        combined.paste(img1, (0, 0))
        combined.paste(img2, (img1.width + gap, 0))
        
        combined.save(output_path, quality=95)
        return True
    except Exception as e:
        print(f"  ✗ 画像合成失敗: {e}")
        return False


def download_with_icrawler(query, save_dir, num_images=10):
    """icrawlerを使って画像を検索・ダウンロード"""
    try:
        from icrawler.builtin import BingImageCrawler
        
        temp_dir = Path(tempfile.mkdtemp())
        
        print(f"  '{query}' を検索中...")
        
        crawler = BingImageCrawler(
            storage={'root_dir': str(temp_dir)},
            feeder_threads=1,
            parser_threads=1,
            downloader_threads=2
        )
        
        crawler.crawl(keyword=query, max_num=num_images)
        
        save_path = Path(save_dir)
        save_path.mkdir(parents=True, exist_ok=True)
        
        saved_count = 0
        existing_files = list(save_path.glob("*.jpg")) + list(save_path.glob("*.png"))
        start_index = len(existing_files) + 1
        
        for img_file in sorted(temp_dir.glob("*")):
            if saved_count >= num_images:
                break
            
            new_name = f"{start_index + saved_count:03d}.jpg"
            dest_path = save_path / new_name
            shutil.copy(img_file, dest_path)
            saved_count += 1
        
        shutil.rmtree(temp_dir)
        print(f"  ✓ {saved_count}枚を保存しました")
        return saved_count
    except ImportError:
        print("  icrawlerがインストールされていません")
        return 0
    except Exception as e:
        print(f"  エラー: {e}")
        return 0


def clear_temp_folders():
    """一時フォルダをクリア"""
    base_path = Path("downloaded_images")
    for folder in ["temp_a", "temp_b"]:
        temp_path = base_path / folder
        if temp_path.exists():
            for f in temp_path.glob("*"):
                f.unlink()


def create_same_images(subject_name, queries, output_name, num_pairs=5):
    """同じもの同士の比較画像を作成"""
    base_path = Path("downloaded_images")
    temp_a = base_path / "temp_a"
    output_path = base_path / "same"
    
    clear_temp_folders()
    
    print(f"\n[同じもの] {subject_name} × {subject_name}")
    print("-" * 40)
    
    print(f"画像をダウンロード中...")
    for query in queries:
        download_with_icrawler(query, temp_a, num_images=num_pairs * 2 + 5)
    
    print(f"画像を合成中...")
    images = list(temp_a.glob("*.jpg"))
    random.shuffle(images)
    
    existing = list(output_path.glob(f"{output_name}_*.jpg"))
    start_index = len(existing) + 1
    
    created = 0
    for i in range(0, min(len(images) - 1, num_pairs * 2), 2):
        if created >= num_pairs:
            break
        
        img_a = images[i]
        img_b = images[i + 1]
        output_file = output_path / f"{output_name}_{start_index + created:03d}.jpg"
        
        if combine_images_side_by_side(img_a, img_b, output_file):
            created += 1
            print(f"  ✓ 作成: {output_file.name}")
    
    print(f"\n✓ {created}枚の「同じもの」画像を作成: {output_path}")
    return created


def create_different_images(name_a, queries_a, name_b, queries_b, output_name, num_pairs=5):
    """違うもの同士の比較画像を作成"""
    base_path = Path("downloaded_images")
    temp_a = base_path / "temp_a"
    temp_b = base_path / "temp_b"
    output_path = base_path / "different"
    
    clear_temp_folders()
    
    print(f"\n[違うもの] {name_a} × {name_b}")
    print("-" * 40)
    
    print(f"1つ目（{name_a}）をダウンロード中...")
    for query in queries_a:
        download_with_icrawler(query, temp_a, num_images=num_pairs + 3)
    
    print(f"2つ目（{name_b}）をダウンロード中...")
    for query in queries_b:
        download_with_icrawler(query, temp_b, num_images=num_pairs + 3)
    
    print(f"画像を合成中...")
    
    images_a = sorted(temp_a.glob("*.jpg"))[:num_pairs]
    images_b = sorted(temp_b.glob("*.jpg"))[:num_pairs]
    
    existing = list(output_path.glob(f"{output_name}_*.jpg"))
    start_index = len(existing) + 1
    
    created = 0
    for i, (img_a, img_b) in enumerate(zip(images_a, images_b)):
        output_file = output_path / f"{output_name}_{start_index + i:03d}.jpg"
        
        if combine_images_side_by_side(img_a, img_b, output_file):
            created += 1
            print(f"  ✓ 作成: {output_file.name}")
    
    print(f"\n✓ {created}枚の「違うもの」画像を作成: {output_path}")
    return created


# 動物データ
ANIMAL_DATA = {
    "cheetah": {"name_ja": "チーター", "queries": ["cheetah face close up", "cheetah portrait photo"]},
    "leopard": {"name_ja": "ヒョウ", "queries": ["leopard face close up", "leopard portrait photo"]},
    "jaguar": {"name_ja": "ジャガー", "queries": ["jaguar face close up", "jaguar portrait photo"]},
    "shiba": {"name_ja": "柴犬", "queries": ["shiba inu face", "shiba inu portrait"]},
    "akita": {"name_ja": "秋田犬", "queries": ["akita dog face", "akita inu portrait"]},
    "husky": {"name_ja": "ハスキー", "queries": ["siberian husky face", "husky portrait"]},
    "malamute": {"name_ja": "マラミュート", "queries": ["alaskan malamute face", "malamute portrait"]},
    "wolf": {"name_ja": "オオカミ", "queries": ["wolf face close up", "gray wolf portrait"]},
    "raccoon": {"name_ja": "アライグマ", "queries": ["raccoon face close up", "raccoon portrait"]},
    "tanuki": {"name_ja": "タヌキ", "queries": ["tanuki face", "japanese raccoon dog portrait"]},
    "crow": {"name_ja": "カラス", "queries": ["crow bird close up", "crow portrait"]},
    "raven": {"name_ja": "ワタリガラス", "queries": ["raven bird close up", "raven portrait"]},
    "sea_lion": {"name_ja": "アシカ", "queries": ["sea lion face close up", "sea lion portrait"]},
    "seal": {"name_ja": "アザラシ", "queries": ["seal face close up", "seal portrait"]},
    "lion": {"name_ja": "ライオン", "queries": ["lion face close up", "lion portrait"]},
    "tiger": {"name_ja": "トラ", "queries": ["tiger face close up", "tiger portrait"]},
    "alligator": {"name_ja": "ワニ", "queries": ["alligator face close up", "alligator portrait"]},
    "crocodile": {"name_ja": "クロコダイル", "queries": ["crocodile face close up", "crocodile portrait"]},
}

SIMILAR_PAIRS = [
    ("cheetah", "leopard"),
    ("jaguar", "leopard"),
    ("shiba", "akita"),
    ("husky", "malamute"),
    ("wolf", "husky"),
    ("raccoon", "tanuki"),
    ("crow", "raven"),
    ("sea_lion", "seal"),
    ("lion", "tiger"),
    ("alligator", "crocodile"),
]


def download_animal_test_set():
    """動物の判別テスト用画像セットをダウンロード"""
    print("\n" + "="*50)
    print("動物判別テスト用画像ダウンロード")
    print("="*50)
    
    print("\n【似ているペア一覧】")
    for i, (a, b) in enumerate(SIMILAR_PAIRS, 1):
        name_a = ANIMAL_DATA[a]["name_ja"]
        name_b = ANIMAL_DATA[b]["name_ja"]
        print(f"  {i}. {name_a} vs {name_b}")
    
    print("\n選択してください:")
    print("1. 特定のペアを選ぶ")
    print("2. 全ペアをダウンロード")
    print("3. カスタム（自分で入力）")
    
    choice = input("\n番号: ").strip()
    
    if choice == "1":
        pair_num = int(input("ペア番号 (1-10): ")) - 1
        if 0 <= pair_num < len(SIMILAR_PAIRS):
            a, b = SIMILAR_PAIRS[pair_num]
            num = int(input("各カテゴリの枚数 (推奨: 3-5): ") or "3")
            
            data_a = ANIMAL_DATA[a]
            data_b = ANIMAL_DATA[b]
            
            create_same_images(data_a["name_ja"], data_a["queries"], f"{a}_same", num)
            create_same_images(data_b["name_ja"], data_b["queries"], f"{b}_same", num)
            create_different_images(
                data_a["name_ja"], data_a["queries"],
                data_b["name_ja"], data_b["queries"],
                f"{a}_{b}_diff", num
            )
    
    elif choice == "2":
        num = int(input("各カテゴリの枚数 (推奨: 2-3): ") or "2")
        
        for a, b in SIMILAR_PAIRS:
            data_a = ANIMAL_DATA[a]
            data_b = ANIMAL_DATA[b]
            
            print(f"\n{'='*50}")
            print(f"処理中: {data_a['name_ja']} vs {data_b['name_ja']}")
            print('='*50)
            
            create_same_images(data_a["name_ja"], data_a["queries"], f"{a}_same", num)
            create_same_images(data_b["name_ja"], data_b["queries"], f"{b}_same", num)
            create_different_images(
                data_a["name_ja"], data_a["queries"],
                data_b["name_ja"], data_b["queries"],
                f"{a}_{b}_diff", num
            )
    
    elif choice == "3":
        name_a = input("1つ目の動物（英語、例: cat）: ").strip()
        name_b = input("2つ目の動物（英語、例: dog）: ").strip()
        num = int(input("各カテゴリの枚数: ") or "3")
        
        queries_a = [f"{name_a} face close up", f"{name_a} portrait"]
        queries_b = [f"{name_b} face close up", f"{name_b} portrait"]
        
        create_same_images(name_a, queries_a, f"{name_a}_same", num)
        create_same_images(name_b, queries_b, f"{name_b}_same", num)
        create_different_images(name_a, queries_a, name_b, queries_b, f"{name_a}_{name_b}_diff", num)


def download_people_images():
    """人物の画像をダウンロード"""
    print("\n" + "="*50)
    print("人物画像ダウンロード")
    print("="*50)
    
    print("\n選択してください:")
    print("1. 双子（一緒に写っている写真）")
    print("2. 似ている人・そっくりさん")
    print("3. 両方ダウンロード")
    
    choice = input("\n番号: ").strip()
    base_path = Path("downloaded_images")
    
    if choice in ["1", "3"]:
        print("\n[双子の画像]")
        queries = [
            "identical twins together photo",
            "twin sisters portrait together",
            "twin brothers portrait together",
        ]
        num = int(input("双子の画像枚数 (推奨: 5-10): ") or "5")
        output_dir = base_path / "twins"
        for query in queries:
            download_with_icrawler(query, output_dir, num_images=num // 2 + 2)
    
    if choice in ["2", "3"]:
        print("\n[似ている人の画像]")
        queries = [
            "look alike people together",
            "doppelganger meeting photo",
            "celebrity look alike side by side",
        ]
        num = int(input("似ている人の画像枚数 (推奨: 5-10): ") or "5")
        output_dir = base_path / "similar_people"
        for query in queries:
            download_with_icrawler(query, output_dir, num_images=num // 2 + 2)


def show_statistics():
    """ダウンロードした画像の統計を表示"""
    base_path = Path("downloaded_images")
    
    if not base_path.exists():
        print("画像フォルダがありません")
        return
    
    print("\n" + "="*50)
    print("ダウンロード済み画像の統計")
    print("="*50)
    
    total = 0
    for folder in sorted(base_path.iterdir()):
        if folder.is_dir() and not folder.name.startswith("temp"):
            count = len(list(folder.glob("*.jpg"))) + len(list(folder.glob("*.png")))
            total += count
            print(f"  {folder.name}: {count}枚")
    
    print("-"*30)
    print(f"  合計: {total}枚")


def main():
    """メイン関数"""
    print("="*50)
    print("  判別テスト用 画像ダウンローダー")
    print("="*50)
    
    create_folders()
    
    print("\n【メニュー】")
    print("1. 動物の判別テスト画像をダウンロード")
    print("2. 人物の画像をダウンロード")
    print("3. ダウンロード済み画像の統計を表示")
    
    choice = input("\n番号を入力: ").strip()
    
    if choice == "1":
        download_animal_test_set()
    elif choice == "2":
        download_people_images()
    elif choice == "3":
        show_statistics()
    else:
        print("無効な選択です")


if __name__ == "__main__":
    main()
