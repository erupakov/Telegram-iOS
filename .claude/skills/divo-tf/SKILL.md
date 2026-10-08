---
name: divo-tf
description: Собрать сборку для TestFlight в нужном окружении — дебажном (stage) или продовом (prod). Аргумент — debug | prod. Отличие сборок ровно в одном флаге --define=divoEnv; дебажная смотрит на stage-контур и несёт ленточку DEBUG на иконке, продовая — на боевой контур с чистой иконкой. Готовит команду и ведёт по шагам загрузки в TF; сам bazel НЕ запускает (билды у Marina вручную).
---

# Сборка DIVO в TestFlight (debug / prod)

Аргумент вызова — окружение: `debug` (синонимы `stage`) или `prod` (синонимы `release`, `prod`).
Пример: `/divo-tf prod`.

**Обе сборки идут в TestFlight и подписаны одинаково** (дистрибуционный профиль). Единственное
отличие — флаг `--define=divoEnv`:

| Аргумент | Флаг | REST API | teamgram IP | Firebase | Иконка |
|---|---|---|---|---|---|
| `debug` | *(флаг не нужен, дефолт stage)* | `api-stage.divo.fashion/api` | `34.44.72.74` | `divo-2-stage` | ленточка **DEBUG** |
| `prod` | `--define=divoEnv=prod` | `api.divo.fashion/v2` | `18.185.234.86` | `divodev-62848` | чистая |

Механизм: флаг вшивает ключ `DivoEnvironment` в `Info.plist`; на старте приложение читает его из
`Bundle.main` и выбирает контур. Иконку Bazel подставляет через `select()`. Подробнее — `Telegram/BUILD`,
`submodules/DivoCore/Sources/Services/DivoEnvironment.swift`.

## Важное про Debug Menu
В **prod-сборке** (`divoEnv=prod`) Debug Menu выключен ЖЁСТКО (`DivoConfig.isDebugEnabled == false`
при env=prod) — не зависит от профиля, боевая сборка не покажет его ни при каких условиях.

Дебажная TF-сборка = **stage-контур + ленточка**; внутренний Debug Menu в ней завязан на наличие
`embedded.mobileprovision`, а Apple вырезает его из дистрибуционных (TF) сборок → в TF он всё равно
выключен. Это не про окружение. Нужен живой Debug Menu — ставить dev/ad-hoc сборку на устройство
(§5–6 QUICKSTART).

## Порядок

Я **не запускаю** `bazel` — готовлю команду и веду по шагам, сборку запускает Marina.

1. **Определить окружение** из аргумента. Нет/неоднозначно — спросить «debug или prod?». Явно
   проговорить выбранное окружение перед выдачей команды (защита от не того контура в TF).

2. **Только для `debug`:** если базовая иконка (`DefaultAppIcon.xcassets`) менялась после последней
   генерации ленточной — напомнить перегенерить:
   `python3 scripts/divo/generate_debug_appicon.py` (иконки коммитятся, сборка герметична).

3. **Подпись (одинаково для обеих сборок — это TF):** проверить, что настроено под дистрибуцию
   (см. QUICKSTART §7):
   - `build-input/configuration-repository/variables.bzl`: `telegram_aps_environment = "production"`;
   - `build-input/configuration-repository/provisioning/Telegram.mobileprovision` — **distribution**
     профиль (App Store / TestFlight).

4. **Номер сборки.** Схема: **debug (stage) — чётные, prod — нечётные** (46 — debug, 47 — prod).
   Попросить Marina посмотреть **максимальный** `buildNumber` в App Store Connect (по обоим окружениям)
   или последний тег `v0.<N>` и взять следующее число нужной чётности (макс. 47 → debug 48, prod 49).
   `buildNumber` должен быть строго больше любой ранее загруженной сборки, иначе загрузка отклонится.
   Тот же расчёт — `scripts/divo/ci_next_build_number.sh <stage|prod> [известные номера…]`.

5. **Версия.** `--define=telegramVersion=2.0.0` (или актуальная версия релиза). Она же уходит в
   REST-заголовок `app-version` (читается из бандла).

6. **Выдать команду** (подставить `<N>`):

   **debug (stage + ленточка):**
   ```bash
   bazel build //Telegram:Telegram \
     --compilation_mode=opt \
     --cpu=ios_arm64 \
     --define=buildNumber=<N> \
     --define=telegramVersion=2.0.0 \
     --//Telegram:disableExtensions=true
   ```

   **prod (боевой + чистая иконка):**
   ```bash
   bazel build //Telegram:Telegram \
     --compilation_mode=opt \
     --cpu=ios_arm64 \
     --define=buildNumber=<N> \
     --define=telegramVersion=2.0.0 \
     --define=divoEnv=prod \
     --//Telegram:disableExtensions=true
   ```

7. **Загрузка.** После сборки IPA — `bazel-bin/Telegram/Telegram.ipa`. Открыть **Transporter**,
   перетащить IPA, **Deliver**. Через несколько минут сборка появится в App Store Connect → TestFlight.

8. **Тег.** Напомнить поставить аннотированный тег `v0.<buildNumber>` на коммит, из которого собирали:
   `git tag -a v0.<N> <commit> -m "TestFlight build <N>"`. **Пуш тега и любой git — только с явного
   «да» Marina** (коммиты/пуши делает Marina сама).

## Проверка после установки
- **debug:** на иконке ленточка DEBUG; приложение работает на stage (`api-stage.divo.fashion`).
- **prod:** иконка чистая; приложение на боевом (`api.divo.fashion/v2`).

⚠️ Прод-контур teamgram (IP `18.185.234.86`) на устройстве стоит проверить живьём перед раздачей
prod-сборки тестерам — убедиться, что боевой мессенджер поднимается.
(Firebase prod исправлен в коммите `480dfca8bcb` (DIVI-118): `bundleID` = `app.divo.fashion`,
проект `divodev-62848` — рассинхрона с бандлом больше нет.)

## Язык и тон
Русский. О себе — мужской род. К Marina — мужской род. Готовые шаги, не «пункты обсудить».
