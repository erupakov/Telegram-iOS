# Онбординг DIVO — спецификация для верстки

**Адресат:** Михаил
**Автор:** Марина Зайцева
**Ветка:** `feature/PROJ-004-onboarding-skeleton`
**Старт работ:** 18 мая 2026
**Срок:** согласовывается отдельно
**Дизайн:** `/Users/Surf/Documents/DIVO/онбординг/` (фреймы Figma)

---

## 1. Что уже сделано (моя часть)

Скелет онбординга полностью собран: state-машина, навигация, form engine, mock submit, тестовая точка входа. Всё лежит в `submodules/OnboardingUI/Sources/Registration/`.

Чтобы запустить онбординг на устройстве:
1. Settings (DIVO табы) → нет ничего нового.
2. Открой Debug Menu → секция «Onboarding» → переключатель **«Show entry in Settings»** → ON.
3. Возвращайся в Settings → под строкой **«Log out»** появится **«Launch onboarding (debug)»**. Тап → модальный онбординг с самого начала.

Прохождение по экранам, ввод данных, переходы Phase 3 → Phase 4 → submit (mock) — всё работает.

---

## 2. Что трогает Михаил, что НЕ трогает

### Можно (нужно) трогать

- **Все файлы из `submodules/OnboardingUI/Sources/Registration/Screens/`** — это 5 контроллеров, в них вся вёрстка экранов. Меняй размещение subview, шрифты, цвета, иконки, отступы, анимации переходов.
- **`OnboardingFormFieldRow`** (внутри `OnboardingFormStepViewController.swift`) — это все типы полей. Можно вынести в отдельный файл; можно заменить на `DivoTextField`/`DivoButton`/etc. если такие компоненты уже есть.
- **Ассеты** — добавляй фоновые картинки для result-экранов в `DivoCore/DivoCoreImages.xcassets/`. Имена есть в `OnboardingResultCatalog.swift` (поле `imageAssetName`).
- **Локализация** — все строки сейчас в `OnboardingStrings.swift` placeholder'ами; переноси их в `DivoStrings.swift` под нужные MARK-секции с правильными `L(en:ru:es:pt:zh:)`.

### НЕ трогать (или менять только согласованно)

- **`State/*.swift`** — state-машина и описание состояния. Если поменяешь — поедет вся навигация.
- **`Coordinator/OnboardingRegistrationCoordinator.swift`** — оркестратор. Все callback'и контроллеров приходят сюда, и он решает «куда дальше».
- **`FormEngine/*.swift`** — описание полей, валидации, сериализация.
- **`Catalog/*.swift`** — содержимое quiz, форм, result-экранов. Если надо добавить роль или поменять состав поля — пиши мне, обсудим.
- **`Submit/*.swift`** — mock submit. Логика отправки.
- **`Entry/OnboardingRegistrationEntry.swift`** — публичная точка входа в модуль.

### Архитектурное правило (важное)

В каждом контроллере есть:
- `protocol Delegate { ... }`
- `weak var delegate: Delegate?`
- `func configure(...)` или `public init(...)` с параметрами
- `func valueSnapshot()` или подобное (на FormStepVC)

**Эти три точки не трогай.** Иначе coordinator не сможет управлять навигацией.

Всё, что внутри `setupUI()` / `applyDescriptor()` / `applyStep()` / `applyPresentation()` — пересобирай как угодно. Расставляй subview'ы по дизайну.

---

## 3. Карта экранов (фрейм → конструктор)

В дизайне Phase 3 (`/Users/Surf/Documents/DIVO/онбординг/Снимок экрана 2026-05-16 в 16.11.41.png` и далее).

### Phase 3 — Role Discovery

