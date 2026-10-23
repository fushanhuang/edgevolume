#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 EdgeVolume 全套 App 图标（iOS 规范：无圆角、无 Alpha 通道，系统自动套圆角遮罩）。

设计：蓝紫渐变底 + 白色竖向音量滑条（轨道 / 填充 / 滑块）。
用法：python3 gen_icons.py
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "EdgeVolume", "Assets.xcassets", "AppIcon.appiconset")

# (文件名, 像素尺寸)
ICONS = [
    ("icon-20@2x.png", 40), ("icon-20@3x.png", 60),
    ("icon-29.png", 29), ("icon-29@2x.png", 58), ("icon-29@3x.png", 87),
    ("icon-40@2x.png", 80), ("icon-40@3x.png", 120),
    ("icon-57.png", 57), ("icon-57@2x.png", 114),
    ("icon-60@2x.png", 120), ("icon-60@3x.png", 180),
    ("icon-20-ipad.png", 20), ("icon-20@2x-ipad.png", 40),
    ("icon-29-ipad.png", 29), ("icon-29@2x-ipad.png", 58),
    ("icon-40.png", 40), ("icon-40@2x.png", 80),
    ("icon-50.png", 50), ("icon-50@2x.png", 100),
    ("icon-72.png", 72), ("icon-72@2x.png", 144),
    ("icon-76.png", 76), ("icon-76@2x.png", 152),
    ("icon-83.5@2x.png", 167),
    ("icon-1024.png", 1024),
]

SS = 4  # 超采样倍数，先画大图再缩小，保证边缘平滑


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def make_icon(size):
    """在 size*SS 画布上绘制，最终缩放到 size。"""
    S = size * SS
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)

    # 1) 竖向渐变底：#3B6BF5 -> #8A5CF6
    top, bottom = (59, 107, 245), (138, 92, 246)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp(top, bottom, y / max(1, S - 1)))

    # 2) 音量滑条（居中）
    track_w = S * 0.115          # 轨道宽
    track_h = S * 0.62           # 轨道高
    cx = S / 2.0
    cy = S * 0.52                # 略偏上，视觉重心
    x0, x1 = cx - track_w / 2, cx + track_w / 2
    y0, y1 = cy - track_h / 2, cy + track_h / 2

    # 轨道底（半透明深色）
    rounded_rect(d, [x0, y0, x1, y1], track_w / 2, (255, 255, 255, 60))

    # 填充（约 65%，从底部往上）
    fill_h = track_h * 0.65
    fy0 = y1 - fill_h
    rounded_rect(d, [x0, fy0, x1, y1], track_w / 2, (255, 255, 255))

    # 填充顶部与轨道圆角衔接：补一小段矩形把上端圆角切齐
    d.rectangle([x0, y1 - track_w / 2, x1, y1], fill=(255, 255, 255))

    # 滑块（圆钮）
    knob_r = S * 0.085
    kcy = y1 - fill_h
    d.ellipse([cx - knob_r, kcy - knob_r, cx + knob_r, kcy + knob_r],
              fill=(255, 255, 255))
    # 滑块内芯（品牌蓝点缀）
    inner_r = knob_r * 0.42
    d.ellipse([cx - inner_r, kcy - inner_r, cx + inner_r, kcy + inner_r],
              fill=(59, 107, 245))

    # 3) 顶部一个小喇叭/声波暗示（两个小圆点声波）
    r = S * 0.022
    d.ellipse([cx - S * 0.20 - r, cy - track_h / 2 - S * 0.02 - r,
               cx - S * 0.20 + r, cy - track_h / 2 - S * 0.02 + r],
              fill=(255, 255, 255))
    d.ellipse([cx + S * 0.20 - r, cy - track_h / 2 - S * 0.02 - r,
               cx + S * 0.20 + r, cy - track_h / 2 - S * 0.02 + r],
              fill=(255, 255, 255))

    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, size in ICONS:
        path = os.path.join(OUT, name)
        make_icon(size).save(path, "PNG", optimize=True)
        print("生成 %-22s %4dx%-4d %6d bytes" % (name, size, size, os.path.getsize(path)))
    print("\n共 %d 个图标 -> %s" % (len(ICONS), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
