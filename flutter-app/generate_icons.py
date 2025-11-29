#!/usr/bin/env python3
"""
Flutterアプリ用のアイコンを生成するスクリプト
純粋なPythonのみ（外部依存なし）
"""

import os
import zlib
import struct
import math

def create_png(width, height, pixels, output_path):
    """PNGファイルを純粋なPythonで作成"""
    def png_chunk(chunk_type, data):
        chunk_len = struct.pack('>I', len(data))
        chunk_crc = struct.pack('>I', zlib.crc32(chunk_type + data) & 0xffffffff)
        return chunk_len + chunk_type + data + chunk_crc
    
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = png_chunk(b'IHDR', ihdr_data)
    
    # IDAT chunk (image data) - bytearrayを使って高速化
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)  # filter byte
        row_start = y * width * 4
        raw_data.extend(pixels[row_start:row_start + width * 4])
    
    compressed = zlib.compress(bytes(raw_data), 9)
    idat = png_chunk(b'IDAT', compressed)
    
    # IEND chunk
    iend = png_chunk(b'IEND', b'')
    
    with open(output_path, 'wb') as f:
        f.write(signature + ihdr + idat + iend)

def create_icon(size, output_path):
    """青い背景に白い虫眼鏡アイコンを作成"""
    # bytearray で高速に処理
    pixels = bytearray(size * size * 4)
    
    bg_r, bg_g, bg_b, bg_a = 0, 122, 255, 255
    white_r, white_g, white_b, white_a = 255, 255, 255, 255
    
    center_x = size // 2
    center_y = size // 2 - size // 10
    circle_radius = size // 4
    thickness = size // 15
    
    outer_r = circle_radius + thickness // 2
    inner_r = circle_radius - thickness // 2
    outer_r_sq = outer_r ** 2
    inner_r_sq = inner_r ** 2
    
    # 持ち手の計算
    handle_sx = center_x + int(circle_radius * 0.7)
    handle_sy = center_y + int(circle_radius * 0.7)
    handle_ex = center_x + int(circle_radius * 1.4)
    handle_ey = center_y + int(circle_radius * 1.4)
    handle_dx = handle_ex - handle_sx
    handle_dy = handle_ey - handle_sy
    handle_len_sq = handle_dx ** 2 + handle_dy ** 2
    handle_half_thick = thickness // 2
    handle_half_thick_sq = handle_half_thick ** 2
    
    for y in range(size):
        for x in range(size):
            idx = (y * size + x) * 4
            
            # 虫眼鏡の円環チェック
            dx = x - center_x
            dy = y - center_y
            dist_sq = dx * dx + dy * dy
            
            is_ring = inner_r_sq <= dist_sq <= outer_r_sq
            
            # 持ち手チェック（線分からの距離）
            is_handle = False
            if handle_len_sq > 0:
                t = max(0, min(1, ((x - handle_sx) * handle_dx + (y - handle_sy) * handle_dy) / handle_len_sq))
                proj_x = handle_sx + t * handle_dx
                proj_y = handle_sy + t * handle_dy
                dist_to_line_sq = (x - proj_x) ** 2 + (y - proj_y) ** 2
                is_handle = dist_to_line_sq <= handle_half_thick_sq
            
            if is_ring or is_handle:
                pixels[idx] = white_r
                pixels[idx+1] = white_g
                pixels[idx+2] = white_b
                pixels[idx+3] = white_a
            else:
                pixels[idx] = bg_r
                pixels[idx+1] = bg_g
                pixels[idx+2] = bg_b
                pixels[idx+3] = bg_a
    
    create_png(size, size, pixels, output_path)