| Фрейм | Конструктор | Файл |
|---|---|---|
| Screen with Question in Onboarding (3 двери) | `OnboardingQuizViewController` | `Screens/OnboardingQuizViewController.swift` |
| Talent sub-role picker + quiz (длинный список) | `OnboardingQuizViewController` | — |
| Experience quiz (Model, New face) — «Do you have professional modelling experience?» | `OnboardingQuizViewController` | — |
| Industry — «How do you work?» | `OnboardingQuizViewController` | — |
| Industry Professionals sub-role picker | `OnboardingQuizViewController` | — |
| Companies & Brands sub-role picker | `OnboardingQuizViewController` | — |
| 3.3.A — Companies & Brands result | `OnboardingRoleResultViewController` | `Screens/OnboardingRoleResultViewController.swift` |
| 3.3.B — Industry Professionals result | то же | — |
| 3.3.C — Creative Professionals result | то же | — |
| 3.3.D — Model variant | то же | — |
| 3.3.D — New Talent variant | то же | — |
| 3.3.D — Actor variant | то же | — |
| 3.3.D — Dancer | то же | — |
| 3.3.D — Singer / Performer | то же | — |
| 3.3.E — Fan | то же | — |

### Phase 4 — Registration Forms

Все шаги всех 8 форм рендерятся одним `OnboardingFormStepViewController`. Контент полей берётся из `OnboardingFormCatalog`.

| Форма | Шагов | FormID | Где увидеть в Figma |
|---|---|---|---|
| 4.A — Companies & Brands | 4 | `companiesAndBrands` | `Снимок 16.14.19.png` |
| 4.B — Industry Professionals | 4 | `industryProfessionals` | `Снимок 16.14.31.png` |
| 4.C1 — Creative Individual | 4 | `creativeIndividual` | `Снимок 16.14.37.png` |
| 4.C2 — Creative Studio | 3 | `creativeStudio` | `Снимок 16.14.42.png` |
| 4.D1 — Talent Model | 4 | `talentModel` | `Снимок 16.14.48.png` |
| 4.D2 — Talent New Talent | 4 (4-й со спец TFP-блоком) | `talentNewTalent` | `Снимок 16.14.52.png` |
| 4.D3 — Actor / Dancer / Singer | 4 (спец-список на step 2 зависит от роли) | `talentActorDancerSinger` | `Снимок 16.15.03.png`, `16.15.08.png`, `16.15.12.png` |
| 4.E — Fan Registration | 2 (Skip на step 2) | `fan` | `Снимок 16.15.19.png` |

### Submit

| Экран | Конструктор | Состояния (enum Phase) |
|---|---|---|
| Финальный submit / loader | `OnboardingSubmitViewController` | `.idle`, `.submitting`, `.success`, `.failed(message:, networkError:)` |

### Bottom-sheet picker (single-select)

Используется для всех полей `.picker(...)` и `.country`:
- `OnboardingPickerSheetViewController` — открывается из `OnboardingFormStepViewController` через coordinator.

---

## 4. Что показывает каждый конструктор

### `OnboardingQuizViewController`

API:
```swift
init(descriptor: OnboardingQuizDescriptor, currentSelection: String?)
weak var delegate: Delegate?
func configure(descriptor: ..., currentSelection: ...)
```

`OnboardingQuizDescriptor` содержит:
- `titleKey`, `subtitleKey?` — резолвятся через `OnboardingStrings.resolve(...)`.
- `progressLabelKey?` — «Question 1 of 2» / «Question 2 of 2» / nil.
- `options: [Option]` — для single-select. Каждая опция: id, titleKey, subtitleKey?, iconAssetName?
- `primaryButtonKey` — текст Continue.
- `showsCloseButton: Bool` — только на самом первом экране (там вместо back — close).

Что отображать:
- Сверху слева — back arrow (на первом экране — close instead).
- Сверху по центру — `progressLabel` (если ключ задан).
- Снизу — Continue button (`DivoButton`), disabled пока не выбрана опция.
- Между ними — title + опциональный subtitle + список опций (`OnboardingQuizOptionRow` внутри файла).

Каждая опция: radio-индикатор, title, subtitle. По дизайну — карточка со скруглением `DivoDesignTokens.Radius.card` и border'ом, выделенный вариант — border `DivoColorPalette.accent` 2px.

### `OnboardingRoleResultViewController`

API:
```swift
init(presentation: OnboardingResultPresentation)
weak var delegate: Delegate?
func configure(presentation: ...)
```

`OnboardingResultPresentation` содержит:
- `titleKey`, `descriptionKey`
- `imageAssetName` — имя ассета из DivoCore xcassets. Подключи через `DivoImage.<name>`.
- `primaryButtonKey` = «Sounds right — let's go»
- `secondaryButtonKey` = «Choose a different role»

