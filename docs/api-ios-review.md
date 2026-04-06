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

## Системные проблемы (по всем эндпоинтам)

| Проблема | Масштаб |
|----------|---------|
| **Нет кеширования справочников** — `/dictionary/*` грузится заново на каждом экране | 6 вызовов вместо 2 |
| **Разнобой в логировании** — микс `print()`, `debugLog()`, emoji-логи, пустые catch | Все файлы |
| **Хардкод лимитов пагинации** — 6, 10, 20, 30, 50 в разных местах без констант | 8+ мест |
| **Нет единого механизма retry** — ни на одном эндпоинте | Все файлы |
| **Нет отмены запросов** — при уходе с экрана запросы продолжают выполняться | Все файлы |
