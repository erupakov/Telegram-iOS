#!/usr/bin/env bash
# CI: следующий buildNumber для TestFlight / App Store по принятой в DIVO схеме:
#   stage (debug, иконка DEBUG) — чётные номера   (…, 44, 46, 48)
#   prod  (release)             — нечётные номера (…, 45, 47, 49)
# Номер = наименьшее число нужной чётности, строго больше МАКСИМУМА из всех известных номеров:
# уже загруженных в App Store Connect (передаются аргументами) и тегов v0.<N> в git.
# App Store Connect требует, чтобы CFBundleVersion был больше всех ранее загруженных, — поэтому
# берём максимум по обоим окружениям, а не по одному.
#
# Использование: scripts/divo/ci_next_build_number.sh <stage|prod> [известный номер …]
# Нечисловые / пустые аргументы игнорируются. Печатает номер в stdout, пояснения — в stderr.
set -euo pipefail

ENV_NAME="${1:?stage|prod}"
shift

case "$ENV_NAME" in
  stage|debug|testflight) PARITY=0 ;;   # чётные
  prod|release)           PARITY=1 ;;   # нечётные
  *) echo "error: неизвестное окружение '$ENV_NAME' (stage|prod)" >&2; exit 1 ;;
esac

MAX=0
consider() {
  local value="$1" source="$2"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "  $source: $value" >&2
    if (( value > MAX )); then MAX=$value; fi
  fi
}

echo "Известные номера сборок:" >&2
for value in "$@"; do
  consider "$value" "App Store Connect"
done
TAG_MAX="$(git tag -l 'v0.*' 2>/dev/null | sed 's/^v0\.//' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)"
consider "${TAG_MAX:-}" "git tag v0.<N>"

NEXT=$(( MAX + 1 ))
if (( NEXT % 2 != PARITY )); then
  NEXT=$(( NEXT + 1 ))
fi
echo "Максимум: $MAX → $ENV_NAME: $NEXT ($([ $PARITY -eq 0 ] && echo чётный || echo нечётный))" >&2
echo "$NEXT"
