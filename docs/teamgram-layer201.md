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
Если layout совпал с 222 — достаточно alias на существующий `parse_*` (как `user#020b1422`).

Покрыто: `message`, `messageService`, `channel`, `channelFull`, `userFull`, `messages.messages`,
`messages.messagesSlice`, ряд `Update`-конструкторов и контейнеры `messages.dialogs`/`updates.*`
(многие совпадают с 222 и работают без правок — потому список чатов/история парсятся).

### 2. Отправка методов (encode) — энкодеры write-методов
Бóльшая ловушка: форк **кодирует** методы 222-конструктором, а сервер на 201 их не понимает
и **молча дропает** (запрос не доходит до хендлера, ответа нет, действие «висит»).
Для каждого дрейфанувшего write-метода — обёртка `*_teamgram_layer201` в
`ApiTeamgramLayer200.swift` (extension `Api.functions.messages`): 201-constructor + поля в
201-порядке + `flags & <whitelist-маска>` (отсекает биты полей, добавленных в 222). Вызовы в
`TelegramCore` свапаются на обёртку (лишние 222-параметры выкидываются).

Сделано (ядро): `sendMessage`, `sendMedia`, `editMessage`, `forwardMessages`, `saveDraft`.

**Осталось (вторичный батч, 10 методов `messages.*`, дрейфанули, но реже используются):**
`readReactions`, `getUnreadReactions`, `markDialogUnread`, `getDialogUnreadMarks`,
`getSavedHistory`, `getSavedDialogs`, `deleteSavedHistory`, `getSponsoredMessages`,
`setChatTheme`, `unpinAllMessages`. Делать по тому же шаблону — по мере необходимости.

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
| `RPC ERROR … code=500 unknown service` | teamgram не реализует сервис | второстепенно (attach-menu, gifts и т.п.); к Eugene или игнор |
| Фича/кнопка пропала, код стоковый | поведение зависит от данных сервера (appConfig/подписки) | проверить соответствующий RPC в `[MTProto]`-логе: `OK` + поля нет → серверная сторона; `can't parse magic` → наш парсер. Пример: «+» сторис гейтится `storyPostingAvailable` ← `help.getAppConfig` (`stories_posting`) |

### Аудит дрейфа методов (какие write-методы кодируются неверно)
Сравнить constructor каждого `Api.functions.messages.*` (первый `buffer.appendInt32` в `Api*.swift`)
с `@201` из `teamgram-proto/mtproto/class_name_registers.go`. Где fork@222 ≠ srv@201 — нужна
201-обёртка. (Из 240 messages-методов дрейфануло 15; ядро из 5 сделано.)

### Серверные логи (FTP, UTC; MSK = UTC+3)
`curl -s -u '$FTP_USER:$FTP_PASS' 'ftp://$FTP_HOST/<path>'`
- `bff/access.log` — высокоуровневые RPC (`sendMessage`, `getHistory`, …): дошёл ли метод.
- `msg/access.log`, `msg/error.log` — message-сервис (readHistory и т.п.).
- `gnetway/access.log` — транспорт/handshake.

## Диагностика — временная
Мост `[MTProto]` и вьюер логов — **снять перед PR** (ломает изоляцию DIVO: см. `DivoConsoleLogger`,
`MTRequestMessageService.m`, parseVector-нотификация в `Api0.swift`, `DivoStandaloneLogsViewController`).