def create_foreground_icon(size, output_path):
    """透明背景に白い虫眼鏡アイコン（フォアグラウンド用）"""
    # bytearray で高速に処理
    pixels = bytearray(size * size * 4)
    
    white_r, white_g, white_b, white_a = 255, 255, 255, 255
    
    center_x = size // 2
    center_y = size // 2 - size // 10
    circle_radius = size // 4
    thickness = size // 15
    
    outer_r = circle_radius + thickness // 2
    inner_r = circle_radius - thickness // 2
    outer_r_sq = outer_r ** 2
    inner_r_sq = inner_r ** 2
    
    # 持ち手の計算
    handle_sx = center_x + int(circle_radius * 0.7)
    handle_sy = center_y + int(circle_radius * 0.7)
    handle_ex = center_x + int(circle_radius * 1.4)
    handle_ey = center_y + int(circle_radius * 1.4)
    handle_dx = handle_ex - handle_sx
    handle_dy = handle_ey - handle_sy
    handle_len_sq = handle_dx ** 2 + handle_dy ** 2
    handle_half_thick = thickness // 2
    handle_half_thick_sq = handle_half_thick ** 2
    
    for y in range(size):
        for x in range(size):
            idx = (y * size + x) * 4
            
            # 虫眼鏡の円環チェック
            dx = x - center_x
            dy = y - center_y
            dist_sq = dx * dx + dy * dy
            
            is_ring = inner_r_sq <= dist_sq <= outer_r_sq
            
            # 持ち手チェック
            is_handle = False
            if handle_len_sq > 0:
                t = max(0, min(1, ((x - handle_sx) * handle_dx + (y - handle_sy) * handle_dy) / handle_len_sq))
                proj_x = handle_sx + t * handle_dx
                proj_y = handle_sy + t * handle_dy
                dist_to_line_sq = (x - proj_x) ** 2 + (y - proj_y) ** 2
                is_handle = dist_to_line_sq <= handle_half_thick_sq
            
            if is_ring or is_handle:
                pixels[idx] = white_r
                pixels[idx+1] = white_g
                pixels[idx+2] = white_b
                pixels[idx+3] = white_a
            # else: 透明のまま（0, 0, 0, 0）
    
    create_png(size, size, pixels, output_path)

