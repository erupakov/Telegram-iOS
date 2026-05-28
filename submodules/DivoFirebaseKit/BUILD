load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoFirebaseKit",
    module_name = "DivoFirebaseKit",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/DivoCore:DivoCore",
        # Firebase SDK deps добавляются в шаге 2 после ./scripts/divo/install_firebase.sh:
        # "//submodules/DivoFirebaseSDK:FirebaseCore",
        # "//submodules/DivoFirebaseSDK:FirebaseCrashlytics",
        # "//submodules/DivoFirebaseSDK:FirebaseAnalytics",
        # "//submodules/DivoFirebaseSDK:FirebasePerformance",
        # "//submodules/DivoFirebaseSDK:FirebaseRemoteConfig",
    ],
    visibility = [
        "//visibility:public",
    ],
)
