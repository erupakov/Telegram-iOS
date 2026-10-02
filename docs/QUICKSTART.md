# 🚀 Quick Start - Build Telegram iOS with Bazel

## Prerequisites

```bash
# Install Xcode 26.2 from Apple Developer
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install CMake
brew install cmake

# Xcode 26+: the Metal compiler is a separate component — without it the build fails
# on shaders (CallScreenShaders: "missing Metal Toolchain")
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # full Xcode, not Command Line Tools
xcodebuild -downloadComponent MetalToolchain                      # ~700 MB; or Xcode → Settings → Components
xcrun metal --version                                             # check: prints a version
```

## Build & Run (5 minutes)

### 1. Clone

```bash
git clone --recursive -j8 https://github.com/erupakov/Telegram-iOS.git
cd Telegram-iOS
git checkout dev
```

The build needs the git submodules (`build-system/bazel-rules/*`, `third-party/*`, several GB).
If you cloned without `--recursive` or the download was interrupted, fetch and verify them:

```bash
git submodule sync --recursive
git submodule update --init --recursive --jobs 8
git submodule status --recursive   # no line may start with "-"
```

### 2. Setup Configuration

The DIVO configuration is already committed in `build-input/configuration-repository/`
(`variables.bzl` with bundle id `app.divo.fashion`, the DIVO team id, `telegram_bazel_path`, etc.).
**Do not copy `build-system/example-configuration`:** it is the stock Telegram example and
overwrites `variables.bzl`, which breaks the build.

Only check the Bazel path — `telegram_bazel_path` in `variables.bzl` (default
`/opt/homebrew/bin/bazel`, Apple Silicon + Homebrew):

```bash
which bazel   # if it differs (e.g. /usr/local/bin/bazel on Intel), edit it locally
```

If the configuration was already overwritten, restore the committed one:

```bash
git checkout -- build-input/configuration-repository
```

### 3. Build

```bash
bazel build //Telegram:Telegram \
  --//Telegram:disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 3. Build без сертификатов
```bash
bazel build //Telegram:Telegram \
  --define=disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 4. Install & Run

```bash
# Boot simulator (if not running)
xcrun simctl boot "iPhone 16"

# Install app
xcrun simctl install booted bazel-bin/Telegram/Telegram.ipa

# Launch app
xcrun simctl launch booted ph.telegra.Telegraph
```

## 📚 Full Documentation

See [BAZEL_BUILD.md](BAZEL_BUILD.md) for detailed instructions, troubleshooting, and CI/CD setup.

## Common Commands

```bash
# Clean build
bazel clean

# Rebuild everything
bazel clean --expunge

# Check Bazel version
bazel --version  # Auto-uses 8.4.2 via Bazelisk
```

## Requirements

| Software | Version |
|----------|---------|
| Xcode | 26.2 |
| Bazel | 8.4.2 (via Bazelisk) |
| macOS | 26.x |
| CMake | Latest |
