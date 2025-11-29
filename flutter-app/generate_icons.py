#!/usr/bin/env python3
"""
Flutterアプリ用のアイコンを生成するスクリプト
"""

from PIL import Image, ImageDraw
import os

def create_icon(size, output_path):
    """青い背景に白い虫眼鏡アイコンを作成"""
    # 青い背景
    img = Image.new('RGBA', (size, size), (0, 122, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # 中心と半径を計算
    center_x = size // 2
    center_y = size // 2 - size // 10
    
    # 虫眼鏡の円部分
    circle_radius = size // 4
    circle_thickness = size // 15
    
    # 外側の円（白）
    draw.ellipse(
        [center_x - circle_radius, center_y - circle_radius,
         center_x + circle_radius, center_y + circle_radius],
        outline='white',
        width=circle_thickness
    )
    
    # 持ち手部分
    handle_start_x = center_x + int(circle_radius * 0.7)
    handle_start_y = center_y + int(circle_radius * 0.7)
    handle_end_x = center_x + int(circle_radius * 1.4)
    handle_end_y = center_y + int(circle_radius * 1.4)
    
    draw.line(
        [handle_start_x, handle_start_y, handle_end_x, handle_end_y],
        fill='white',
        width=circle_thickness
    )
    
    img.save(output_path)

def create_foreground_icon(size, output_path):
    """透明背景に白い虫眼鏡アイコン（フォアグラウンド用）"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x = size // 2
    center_y = size // 2 - size // 10
    
    circle_radius = size // 4
    circle_thickness = size // 15
    
    draw.ellipse(
        [center_x - circle_radius, center_y - circle_radius,
         center_x + circle_radius, center_y + circle_radius],
        outline='white',
        width=circle_thickness
    )
    
    handle_start_x = center_x + int(circle_radius * 0.7)
    handle_start_y = center_y + int(circle_radius * 0.7)
    handle_end_x = center_x + int(circle_radius * 1.4)
    handle_end_y = center_y + int(circle_radius * 1.4)
    
    draw.line(
        [handle_start_x, handle_start_y, handle_end_x, handle_end_y],
        fill='white',
        width=circle_thickness
    )
    
    img.save(output_path)

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
