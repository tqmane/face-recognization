import os
import json
import shutil
from pathlib import Path
from reliable_image_downloader import GENRES, OUTPUT_DIR, create_genre_zip

TARGET_GENRES = ["bears", "birds", "dogs", "small_cats"]

def finalize_dataset():
    print(f"Finalizing dataset in: {OUTPUT_DIR.absolute()}")
    
    for genre_id in TARGET_GENRES:
        if genre_id not in GENRES:
            print(f"Skipping unknown genre: {genre_id}")
            continue
            
        genre = GENRES[genre_id]
        genre_dir = OUTPUT_DIR / genre_id
        
        if not genre_dir.exists():
            print(f"Skipping missing directory: {genre_dir}")
            continue
            
        print(f"\nProcessing genre: {genre.display_name} ({genre_id})")
        
        # Manifest data structure
        manifest = {
            "version": 1,
            "genre": genre_id,
            "display_name": genre.display_name,
            "description": genre.description,
            "types": {},
            "similar_pairs": [{"id1": p.id1, "id2": p.id2} for p in genre.similar_pairs],
        }
        
        # Process each item (breed/species)
        for item in genre.items:
            item_dir = genre_dir / item.id
            if not item_dir.exists():
                print(f"  Skipping missing item: {item.id}")
                continue
                
            # Collect image files
            image_files = []
            for ext in ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]:
                image_files.extend(list(item_dir.glob(ext)))
            
            # Sort files to ensure deterministic order
            image_files.sort(key=lambda x: x.name)
            
            if not image_files:
                print(f"  No images found for: {item.id}")
                continue
                
            print(f"  [{item.id}] Renaming {len(image_files)} images...")
            
            # 衝突回避のため、まず一時的な名前にリネーム
            import uuid
            temp_files = []
            for img_path in image_files:
                ext = img_path.suffix.lower()
                if ext == ".jpeg": ext = ".jpg"
                temp_name = f"temp_{uuid.uuid4()}{ext}"
                temp_path = item_dir / temp_name
                img_path.rename(temp_path)
                temp_files.append(temp_path)
            
            # 連番にリネーム
            for i, temp_path in enumerate(temp_files):
                final_name = f"{i+1:03d}{temp_path.suffix}"
                final_path = item_dir / final_name
                temp_path.rename(final_path)
            
            # Remove any non-image files if needed (optional, skipping for safety)
            
            # Update manifest
            final_count = len(list(item_dir.glob("*.jpg")) + list(item_dir.glob("*.png")) + list(item_dir.glob("*.webp")))
            manifest["types"][item.id] = {
                "display_name": item.name_ja,
                "count": final_count,
            }
        
        # Save manifest.json
        manifest_path = genre_dir / "manifest.json"
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
        print(f"  ✓ manifest.json generated")
        
        # Create ZIP
        create_genre_zip(genre_id)

if __name__ == "__main__":
    finalize_dataset()
