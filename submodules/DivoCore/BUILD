load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load(
    "@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl",
    "ios_test_runner",
)

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

# Unit-тесты DivoCore — без сборки приложения: собирается только DivoCore + тестовый бандл,
# прогон в симуляторе (logic tests, без test host). Запуск:
#   bazel test //submodules/DivoCore:DivoCoreTests
# Сеть не нужна: весь трафик идёт через StubURLProtocol (Tests/Support).
swift_library(
    name = "DivoCoreTestsLib",
    testonly = True,
    module_name = "DivoCoreTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":DivoCore",
    ],
    tags = ["manual"],
)

ios_test_runner(
    name = "iPhone-17__26.2",
    device_type = "iPhone 17",
    os_version = "26.2",
)

ios_unit_test(
    name = "DivoCoreTests",
    minimum_os_version = "13.0",
    runner = ":iPhone-17__26.2",
    deps = [
        ":DivoCoreTestsLib",
    ],
)
