load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

# Firebase iOS SDK xcframework targets.
# Files come from the external repo @firebase_ios_sdk (registered in //:MODULE.bazel).
# Inside the zip xcframeworks live in Firebase/<Product>/<Framework>.xcframework.
# Identical transitives (FirebaseCore, GoogleUtilities, etc.) are duplicated across
# product folders — we pick any one of them, they are bit-for-bit identical.

# --- Core & transitives ---

apple_static_xcframework_import(
    name = "FirebaseCore",
    xcframework_imports = glob(["FirebaseAnalytics/FirebaseCore.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCoreInternal",
    xcframework_imports = glob(["FirebaseAnalytics/FirebaseCoreInternal.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCoreExtension",
    xcframework_imports = glob(["FirebaseAuth/FirebaseCoreExtension.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseInstallations",
    xcframework_imports = glob(["FirebaseAnalytics/FirebaseInstallations.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseSharedSwift",
    xcframework_imports = glob(["FirebaseRemoteConfig/FirebaseSharedSwift.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleUtilities",
    xcframework_imports = glob(["FirebaseAnalytics/GoogleUtilities.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleDataTransport",
    xcframework_imports = glob(["FirebaseCrashlytics/GoogleDataTransport.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "nanopb",
    xcframework_imports = glob(["FirebaseAnalytics/nanopb.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FBLPromises",
    xcframework_imports = glob(["FirebaseAnalytics/FBLPromises.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "Promises",
    xcframework_imports = glob(["FirebaseCrashlytics/Promises.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Analytics (transitive for Crashlytics / Performance / RemoteConfig) ---

apple_static_xcframework_import(
    name = "FirebaseAnalytics",
    xcframework_imports = glob(["FirebaseAnalytics/FirebaseAnalytics.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurement",
    xcframework_imports = glob(["FirebaseAnalytics/GoogleAppMeasurement.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurementIdentitySupport",
    xcframework_imports = glob(["FirebaseAnalytics/GoogleAppMeasurementIdentitySupport.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Auth ---

apple_static_xcframework_import(
    name = "FirebaseAuth",
    xcframework_imports = glob(["FirebaseAuth/FirebaseAuth.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseAuthInterop",
    xcframework_imports = glob(["FirebaseAuth/FirebaseAuthInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseAppCheckInterop",
    xcframework_imports = glob(["FirebaseAuth/FirebaseAppCheckInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GTMSessionFetcher",
    xcframework_imports = glob(["FirebaseAuth/GTMSessionFetcher.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "RecaptchaInterop",
    xcframework_imports = glob(["FirebaseAuth/RecaptchaInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Crashlytics ---

apple_static_xcframework_import(
    name = "FirebaseCrashlytics",
    xcframework_imports = glob(["FirebaseCrashlytics/FirebaseCrashlytics.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseSessions",
    xcframework_imports = glob(["FirebaseCrashlytics/FirebaseSessions.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseRemoteConfigInterop",
    xcframework_imports = glob(["FirebaseCrashlytics/FirebaseRemoteConfigInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Performance ---

apple_static_xcframework_import(
    name = "FirebasePerformance",
    xcframework_imports = glob(["FirebasePerformance/FirebasePerformance.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Remote Config ---

apple_static_xcframework_import(
    name = "FirebaseRemoteConfig",
    xcframework_imports = glob(["FirebaseRemoteConfig/FirebaseRemoteConfig.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseABTesting",
    xcframework_imports = glob(["FirebaseRemoteConfig/FirebaseABTesting.xcframework/**"]),
    visibility = ["//visibility:public"],
)
