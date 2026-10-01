# POST /auth/telegram-link: подпись proof от teamgram

Что меняется на клиенте после исправления дыры в выдаче токенов DIVO (2026-10-01).

- Бэкенд: [app-backend !2](https://gitlab.com/divofashion/app-backend/-/merge_requests/2) (`feature/ban_user` → `stage`).
- Teamgram: [divo-server !2](https://gitlab.com/divofashion/divo2025/divo-server/-/merge_requests/2) (`feature/divo-link-proof` → `main`).

Оба MR на момент написания не смержены. **Пока их не выкатили, клиент должен работать по-старому.** После выкатки `telegram-link` без `proof` возвращает 403, то есть вход через него перестаёт работать.

## Зачем

Раньше `/auth/telegram-link` без авторизации выдавал токен **любого** пользователя по `divoUserId` (или `phone`) + `telegramUserId`. Оба значения публичные. Теперь бэкенд требует подпись, которую выдаёт сервер teamgram только владельцу сессии.

## Что сделать клиенту

1. После успешного входа в teamgram (`auth.signIn` / `auth.signUp` → `auth.authorization`) вызвать `help.getAppConfig` с `hash: 0`. Нужен свежий ответ, кэш не подходит.
2. Взять из JSON ответа два строковых поля:
   - `divo_link_proof` — подпись, действует **10 минут**;
   - `divo_link_phone` — номер аккаунта teamgram (только цифры), под который сделана подпись.
3. Передать их в `POST /auth/telegram-link`:

```json
{
  "telegramUserId": 123456789,
  "phone": "<divo_link_phone>",
  "proof": "<divo_link_proof>",
  "divoUserId": 42,
  "deviceId": "...",
  "deviceType": "ios"
}
```

- `phone` и `proof` теперь **обязательны** всегда, в том числе вместе с `divoUserId`.
- `phone` берите именно из `divo_link_phone`. Другой номер или другой формат дадут несовпадение подписи и 403. Бэкенд сравнивает только цифры.
- Если у клиента уже есть токен DIVO (например, после `registration` / `registration-social` / `login-social`), отправляйте запрос **с заголовком `Authorization: Bearer <токен>`**. Без него привязка по `divoUserId` работает, только если номер в профиле DIVO совпадает с `divo_link_phone`. У соц-пользователей, вошедших в teamgram с dummy-номером (`/auth/dummy_phone`), номера в профиле DIVO обычно нет, так что токен для них обязателен.

Сейчас запрос собирается в `AuthRestService.telegramLink` (`submodules/DivoCore/Sources/Services/AuthRestService.swift`) через `AuthTelegramLinkRequest`, туда нужно добавить `proof`.

## Очередь повторов

`PendingTelegramOpsQueue` повторяет `telegram-link` позже, в том числе после холодного старта. Proof к этому моменту может истечь, поэтому:

- **не храните proof в очереди**, перед каждой попыткой берите свежий через `help.getAppConfig`;
- 403 из-за просроченного proof лечится новым proof и повтором; 403 со свежим proof повторять бессмысленно.

## Когда proof не приходит

`divo_link_proof` отсутствует в `help.getAppConfig`, если:

- на сервере teamgram не задан `DivoLinkSecret` (функция выключена);
- запрос сделан до входа (нет пользователя в сессии);
- у пользователя включён пароль 2FA — это намеренно, чтобы не выдавать proof до ввода пароля;
- аккаунт teamgram удалён или у него нет номера.

В этих случаях вход через `telegram-link` невозможен. Нужен другой путь (например, `login-social`) или понятная ошибка пользователю.

## Ответы telegram-link

| Код | Когда | Что делать |
| --- | --- | --- |
| 200 | Связано (или уже было связано с тем же `telegramUserId`) | Новый токен DIVO в `data.accessToken` |
| 403 | Нет `proof`, он истёк или неверен; или `divoUserId` без своего токена и с другим номером в профиле | Получить свежий proof; если не помогло — не повторять |
| 404 | По номеру не найден активный пользователь DIVO | Считать, что аккаунта нет |
| 409 | Пользователь DIVO уже связан с другим `telegramUserId`, или этот `telegramUserId` занят другим пользователем | Не повторять; различаются только текстом `message` |
| 422 | Ошибка валидации (например, нет `phone` или `proof`) | Ошибка клиента |

## Формат подписи (для отладки)

`proof = "<exp>.<hex HMAC-SHA256(secret, "<telegramUserId>:<цифры номера>:<exp>")>"`, где `exp` — unix-время истечения. Секрет общий: `DivoLinkSecret` в `bff.yaml` teamgram и `TEAMGRAM_LINK_SECRET` в бэкенде. Клиент секрет не знает и подпись не проверяет.

## Известные ограничения

- Пока в teamgram работает фиксированный PIN `12345` (провайдер кода `none`), любой может войти в чужой аккаунт teamgram по номеру и получить его proof. Полностью дыра закроется только с настоящей проверкой кода.
- `GET /user/{id}` и `/user/by-telegram` по-прежнему отдают `phone`, `telegramId` и `email` чужих профилей.
