# Teamgram layer-201 — адаптация клиента

DIVO-клиент собран из свежего Telegram-iOS (схема **layer ~222**), а teamgram-сервер
говорит на **layer 201**. Принцип работы: **весь код — стоковый Telegram, мы только
адаптируем wire-формат под 201.** Никаких UX-правок (не прятать индикаторы/кнопки и т.п.) —
поведение и вид должны быть как в Telegram; меняется только сериализация/парсинг на проводе.

## Почему вообще нужна адаптация

Каждый TL-тип/метод помечен «отпечатком» — CRC32 от текста его определения. Между layer 201
и 222 апстрим Telegram дописывал в типы поля → CRC (constructor ID) поменялся, даже если
смысл тот же. Клиент шлёт `invokeWithLayer(201)` (`Serialization.swift:currentLayer() -> 201`),
сервер отдаёт **201-формат**, а парсеры/энкодеры форка ждут 222 → рассинхрон.

**Layer НЕ меняем** — он зафиксирован (вся экосистема, включая Android, на 201). Источник
TL-определений — официальная схема **core.telegram.org/schema** (выбрать нужный слой). teamgram-репо
(`/Users/Surf/Projects/DIVO/teamgram-*`) — только для сверки constructor ID и поиска предиката,
НЕ как источник layout'а.

## Две стороны адаптации

### 1. Чтение ответов (decode) — парсеры
Сервер шлёт 201-конструкторы; форк их не знает. Для каждого добавляем alias в
`submodules/TelegramApi/Sources/Api0.swift`:
```swift
dict[<201-id>] = { return Api.<Type>.parse_<name>_teamgram_layer201($0) }
```
а сам парсер (под 201-layout) — в `submodules/TelegramApi/Sources/ApiTeamgramLayer200.swift`.
Alias на существующий `parse_*` достаточен **только** если 201 — строгий префикс 222 и ни один
общий бит не переинтерпретирован (пример: `storyItem#79b26a24` — 222 лишь дописал `albums`@flags.19,
который 201-сервер не выставляет). **Осторожно:** совпадение constructor-имени ≠ совпадение layout.
Контрпример — `user#020b1422`: на flags2.5 у 201 `stories_max_id:int`, а у 222 `RecentStory`
(объект), общий бит с РАЗНЫМ типом → alias на `parse_user` ломал парсинг на любом юзере со сторис
(красный «!», бесконечный getDifference). Нужен был отдельный `parse_user_teamgram_layer201`.

Покрыто: `message`, `messageService`, `channel`, `channelFull`, `userFull`, `messages.messages`,
`messages.messagesSlice`, `user` (свой парсер — flags2.5 `stories_max_id:int`≠222),
`storyItem` (alias — префикс 222), ряд `Update`-конструкторов и контейнеры
`messages.dialogs`/`updates.*` (многие совпадают с 222 и работают без правок — потому список
чатов/история парсятся).

### 2. Отправка методов (encode) — энкодеры write-методов
Бóльшая ловушка: форк **кодирует** методы 222-конструктором, а сервер на 201 их не понимает
и **молча дропает** (запрос не доходит до хендлера, ответа нет, действие «висит»).
Для каждого дрейфанувшего write-метода — обёртка `*_teamgram_layer201` в
`ApiTeamgramLayer200.swift` (extension `Api.functions.messages`): 201-constructor + поля в
201-порядке + `flags & <whitelist-маска>` (отсекает биты полей, добавленных в 222). Вызовы в
`TelegramCore` свапаются на обёртку (лишние 222-параметры выкидываются).

Сделано (ядро): `sendMessage`, `sendMedia`, `editMessage`, `forwardMessages`, `saveDraft`.
Также (другие namespace): `contacts.addContact` (222 `d9ba2e54`+note → 201 `e8f463d0`),
`stories.sendStory` (222 `737fc2ec`+albums → 201 `e4e6694b`).

