# Ревью реализованных REST-эндпоинтов (iOS)

Дата: 2026-04-06

---

## GET /dictionary/appearances и GET /dictionary/gender

**Где:** EditProfileController, AddModelController, CreateEventController, AuthorizationSequenceApplyAsController

| Проблема | Серьёзность |
|----------|-------------|
| Нет кеширования — каждый экран грузит справочники заново (3 независимых вызова одного и того же) | Высокая |
| Ошибка копипаста в EditProfileController — при ошибке загрузки gender показывается сообщение "failedToLoadAppearance" | Средняя |
| Нет спиннера в CreateEventController (в отличие от EditProfile) | Низкая |

---

## GET /user/info

**Где:** EventsController, DivoSettingsController, DebugUserInfoController

| Проблема | Серьёзность |
|----------|-------------|
| DivoSettingsController: флаг `isProfileLoaded` не сбрасывается при ошибке — повторная загрузка невозможна | Высокая |
| EventsController: вызывается и в init, и в viewWillAppear — дублирование запросов | Средняя |
| DivoSettingsController: нет таймаута — если запрос зависнет, шиммер бесконечный | Средняя |

---

## GET /user/{id}

**Где:** WorkExperienceController, PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| WorkExperienceController: если основной запрос `/model-work-history` падает, грузится ВЕСЬ профиль `/user/{id}` только ради текстового поля — избыточная загрузка данных | Высокая |

---

## POST /user/update-profile

**Где:** EditProfileController, EditSocialLinksController, PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| EditProfileController: ошибка копипаста — при ошибке агентства показывается "Error saving social links" | Средняя |
| EditSocialLinksController: URL соцсетей не валидируются перед отправкой | Средняя |
| EditSocialLinksController: nil конвертится в пустую строку "" — неясен контракт с API | Низкая |

---

## GET /user/engagement

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Force unwrap `model.userId!` на строке 438 — потенциальный краш | Критическая |
| Для счётчиков профиля запрос с `limit=1` тянет item только ради `totalCount` из пагинации — лишние данные | Средняя |
| Ошибки пишутся через `print()` вместо `debugLog()` — нет единого формата логов | Низкая |

---

## POST /user-gallery/list

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Хардкод `limit: 6` без возможности настройки | Средняя |
| Race condition: параллельные запросы фото и видео могут одновременно модифицировать массивы без синхронизации | Высокая |

---

## POST /user-gallery/add

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Два отдельных Task-блока (UI-обновление и загрузка) — нет гарантии порядка выполнения | Высокая |

---

## DELETE /user-gallery/{id} и DELETE /publication/{id}

**Где:** ProfileGalleryController

| Проблема | Серьёзность |
|----------|-------------|
| Проверка ошибки `response.errors == nil` — если API вернёт пустой массив `[]`, покажет ошибку на успешном ответе | Средняя |
| Риск IndexOutOfBounds при удалении последнего элемента во время другого удаления | Средняя |

---

## POST /publication/list

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Ответ фильтруется клиентом на видео — API возвращает лишние данные, нет серверного фильтра | Высокая |
| Хардкод `limit: 6` | Средняя |

---

## POST /publication/create

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Хардкод: `title: "My Video"`, `description: "Video description"`, `type: "educational"` — заглушки в проде | Критическая |

---

## POST /event/list

**Где:** EventsController, PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| EventsController: `offset` всегда 0, нет пагинации — грузятся только первые 30 событий | Высокая |
| EventsController: пустой `catch {}` — ошибка полностью проглатывается | Высокая |
| PublicProfileScreenController: N+1 запрос — грузит список, потом по одному `/event/{id}` на каждое событие | Высокая |

---

## POST /event/types

**Где:** CreateEventController

| Проблема | Серьёзность |
|----------|-------------|
| Используется `AgencyListRequest` вместо корректного типа запроса — копипаста | Средняя |
| `title: nil` всегда отправляется в body | Низкая |

---

## GET /event/{id}

**Где:** EventDetailController, CreateEventController

| Проблема | Серьёзность |
|----------|-------------|
| EventDetailController: грузит данные в viewWillAppear каждый раз, хотя данные уже переданы в параметре | Высокая |
| EventDetailController: парсинг даты через поиск символа `T` — хрупко | Средняя |
| PublicProfileScreenController: без лимита на параллельность — может запустить 30+ одновременных запросов | Средняя |

---

## POST /event/create и POST /event/update/{id}

**Где:** CreateEventController

| Проблема | Серьёзность |
|----------|-------------|
| Raw-текст ошибки API показывается пользователю без санитизации | Средняя |
| Если запрос зависнет, кнопка сохранения остаётся заблокированной навсегда (нет таймаута) | Средняя |

---

## POST /file/upload-file

**Где:** EditProfileController, AddModelController, PublicProfileScreenController, CreateEventController

| Проблема | Серьёзность |
|----------|-------------|
| Нет защиты от повторных нажатий — можно запустить несколько параллельных аплоадов | Высокая |
| Хардкод имён файлов: "photo.jpg", "event_cover.jpg", "event_photo.jpg" — не уникальны | Средняя |
| Хардкод JPEG compression quality 0.8, нет проверки размера | Низкая |
| Непоследовательность: AddModelController не передаёт fileName/mimeType, а CreateEventController передаёт | Низкая |

