import Foundation

/// HTTP method constants.
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Path constants for Divo API (matches openapi.yaml).
public enum APIPath {
    public static let authLogin = "/auth/login"
    public static let authLogout = "/auth/logout"
    public static let authRegistration = "/auth/registration"
    public static let authRegistrationSocial = "/auth/registration-social"
    public static let authLoginSocial = "/auth/login-social"
    public static let authSendEmailCode = "/auth/send-email-code"
    public static let authConfirmEmail = "/auth/confirm-email"
    public static let authConfirmCode = "/auth/confirm-code"
    public static let authResetPassword = "/auth/reset-password"
    public static let authFindUser = "/auth/find-user"

    public static let userInfo = "/user/info"
    public static let userRating = "/user/rating"
    public static let userAvailableRatingFeatures = "/user/available-rating-features"
    public static let userViewers = "/user/viewers"
    public static let userBudgeCount = "/user/budge-count"
    public static func user(id: Int) -> String { "/user/\(id)" }
    public static let userUpdateProfile = "/user/update-profile"
    public static let userUpdatePassword = "/user/update-password"
    public static let userUpdateEmail = "/user/update-email"
    public static let userUpdateEmailConfirm = "/user/update-email-confirm"
    public static let userListWithWallets = "/user/list-with-wallets"
    public static let userSavePushToken = "/user/save-push-token"
    public static let userSendTestPush = "/user/send-test-push"
    public static let userDeleteAccount = "/user/delete-account"
    public static let userChangeRole = "/user/change-role"

    public static let publicationList = "/publication/list"
    public static let publicationFeed = "/publication/feed"
    public static let publicationCreate = "/publication/create"
    public static let publicationLike = "/publication/like"
    public static let publicationUnlike = "/publication/unlike"
    public static func publication(id: Int) -> String { "/publication/\(id)" }

    public static let eventUserApplies = "/event/user/applies"
    public static let eventList = "/event/list"
    public static let eventCreate = "/event/create"
    public static func eventUpdate(id: Int) -> String { "/event/update/\(id)" }
    public static func eventApplies(id: Int) -> String { "/event/\(id)/applies" }
    public static func event(id: Int) -> String { "/event/\(id)" }
    public static let eventTypes = "/event/types"
    public static let eventApply = "/event/apply"
    public static func eventLike(id: Int) -> String { "/event/\(id)/like" }
    public static func eventUnlike(id: Int) -> String { "/event/\(id)/unlike" }

    public static let fileUploadFile = "/file/upload-file"
    public static let fileUploadFiles = "/file/upload-files"
    public static let fileResize = "/file/resize"

    public static let agencyList = "/agency/list"
    public static func agency(id: Int) -> String { "/agency/\(id)" }
    public static let agencyUpdate = "/agency/update"
    public static func agencyModelsList(id: Int) -> String { "/agency/\(id)/models/list" }
    public static func agencyModelsModel(agencyId: Int, modelId: Int) -> String { "/agency/\(agencyId)/models/\(modelId)" }

    public static let agencyEmployeeRoles = "/agency-employee/roles"
    public static let customerRoles = "/customer/roles"
    public static let geoSearchByAddressName = "/geo/search-by-address-name"
    public static let geoSearchGeocoder = "/geo/search-geocoder"

    public static let feedlineList = "/feedline/list"
    public static let feedlineLike = "/feedline/like"
    public static let feedlineUnlike = "/feedline/unlike"
    public static let feedlineUserActivity = "/feedline/user-activity"
    public static let feedlineSearch = "/feedline/search"
    public static let feedlineReport = "/feedline/report"
    public static func feedline(id: Int) -> String { "/feedline/\(id)" }

    public static let followerFollow = "/follower/follow"
    public static let followerUnfollow = "/follower/unfollow"
    public static let followerFollowing = "/follower/following"
    public static let followerFollowers = "/follower/followers"

    public static let favoriteMark = "/favorite/mark"
    public static let favoriteUnmark = "/favorite/unmark"
    public static let favoriteList = "/favorite/list"

    public static let userGalleryAdd = "/user-gallery/add"
    public static let userGalleryList = "/user-gallery/list"
    public static func userGallery(id: Int) -> String { "/user-gallery/\(id)" }
    public static let userGalleryLike = "/user-gallery/like"
    public static let userGalleryUnlike = "/user-gallery/unlike"

