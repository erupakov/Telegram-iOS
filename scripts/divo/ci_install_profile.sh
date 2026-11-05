#!/usr/bin/env bash
# CI (Codemagic): кладёт App Store-профиль приложения туда, где его ждёт Bazel —
# build-input/configuration-repository/provisioning/Telegram.mobileprovision.
#
# Codemagic (environment.ios_signing) скачивает профили и сертификаты сам и ставит профили в
# ~/Library/MobileDevice/Provisioning Profiles/. Здесь выбираем среди них профиль App Store
# (без ProvisionedDevices и без get-task-allow) для нужного App ID.
#
# Использование: scripts/divo/ci_install_profile.sh <team_id> <bundle_id>
set -euo pipefail

TEAM_ID="${1:?team id}"
BUNDLE_ID="${2:?bundle id}"
APP_ID="${TEAM_ID}.${BUNDLE_ID}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="${REPO_ROOT}/build-input/configuration-repository/provisioning/Telegram.mobileprovision"

PROFILES_DIRS=(
  "${HOME}/Library/MobileDevice/Provisioning Profiles"
  "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"
)

found=""
for dir in "${PROFILES_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for profile in "$dir"/*.mobileprovision; do
    [ -e "$profile" ] || continue
    plist="$(mktemp)"
    security cms -D -i "$profile" > "$plist" 2>/dev/null || { rm -f "$plist"; continue; }
    app_id="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$plist" 2>/dev/null || true)"
    get_task_allow="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$plist" 2>/dev/null || echo false)"
    has_devices="yes"
    /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$plist" >/dev/null 2>&1 || has_devices="no"
    name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist" 2>/dev/null || true)"
    rm -f "$plist"
    if [ "$app_id" = "$APP_ID" ] && [ "$get_task_allow" != "true" ] && [ "$has_devices" = "no" ]; then
      found="$profile"
      echo "App Store profile: ${name} (${profile})"
      break 2
    fi
  done
done

if [ -z "$found" ]; then
  echo "error: не найден App Store-профиль для ${APP_ID}." >&2
  echo "Проверь environment.ios_signing (distribution_type: app_store, bundle_identifier: ${BUNDLE_ID})." >&2
  exit 1
fi

cp "$found" "$DEST"
echo "Installed -> ${DEST}"
