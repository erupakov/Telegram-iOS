#!/usr/bin/env python3
"""Генерация отладочной иконки с ленточкой DEBUG.

Берёт чистый набор AppIconLLC из DefaultAppIcon.xcassets и накладывает на каждый размер
диагональную ленточку в правом нижнем углу с надписью DEBUG. Результат кладётся в
DebugAppIcon.xcassets (набор называется так же — AppIconLLC, чтобы CFBundleIconName в Info.plist
не менять). Bazel выбирает чистую/ленточную иконку через select() по --define=divoEnv (см. Telegram/BUILD).

Запускать вручную при изменении базовой иконки:
    python3 scripts/divo/generate_debug_appicon.py

Иконки генерённые — коммитятся в git (сборка остаётся герметичной, как generate_divo_images.py).
"""

import os
import shutil
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Нужен Pillow: pip3 install Pillow")

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(REPO, "Telegram", "Telegram-iOS", "DefaultAppIcon.xcassets", "AppIconLLC.appiconset")
DST = os.path.join(REPO, "Telegram", "Telegram-iOS", "DebugAppIcon.xcassets", "AppIconLLC.appiconset")
DST_ROOT = os.path.dirname(DST)

# Параметры ленточки
RIBBON_COLOR = (214, 40, 40, 240)   # насыщенный красный
TEXT_COLOR = (255, 255, 255, 255)
TEXT = "DEBUG"
CENTER_DIST = 0.34      # расстояние центра полосы от угла по каждой оси, доля от стороны
BAND_THICKNESS = 0.26   # толщина полосы вдоль диагонали, доля от стороны

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]


def load_font(px):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except Exception:
                continue
    return ImageFont.load_default()


def text_size(draw, text, font):
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1], box[0], box[1]


def add_ribbon(img):
    img = img.convert("RGBA")
    size = img.width
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    c = CENTER_DIST * size
    t = BAND_THICKNESS * size
    d1 = c - t / 2.0        # ближняя к углу граница полосы
    d2 = c + t / 2.0        # дальняя от угла граница полосы
    W = H = size
    # Полоса между двумя анти-диагоналями в правом нижнем углу
    poly = [(W - d2, H), (W - d1, H), (W, H - d1), (W, H - d2)]
    draw.polygon(poly, fill=RIBBON_COLOR)

    # Центр полосы лежит на главной диагонали
    cx = W - c / 2.0
    cy = H - c / 2.0

    # Текст на прозрачном слое, вписываем в длину видимой хорды полосы (~ sqrt(2)*c)
    band_perp = t / (2 ** 0.5)                    # перпендикулярная толщина полосы
    max_text_h = band_perp * 0.60
    max_text_w = (2 ** 0.5) * c * 0.86           # длина хорды по центру с запасом

    font_px = max(6, int(max_text_h))
    font = load_font(font_px)
    tw, th, ox, oy = text_size(draw, TEXT, font)
    # ужимаем шрифт, если надпись длиннее полосы
    if tw > max_text_w and tw > 0:
        font_px = max(6, int(font_px * max_text_w / tw))
        font = load_font(font_px)
        tw, th, ox, oy = text_size(draw, TEXT, font)

    tpad = max(2, int(font_px * 0.3))
    tmp = Image.new("RGBA", (tw + tpad * 2, th + tpad * 2), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(tmp)
    tdraw.text((tpad - ox, tpad - oy), TEXT, font=font, fill=TEXT_COLOR)
    tmp = tmp.rotate(45, expand=True, resample=Image.BICUBIC)

    overlay.alpha_composite(tmp, (int(cx - tmp.width / 2), int(cy - tmp.height / 2)))

    return Image.alpha_composite(img, overlay)


def main():
    if not os.path.isdir(SRC):
        sys.exit("Не найден исходный набор: %s" % SRC)

    if os.path.isdir(DST_ROOT):
        shutil.rmtree(DST_ROOT)
    os.makedirs(DST)

    # Contents.json набора и корневой Contents.json xcassets
    shutil.copy2(os.path.join(SRC, "Contents.json"), os.path.join(DST, "Contents.json"))
    src_root_contents = os.path.join(os.path.dirname(SRC), "Contents.json")
    if os.path.exists(src_root_contents):
        shutil.copy2(src_root_contents, os.path.join(DST_ROOT, "Contents.json"))

    count = 0
    for name in sorted(os.listdir(SRC)):
        if not name.lower().endswith(".png"):
            continue
        out = add_ribbon(Image.open(os.path.join(SRC, name)))
        out.save(os.path.join(DST, name))
        count += 1

    print("Готово: %d иконок → %s" % (count, DST))


if __name__ == "__main__":
    main()