**Осталось (вторичный батч, 10 методов `messages.*`, дрейфанули, но реже используются):**
`readReactions`, `getUnreadReactions`, `markDialogUnread`, `getDialogUnreadMarks`,
`getSavedHistory`, `getSavedDialogs`, `deleteSavedHistory`, `getSponsoredMessages`,
`setChatTheme`, `unpinAllMessages`. Делать по тому же шаблону — по мере необходимости.

### 3. Дрейф типа ВОЗВРАТА метода (отдельный случай)
Бывает, что request-конструктор форк шлёт нормально и сервер отвечает, но **тип ответа** между
201 и 222 разный. Симптом в логе: `can't parse magic 0x<сырое-значение> in <Type> [i/N]` — парсер
пытается читать элементы вектора как boxed-объекты, а сервер прислал сырые скаляры.
Пример: `stories.getPeerMaxIDs` — на 222 возвращает `Vector<RecentStory>` (boxed), на 201 —
`Vector<int>` (constructor запроса `535983c3`, ответ — сырые int). Форк (222, запрос `78499170`)
давится: `can't parse magic 0x712a292d in RecentStory`. Фикс — обёртка `*_teamgram_layer201` в
`ApiTeamgramLayer200.swift` с тем же request-buffer, но своим `DeserializeFunctionResponse`,
читающим 201-тип и при необходимости заворачивающим в форк-тип (int → `RecentStory(maxId:)`).
Свап вызова в `TelegramCore` (`AccountViewTracker`). Сделано: `stories.getPeerMaxIDs`.

## Поведенческая адаптация (не парсер, но нужна)
`submodules/TelegramUI/Sources/ApplicationContext.swift` — `deviceContactPhoneNumbers` отдаёт
пустое множество СРАЗУ. Иначе при не-определённом доступе к контактам сигнал не эмитит, а от него
зависит combineLatest истории → **открытие чата висит**. UI не меняется, поведение Telegram сохранено.

## Как понять, что всё работает (верификация)

Диагностика идёт на **debug-экран** (shake → `DivoStandaloneLogsViewController`) через мост
`[MTProto]` (`DivoConsoleLogger` слушает нотификацию `DivoMTProtoLog`; постят
`MTRequestMessageService.m` и `Api0.swift`). По каждому RPC видно:
- `[MTProto] → <method>` — запрос ушёл;
- `[MTProto] OK ← <method>` — успех;
- `[MTProto] RPC ERROR ← <method> | code= desc=` — ошибка сервера (с текстом, как в Android);
- `[MTProto] can't parse magic 0x… in <type>` — ответ не распарсился (нужен 201-парсер).

Чек-лист «работает»:
1. **Список чатов** — грузится (`getDialogs` → `OK`).
2. **Открытие чата** — открывается (`getHistory`/`getFullUser` → `OK`, экран показывается).
3. **Отправка** — текст/фото/правка/пересылка уходят: `→ sendMessage` затем `OK ← sendMessage`
   (а НЕ тишина). Сообщение не «висит».
4. В логе нет `can't parse magic` и нет неожиданных `RPC ERROR` по нужным методам.

## Что делать при проблемах

