load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

filegroup(
    name = "DivoCoreAssets",
    srcs = glob(["DivoCoreImages.xcassets/**"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "DivoCoreResources",
    srcs = glob(["Resources/**/*"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "DivoCore",
    module_name = "DivoCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
