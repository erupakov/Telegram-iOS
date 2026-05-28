#!/usr/bin/env bash
# Скачивает Firebase iOS SDK xcframework binaries в submodules/DivoFirebaseSDK/xcframeworks/.
#
# Зачем: SDK ~500 MB бинарей не лежат в git (см. submodules/DivoFirebaseSDK/.gitignore).
# Этот скрипт идемпотентно скачивает дистрибуцию и распаковывает нужные xcframework.
#
# Запуск:
#   ./scripts/divo/install_firebase.sh
#
# Версия SDK закреплена ниже. Проверить актуальную:
#   https://github.com/firebase/firebase-ios-sdk/releases
#
# Обновление до новой версии:
#   1. Поменять FIREBASE_VERSION ниже
#   2. Удалить старые бинари: rm -rf submodules/DivoFirebaseSDK/xcframeworks/*.xcframework
#   3. Запустить скрипт повторно
#
# Переопределить версию из командной строки:
#   FIREBASE_VERSION=12.0.0 ./scripts/divo/install_firebase.sh

set -e

FIREBASE_VERSION="${FIREBASE_VERSION:-11.5.0}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
DEST="$REPO_ROOT/submodules/DivoFirebaseSDK/xcframeworks"
TMP="$(mktemp -d -t divo-firebase.XXXXXX)"
ZIP_URL="https://github.com/firebase/firebase-ios-sdk/releases/download/${FIREBASE_VERSION}/Firebase.zip"

trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"

echo "[divo] Firebase iOS SDK v${FIREBASE_VERSION}"
echo "[divo] tmp:  $TMP"
echo "[divo] dest: $DEST"
echo ""

if ! command -v curl >/dev/null 2>&1; then
    echo "[divo] error: curl не найден" >&2
    exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
    echo "[divo] error: unzip не найден" >&2
    exit 1
fi

echo "[divo] скачиваю Firebase.zip (~500 MB)..."
curl -L --fail --progress-bar -o "$TMP/Firebase.zip" "$ZIP_URL"
echo ""

echo "[divo] распаковываю (займёт минуту)..."
unzip -q "$TMP/Firebase.zip" -d "$TMP"

if [ ! -d "$TMP/Firebase" ]; then
    echo "[divo] error: ожидалась папка Firebase/ внутри zip, не найдена" >&2
    exit 1
fi

echo "[divo] переношу xcframework в $DEST..."
imported=0
skipped=0
while IFS= read -r framework; do
    name="$(basename "$framework")"
    if [ -d "$DEST/$name" ]; then
        skipped=$((skipped + 1))
        continue
    fi
    cp -R "$framework" "$DEST/"
    imported=$((imported + 1))
done < <(find "$TMP/Firebase" -type d -name "*.xcframework" -prune)

echo ""
echo "[divo] готово: импортировано $imported, пропущено $skipped (уже было)"
echo "[divo] установленные xcframework:"
ls -1 "$DEST" 2>/dev/null | grep '\.xcframework$' | sed 's/^/  /' || true
