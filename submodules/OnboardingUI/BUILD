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
        "//submodules/Display:Display",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoUIKit:DivoUIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
