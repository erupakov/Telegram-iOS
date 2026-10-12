load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FlatBuffers",
    module_name = "FlatBuffers",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    # Без -suppress-warnings: swiftc запрещает его вместе с глобальным
    # «-Wwarning DeprecatedDeclaration» из .bazelrc. -warnings-as-errors здесь нет,
    # так что предупреждения FlatBuffers сборку не валят.
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
