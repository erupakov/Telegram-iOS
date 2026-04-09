load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DebugScreenUI",
    module_name = "DebugScreenUI",
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
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/DivoCore:DivoCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
