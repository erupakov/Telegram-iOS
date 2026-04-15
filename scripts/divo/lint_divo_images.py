#!/usr/bin/env python3
"""
Lint для DIVO-ассетов.

Правила (см. docs/DESIGN_SYSTEM.md, раздел «Ассеты»):
  [R1] каждый .imageset в DivoCoreImages.xcassets начинается с префикса Divo
  [R2] префикс Divo не встречается ни в одном другом .xcassets
  [R3] в DivoCoreImages.xcassets нигде нет provides-namespace: true
  [R4] в Swift-коде нет UIImage(named: "Divo...") / UIImage(bundleImageName: "Divo...")
       — для DIVO-ассетов должен использоваться DivoImage.xxx
  [R5] DivoImage.swift синхронизирован со списком .imageset в DivoCoreImages.xcassets

Зачем:
  R1 — визуально отличать DIVO-ресурсы от Telegram в навигации по xcassets.
  R2 — чтобы напарник случайно не положил Divo-ассет в чужой каталог
       (он не подтянется бандлом DivoCore, и UIImage отдаст nil в рантайме).
  R3 — без namespace-а подкаталог становится частью имени (Components/Xxx),
       из-за этого имя ассета теряет префикс и R1 обходится.
  R4 — строковое обращение ломается при переименовании и не ловится компилятором.
       Через DivoImage.xxx — опечатка = ошибка сборки.
  R5 — если кто-то добавил ассет и забыл перегенерировать DivoImage.swift,
       ассет недоступен в коде — пусть CI падает, а не ловим руками.

Как запускать:
  python3 scripts/divo/lint_divo_images.py           — прогнать все проверки
  Возвращает 0 при успехе, 1 если нарушения найдены.

Где запускается автоматически:
  - .githooks/pre-commit — локально при git commit
  - .github/workflows/divo-lint.yml — в CI на pull_request
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DIVO_XCASSETS = REPO_ROOT / "submodules" / "DivoCore" / "DivoCoreImages.xcassets"
DIVO_IMAGE_SWIFT = REPO_ROOT / "submodules" / "DivoUIKit" / "Sources" / "DivoImage.swift"
GENERATE_SCRIPT = REPO_ROOT / "scripts" / "divo" / "generate_divo_images.py"
PREFIX = "Divo"

# Куда НЕ ходим — сторонний код и билд-артефакты.
EXCLUDE_DIRS = {
    "third-party",
    "build-system",
    ".build",
    "bazel-bin",
    "bazel-out",
    "bazel-telegram-ios",
    "bazel-testlogs",
    ".git",
}

# R4 — игнорируем сам сгенерированный файл (там строковые имена — это норма)
# и скрипты.
R4_EXCLUDE_PATHS = {
    REPO_ROOT / "submodules" / "DivoUIKit" / "Sources" / "DivoImage.swift",
    REPO_ROOT / "scripts" / "divo" / "lint_divo_images.py",
    REPO_ROOT / "scripts" / "divo" / "generate_divo_images.py",
}

# Regex для UIImage(named: "Divo...") и UIImage(bundleImageName: "Divo...")
# Поддерживает пробелы и переносы: UIImage(\n  named: "DivoXxx"\n )
R4_PATTERN = re.compile(
    r'UIImage\s*\(\s*(?:named|bundleImageName)\s*:\s*"(Divo[A-Za-z0-9_]*)"'
)

# ANSI цвета — включаем только если stdout tty
USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
RED = "\033[31m" if USE_COLOR else ""
YELLOW = "\033[33m" if USE_COLOR else ""
GREEN = "\033[32m" if USE_COLOR else ""
BOLD = "\033[1m" if USE_COLOR else ""
RESET = "\033[0m" if USE_COLOR else ""


@dataclass
class LintReport:
    errors: list[str] = field(default_factory=list)

    def add(self, rule: str, message: str) -> None:
        self.errors.append(f"{RED}[{rule}]{RESET} {message}")

    @property
    def ok(self) -> bool:
        return not self.errors


def relpath(p: Path) -> str:
    try:
        return str(p.relative_to(REPO_ROOT))
    except ValueError:
        return str(p)


def iter_imagesets(xcassets: Path):
    """Yields (imageset_dir, name_without_ext) для всех .imageset внутри xcassets."""
    for dirpath, dirnames, _ in os.walk(xcassets):
        for d in list(dirnames):
            if d.endswith(".imageset"):
                yield Path(dirpath) / d, d[: -len(".imageset")]
        # не спускаемся внутрь .imageset
        dirnames[:] = [d for d in dirnames if not d.endswith(".imageset")]


def iter_xcassets_roots(root: Path):
    """Возвращает все каталоги *.xcassets в репозитории (кроме EXCLUDE_DIRS)."""
    for dirpath, dirnames, _ in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        # не заходим внутрь .xcassets дальше по walk-у
        drop = []
        for d in dirnames:
            if d.endswith(".xcassets"):
                yield Path(dirpath) / d
                drop.append(d)
        for d in drop:
            dirnames.remove(d)


def iter_swift_files(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for f in filenames:
            if f.endswith(".swift"):
                yield Path(dirpath) / f


# ---------- Правила ----------

def check_r1_divo_prefix_in_divo_xcassets(report: LintReport) -> None:
    """Каждый .imageset в DivoCoreImages.xcassets должен иметь префикс Divo."""
    if not DIVO_XCASSETS.is_dir():
        report.add("R1", f"не найден каталог {relpath(DIVO_XCASSETS)}")
        return
    for imageset_dir, name in iter_imagesets(DIVO_XCASSETS):
        if not name.startswith(PREFIX):
            report.add(
                "R1",
                f"{relpath(imageset_dir)}: имя '{name}' без префикса '{PREFIX}' "
                f"— переименуй в '{PREFIX}{name[:1].upper()}{name[1:]}' "
                f"и перегенерируй DivoImage.swift",
            )


def check_r2_no_divo_prefix_outside(report: LintReport) -> None:
    """Префикс Divo не должен встречаться вне DivoCoreImages.xcassets."""
    for xcassets in iter_xcassets_roots(REPO_ROOT):
        if xcassets.resolve() == DIVO_XCASSETS.resolve():
            continue
        for imageset_dir, name in iter_imagesets(xcassets):
            if name.startswith(PREFIX):
                report.add(
                    "R2",
                    f"{relpath(imageset_dir)}: ассет с префиксом '{PREFIX}' "
                    f"лежит не в DivoCoreImages.xcassets — перенеси его туда "
                    f"(иначе DivoCore bundle его не подхватит)",
                )


def check_r3_no_provides_namespace(report: LintReport) -> None:
    """В DivoCoreImages.xcassets не должно быть provides-namespace: true."""
    if not DIVO_XCASSETS.is_dir():
        return  # R1 уже сообщил
    for dirpath, _, filenames in os.walk(DIVO_XCASSETS):
        for f in filenames:
            if f != "Contents.json":
                continue
            path = Path(dirpath) / f
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as e:
                report.add("R3", f"{relpath(path)}: не удалось прочитать JSON ({e})")
                continue
            props = data.get("properties") or {}
            if props.get("provides-namespace") is True:
                report.add(
                    "R3",
                    f"{relpath(path)}: provides-namespace: true — убери это поле "
                    f"(подкаталог начнёт прятать префикс Divo в имени ассета)",
                )


def check_r4_no_string_literals(report: LintReport) -> None:
    """В Swift-коде нет UIImage(named: "Divo...") / UIImage(bundleImageName: "Divo...")."""
    excluded = {p.resolve() for p in R4_EXCLUDE_PATHS}
    roots = [REPO_ROOT / "submodules", REPO_ROOT / "Telegram"]
    for root in roots:
        if not root.is_dir():
            continue
        for swift_file in iter_swift_files(root):
            if swift_file.resolve() in excluded:
                continue
            try:
                text = swift_file.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if "Divo" not in text:  # быстрый отсев — regex дорогой
                continue
            for m in R4_PATTERN.finditer(text):
                # номер строки
                line_no = text.count("\n", 0, m.start()) + 1
                asset = m.group(1)
                prop = asset[len(PREFIX):]
                prop = prop[:1].lower() + prop[1:] if prop else prop
                report.add(
                    "R4",
                    f"{relpath(swift_file)}:{line_no}: "
                    f'UIImage(..., "{asset}") — замени на DivoImage.{prop}',
                )


def check_r5_divoimage_in_sync(report: LintReport) -> None:
    """DivoImage.swift синхронизирован с xcassets (набор ассетов совпадает)."""
    if not DIVO_IMAGE_SWIFT.is_file():
        report.add("R5", f"не найден файл {relpath(DIVO_IMAGE_SWIFT)}")
        return
    if not DIVO_XCASSETS.is_dir():
        return  # R1 уже сообщил

    # Список ассетов из xcassets (только валидные с префиксом Divo)
    assets_in_xcassets = sorted(
        n for _, n in iter_imagesets(DIVO_XCASSETS) if n.startswith(PREFIX)
    )

    # Список ассетов, на которые ссылается DivoImage.swift через load("...").
    text = DIVO_IMAGE_SWIFT.read_text(encoding="utf-8")
    assets_in_swift = sorted(set(re.findall(r'load\("(Divo[A-Za-z0-9_]*)"\)', text)))

    missing_in_swift = sorted(set(assets_in_xcassets) - set(assets_in_swift))
    extra_in_swift = sorted(set(assets_in_swift) - set(assets_in_xcassets))

    if missing_in_swift:
        report.add(
            "R5",
            f"{relpath(DIVO_IMAGE_SWIFT)}: ассеты есть в xcassets, но отсутствуют "
            f"в DivoImage.swift: {', '.join(missing_in_swift)}. "
            f"Запусти: python3 {relpath(GENERATE_SCRIPT)}",
        )
    if extra_in_swift:
        report.add(
            "R5",
            f"{relpath(DIVO_IMAGE_SWIFT)}: DivoImage.swift ссылается на несуществующие "
            f"ассеты: {', '.join(extra_in_swift)}. "
            f"Запусти: python3 {relpath(GENERATE_SCRIPT)}",
        )


# ---------- main ----------

def main() -> int:
    report = LintReport()

    check_r1_divo_prefix_in_divo_xcassets(report)
    check_r2_no_divo_prefix_outside(report)
    check_r3_no_provides_namespace(report)
    check_r4_no_string_literals(report)
    check_r5_divoimage_in_sync(report)

    if report.ok:
        print(f"{GREEN}{BOLD}[divo-lint]{RESET} OK — все 5 проверок прошли.")
        return 0

    print(f"{RED}{BOLD}[divo-lint]{RESET} нарушения ({len(report.errors)}):")
    for err in report.errors:
        print(f"  {err}")
    print()
    print(
        f"{YELLOW}Подробности о правилах: docs/DESIGN_SYSTEM.md, раздел «Ассеты».{RESET}"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
