load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoSettingsUI",
    module_name = "DivoSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoUIKit:DivoUIKit",
        "//submodules/ProfileScreenUI:ProfileScreenUI",
        "//submodules/OnboardingUI:OnboardingUI",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