| Симптом | Диагноз | Действие |
|---|---|---|
| Список/история пустые, в логе `can't parse magic 0x<hex> in <type>` | сервер прислал 201-конструктор, нет парсера | по hex найти предикат в `teamgram-proto/mtproto/class_name_registers.go`; взять layout с core.telegram.org/schema; добавить `parse_*_teamgram_layer201` + alias в `Api0` |
| Действие (отправка/правка/…) «висит», в `bff/access.log` метода НЕТ | клиент шлёт 222-конструктор, сервер дропнул | сверить constructor метода @201 vs @222 (`class_name_registers.go`); написать `*_teamgram_layer201` encode-обёртку + свапнуть вызовы |
| `can't parse magic 0x<сырое> in <Type> [i/N]` (парс вектора) | дрейф ТИПА ВОЗВРАТА: сервер шлёт `Vector<скаляр>`, форк ждёт `Vector<boxed>` | обёртка `*_teamgram_layer201` с тем же request, но своим `DeserializeFunctionResponse` под 201-тип (см. раздел «Две стороны → 3») |
| `RPC ERROR … code=500 unknown service` | teamgram не реализует сервис | второстепенно (attach-menu, gifts и т.п.); к Eugene или игнор |
| Фича/кнопка пропала, код стоковый | поведение зависит от данных сервера (appConfig/подписки) | проверить соответствующий RPC в `[MTProto]`-логе: `OK` + поля нет → серверная сторона; `can't parse magic` → наш парсер. Пример: «+» сторис гейтится `storyPostingAvailable` ← `help.getAppConfig` (`stories_posting`) |

### Аудит дрейфа методов (какие write-методы кодируются неверно)
Сравнить constructor каждого `Api.functions.messages.*` (первый `buffer.appendInt32` в `Api*.swift`)
с `@201` из `teamgram-proto/mtproto/class_name_registers.go`. Где fork@222 ≠ srv@201 — нужна
201-обёртка. (Из 240 messages-методов дрейфануло 15; ядро из 5 сделано.)

### Серверные логи (FTP, UTC; MSK = UTC+3)
Креды FTP — из секретов (в репо не хранятся): `curl -s -u "$FTP_USER:$FTP_PASS" 'ftp://$FTP_HOST/<path>'`
- `bff/access.log` — высокоуровневые RPC (`sendMessage`, `getHistory`, `getDifference`, …): дошёл ли метод.
  Большой (10+ МБ) и по FTP часто рвётся по таймауту — тянуть **хвост по диапазону**: получить размер
  из листинга `bff/`, затем `curl --range $((SIZE-1200000))- …`.
- `msg/access.log` — message-сервис (sendMessage/sendMedia доходят сюда; `updates.getState` — НЕ здесь).
- `gnetway/access.log`, `session.log` — транспорт/handshake/сессии.
- Полезный фильтр: `getDifference - reply` → `updates_difference` (ещё синкается) vs `updates_differenceEmpty` (синк встал).

## Наблюдения сессии 2026-05-27 (для следующего окна)
- **user@201 подтверждён по серверу:** до фикса getDifference долбил `updates_difference` каждые ~5с
  (pts не двигался из-за `stories_max_id`), после — досходится до `differenceEmpty`. Цикл снят.
- **Навбарное «Updating…»** зажигается от `stateManager.isUpdating` (difference) ИЛИ MTProto
  `connectionStatus == .updating` (`Account.swift:1297-1325`) — сторис-синк сюда НЕ входит.
  Если «Updating…» висит при рабочих чатах и getDifference=`differenceEmpty` — подозревать
  застрявший транспортный `connectionStatus` (teamgram не сигналит «сессия догналась»); копать
  gnetway/session + где `connectionStatus` флипается в `.online`. На момент сессии — НЕ дорешено.
- **Auth: пропадает шаг ввода кода — это НЕ баг.** После `auth.logOut` клиент хранит logout-token;
  следующий `auth.sendCode` подкладывает его, сервер отвечает `auth.sentCodeSuccess` (быстрый
  ре-логин без кода). Форк это обрабатывает штатно (`Authorization.swift:369` → `.loggedIn`).
  Чтобы вернуть шаг кода — чистая установка/вход без сохранённого токена.
- **Сторис — критическая фича DIVO** (не «не делаем»). Постинг чинится `sendStory`+`storyItem`+`getPeerMaxIDs`.

## Диагностика — временная
Мост `[MTProto]` и вьюер логов — **снять перед PR** (ломает изоляцию DIVO: см. `DivoConsoleLogger`,
`MTRequestMessageService.m`, parseVector-нотификация в `Api0.swift`, `DivoStandaloneLogsViewController`).
