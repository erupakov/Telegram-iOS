#!/usr/bin/env bash
# Устанавливает .githooks/ как каталог git-хуков для локального клона.
#
# Зачем: git по умолчанию ищет хуки в .git/hooks (не трекается). Мы храним
# хуки в .githooks/ внутри репозитория, чтобы они ехали с кодом. Команда
# ниже переключает этот каталог для текущего клона.
#
# Выполнить один раз после клонирования репо:
#   ./scripts/divo/install_hooks.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

git config core.hooksPath .githooks

echo "[divo] core.hooksPath = .githooks"
echo "[divo] хуки активны. Проверить: ls -la .githooks/"