---

## POST /feedline/list

**Где:** ModelsFeedController, PublicProfileScreenNode

| Проблема | Серьёзность |
|----------|-------------|
| ModelsFeedController: нет защиты от параллельных вызовов при быстром переключении табов | Критическая |
| PublicProfileScreenNode: нет `[weak self]` — потенциальная утечка памяти | Высокая |
| PublicProfileScreenNode: `similarProfilesOffset` не увеличивается после ответа — повторные запросы грузят одно и то же | Высокая |
| `hasMore` определяется как `count >= limit` — ложный true на последней странице | Средняя |

---

## POST /follower/follow и POST /follower/unfollow

**Где:** ModelsFeedNode

| Проблема | Серьёзность |
|----------|-------------|
| Нет дебаунса — спам нажатий создаёт N одновременных запросов, которые могут выполниться не по порядку | Критическая |
| Optimistic UI update до ответа API — при ошибке откатывается, но окно рассинхрона есть | Высокая |
| Ответ API игнорируется (`let _: FollowResponse`) | Низкая |

---

## POST /agency/list

**Где:** AuthorizationSequenceApplyAsController

| Проблема | Серьёзность |
|----------|-------------|
| Не обнаружено критичных проблем | -- |

---

## POST /agency/update

**Где:** EditProfileController, PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Нет валидации agencyId перед отправкой | Средняя |

---

## POST /agency/{id}/models/list

**Где:** PublicProfileScreenController

| Проблема | Серьёзность |
|----------|-------------|
| Хардкод `offset: 0, limit: 50` — нет пагинации, если моделей больше 50 | Высокая |
| Хардкод `role: "Model"` — роль не берётся из ответа API | Средняя |
| Хардкод `isPremium: false` — премиум-статус не берётся из ответа API | Средняя |
| Нет `userId` в `ModelItem` — нельзя перейти в профиль модели по тапу | Высокая |

---

## GET /model-work-history и CRUD

**Где:** WorkExperienceController, AddWorkExperienceNode

| Проблема | Серьёзность |
|----------|-------------|
| После каждого DELETE вызывается полная перезагрузка списка (1-2 запроса) — при удалении 5 записей = 5-10 лишних запросов | Высокая |
| AddWorkExperienceNode: дата форматируется без учёта timezone — возможен сдвиг на день | Средняя |
| AddWorkExperienceNode: raw-ошибка API показывается пользователю | Средняя |
| `agencyId: nil` всегда — хардкод | Средняя |

---

## Проблемы, требующие доработок Backend API

### 9. POST /event/types — совпадение структуры с /agency/list случайное

**Серьёзность:** Средняя

Для загрузки типов событий клиент использует модели от эндпоинта агентств — `AgencyListRequest` и `AgencyListResponse` / `AgencyItem`:
```swift
let request = AgencyListRequest(offset: offset, limit: limit, title: nil)
let response: AgencyListResponse = try await DivoAPIClient.shared.request(
    path: "/event/types",
    method: "POST",
    body: request
)
```

Это работает только потому, что оба ответа случайно имеют одинаковую структуру (`{ id, title }`). Но:
- В body всегда отправляется лишнее поле `title: null` (от `AgencyListRequest`), которое к типам событий не относится
- Если бэкенд добавит поля в ответ `/agency/list` или `/event/types` (например `description`, `icon`, `parentId`) — второй эндпоинт сломается, т.к. оба парсятся одной моделью

**Что нужно от бэкенда:**
- Задокументировать контракт `/event/types` отдельно от `/agency/list`
- Если это справочник (14 элементов, меняется редко) — перенести в `GET /dictionary/event-types` и отдавать без пагинации, как `/dictionary/gender`

---

### 10. POST /feedline/list — нет пагинации в ответе и нет excludeUserId

**Серьёзность:** Средняя

1. Ответ содержит только `items`, без `pagination` / `totalCount`. Клиент определяет наличие следующей страницы как `items.count >= limit` — на последней странице, если элементов ровно `limit`, делается лишний запрос, возвращающий пустой массив.

2. Для блока «Похожие профили» в профиле клиент фильтрует ответ, убирая текущего пользователя:
```swift
guard item.user.id != currentUserId else { return nil }
```

**Что нужно от бэкенда:**
- Добавить `pagination` с `totalCount` в ответ (как в `/user-gallery/list`)
- Добавить параметр `excludeUserId`

---

### 11. GET /model-work-history — не возвращает agencyPhoto

**Серьёзность:** Средняя

Клиентская модель `WorkHistoryItem` содержит поле `agencyPhoto: UserFile?`, по дизайну у каждой записи должен быть логотип агентства. Но бэкенд это поле не возвращает:
```json
{ "id": 17, "agencyId": null, "agencyName": "test", "agencyDisplayName": "test", "startDate": "2026-03-25", "endDate": null, "isCurrent": true }
```

