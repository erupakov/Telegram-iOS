load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

# Firebase iOS SDK xcframework binaries.
# Bins are NOT in git — run scripts/divo/install_firebase.sh after clone.
# See submodules/DivoFirebaseSDK/.gitignore.

# --- Firebase core & transitive ---

apple_static_xcframework_import(
    name = "FirebaseCore",
    xcframework_imports = glob(["xcframeworks/FirebaseCore.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCoreInternal",
    xcframework_imports = glob(["xcframeworks/FirebaseCoreInternal.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCoreExtension",
    xcframework_imports = glob(["xcframeworks/FirebaseCoreExtension.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseInstallations",
    xcframework_imports = glob(["xcframeworks/FirebaseInstallations.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseSharedSwift",
    xcframework_imports = glob(["xcframeworks/FirebaseSharedSwift.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleUtilities",
    xcframework_imports = glob(["xcframeworks/GoogleUtilities.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleDataTransport",
    xcframework_imports = glob(["xcframeworks/GoogleDataTransport.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "nanopb",
    xcframework_imports = glob(["xcframeworks/nanopb.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FBLPromises",
    xcframework_imports = glob(["xcframeworks/FBLPromises.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "PromisesObjC",
    xcframework_imports = glob(["xcframeworks/PromisesObjC.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Analytics (transitive for Crashlytics / Performance / RemoteConfig) ---

apple_static_xcframework_import(
    name = "FirebaseAnalytics",
    xcframework_imports = glob(["xcframeworks/FirebaseAnalytics.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurement",
    xcframework_imports = glob(["xcframeworks/GoogleAppMeasurement.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurementIdentitySupport",
    xcframework_imports = glob(["xcframeworks/GoogleAppMeasurementIdentitySupport.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Auth ---

apple_static_xcframework_import(
    name = "FirebaseAuth",
    xcframework_imports = glob(["xcframeworks/FirebaseAuth.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseAuthInterop",
    xcframework_imports = glob(["xcframeworks/FirebaseAuthInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GTMSessionFetcher",
    xcframework_imports = glob(["xcframeworks/GTMSessionFetcher.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "RecaptchaInterop",
    xcframework_imports = glob(["xcframeworks/RecaptchaInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Crashlytics ---

apple_static_xcframework_import(
    name = "FirebaseCrashlytics",
    xcframework_imports = glob(["xcframeworks/FirebaseCrashlytics.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseSessions",
    xcframework_imports = glob(["xcframeworks/FirebaseSessions.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseRemoteConfigInterop",
    xcframework_imports = glob(["xcframeworks/FirebaseRemoteConfigInterop.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Performance ---

apple_static_xcframework_import(
    name = "FirebasePerformance",
    xcframework_imports = glob(["xcframeworks/FirebasePerformance.xcframework/**"]),
    visibility = ["//visibility:public"],
)

# --- Remote Config ---

apple_static_xcframework_import(
    name = "FirebaseRemoteConfig",
    xcframework_imports = glob(["xcframeworks/FirebaseRemoteConfig.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseABTesting",
    xcframework_imports = glob(["xcframeworks/FirebaseABTesting.xcframework/**"]),
    visibility = ["//visibility:public"],
)
