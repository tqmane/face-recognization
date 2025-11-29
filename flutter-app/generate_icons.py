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
    # 出力ディレクトリを作成
    output_dir = os.path.join(os.path.dirname(__file__), 'assets', 'icon')
    os.makedirs(output_dir, exist_ok=True)
    
    # メインアイコン（1024x1024）
    create_icon(1024, os.path.join(output_dir, 'app_icon.png'))
    
    # フォアグラウンドアイコン（適応型アイコン用）
    create_foreground_icon(1024, os.path.join(output_dir, 'app_icon_foreground.png'))
    
    print("Icons generated successfully!")

if __name__ == '__main__':
    main()