Что отображать (по дизайну 3.3.*):
- Верхняя половина экрана — фоновое фото на весь width, gradient внизу.
- Заголовок (`Font.helveticaNeue(28)`, белым, `DivoColorPalette.primaryTextOnDark`) над описанием.
- Описание мелким текстом (`Font.regular(14)`, `DivoColorPalette.textOnDarkSecondary`).
- Primary button — оранжевый `DivoButton`.
- Secondary button — тёмный фон `bannerBackgroundDark`, белый текст, скругление `Radius.pill`.
- Сверху слева — back arrow белый.
- Фон экрана — `DivoColorPalette.darkBackground`.

### `OnboardingFormStepViewController`

API:
```swift
init(step: FormStep, currentValues: [String: FormFieldValue])
weak var delegate: Delegate?
func configure(step: ..., currentValues: ...)
func valueSnapshot() -> [String: FormFieldValue]
func updateFieldValue(_ value: FormFieldValue, forKey key: String)
```

`FormStep` содержит:
- `titleKey` — «PERSONAL DETAILS» и т.п.
- `subtitleKey?` — опционально, под title. Для 4.D2 step 4 это TFP-инфо-блок.
- `stepProgressKey?` — «Step 2 of 4».
- `fields: [FormField]` — массив полей.
- `primaryButtonKey` — «Continue» / «Done» / «Let's go».
- `allowSkip: Bool` — показывать ли «Skip for now» справа в шапке.

Каждое поле (`FormField`):
- `key: String` — стабильный ключ, по которому coordinator хранит значение.
- `kind: FormFieldKind` — `.text` / `.email` / `.url` / `.phone` / `.date` / `.picker(options)` / `.multiPicker(...)` / `.country` / `.city` / `.photo(aspect:)`.
- `placeholderKey?`, `helpTextKey?`, `isRequired: Bool`.

Что отображать:
- Шапка: back arrow слева, прогресс-лейбл по центру, Skip (если `allowSkip`) справа — обычный UILabel/UIButton оранжевого цвета.
- Заголовок (`Font.helveticaNeue(22)`).
- Subtitle (если есть).
- Стек полей. Сейчас у меня placeholder-стиль (white card, border `separatorLight`). Замени на финальные `Divo*` компоненты.
- Primary button внизу. Disabled пока валидация формы не пройдёт (`FormValidator.isStepValid(...)`).

Важно для полей:
- **Текстовые** (`.text`, `.email`, `.url`, `.phone`, `.city`) — UITextField, событие `editingChanged` → `onValueChanged?(.string(text))`.
- **Picker** (`.picker`, `.country`, `.multiPicker`) — кнопка с placeholder'ом → тап → `onTapPickerOpen?()` → coordinator открывает `OnboardingPickerSheetViewController`.
- **Date** (`.date`) — тап → coordinator открывает date-picker (сейчас заглушка: ставит сегодняшнюю дату; ты подключаешь UIDatePicker bottom-sheet).
- **Photo** (`.photo`) — UIControl-область, тап → coordinator открывает галерею/камеру (сейчас заглушка: ставит `.asset("placeholder-asset")`).

### `OnboardingPickerSheetViewController`

API:
```swift
init(titleKey: String, options: [FormPickerOption], selectedId: String?, onSelect: (String?) -> Void)
```

Bottom-sheet single-select. Сейчас стиль простой; по дизайну (`Снимок 16.12.39.png` — Specialisation picker) надо:
- Заголовок по центру с галочкой подтверждения справа.
- Список опций. Выбранная — оранжевая галочка справа.
- Закрытие на тап галочки или pull-down.

### `OnboardingSubmitViewController`

API:
```swift
init()
weak var delegate: Delegate?
func startSubmit()
func applySuccess()
func applyFailure(error: Error)
```

State enum `Phase`:
- `.idle` — экран пустой, ждём запуска submit.
- `.submitting` — спиннер + «Setting up your profile…».
- `.success` — мелькает быстро перед onFinish.
- `.failed(message, networkError)` — заголовок «We couldn't finish that», persistent snackbar с описанием, кнопка Retry.