def main():
    base_dir = os.path.dirname(__file__)
    
    # Flutter assets用アイコン
    output_dir = os.path.join(base_dir, 'assets', 'icon')
    os.makedirs(output_dir, exist_ok=True)
    
    # メインアイコン（1024x1024）
    create_icon(1024, os.path.join(output_dir, 'app_icon.png'))
    
    # フォアグラウンドアイコン（適応型アイコン用）
    create_foreground_icon(1024, os.path.join(output_dir, 'app_icon_foreground.png'))
    
    # Android用アイコン生成
    android_res_dir = os.path.join(base_dir, 'android', 'app', 'src', 'main', 'res')
    if os.path.exists(os.path.join(base_dir, 'android')):
        mipmap_sizes = {
            'mipmap-mdpi': 48,
            'mipmap-hdpi': 72,
            'mipmap-xhdpi': 96,
            'mipmap-xxhdpi': 144,
            'mipmap-xxxhdpi': 192,
        }
        for folder, size in mipmap_sizes.items():
            folder_path = os.path.join(android_res_dir, folder)
            os.makedirs(folder_path, exist_ok=True)
            create_icon(size, os.path.join(folder_path, 'ic_launcher.png'))
            create_icon(size, os.path.join(folder_path, 'ic_launcher_round.png'))
            # 適応型アイコン用フォアグラウンド
            fg_size = int(size * 108 / 48)
            create_foreground_icon(fg_size, os.path.join(folder_path, 'ic_launcher_foreground.png'))
        print(f"Android icons generated in {android_res_dir}")
    
    # iOS用アイコン生成
    ios_dir = os.path.join(base_dir, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    if os.path.exists(os.path.join(base_dir, 'ios')):
        os.makedirs(ios_dir, exist_ok=True)
        ios_sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
        for size in ios_sizes:
            create_icon(size, os.path.join(ios_dir, f'Icon-App-{size}x{size}.png'))
        
        # Contents.jsonを生成
        contents = generate_ios_contents_json()
        with open(os.path.join(ios_dir, 'Contents.json'), 'w') as f:
            f.write(contents)
        print(f"iOS icons generated in {ios_dir}")
    
    # macOS用アイコン生成
    macos_dir = os.path.join(base_dir, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    if os.path.exists(os.path.join(base_dir, 'macos')):
        os.makedirs(macos_dir, exist_ok=True)
        macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
        for size in macos_sizes:
            create_icon(size, os.path.join(macos_dir, f'app_icon_{size}.png'))
        
        # Contents.jsonを生成
        contents = generate_macos_contents_json()
        with open(os.path.join(macos_dir, 'Contents.json'), 'w') as f:
            f.write(contents)
        print(f"macOS icons generated in {macos_dir}")
    
    print("Icons generated successfully!")

def generate_ios_contents_json():
    """iOS用Contents.jsonを生成"""
    return '''{
  "images" : [
    {"size" : "20x20", "idiom" : "iphone", "filename" : "Icon-App-40x40.png", "scale" : "2x"},
    {"size" : "20x20", "idiom" : "iphone", "filename" : "Icon-App-60x60.png", "scale" : "3x"},
    {"size" : "29x29", "idiom" : "iphone", "filename" : "Icon-App-58x58.png", "scale" : "2x"},
    {"size" : "29x29", "idiom" : "iphone", "filename" : "Icon-App-87x87.png", "scale" : "3x"},
    {"size" : "40x40", "idiom" : "iphone", "filename" : "Icon-App-80x80.png", "scale" : "2x"},
    {"size" : "40x40", "idiom" : "iphone", "filename" : "Icon-App-120x120.png", "scale" : "3x"},
    {"size" : "60x60", "idiom" : "iphone", "filename" : "Icon-App-120x120.png", "scale" : "2x"},
    {"size" : "60x60", "idiom" : "iphone", "filename" : "Icon-App-180x180.png", "scale" : "3x"},
    {"size" : "20x20", "idiom" : "ipad", "filename" : "Icon-App-20x20.png", "scale" : "1x"},
    {"size" : "20x20", "idiom" : "ipad", "filename" : "Icon-App-40x40.png", "scale" : "2x"},
    {"size" : "29x29", "idiom" : "ipad", "filename" : "Icon-App-29x29.png", "scale" : "1x"},
    {"size" : "29x29", "idiom" : "ipad", "filename" : "Icon-App-58x58.png", "scale" : "2x"},
    {"size" : "40x40", "idiom" : "ipad", "filename" : "Icon-App-40x40.png", "scale" : "1x"},
    {"size" : "40x40", "idiom" : "ipad", "filename" : "Icon-App-80x80.png", "scale" : "2x"},
    {"size" : "76x76", "idiom" : "ipad", "filename" : "Icon-App-76x76.png", "scale" : "1x"},
    {"size" : "76x76", "idiom" : "ipad", "filename" : "Icon-App-152x152.png", "scale" : "2x"},
    {"size" : "83.5x83.5", "idiom" : "ipad", "filename" : "Icon-App-167x167.png", "scale" : "2x"},
    {"size" : "1024x1024", "idiom" : "ios-marketing", "filename" : "Icon-App-1024x1024.png", "scale" : "1x"}
  ],
  "info" : {"version" : 1, "author" : "xcode"}
}'''

def generate_macos_contents_json():
    """macOS用Contents.jsonを生成"""
    return '''{
  "images" : [
    {"size" : "16x16", "idiom" : "mac", "filename" : "app_icon_16.png", "scale" : "1x"},
    {"size" : "16x16", "idiom" : "mac", "filename" : "app_icon_32.png", "scale" : "2x"},
    {"size" : "32x32", "idiom" : "mac", "filename" : "app_icon_32.png", "scale" : "1x"},
    {"size" : "32x32", "idiom" : "mac", "filename" : "app_icon_64.png", "scale" : "2x"},
    {"size" : "128x128", "idiom" : "mac", "filename" : "app_icon_128.png", "scale" : "1x"},
    {"size" : "128x128", "idiom" : "mac", "filename" : "app_icon_256.png", "scale" : "2x"},
    {"size" : "256x256", "idiom" : "mac", "filename" : "app_icon_256.png", "scale" : "1x"},
    {"size" : "256x256", "idiom" : "mac", "filename" : "app_icon_512.png", "scale" : "2x"},
    {"size" : "512x512", "idiom" : "mac", "filename" : "app_icon_512.png", "scale" : "1x"},
    {"size" : "512x512", "idiom" : "mac", "filename" : "app_icon_1024.png", "scale" : "2x"}
  ],
  "info" : {"version" : 1, "author" : "xcode"}
}'''

if __name__ == '__main__':
    main()
