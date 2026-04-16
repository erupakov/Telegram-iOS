# Mock API

Локальные моки для работы без бэкенда. Перехватывают сетевые запросы на уровне `URLProtocol` — бизнес-код не знает о подмене.

## Как включить

1. Открыть **Debug Screen** (таб Settings → Debug)
2. В секции **Network** включить тоггл **Mock API**
3. Все запросы к `*.divo.fashion` начнут возвращать локальные данные

Выключение тоггла возвращает работу с реальным сервером. Перезапуск приложения не нужен.

## Связь с ролью

Mock `/user/info` (свой профиль) возвращает данные в зависимости от **User Role** в Debug Screen:

| User Role | `role` в ответе | Заполненные поля |
|-----------|-----------------|------------------|
| Model | `model` | `model` (height, weight, bust, waist, hips, shoeSize, hair/eye/skin) |
| New Face | `new_face` | `model` (аналогично, другие значения) |
| Agency | `agency_employee` | `agencyEmployee` (agencyId, agencyName, position) |
| Fan | `fan` | `customer` (interests) |

При смене токена роль выставляется автоматически (Agency token → Agency, Model token → Model). При смене роли токен тоже синхронизируется.

Чужие профили (`/user/{id}`) всегда возвращают модель — независимо от выбранной роли.

## Замоканные эндпоинты

### С данными

| Эндпоинт | Метод | Описание |
|----------|-------|----------|
| `/feedline/list` | POST | Лента моделей, 30 элементов, пагинация по offset/limit |
| `/feedline/search` | POST | Поиск, 25 элементов, пагинация по offset/limit |
| `/dictionary/gender` | GET | 3 пола (Male, Female, Non-binary) |
| `/dictionary/appearances` | GET | Длина/цвет волос, цвет глаз, цвет кожи |
| `/user/info` | GET | Свой профиль (зависит от роли) |
| `/user/{id}` | GET | Чужой профиль (всегда модель) |
| `/user/engagement` | GET | Статистика: 128 лайков, 540 просмотров, 42 подписки |
| `/user-gallery/list` | GET | 12 фото в галерее |
| `/event/list` | GET | Пустой список |
| `/event/{id}` | GET | Детали мок-события |
| `/event/types` | GET | 3 типа (Photoshoot, Fashion Show, Casting) |
| `/agency/list` | GET | 3 агентства |
| `/agency/{id}/models/list` | GET | Пустой список |
| `/model-work-history` | GET | Пустой список |

### Action-эндпоинты (возвращают `{"message": "OK"}`)

`/feedline/like`, `/feedline/unlike`, `/follower/follow`, `/follower/unfollow`, `/file/upload-file`, `/user-gallery/add`, `/publication/create`, `/user/update-profile`, `/agency/update`, `/user/update-social-links`

### Все остальные

Любой запрос к `*.divo.fashion`, не попавший в списки выше, получает generic success: `{"message": "OK", "data": null, "errors": []}`.

## Картинки

Моки используют [picsum.photos](https://picsum.photos) — публичные плейсхолдеры. Для отображения нужен интернет (или Wi-Fi без VPN-блокировок). Если картинки не грузятся — ячейки покажут стандартный placeholder.

## Файлы

```
submodules/DivoCore/Sources/Services/Mocks/
├── DivoMockURLProtocol.swift   # URLProtocol — перехват и роутинг запросов
└── DivoMockData.swift          # Мок-данные (JSON как Swift-строки)
```

Флаг `isMockEnabled` хранится в `DivoConfig` (UserDefaults).

## Как добавить мок для нового эндпоинта

### 1. Добавить данные в `DivoMockData.swift`

```swift
// Статический ответ
static let myNewEndpoint = """
{
    "message": "OK",
    "data": { ... }
}
""".data(using: .utf8)!

// Или динамический (с пагинацией, зависимостью от роли и т.д.)
static func myNewEndpoint(offset: Int, limit: Int) -> Data {
    // ...
}
```

Если ответ зависит от роли — используй `DivoConfig.currentUserRole`:

```swift
static func myEndpoint() -> Data {
    let role = DivoConfig.currentUserRole
    switch role {
    case .model, .newFace:
        return modelResponse
    case .agency:
        return agencyResponse
    case .fan:
        return fanResponse
    }
}
```

### 2. Добавить маршрут в `DivoMockURLProtocol.swift`

В метод `mockResponse(for:offset:limit:)`:

```swift
// Точное совпадение по суффиксу пути
case _ where path.hasSuffix("/my/new/endpoint"):
    return DivoMockData.myNewEndpoint

// Или паттерн с regex (для путей с ID)
if path.range(of: #"/my-entity/\d+$"#, options: .regularExpression) != nil {
    let id = Int(path.split(separator: "/").last ?? "1") ?? 1
    return DivoMockData.myEntityDetail(id: id)
}
```

### 3. Проверить модель ответа

Мок-JSON должен соответствовать Decodable-структуре, в которую декодируется ответ. Если структура не совпадёт — приложение получит ошибку декодирования (как при реальном 500).

Найти модель: посмотри тип в `let response: SomeResponse = try await DivoAPIClient.shared.request(...)` в контроллере, затем найди `struct SomeResponse` в `submodules/DivoCore/Sources/Models/`.

## Ограничения

- **Upload** (`/file/upload-file`) возвращает generic success без `fileUuid` — загрузка фото "пройдёт", но ответ может не содержать нужных полей для следующего шага
- **Пагинация** работает корректно только для `/feedline/list`, `/feedline/search` и `/user-gallery/list` — остальные списки возвращают фиксированные данные
- **Картинки** требуют интернет (picsum.photos) — для полностью офлайн-работы нужно заменить URL на локальные ассеты
