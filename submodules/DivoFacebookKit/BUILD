load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DivoFacebookKit",
    module_name = "DivoFacebookKit",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/DivoCore:DivoCore",
        # Facebook (Meta) iOS SDK (тянется через http_archive в MODULE.bazel)
        "@facebook_ios_sdk//:FBSDKCoreKit_Basics",
        "@facebook_ios_sdk//:FBAEMKit",
        "@facebook_ios_sdk//:FBSDKCoreKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
