# DIVO Design System

Правила и соглашения дизайн-системы DIVO. Источник правды для токенов — `DivoDesignTokens.swift`.

---

## Press State

**Правило:** все тапабельные ячейки должны давать визуальный отклик при нажатии.

Кнопки (`UIButton`) управляют press-state самостоятельно. Для остальных интерактивных элементов (ячейки фильтров, дропдауны, опции) используется `addPressState()`.

### Токены

| Токен | Значение | Назначение |
|---|---|---|
| `PressState.alpha` | 0.65 | Ячейки с непрозрачным фоном (`FilterRowView`) |
| `PressState.alphaOnClear` | 0.4 | Ячейки с прозрачным фоном (`AppearanceFilterRowView`, option cells) |
| `PressState.pressDuration` | 0.07s | Анимация нажатия |
| `PressState.releaseDuration` | 0.25s | Анимация отпускания |

### Применение

```swift
// Ячейка с собственным фоном — стандартный alpha
view.addPressState()

// Ячейка с прозрачным фоном — усиленный alpha
view.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear)
```

### Где уже применено

- `FilterRowView` — встроено в `init`
- `AppearanceFilterRowView` — встроено в `init`
- `FilterOptionsController` — на каждую option cell в `reloadOptions()`

### Где применять при создании новых компонентов

Любой `UIView`, который реагирует на тап (через `UITapGestureRecognizer` или иной жест), но не является `UIButton`, должен вызывать `addPressState()` в `init` или при создании.

---

## Цветовая палитра

Определена в `DivoColorPalette.swift`. Запрещено использовать `.white` / `.black` напрямую — вместо них токены палитры (`cardBackground`, `primaryText`, `screenBackground` и т.д.).

---

## Spacing

| Токен | Значение |
|---|---|
| `xs` | 4 |
| `s` | 8 |
| `m` | 16 |
| `l` | 24 |
| `xl` | 32 |

---

## Radius

| Токен | Значение | Назначение |
|---|---|---|
| `xs` | 4 | Чипы, мини-индикаторы |
| `s` | 8 | Инпуты, малые кнопки |
| `m` | 12 | Средние контейнеры |
| `l` | 16 | Крупные контейнеры |
| `pill` | 20 | Pill-кнопки |
| `card` | 24 | Карточки |
| `sheet` | 34 | Модалки |

---

## Shadow

Применять через `layer.applyDivoShadow()`. Цвет фиксирован (`DivoColorPalette.shadow`).

| Вариант | Opacity | Radius | Offset |
|---|---|---|---|
| Карточный (default) | 0.08 | 12 | (0, 4) |
| Акцентный | 0.10 | 16 | (0, 4) |
| Thumb (slider) | 0.08 | 4 | (0, 2) |

---

## Иконки и ассеты

Все DIVO-ассеты живут в `DivoCore/DivoCoreImages.xcassets/Components/`.

- Подпапки с `provides-namespace: true` → путь включает имя папки: `Components/Search/FilterIcon`
- Подпапки без namespace → путь без имени папки: `Components/IconName`
- При добавлении новой подпапки **обязательно** добавить `provides-namespace: true` в `Contents.json`, если код будет ссылаться на иконки через путь с именем папки.
- Иконки, используемые с `tintColor`, должны иметь `template-rendering-intent: template` в `Contents.json`, либо загружаться через `.withRenderingMode(.alwaysTemplate)`.
