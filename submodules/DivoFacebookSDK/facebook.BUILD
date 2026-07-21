load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

# Facebook (Meta) iOS SDK xcframework targets (DIVI-62).
# Files come from the external repo @facebook_ios_sdk (registered in //:MODULE.bazel).
# strip_prefix "XCFrameworks" → внутри zip фреймворки лежат как <Framework>.xcframework.
# Тянем только Core + Basics + AEM (app events + attribution); Login/Share/Gaming не нужны.

apple_static_xcframework_import(
    name = "FBSDKCoreKit_Basics",
    xcframework_imports = glob(["FBSDKCoreKit_Basics.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FBAEMKit",
    xcframework_imports = glob(["FBAEMKit.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FBSDKCoreKit",
    xcframework_imports = glob(["FBSDKCoreKit.xcframework/**"]),
    visibility = ["//visibility:public"],
)
