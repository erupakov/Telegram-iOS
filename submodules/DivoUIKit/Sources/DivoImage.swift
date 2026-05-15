// DO NOT EDIT — сгенерирован scripts/divo/generate_divo_images.py
// Regenerate: python3 scripts/divo/generate_divo_images.py
//
// Typed-namespace для DIVO-ассетов. Цель:
// 1. Визуально отличать DIVO-ресурсы от Telegram в коде (DivoImage.xxx).
// 2. Compile-time safety: опечатка в имени → ошибка сборки, а не nil в рантайме.
// 3. Единая точка загрузки — если сменится bundle/способ загрузки, правим здесь.

import UIKit
import AppBundle

public enum DivoImage {

    public static var addIcon: UIImage { load("DivoAddIcon") }
    public static var addMediaProfile: UIImage { load("DivoAddMediaProfile") }
    public static var addPhotoIcon: UIImage { load("DivoAddPhotoIcon") }
    public static var ageIcon: UIImage { load("DivoAgeIcon") }
    public static var associatedModels: UIImage { load("DivoAssociatedModels") }
    public static var badgeBaseWork: UIImage { load("DivoBadgeBaseWork") }
    public static var badgeCalendar: UIImage { load("DivoBadgeCalendar") }
    public static var basket: UIImage { load("DivoBasket") }
    public static var basketWork: UIImage { load("DivoBasketWork") }
    public static var block: UIImage { load("DivoBlock") }
    public static var calendar: UIImage { load("DivoCalendar") }
    public static var channelIcon: UIImage { load("DivoChannelIcon") }
    public static var checkbox: UIImage { load("DivoCheckbox") }
    public static var checkboxSelected: UIImage { load("DivoCheckboxSelected") }
    public static var chevronDown: UIImage { load("DivoChevronDown") }
    public static var contactEditAction: UIImage { load("DivoContactEditAction") }
    public static var crownPremium: UIImage { load("DivoCrownPremium") }
    public static var defWork: UIImage { load("DivoDefWork") }
    public static var emptyAppearanceProfile: UIImage { load("DivoEmptyAppearanceProfile") }
    public static var emptyBioProfile: UIImage { load("DivoEmptyBioProfile") }
    public static var emptyImageWork: UIImage { load("DivoEmptyImageWork") }
    public static var emptyModelsAgency: UIImage { load("DivoEmptyModelsAgency") }
    public static var emptyWorkProfile: UIImage { load("DivoEmptyWorkProfile") }
    public static var eventTest: UIImage { load("DivoEventTest") }
    public static var eventsAgency: UIImage { load("DivoEventsAgency") }
    public static var faceScanBlack: UIImage { load("DivoFaceScanBlack") }
    public static var faceSearchEmpty: UIImage { load("DivoFaceSearchEmpty") }
    public static var faceSearchError: UIImage { load("DivoFaceSearchError") }
    public static var faceSearchInfo: UIImage { load("DivoFaceSearchInfo") }
    public static var genderIcon: UIImage { load("DivoGenderIcon") }
    public static var group: UIImage { load("DivoGroup") }
    public static var heartActionIcon: UIImage { load("DivoHeartActionIcon") }
    public static var heightIcon: UIImage { load("DivoHeightIcon") }
    public static var iconEvents: UIImage { load("DivoIconEvents") }
    public static var iconModels: UIImage { load("DivoIconModels") }
    public static var instaIcon: UIImage { load("DivoInstaIcon") }
    public static var link: UIImage { load("DivoLink") }
    public static var logo: UIImage { load("DivoLogo") }
    public static var moreActionIcon: UIImage { load("DivoMoreActionIcon") }
    public static var moreActionIconBlack: UIImage { load("DivoMoreActionIconBlack") }
    public static var moreIcon: UIImage { load("DivoMoreIcon") }
    public static var onboardingFirst: UIImage { load("DivoOnboardingFirst") }
    public static var onboardingSecond: UIImage { load("DivoOnboardingSecond") }
    public static var onboardingThird: UIImage { load("DivoOnboardingThird") }
    public static var paid: UIImage { load("DivoPaid") }
    public static var pencil: UIImage { load("DivoPencil") }
    public static var photoIcon: UIImage { load("DivoPhotoIcon") }
    public static var plus: UIImage { load("DivoPlus") }
    public static var plusWorkHistory: UIImage { load("DivoPlusWorkHistory") }
    public static var premiumIcon: UIImage { load("DivoPremiumIcon") }
    public static var profileEditAction: UIImage { load("DivoProfileEditAction") }
    public static var profileLevelInfo2: UIImage { load("DivoProfileLevelInfo2") }
    public static var profileLevelInfo3: UIImage { load("DivoProfileLevelInfo3") }
    public static var profileLevelProgressIcon: UIImage { load("DivoProfileLevelProgressIcon") }
    public static var profileLevelWarningIcon: UIImage { load("DivoProfileLevelWarningIcon") }
    public static var qrCode: UIImage { load("DivoQrCode") }
    public static var refresh: UIImage { load("DivoRefresh") }
    public static var report: UIImage { load("DivoReport") }
    public static var roleAgency: UIImage { load("DivoRoleAgency") }
    public static var roleModel: UIImage { load("DivoRoleModel") }
    public static var roleNewTalent: UIImage { load("DivoRoleNewTalent") }
    public static var searchArrowProfile: UIImage { load("DivoSearchArrowProfile") }
    public static var searchChevronLeft: UIImage { load("DivoSearchChevronLeft") }
    public static var searchChevronRight: UIImage { load("DivoSearchChevronRight") }
    public static var searchCloseIcon: UIImage { load("DivoSearchCloseIcon") }
    public static var searchFaceScan: UIImage { load("DivoSearchFaceScan") }
    public static var searchFieldIcon: UIImage { load("DivoSearchFieldIcon") }
    public static var searchFilterIcon: UIImage { load("DivoSearchFilterIcon") }
    public static var searchOrangeCheckmark: UIImage { load("DivoSearchOrangeCheckmark") }
    public static var searchPersonHeart: UIImage { load("DivoSearchPersonHeart") }
    public static var searchWhiteCheckmark: UIImage { load("DivoSearchWhiteCheckmark") }
    public static var seat: UIImage { load("DivoSeat") }
    public static var sendDM: UIImage { load("DivoSendDM") }
    public static var settingsBannerBackground: UIImage { load("DivoSettingsBannerBackground") }
    public static var settingsData: UIImage { load("DivoSettingsData") }
    public static var settingsLanguage: UIImage { load("DivoSettingsLanguage") }
    public static var settingsLogOut: UIImage { load("DivoSettingsLogOut") }
    public static var settingsNotifications: UIImage { load("DivoSettingsNotifications") }
    public static var settingsParameters: UIImage { load("DivoSettingsParameters") }
    public static var settingsPrivacy: UIImage { load("DivoSettingsPrivacy") }
    public static var settingsSavedMessages: UIImage { load("DivoSettingsSavedMessages") }
    public static var settingsSetUsername: UIImage { load("DivoSettingsSetUsername") }
    public static var settingsSmallLogo: UIImage { load("DivoSettingsSmallLogo") }
    public static var share: UIImage { load("DivoShare") }
    public static var signUpAgencies: UIImage { load("DivoSignUpAgencies") }
    public static var signUpChooseRoleBackground: UIImage { load("DivoSignUpChooseRoleBackground") }
    public static var signUpFan: UIImage { load("DivoSignUpFan") }
    public static var signUpModel: UIImage { load("DivoSignUpModel") }
    public static var signUpNewTalent: UIImage { load("DivoSignUpNewTalent") }
    public static var splashScreen: UIImage { load("DivoSplashScreen") }
    public static var statLike: UIImage { load("DivoStatLike") }
    public static var statLikeFilled: UIImage { load("DivoStatLikeFilled") }
    public static var statSave: UIImage { load("DivoStatSave") }
    public static var statSaveFilled: UIImage { load("DivoStatSaveFilled") }
    public static var statView: UIImage { load("DivoStatView") }
    public static var stories: UIImage { load("DivoStories") }
    public static var storyAvatarStub1: UIImage { load("DivoStoryAvatarStub1") }
    public static var storyAvatarStub2: UIImage { load("DivoStoryAvatarStub2") }
    public static var storyAvatarStub3: UIImage { load("DivoStoryAvatarStub3") }
    public static var storyAvatarStub4: UIImage { load("DivoStoryAvatarStub4") }
    public static var storyAvatarStub5: UIImage { load("DivoStoryAvatarStub5") }
    public static var storyAvatarStub6: UIImage { load("DivoStoryAvatarStub6") }
    public static var storyAvatarStub7: UIImage { load("DivoStoryAvatarStub7") }
    public static var storyAvatarStub8: UIImage { load("DivoStoryAvatarStub8") }
    public static var tikTokIcon: UIImage { load("DivoTikTokIcon") }
    public static var timeIcon: UIImage { load("DivoTimeIcon") }
    public static var videoIcon: UIImage { load("DivoVideoIcon") }
    public static var webIcon: UIImage { load("DivoWebIcon") }
    public static var whitePlus: UIImage { load("DivoWhitePlus") }
    public static var youtubeIcon: UIImage { load("DivoYoutubeIcon") }

    private static func load(_ name: String) -> UIImage {
        guard let image = UIImage(bundleImageName: name) else {
            assertionFailure("DIVO asset not found in bundle: \(name)")
            return UIImage()
        }
        return image
    }
}
