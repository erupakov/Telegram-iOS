# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository.

## Project Overview
This is a fork of Telegram-iOS with a DIVO layer on top. DIVO code uses REST API instead of MTProto. Contractor code starts from commit `6e13a25f3f`. Development is primarily done in a dummy repo and periodically migrated here.

- Dummy repo: `/Users/Surf/Projects/DIVO/divo-ios-dummy`
- Migration guide: `docs/migration-guide.md`

## Key Paths
- Divo services: `submodules/TelegramCore/Sources/TelegramEngine/Divo/Services/`
- Divo models: `submodules/TelegramCore/Sources/TelegramEngine/Divo/Models/`
- Profile UI: `submodules/ProfileScreenUI/Sources/`
- Events UI: `submodules/EventsUI/Sources/`
- Models Feed: `submodules/ModelsFeedUI/Sources/`
- Onboarding: `submodules/OnboardingUI/Sources/`

## Build
- Bazel. **Never run `bazel` or `make` — the user always runs builds manually.**
- All modules use `glob(["Sources/**/*.swift"])` — new files are picked up automatically.
- Simulator ID: `C00BA86B-0536-4BFC-A845-F46BB4E2267D` (iPhone 15 / iOS 18)
- App binary: `bazel-bin/Telegram/Telegram_archive-root/Payload/Telegram.app`

## Developer setup
После клонирования репо — один раз активировать git hooks:
```
./scripts/divo/install_hooks.sh
```
Это переключает `core.hooksPath` на `.githooks/`. Pre-commit хук гоняет
`scripts/divo/lint_divo_images.py` — правила работы с DIVO-ассетами
(см. `docs/DESIGN_SYSTEM.md`, раздел «Ассеты»). Те же проверки дублируются
в CI на PR (`.github/workflows/divo-lint.yml`).

Если хук падает — скрипт печатает конкретный файл/строку и что чинить.
При добавлении/переименовании DIVO-ассетов: запустить
`python3 scripts/divo/generate_divo_images.py` (перегенерит `DivoImage.swift`).

## Code Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/methods
- **Imports**: Group and sort imports at the top of files
- **Error Handling**: Properly handle errors with appropriate redaction of sensitive data
- **Formatting**: Use standard Swift formatting and spacing
- **Types**: Prefer strong typing and explicit type annotations where needed
- All types in `Divo/Models` and `Divo/Services` must be `public`

## Project Structure
- Core launch and application extensions code is in `Telegram/` directory
- Most code is organized into libraries in `submodules/`
- External code is located in `third-party/`
- No tests are used at the moment

## Boilerplate Adaptations (dummy → TelegramApp)
When migrating code from the dummy repo, apply these transformations:
- `context.presentationData` → `context.sharedContext.currentPresentationData.with { $0 }`
- `Any?` disposables → `Disposable?`
- `NavigationBarStrings(back:close:)` → `NavigationBarStrings(presentationStrings:)`
- Add `.strict()` to Signal subscriptions
- Add `overallDarkAppearance: true` to NavigationBarTheme
- Simplified `super.init` (no panel params)
- Keep TelegramApp imports: `Postbox`, `SwiftSignalKit`, `TelegramCore`, etc.
- Navigation stays Telegram-native — do NOT migrate App-level controllers from dummy
- `DivoStubs.swift` is NOT migrated — real Telegram types are used

## Known Issues
- `ShimmerView` и `ImageLoader` живут в `submodules/DivoUIKit/Sources/Services/`: `ShimmerView` берёт цвета из `DivoColorPalette`, а `ImageLoader.loadImage(...)` сам дёргает `addShimmerOverlay()`/`removeShimmerOverlay()` — поэтому оба класса лежат рядом с палитрой в одном модуле
- `startShimmering()`/`stopShimmering()` — separate extensions in `ProfileInfoView.swift` (ProfileScreenUI)
- `DivoConfig` has a hardcoded stage token — this is intentional for now
- EventsUI: MTProto calls are commented out with `// FIXME DIVO` — need REST replacements
