load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoAuth",
    module_name = "DivoAuth",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoFirebaseKit:DivoFirebaseKit",
        "@firebase_ios_sdk//:FirebaseAuth",
        "@firebase_ios_sdk//:FirebaseCore",
        # TelegramCore добавляется в шаге 5 для teamgram signIn/signUp:
        # "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
