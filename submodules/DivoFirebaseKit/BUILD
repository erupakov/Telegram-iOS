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
        # Firebase iOS SDK (тянется через http_archive в MODULE.bazel)
        "@firebase_ios_sdk//:FirebaseCore",
        "@firebase_ios_sdk//:FirebaseCoreInternal",
        "@firebase_ios_sdk//:FirebaseCoreExtension",
        "@firebase_ios_sdk//:FirebaseInstallations",
        "@firebase_ios_sdk//:FirebaseSharedSwift",
        "@firebase_ios_sdk//:GoogleUtilities",
        "@firebase_ios_sdk//:GoogleDataTransport",
        "@firebase_ios_sdk//:nanopb",
        "@firebase_ios_sdk//:FBLPromises",
        "@firebase_ios_sdk//:Promises",
        "@firebase_ios_sdk//:FirebaseAnalytics",
        "@firebase_ios_sdk//:GoogleAppMeasurement",
        "@firebase_ios_sdk//:GoogleAppMeasurementIdentitySupport",
        "@firebase_ios_sdk//:FirebaseAuth",
        "@firebase_ios_sdk//:FirebaseAuthInterop",
        "@firebase_ios_sdk//:FirebaseAppCheckInterop",
        "@firebase_ios_sdk//:GTMSessionFetcher",
        "@firebase_ios_sdk//:RecaptchaInterop",
        "@firebase_ios_sdk//:FirebaseCrashlytics",
        "@firebase_ios_sdk//:FirebaseSessions",
        "@firebase_ios_sdk//:FirebaseRemoteConfigInterop",
        "@firebase_ios_sdk//:FirebasePerformance",
        "@firebase_ios_sdk//:FirebaseRemoteConfig",
        "@firebase_ios_sdk//:FirebaseABTesting",
    ],
    visibility = [
        "//visibility:public",
    ],
)
