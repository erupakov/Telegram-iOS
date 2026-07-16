# Быстрый старт - Сборка Telegram iOS с Bazel

## Требования

| ПО | Версия |
|----------|---------|
| Xcode | 16.2+ |
| Bazel | 8.4.2 (устанавливается автоматически через Bazelisk) |
| macOS | Sequoia 15.x+ |
| CMake | Последняя |
| Homebrew | Последняя |

### Установка зависимостей

```bash
# Установить Homebrew (если не установлен)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Установить Bazelisk (менеджер версий Bazel) и CMake
brew install bazelisk cmake
```

## Сборка и запуск

### 1. Клонирование

```bash
git clone --recursive -j8 https://github.com/ShagMichail/TelegramApp.git
cd TelegramApp
```

### 2. Настройка конфигурации

```bash
mkdir -p build-input/configuration-repository
cp -r build-system/example-configuration/* build-input/configuration-repository/

cat > build-input/configuration-repository/MODULE.bazel << 'EOF'
module(
    name = "build_configuration",
    version = "1.0.0",
)
EOF
```

### Provisioning-профайлы (dev / distribution)

Реальные профайлы и сертификаты **в репозиторий не коммитятся** (`.gitignore` исключает
`provisioning/*.mobileprovision`) — кладёшь их локально.

- **Папка:** `build-input/configuration-repository/provisioning/`
- **Имя файла:** всегда `Telegram.mobileprovision` (при сборке с `--//Telegram:disableExtensions=true`
  нужен только он; без флага — ещё и профайлы расширений: `Share`, `Widget`, `NotificationService` и т.д.).

Путь и имя одни и те же — **профайл свопается под тип сборки**, и согласованно меняется
`telegram_aps_environment` в `variables.bzl`:

| Тип сборки | Профайл (`Telegram.mobileprovision`) | `telegram_aps_environment` |
|---|---|---|
| Дев / физ. девайс (§5) | **development** (aps-environment=development) | `development` |
| TestFlight / App Store (§7) | **distribution** (App Store, aps-environment=production) | `production` |

Симулятор (§3) профайл не требует — там `--define=disableProvisioningProfiles=true`.

#### Откуда брать профайлы

