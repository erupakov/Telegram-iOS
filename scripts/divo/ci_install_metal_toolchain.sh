#!/usr/bin/env bash
# CI: ставит Metal Toolchain для Xcode 26+ (компилятор `metal` — отдельный компонент; без него
# не собираются шейдеры: CallScreenShaders и др.).
#
# На CI-машинах (Codemagic, GitHub Actions) `xcodebuild -downloadComponent MetalToolchain`
# скачивает компонент («Done downloading: Metal Toolchain …»), но `metal` его не видит:
# «cannot execute tool 'metal' due to missing Metal Toolchain». Известная проблема Xcode 26 на
# CI — компонент не регистрируется после загрузки. Обходной путь: экспортировать компонент и
# импортировать его обратно (`-exportPath` / `-importComponent`), при необходимости — с правкой
# номера сборки в ExportMetadata.plist (METAL_TOOLCHAIN_BUILD_ID).
#
# Скрипт пробует по очереди и останавливается на первом рабочем варианте; если ничего не помогло —
# печатает диагностику и падает.
#
# Переменные (необязательные):
#   METAL_TOOLCHAIN_BUILD_ID — номер сборки, который ждёт Xcode (подставляется в ExportMetadata.plist
#                              перед импортом), если экспорт/импорт как есть не помог.
set -uo pipefail

log() { echo "[metal-toolchain] $*"; }

metal_works() {
  # Проверяем ровно так, как его зовут при сборке: через xcrun под iOS SDK.
  xcrun -sdk iphoneos metal --version >/dev/null 2>&1
}

wait_for_metal() {
  # Компонент подключается асинхронно — даём системе несколько секунд.
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if metal_works; then
      return 0
    fi
    sleep 5
  done
  return 1
}

success() {
  log "OK ($1):"
  xcrun -sdk iphoneos metal --version
  exit 0
}

diagnostics() {
  log "---- диагностика ----"
  xcodebuild -version || true
  xcode-select -p || true
  xcodebuild -showComponent MetalToolchain 2>&1 || true
  xcrun --find metal 2>&1 || true
  ls -la /System/Library/AssetsV2/com_apple_MobileAsset_MetalToolchain 2>&1 || true
  ls -la /private/var/run/com.apple.security.cryptexd/mnt 2>&1 || true
  if [ -n "${EXPORT_DIR:-}" ]; then
    find "$EXPORT_DIR" -maxdepth 2 2>&1 || true
    for plist in "$EXPORT_DIR"/*.exportedBundle/ExportMetadata.plist; do
      [ -f "$plist" ] && { log "$plist:"; plutil -p "$plist" 2>&1 || cat "$plist"; }
    done
  fi
  log "---------------------"
}

import_bundle() {
  local bundle="$1"
  log "importComponent: $bundle"
  xcodebuild -importComponent MetalToolchain -importPath "$bundle" 2>&1 \
    || sudo xcodebuild -importComponent MetalToolchain -importPath "$bundle" 2>&1 \
    || return 1
}

# 1. Уже есть (образ машины или кэш).
metal_works && success "уже установлен"

# 2. Обычная загрузка.
log "downloadComponent MetalToolchain"
xcodebuild -downloadComponent MetalToolchain 2>&1 || log "downloadComponent завершился с ошибкой"
wait_for_metal && success "downloadComponent"

# 3. Регистрация Xcode (иногда нужна после загрузки компонента на свежей машине).
log "runFirstLaunch"
sudo xcodebuild -runFirstLaunch 2>&1 || true
wait_for_metal && success "runFirstLaunch"

# 4. Экспорт → импорт как есть.
EXPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MetalToolchainExport.XXXXXX")"
log "downloadComponent -exportPath $EXPORT_DIR"
xcodebuild -downloadComponent MetalToolchain -exportPath "$EXPORT_DIR" 2>&1 || log "экспорт завершился с ошибкой"
BUNDLE="$(ls -d "$EXPORT_DIR"/*.exportedBundle 2>/dev/null | head -1)"
if [ -n "$BUNDLE" ]; then
  if import_bundle "$BUNDLE" && wait_for_metal; then
    success "export/import"
  fi

  # 5. Экспорт → правка номера сборки в метаданных → импорт.
  if [ -n "${METAL_TOOLCHAIN_BUILD_ID:-}" ]; then
    PLIST="$BUNDLE/ExportMetadata.plist"
    CURRENT="$(/usr/libexec/PlistBuddy -c 'Print :buildUpdateVersion' "$PLIST" 2>/dev/null || true)"
    log "ExportMetadata buildUpdateVersion: '${CURRENT}' → '${METAL_TOOLCHAIN_BUILD_ID}'"
    if [ -n "$CURRENT" ]; then
      sed -i '' -e "s/${CURRENT}/${METAL_TOOLCHAIN_BUILD_ID}/g" "$PLIST"
      if import_bundle "$BUNDLE" && wait_for_metal; then
        success "export/patch/import"
      fi
    else
      log "в ExportMetadata.plist нет buildUpdateVersion — правка пропущена"
    fi
  fi
else
  log "экспортированный бандл не найден"
fi

diagnostics
log "error: Metal Toolchain так и не стал доступен."
log "Если в диагностике видно расхождение номеров сборки — задай METAL_TOOLCHAIN_BUILD_ID и перезапусти."
exit 1
