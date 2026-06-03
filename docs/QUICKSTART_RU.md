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

1. В файле `build-input/configuration-repository/variables.bzl` установить:

```python
telegram_aps_environment = "production"
```

2. В папке `build-input/configuration-repository/provisioning/` должен лежать файл с именем `Telegram.mobileprovision` — **distribution** профиль (aps-environment=production, App Store / TestFlight).

3. **Определить номер сборки.** Посмотреть последний `buildNumber` в TestFlight (App Store Connect) и прибавить 1. Например, если последняя сборка `17` — ставим `18`.

#### Команда сборки

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
