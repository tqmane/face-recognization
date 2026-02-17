from pathlib import Path
from reliable_image_downloader import GENRES

OUTPUT_DIR = Path("test_sets")

def create_folders():
    print(f"Creating folders in: {OUTPUT_DIR.absolute()}")
    OUTPUT_DIR.mkdir(exist_ok=True)
    
    count = 0
    for genre_id, genre in GENRES.items():
        genre_dir = OUTPUT_DIR / genre_id
        genre_dir.mkdir(exist_ok=True)
        print(f"  [{genre_id}] {genre.display_name}")
        
        for item in genre.items:
            item_dir = genre_dir / item.id
            item_dir.mkdir(exist_ok=True)
            # print(f"    - {item.id}: {item.name_ja}")
            count += 1
            
    print(f"\nDone! Created folders for {len(GENRES)} genres and {count} items.")

if __name__ == "__main__":
    create_folders()