Создаются/скачиваются в Apple Developer Portal
([developer.apple.com/account](https://developer.apple.com/account) → Certificates,
Identifiers & Profiles → Profiles) под аккаунтом команды DIVO (App ID `app.divo.fashion`).
Доступ к Apple Developer-аккаунту — у администратора аккаунта.

- **Development** (§5): тип профиля «iOS App Development» для `app.divo.fashion`,
  привязан к development-сертификату + UDID зарегистрированных устройств (новый девайс
  сперва добавить в разделе Devices). Скачать → переименовать в `Telegram.mobileprovision`.
- **Distribution** (§7): тип «App Store» для `app.divo.fashion`, привязан к
  distribution-сертификату команды. Скачать → тот же путь и имя (свопаешь файл).

Нужны и **сертификаты** в Keychain (`.p12` с приватным ключом): development — для дева,
distribution — для релиза; без приватного ключа подпись не пройдёт. Если используется
**Xcode-managed signing** — есть флаг `telegram_use_xcode_managed_codesigning`, тогда Xcode
генерит профайлы сам и класть файл вручную не нужно.

### 3. Сборка (симулятор)

```bash
bazel build //Telegram:Telegram \
  --define=disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=11.8.1
```

### 4. Установка и запуск на симуляторе

```bash
# Посмотреть доступные симуляторы
xcrun simctl list devices available

# Запустить симулятор (указать имя или UUID устройства)
xcrun simctl boot "iPhone 16"

# Открыть окно симулятора
open -a Simulator

# Установить приложение
xcrun simctl install booted bazel-bin/Telegram/Telegram.ipa

# Запустить приложение
xcrun simctl launch booted app.divo.fashion
```

### 5. Сборка для физического девайса

#### Настройка перед сборкой

В файле `build-input/configuration-repository/variables.bzl` установить:

```python
telegram_aps_environment = "development"
```

В папке `build-input/configuration-repository/provisioning/` должен лежать файл с именем `Telegram.mobileprovision` — **development** профиль (aps-environment=development).

```bash
bazel build //Telegram:Telegram \
  --compilation_mode=opt \
  --cpu=ios_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=11.8.1 \
  --//Telegram:disableExtensions=true
```

### 6. Установка на физический девайс

Пример ниже использует **конкретный UDID девайса** (`51CB07C4-5E7A-5044-A4D3-8FABEDA1B647`).
У себя подставьте **UDID своего устройства**, который можно посмотреть в Xcode → `Devices and Simulators` или через `xcrun devicectl list devices`.

```bash
xcrun devicectl device install app \
  bazel-bin/Telegram/Telegram.ipa \
  --device 51CB07C4-5E7A-5044-A4D3-8FABEDA1B647
```

### 7. Сборка для TestFlight (дистрибуция)

#### Настройка перед сборкой

1. **Отключить дебаг-экран (обязательно, первым делом).** В `submodules/DivoCore/Sources/Services/DivoConfig.swift` выставить `DivoConfig.isDebugEnabled = false` (по умолчанию захардкожен в `true`) — иначе Debug Menu уедет в релизный билд. Команда TF/релизной сборки выдаётся только вместе с этим шагом: спрашиваешь команду для TestFlight — сначала этот пункт.

2. В файле `build-input/configuration-repository/variables.bzl` установить:

```python
telegram_aps_environment = "production"
```

3. В папке `build-input/configuration-repository/provisioning/` должен лежать файл с именем `Telegram.mobileprovision` — **distribution** профиль (aps-environment=production, App Store / TestFlight).

4. **Определить номер сборки.** Посмотреть последний `buildNumber` в TestFlight (App Store Connect) и прибавить 1. Например, если последняя сборка `17` — ставим `18`.

#### Команда сборки

> **⚠️ ВНИМАНИЕ! Для релиза надо отключить дебаг-экран.**
> Перед сборкой выставить `DivoConfig.isDebugEnabled = false` в
> `submodules/DivoCore/Sources/Services/DivoConfig.swift` (сейчас захардкожен в `true`),
> иначе Debug Menu попадёт в релизный билд.

```bash
bazel build //Telegram:Telegram \
  --compilation_mode=opt \
  --cpu=ios_arm64 \
  --define=buildNumber=18 \
  --define=telegramVersion=11.8.1 \
  --//Telegram:disableExtensions=true
```

> **Важно:** `buildNumber` должен быть строго больше предыдущей сборки в TestFlight, иначе загрузка завершится ошибкой.

#### Загрузка в TestFlight

После успешной сборки IPA находится по пути `bazel-bin/Telegram/Telegram.ipa`.
Загрузить можно через **Transporter** (приложение из Mac App Store):

1. Открыть Transporter
2. Перетащить `Telegram.ipa` в окно приложения
3. Нажать **Deliver**
4. Через несколько минут сборка появится в App Store Connect → TestFlight

#### После загрузки: обязательно поставить тег

`buildNumber` задаётся в команде сборки и в репозиторий не коммитится — поэтому
тег это единственная привязка TestFlight-сборки к дереву исходников. Без него
не получится сопоставить баг-репорты с конкретным билдом.

После того как сборка появилась в TestFlight, поставить аннотированный тег на тот
коммит, **из которого собирали** (обычно последний коммит в `dev`):

```bash
# формат: v0.<buildNumber> — например v0.32 для сборки 32
git tag -a v0.32 <commit> -m "TestFlight build 32"
git push origin v0.32
```

- `<commit>` — хэш коммита, с которого делали сборку (можно опустить, тогда тег
  встанет на текущий `HEAD`).
- Тег указывает на уже опубликованный коммит, поэтому пуш отправляет только сам
  тег — историю/ветки он не трогает.

## Часто используемые команды

```bash
# Очистить сборку
bazel clean

# Полная очистка (пересобрать всё с нуля)
bazel clean --expunge

# Проверить версию Bazel
bazel --version

# Установить на конкретный симулятор (по UUID)
xcrun simctl install <UUID> bazel-bin/Telegram/Telegram.ipa
```

## Алиасы для разработки (опционально)

Добавьте в `~/.zshrc`, заменив путь на свой:

```bash
# Telegram iOS Build Aliases
TELEGRAM_ROOT="$HOME/Projects/TelegramApp"  # <-- укажите свой путь

alias tg-build='cd $TELEGRAM_ROOT && bazel build //Telegram:Telegram --define=disableProvisioningProfiles=true --cpu=ios_sim_arm64 --define=buildNumber=100001 --define=telegramVersion=11.8.1'
alias tg-install='xcrun simctl install booted $TELEGRAM_ROOT/bazel-bin/Telegram/Telegram.ipa'
alias tg-run='xcrun simctl launch booted app.divo.fashion'
alias tg-boot='xcrun simctl boot "iPhone 16" 2>/dev/null || true && open -a Simulator'
alias tg-go='tg-boot && tg-build && tg-install && tg-run'
alias tg-clean='cd $TELEGRAM_ROOT && bazel clean --expunge'
```

Применить: `source ~/.zshrc`