**Что нужно от бэкенда:**
- Добавить `agencyPhoto` в ответ `/model-work-history`
- Заполнять `agencyId` если агентство существует в базе

---

### 12. POST /publication/create — обязательные поля без UI

**Серьёзность:** Средняя

При загрузке видео в галерею клиент отправляет хардкоды:
```swift
title: "My Video",
description: "Video description",
type: "educational"
```
Пользователь не вводит ни заголовок, ни описание, ни тип — он просто добавляет видео в галерею.

**Что нужно от бэкенда (одно из):**
- Сделать `title`, `description`, `type` опциональными с дефолтами на сервере
- Или добавить поддержку видео в `/user-gallery/add`

---

### 13. POST /event/create — ответ без data, хардкоды, нет geo-интеграции

**Серьёзность:** Высокая

1. Ответ `CreateEventResponse` содержит только `message` и `errors`, без `data` — клиент не знает ID созданного события
2. Хардкоды: `paymentType: 1`, `paymentFrequency: 1`, `cost: "0"`, `role: ["model"]` — нет UI для этих полей
3. `cityId: 1` — хардкод-заглушка. Используется Telegram-овский пикер стран вместо `/geo/search-by-address-name`
4. `address.latitude` и `address.longitude` всегда `null`
5. `dateTo` автоматически = `date + 2 часа`, нет UI для выбора конца
6. `measuringSystem` не передаётся — бэкенд не знает в какой системе размеры

**Что нужно от бэкенда:**
- Возвращать `data` с ID созданного события в ответе
- Сделать `paymentType`, `paymentFrequency`, `cost`, `dateTo` опциональными с дефолтами
- Документировать: может ли бэкенд определить `cityId` по координатам или `formatted`-адресу
- Документировать ожидаемую систему измерений для размеров

---

### 14. POST /file/upload-file — осиротевшие файлы

**Серьёзность:** Средняя

Двухшаговый процесс: сначала `POST /file/upload-file` (получает uuid), потом привязка через `/user-gallery/add`, `/publication/create`, `/user/update-profile` и т.д. Если второй запрос упадёт — файл остаётся на сервере без привязки.

**Что нужно от бэкенда:**
- Механизм TTL / автоочистки неприкреплённых файлов (например, удалять через 24 часа)
- Или эндпоинт `DELETE /file/{uuid}` для явного удаления клиентом при отмене операции

---

### 15. Неконсистентный формат ошибок между эндпоинтами

**Серьёзность:** Низкая

| Эндпоинт | Тип `errors` |
|----------|-------------|
| `POST /user-gallery/add` | `String?` |
| `POST /user-gallery/list` | `[String]?` |
| `DELETE /user-gallery/{id}` | `[String]?` |
| `POST /event/create` | `[String]?` |
| `POST /publication/create` | `String?` |

**Что нужно от бэкенда:**
Унифицировать формат ошибок — везде `[String]?` или везде `String?`.

---

### Сводная таблица

| # | Проблема | Эндпоинт | Серьёзность |
|---|----------|----------|-------------|
| 1 | Нет фильтрации событий по userId | POST /event/list | Критическая |
| 2 | N+1 запросов на детали событий | POST /event/list + GET /event/{id} | Критическая |
| 3 | Нет фильтрации по типу медиа | POST /publication/list | Высокая |
| 4 | Нет summary-эндпоинта для engagement | GET /user/engagement | Средняя |
| 5 | Нет серверной сортировки | POST /event/list | Средняя |
| 6 | Один эндпоинт для разных обновлений | POST /user/update-profile | Средняя |
| 7 | Непоследовательная структура изображений в feedline | POST /feedline/list | Средняя |
| 8 | Upload не возвращает созданный объект | POST /user-gallery/add, /publication/create | Низкая |
| 9 | Совпадение структуры /event/types и /agency/list случайное | POST /event/types | Средняя |
| 10 | Нет pagination и excludeUserId | POST /feedline/list | Средняя |
| 11 | Нет agencyPhoto в ответе | GET /model-work-history | Средняя |
| 12 | Обязательные поля без UI (title, description, type) | POST /publication/create | Средняя |
| 13 | Ответ без data, хардкоды, нет geo | POST /event/create | Высокая |
| 14 | Осиротевшие файлы без TTL | POST /file/upload-file | Средняя |
| 15 | Разный формат errors (String vs [String]) | Несколько эндпоинтов | Низкая |

Подробности пунктов 1-8 — см. [api-backend-needs.md](api-backend-needs.md)

---

## Системные проблемы (по всем эндпоинтам)

| Проблема | Масштаб |
|----------|---------|
| **Нет кеширования справочников** — `/dictionary/*` грузится заново на каждом экране | 6 вызовов вместо 2 |
| **Разнобой в логировании** — микс `print()`, `debugLog()`, emoji-логи, пустые catch | Все файлы |
| **Хардкод лимитов пагинации** — 6, 10, 20, 30, 50 в разных местах без констант | 8+ мест |
| **Нет единого механизма retry** — ни на одном эндпоинте | Все файлы |
| **Нет отмены запросов** — при уходе с экрана запросы продолжают выполняться | Все файлы |
