# Код-ревью DIVO — чеклист

Этот документ описывает обязательные проверки при ревью DIVO-веток. Цель — единообразие, минимум повторных замечаний, поддержание изоляции от Telegram-форка.

Смежные гайды: [LOCALIZATION.md](LOCALIZATION.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md).

---

## 1. Локализация

Подробный гайд — [LOCALIZATION.md](LOCALIZATION.md).

- [ ] Все UI-строки проходят через `DivoStrings.L(en:ru:es:pt:zh:)` — **5 языков**.
- [ ] Нет hardcoded-строк в UI-коде (`"Not set"`, `"Loading..."`, `"Save"` и т.п.). Поиск: `grep -rn '"[A-Z]' Sources/` в затронутых модулях.
- [ ] Новые строки добавлены в правильную MARK-секцию `DivoStrings.swift`.
- [ ] Если строка содержит `Font.helveticaNeue()` — есть `heightAnchor.constraint(greaterThanOrEqualToConstant:)` для CJK (таблица минимальных высот в [LOCALIZATION.md](LOCALIZATION.md)).

---

## 2. Дизайн-система

Подробный гайд — [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

### Цвета

- [ ] Цвета берутся из `DivoColorPalette`, а не из `.white`, `.black`, `UIColor(red:...)`.
- [ ] Исключение: системные цвета в `UIVisualEffectView` / `UIBlurEffect` — это ОК.

### Токены

- [ ] Радиусы — из `DivoDesignTokens.Radius.*`. Если значение не в шкале — TODO-комментарий.
- [ ] Отступы — из `DivoDesignTokens.Spacing.*`. Допустимо raw-значение, если оно одноразовое и локальное.
- [ ] Тени — через `layer.applyDivoShadow(...)`.
- [ ] Нет магических числовых литералов, повторяющихся в 2+ местах.

### Компоненты

- [ ] Если компонент дублируется между модулями — вынести в `DivoUIKit` (по правилам из DESIGN_SYSTEM.md).
- [ ] Публичные компоненты в DivoUIKit не содержат доменных зависимостей (`TelegramCore`, API-модели).
- [ ] Шрифты — через `Font.helveticaNeue()` или `Font.regular()`, а не `UIFont.systemFont`.

---

## 3. Изоляция DIVO от Telegram

Цель: минимизировать merge-конфликты при обновлении Telegram upstream.

### Ресурсы

- [ ] Все DIVO-ассеты лежат в `DivoCore/DivoCoreImages.xcassets/`, а не в `TelegramUI/Images.xcassets` или других Telegram-каталогах.
- [ ] Папки в `DivoCoreImages.xcassets/` **не** имеют `"provides-namespace": true` (иначе `bundleImageName` не найдёт ассет по короткому имени).
- [ ] Tinted-иконки имеют `"template-rendering-intent": "template"` в Contents.json.

### Код

- [ ] DIVO-файлы не попадают в модули Telegram-слоя (`TelegramUI`, `AuthorizationUI`, `SettingsUI` и т.д.).
- [ ] В DIVO-модулях (`DivoUIKit`, `ProfileScreenUI`, `EventsUI` и др.) нет лишних импортов Telegram-инфраструктуры. Допустимо: `Display`, `AsyncDisplayKit`, `AppBundle`, `SwiftSignalKit` — они часть инфраструктурного слоя. Недопустимо: `TelegramCore`, `TelegramUI`, `AccountContext` **в DivoUIKit**.
- [ ] `import` соответствует реальному использованию — нет `import SwiftSignalKit` если ни один тип из него не задействован.

### BUILD

- [ ] Если модуль использует новый импорт — проверить `deps` в `BUILD` файле. Транзитивные зависимости работают, но explicit imports без explicit deps — ложная связность.

---

## 4. Техническое качество

### Мёртвый код

- [ ] Нет пустых `if`-блоков, оставшихся после удаления содержимого.
- [ ] Нет закомментированного кода (допускается только `// FIXME DIVO` для заглушек MTProto).
- [ ] Нет неиспользуемых `import`, `var`, `let`, `func`.
- [ ] Нет файлов, полностью состоящих из закомментированного кода — удалять (git хранит историю).

### Логирование

- [ ] Вместо `print()` использовать `divoLog(_:level:)` из `DivoCore`. Логи попадают в `DivoConsoleLogger` и доступны в Debug Menu.
- [ ] Для ошибок — `divoLog("...", level: .error)`. Для отладки — `divoLog("...")` (level по умолчанию `.debug`).
- [ ] `print()` в DIVO-коде не допускается — он не попадает в консоль DivoConsoleLogger и может утечь в production.

### Именование

- [ ] PascalCase для типов, camelCase для свойств/методов.
- [ ] Идентификаторы — только латиница. Кириллические символы в именах переменных (`closeСircleButton` с кириллической «С») не находятся поиском и ведут к скрытым багам.
- [ ] Переименование переменной после копипасты (`createEventNode` → осмысленное `editProfileNode`).

### API контрактов

- [ ] `onSave`, `onComplete` и подобные колбэки: если передаются через `init` — non-optional. Если через `var` после init — допустим optional, но тогда silent no-op при nil должен быть осознанным.
- [ ] Публичные типы в `Divo/Models` и `Divo/Services` — `public`.

---

## 5. Логическая корректность

### Порядок операций

- [ ] `popViewController` / `dismiss` — **после** всех действий над текущим контроллером (делегаты, spinners, cleanup). Иначе код выполняется на контроллере, уходящем из иерархии.
- [ ] Делегат вызывается после завершения сетевой операции, а не до.

### Обработка ошибок

- [ ] Ошибки сетевых запросов показываются пользователю через `DivoSnackbar`, а не через `print()` или `showAlert`.
- [ ] Если словарь / метаданные (gender, appearance, countries) не загрузились — **не** подставлять hardcoded fallback. Зависящий UI остаётся в disabled-состоянии + persistent snackbar с Retry.
- [ ] Retry перезапускает запрос и возвращает UI в loading-state.
- [ ] На success-path снекбар успеха показывается на экране, **который виден пользователю** (часто — предыдущий экран через делегат), а не на том, который закрывается.

### Fallback-значения

- [ ] `?? 0`, `?? 1`, `?? ""` для данных с API — подозрительны. Если поле nil, то nil должен оставаться nil, а не превращаться в мусорное значение (`height = 1 cm`).
- [ ] Пустая строка `""` — это не nil. API может трактовать их по-разному. Если поле опционально — передавать `nil`.

### Шиммеры и состояния загрузки

- [ ] Шиммер (`ImageLoader.addShimmerOverlay` / `removeShimmerOverlay`) используется при загрузке изображений.
- [ ] Спиннер (`DivoSegmentedSpinner`, `UIActivityIndicatorView`) — при загрузке данных / отправке формы.
- [ ] Все три состояния покрыты: loading → success → error. Нет зависшего спиннера при ошибке.
- [ ] Спиннер останавливается в **обоих** ветках — и success, и error.
- [ ] При ошибке загрузки UI не показывает частичные / пустые данные без объяснения.

### Клавиатура

- [ ] `keyboardWillShow` / `keyboardWillHide` — парные, не остаётся «сдвинутый» layout после dismiss.
- [ ] Кнопка Save / Apply доступна и при поднятой клавиатуре (constraint поднимается вместе с клавиатурой).
- [ ] `view.endEditing(true)` вызывается перед open picker / save / dismiss.

---

## Как проводить ревью

1. **`git diff --stat`** — оценить масштаб, убедиться что нет изменений в Telegram-модулях.
2. **`git diff --name-only`** — проверить, что DIVO-файлы лежат в DIVO-каталогах.
3. **grep по diff на hardcoded строки** — `"[A-Z]` в UI-коде без `DivoStrings`.
4. **grep по diff на hardcoded цвета** — `.white`, `.black`, `UIColor(red:` в DIVO-файлах.
5. **Пройти по секциям 1-5 этого документа.**
6. **Собрать и проверить на симуляторе** — happy path + error path.
