load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ModelsFeedUI",
    module_name = "ModelsFeedUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/MergeLists:MergeLists",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/PeerOnlineMarkerNode:PeerOnlineMarkerNode",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ProfileScreenUI:ProfileScreenUI",
        "//submodules/FaceSearchUI:FaceSearchUI",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen:StoryContainerScreen",
        "//submodules/DivoCore:DivoCore",
        "//submodules/DivoUIKit:DivoUIKit",
        "//submodules/DivoGallery:DivoGallery",
    ],
    visibility = [
        "//visibility:public",
    ],
)