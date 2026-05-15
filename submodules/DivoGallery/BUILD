load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoGallery",
    module_name = "DivoGallery",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoUIKit:DivoUIKit",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/TelegramBaseController:TelegramBaseController",
        
    ],
    visibility = [
        "//visibility:public",
    ],
)
