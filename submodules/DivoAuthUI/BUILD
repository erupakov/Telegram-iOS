load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoAuthUI",
    module_name = "DivoAuthUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AppBundle:AppBundle",
        "//submodules/Display:Display",
        "//submodules/DivoAuth:DivoAuth",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoFirebaseKit:DivoFirebaseKit",
        "//submodules/DivoUIKit:DivoUIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
