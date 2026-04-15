#!/usr/bin/env python3
"""
Генератор typed-namespace DivoImage из DivoCoreImages.xcassets.

Обходит xcassets, находит все .imageset с префиксом Divo и перегенерирует
submodules/DivoUIKit/Sources/DivoImage.swift.

Как запускать:
    python3 scripts/divo/generate_divo_images.py

Запускать надо после:
    - добавления нового ассета в DivoCoreImages.xcassets
    - переименования ассета
    - удаления ассета

Если скрипт не запустить, DivoImage.swift будет рассинхронизирован
с каталогом — CI/lint это поймает.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
XCASSETS = REPO_ROOT / "submodules" / "DivoCore" / "DivoCoreImages.xcassets"
OUTPUT = REPO_ROOT / "submodules" / "DivoUIKit" / "Sources" / "DivoImage.swift"
PREFIX = "Divo"

HEADER = """\
// DO NOT EDIT — сгенерирован scripts/divo/generate_divo_images.py
// Regenerate: python3 scripts/divo/generate_divo_images.py
//
// Typed-namespace для DIVO-ассетов. Цель:
// 1. Визуально отличать DIVO-ресурсы от Telegram в коде (DivoImage.xxx).
// 2. Compile-time safety: опечатка в имени → ошибка сборки, а не nil в рантайме.
// 3. Единая точка загрузки — если сменится bundle/способ загрузки, правим здесь.

import UIKit
import AppBundle

public enum DivoImage {
"""

FOOTER = """\

    private static func load(_ name: String) -> UIImage {
        guard let image = UIImage(bundleImageName: name) else {
            assertionFailure("DIVO asset not found in bundle: \\(name)")
            return UIImage()
        }
        return image
    }
}
"""


def find_imagesets(root: Path) -> list[str]:
    """Возвращает список имён .imageset (без расширения), отсортированный."""
    names: list[str] = []
    for dirpath, dirnames, _ in os.walk(root):
        for d in dirnames:
            if d.endswith(".imageset"):
                names.append(d[: -len(".imageset")])
    return sorted(names)


def property_name(asset_name: str) -> str:
    """DivoAddPhotoIcon -> addPhotoIcon. Просто снимаем префикс и lowercase первой буквы."""
    if not asset_name.startswith(PREFIX):
        raise ValueError(
            f"Asset '{asset_name}' не начинается с префикса '{PREFIX}'. "
            "Запусти scripts/divo/lint_divo_images.sh — там это ловится."
        )
    stripped = asset_name[len(PREFIX):]
    if not stripped:
        raise ValueError(f"Asset '{asset_name}' — только префикс, без имени.")
    return stripped[0].lower() + stripped[1:]


def generate_swift(asset_names: list[str]) -> str:
    lines = [HEADER]
    for asset in asset_names:
        prop = property_name(asset)
        lines.append(f'    public static var {prop}: UIImage {{ load("{asset}") }}')
    lines.append(FOOTER)
    return "\n".join(lines)


def main() -> int:
    if not XCASSETS.is_dir():
        print(f"ERR: не найден каталог {XCASSETS}", file=sys.stderr)
        return 1

    assets = find_imagesets(XCASSETS)
    if not assets:
        print(f"ERR: в {XCASSETS} не найдено ни одного .imageset", file=sys.stderr)
        return 1

    # Проверка уникальности property-имён (разные пути → одно имя = ошибка)
    props: dict[str, str] = {}
    for a in assets:
        try:
            p = property_name(a)
        except ValueError as e:
            print(f"ERR: {e}", file=sys.stderr)
            return 1
        if p in props:
            print(
                f"ERR: коллизия property-имён: '{a}' и '{props[p]}' оба дают '{p}'",
                file=sys.stderr,
            )
            return 1
        props[p] = a

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generate_swift(assets), encoding="utf-8")
    print(f"OK: {OUTPUT} — {len(assets)} ассетов")
    return 0


if __name__ == "__main__":
    sys.exit(main())