Дизайн этого экрана пока не утверждён — можешь сделать простой минималистичный с лого DIVO и спиннером по центру.

---

## 5. DIVO-конвенции (обязательно)

См. [docs/CODE_REVIEW.md](CODE_REVIEW.md) полностью. Краткий список применительно к онбордингу:

1. **Цвета** — только из `DivoColorPalette`. Нет `.white`, `.black`, `UIColor(red:)`, `UIColor(hex:)`. Если нужен новый токен — добавь в `DivoColorPalette` и используй.
2. **Радиусы / отступы** — `DivoDesignTokens.Radius.*` и `DivoDesignTokens.Spacing.*`. Если значения нет в шкале — TODO-комментарий.
3. **Шрифты** — `Font.helveticaNeue(...)` / `Font.regular(...)` из `Display`. **Не** `UIFont.systemFont`.
4. **Локализация — 5 языков**. Сейчас все строки в `OnboardingStrings.swift` placeholder'ами. **Каждый ключ нужно перенести в `DivoStrings.swift`** под отдельной MARK-секцией `// MARK: - Onboarding` и вызвать через `OnboardingStrings.mappedFromDivoStrings(_:)` (там подменяй `default: nil` на конкретный кейс).
5. **Ассеты** — все картинки в `DivoCore/DivoCoreImages.xcassets/`. Никаких `provides-namespace: true`. Tinted иконки — `template-rendering-intent: template`.
6. **Логирование** — `divoLog(...)`, не `print()`.
7. **Шиммеры / спиннеры** — для submit-экрана есть state-машина; для фото-загрузки используй `ImageLoader.addShimmerOverlay(...)` / `removeShimmerOverlay(...)`.
8. **Клавиатура** — keyboard avoidance уже в `OnboardingFormStepViewController` (поднимает primary button, корректирует `scrollView.contentInset.bottom`, тап по контенту гасит). Если будешь менять constraint primary button — сохрани reference `primaryButtonBottomConstraint` и логику в `handleKeyboardChange`/`handleKeyboardHide`.

---

## 6. Локализация — статус

Все ключи онбординга **уже мигрированы** в `DivoStrings.swift` под MARK-секциями `// MARK: - Onboarding — …` (Buttons, Quiz top-level, Quiz industry door, Quiz sub-role pickers + experience, Roles, Result screens, Common sections / fields, Form 4.A / 4.B / 4.C1 / 4.C2 / 4.D1 / 4.D2 / 4.D3 / 4.E). Резолвер `OnboardingStrings.mappedFromDivoStrings(_:)` использует все эти property.

Если **добавляешь новый ключ** (например, при доработке экрана):
1. Добавь property в `DivoStrings.swift` под соответствующей MARK-секцией с `L(en:ru:es:pt:zh:)`.
2. Добавь case в `OnboardingStrings.mappedFromDivoStrings(_:)`.
3. (Опционально) Добавь fallback в `OnboardingStrings.placeholders` — это safety-net, чтобы при забытом case в резолвере UI не показал сам key.

Параллельно — финальный copywriting придёт от продукта. Текущие тексты — рабочие, нo не утверждённые: при правках от копирайтера меняй только English+Russian, остальные 3 языка делают переводчики позже.

---

## 7. Что точно нужно сделать (минимальный чек-лист)

