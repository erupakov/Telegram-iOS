load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "OnboardingUI",
    module_name = "OnboardingUI",
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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AppBundle:AppBundle",
        "//submodules/DivoCore:DivoCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