    public static let socialNetworkList = "/social-network/"
    public static let socialNetworkInstagramImport = "/social-network/instagram/import"
    public static let socialNetworkInstagramAdd = "/social-network/instagram/add"
    public static func socialNetworkInstagramUpdate(id: Int) -> String { "/social-network/instagram/\(id)/update" }
    public static func socialNetworkInstagramDelete(id: Int) -> String { "/social-network/instagram/\(id)/delete" }

    public static let userSocialNetworkList = "/user-social-network/"
    public static let userSocialNetworkUpsert = "/user-social-network/upsert"
    public static func userSocialNetwork(id: Int) -> String { "/user-social-network/\(id)" }

    public static func messengerThreadPinMessage(thread: Int) -> String { "/messenger/threads/\(thread)/pin-message" }
    public static func messengerThreadUnpinMessage(thread: Int) -> String { "/messenger/threads/\(thread)/unpin-message" }
    public static func messengerThreadPinned(thread: Int) -> String { "/messenger/threads/\(thread)/pinned" }
    public static func messengerThreadSearch(thread: Int, query: String) -> String { "/messenger/threads/\(thread)/search/\(query)" }
    public static func messengerThreadMessagesToken(thread: Int) -> String { "/messenger/threads/\(thread)/messages/token" }
    public static func messengerThreadMessagesPhone(thread: Int) -> String { "/messenger/threads/\(thread)/messages/phone" }
    public static func messengerThreadMessages(thread: Int) -> String { "/messenger/threads/\(thread)/messages" }
    public static func messengerThreadImages(thread: Int) -> String { "/messenger/threads/\(thread)/images" }
    public static func messengerThreadDocuments(thread: Int) -> String { "/messenger/threads/\(thread)/documents" }
    public static func messengerThreadsSearch(query: String) -> String { "/messenger/threads-search/\(query)" }
    public static let messengerStartDialog = "/messenger/start-dialog"
    public static let messengerStartSystemDialog = "/messenger/start-system-dialog"
    public static let messengerBlockUser = "/messenger/block-user"
    public static let messengerUnblockUser = "/messenger/unblock-user"
    public static func messengerBlock(recipientId: Int) -> String { "/messenger/block/\(recipientId)" }
    public static let messengerGetUsersForMessenging = "/messenger/get-users-for-messenging"
    public static func messengerThreadLeave(thread: Int) -> String { "/messenger/thread-leave/\(thread)" }
    public static let messengerPrivatesToken = "/messenger/privates/token"
    public static let messengerPrivatesPhone = "/messenger/privates/phone"
    public static let messengerFriends = "/messenger/friends"

    public static let dictionaryGender = "/dictionary/gender"
    public static let dictionaryAppearances = "/dictionary/appearances"
    public static let dictionaryPayments = "/dictionary/payments"
    public static let dictionaryFeedReportTypes = "/dictionary/feed-report-types"

    public static let userGeopositionAdd = "/user-geoposition/add"

    public static let radar = "/radar/"
    public static let radarModels = "/radar/models"
    public static let radarPlaces = "/radar/places"
    public static func radarPlace(id: Int) -> String { "/radar/places/\(id)" }
    public static func radarPlaceReviewsList(id: Int) -> String { "/radar/places/\(id)/reviews/list" }
    public static func radarPlaceReviewsAdd(id: Int) -> String { "/radar/places/\(id)/reviews/add" }

    public static let walletList = "/wallet/list"
    public static let walletWithdrawalNetworks = "/wallet/withdrawal-networks"
    public static let walletBonus = "/wallet/bonus"
    public static func wallet(id: Int) -> String { "/wallet/\(id)" }
    public static func walletOperations(walletId: Int) -> String { "/wallet/\(walletId)/operations" }
    public static func walletWithdraw(walletId: Int) -> String { "/wallet/\(walletId)/withdraw" }
    public static func walletSend(walletId: Int) -> String { "/wallet/\(walletId)/send" }

    public static let userPaidServicesList = "/user-paid-services/"
    public static let userPaidServicesCheckBalance = "/user-paid-services/check-balance"
    public static let userPaidServicesBuy = "/user-paid-services/buy"

    public static let nftCreate = "/nft/create"
    public static func nft(id: Int) -> String { "/nft/\(id)" }
    public static func nftUpdate(id: Int) -> String { "/nft/update/\(id)" }
    public static let nftList = "/nft/list"
    public static func nftBuy(id: Int) -> String { "/nft/buy/\(id)" }

    public static let banners = "/banners/"
    public static let bannersList = "/banners/list"
    public static func bannersClose(id: Int) -> String { "/banners/\(id)/close" }

    public static let systemFeatureFlags = "/system/feature-flags"
    public static let cryptoWebhook = "/crypto/webhook"
}
