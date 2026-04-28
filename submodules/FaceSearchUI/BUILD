load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FaceSearchUI",
    module_name = "FaceSearchUI",
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
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoUIKit:DivoUIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