- [ ] Phase 3 — все экраны (top-level / пикеры / квиз / 9 result-экранов) выглядят как в Figma.
- [ ] Phase 4 — все 8 форм с правильными полями и порядком.
- [ ] Bottom-sheet pickers — стилистически как `Specialisation` в дизайне.
- [ ] Финальные фоновые картинки result-экранов в `DivoCoreImages.xcassets/`.
- [ ] Финальные иконки саб-ролей в пикерах (сейчас SF Symbol placeholder'ы).
- [x] Keyboard avoidance для FormStepVC — **сделано Мариной**: primary button поднимается над клавиатурой с keyboard duration/curve, scrollView получает `contentInset.bottom`, тап по контенту скрывает клавиатуру, picker-sheet и dismiss VC гасят её явно.
- [x] **Перенос всех строк онбординга в `DivoStrings.swift` с 5 языками — сделано Мариной**. См. MARK-секции `// MARK: - Onboarding — …` в `submodules/DivoCore/Sources/Services/DivoStrings.swift`. Резолвер `OnboardingStrings.mappedFromDivoStrings(_:)` уже использует эти property. Если правишь катaloги и добавляешь новый ключ — добавь property в DivoStrings (5 языков) и case в резолвер.
- [x] **UIDatePicker bottom-sheet для `.date` полей — сделано Мариной** (`OnboardingDateSheetViewController`, открывается из coordinator при тапе по любому date-полю).
- [x] **PHPicker для `.photo` полей — сделано Мариной** (`OnboardingPhotoPicker`, превью в `OnboardingFormFieldRow` показывает выбранную фотографию из файла).
- [ ] (Опционально) CityPicker для `.city` поля — после 22 мая.

---

## 8. Что точно НЕ нужно делать (моя зона)

- Менять `State/`, `Coordinator/`, `FormEngine/`, `Submit/`, `Catalog/`, `Entry/`.
- Подключать реальный registration endpoint — это после согласования контракта с бэком.
- Менять список ролей — это `OnboardingRoleRegistry.defaultRoles` в `OnboardingRoles.swift`.
- Менять состав полей формы — это `OnboardingFormCatalog`.
- Если по дизайну нужны новые поля / другие шаги — пиши, обсудим и поправим catalog вместе.

---

## 9. Локальное тестирование без бэка

1. Открой Debug Menu → секция «Onboarding» → toggle ON.
2. Settings → «Launch onboarding (debug)».
3. Проходи happy-path всех 5 веток (для каждой top-level двери и каждой саб-роли):
   - I want to get hired → Model → опыт → Yes → 3.3.D Model → 4.D1 4 шага → Submit.
   - I want to get hired → Model → опыт → No → 3.3.D New Talent → 4.D2 4 шага → Submit.
   - I want to get hired → Photographer → 3.3.C Creative → 4.C1 4 шага → Submit.
   - I'm looking for talent → I'm an industry pro → Scout → 3.3.B → 4.B 4 шага → Submit.
   - I'm looking for talent → I represent a company → Fashion brand → 3.3.A → 4.A 4 шага → Submit.
   - I'm here to follow → 3.3.E Fan → 4.E 2 шага → Submit.
4. Проверь back-навигацию на каждом шаге, «Choose a different role» с любого result-экрана.
5. Submit-экран при mock-режиме всегда успешен. Чтобы проверить error-path — временно в `OnboardingRegistrationCoordinator.init(...)` вызывающей стороне (DivoSettingsController.launchOnboardingDebug) передай `submitService: MockOnboardingSubmitService(mode: .alwaysFail(...))`. Появится snackbar и Retry.
6. После submit → onFinish дёргается с `true`; controller дисмиссится автоматически.
7. Прерви онбординг (закрой приложение / убей таск) и зайди снова — он подхватит сохранённый прогресс (`OnboardingProgressStore`). Только при `forceFresh: true` (Settings → debug) — каждый раз с нуля.

---

## 10. Открытые вопросы — обсудим в понедельник

Из плана работ (`/Users/Surf/Documents/DIVO/онбординг/work-plan.md`):

1. **3 двери (дизайн) vs 5 дверей (PDF v3.0)** — ждём решение продукта.
2. **Creative — отдельная категория или внутри Talent-пикера?** — ждём решение дизайна/продукта.
3. **Где появляется C8 Studio / Location в навигации?** — Studio-форма (4.C2) реализована, но в текущем графе недостижима.
4. **Финальные тексты result-экранов** — ждём от копирайтера.
5. **Premium-gating в онбординге** — продукт.
6. **Точный JSON-контракт registration endpoint** — бэк.

Решения по 1–3 могут изменить registry/state-machine, но не контроллеры. Поэтому твоя вёрстка останется в силе.

---

## 11. Контакты

Любые вопросы по архитектуре, поведению, callback'ам — пиши Марине. Если идея «давай сделаю по-другому в state-машине / coordinator» — сначала согласуем, чтобы не разойтись.
