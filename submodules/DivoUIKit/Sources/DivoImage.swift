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
    public static var addPhotoIcon: UIImage { load("DivoAddPhotoIcon") }
    public static var ageIcon: UIImage { load("DivoAgeIcon") }
    public static var associatedModels: UIImage { load("DivoAssociatedModels") }
    public static var badgeBaseWork: UIImage { load("DivoBadgeBaseWork") }
    public static var basket: UIImage { load("DivoBasket") }
    public static var checkbox: UIImage { load("DivoCheckbox") }
    public static var checkboxSelected: UIImage { load("DivoCheckboxSelected") }
    public static var chevronDown: UIImage { load("DivoChevronDown") }
    public static var contactEditAction: UIImage { load("DivoContactEditAction") }
    public static var crownPremium: UIImage { load("DivoCrownPremium") }
    public static var defWork: UIImage { load("DivoDefWork") }
    public static var eventTest: UIImage { load("DivoEventTest") }
    public static var eventsAgency: UIImage { load("DivoEventsAgency") }
    public static var filmstripIcon: UIImage { load("DivoFilmstripIcon") }
    public static var genderIcon: UIImage { load("DivoGenderIcon") }
    public static var gridIcon: UIImage { load("DivoGridIcon") }
    public static var heartActionIcon: UIImage { load("DivoHeartActionIcon") }
    public static var heightIcon: UIImage { load("DivoHeightIcon") }
    public static var iconEvents: UIImage { load("DivoIconEvents") }
    public static var iconModels: UIImage { load("DivoIconModels") }
    public static var instaIcon: UIImage { load("DivoInstaIcon") }
    public static var link: UIImage { load("DivoLink") }
    public static var moreActionIcon: UIImage { load("DivoMoreActionIcon") }
    public static var moreIcon: UIImage { load("DivoMoreIcon") }
    public static var plus: UIImage { load("DivoPlus") }
    public static var premiumIcon: UIImage { load("DivoPremiumIcon") }
    public static var profileEditAction: UIImage { load("DivoProfileEditAction") }
    public static var profileLevelInfo2: UIImage { load("DivoProfileLevelInfo2") }
    public static var profileLevelInfo3: UIImage { load("DivoProfileLevelInfo3") }
    public static var profileLevelProgressIcon: UIImage { load("DivoProfileLevelProgressIcon") }
    public static var profileLevelWarningIcon: UIImage { load("DivoProfileLevelWarningIcon") }
    public static var roleAgency: UIImage { load("DivoRoleAgency") }
    public static var roleModel: UIImage { load("DivoRoleModel") }
    public static var roleNewTalent: UIImage { load("DivoRoleNewTalent") }
    public static var saveMedia: UIImage { load("DivoSaveMedia") }
    public static var searchArrowProfile: UIImage { load("DivoSearchArrowProfile") }
    public static var searchChevronLeft: UIImage { load("DivoSearchChevronLeft") }
    public static var searchChevronRight: UIImage { load("DivoSearchChevronRight") }
    public static var searchCloseIcon: UIImage { load("DivoSearchCloseIcon") }
    public static var searchFaceScan: UIImage { load("DivoSearchFaceScan") }
    public static var searchFieldIcon: UIImage { load("DivoSearchFieldIcon") }
    public static var searchFilterIcon: UIImage { load("DivoSearchFilterIcon") }
    public static var searchPersonHeart: UIImage { load("DivoSearchPersonHeart") }
    public static var signUpAgencies: UIImage { load("DivoSignUpAgencies") }
    public static var signUpChooseRoleBackground: UIImage { load("DivoSignUpChooseRoleBackground") }
    public static var signUpFan: UIImage { load("DivoSignUpFan") }
    public static var signUpModel: UIImage { load("DivoSignUpModel") }
    public static var signUpNewTalent: UIImage { load("DivoSignUpNewTalent") }
    public static var statLike: UIImage { load("DivoStatLike") }
    public static var statLikeFilled: UIImage { load("DivoStatLikeFilled") }
    public static var statSave: UIImage { load("DivoStatSave") }
    public static var statSaveFilled: UIImage { load("DivoStatSaveFilled") }
    public static var statView: UIImage { load("DivoStatView") }
    public static var storyAvatarStub1: UIImage { load("DivoStoryAvatarStub1") }
    public static var storyAvatarStub2: UIImage { load("DivoStoryAvatarStub2") }
    public static var storyAvatarStub3: UIImage { load("DivoStoryAvatarStub3") }
    public static var storyAvatarStub4: UIImage { load("DivoStoryAvatarStub4") }
    public static var storyAvatarStub5: UIImage { load("DivoStoryAvatarStub5") }
    public static var storyAvatarStub6: UIImage { load("DivoStoryAvatarStub6") }
    public static var storyAvatarStub7: UIImage { load("DivoStoryAvatarStub7") }
    public static var storyAvatarStub8: UIImage { load("DivoStoryAvatarStub8") }
    public static var tikTokIcon: UIImage { load("DivoTikTokIcon") }
    public static var webIcon: UIImage { load("DivoWebIcon") }
    public static var youtubeIcon: UIImage { load("DivoYoutubeIcon") }

    private static func load(_ name: String) -> UIImage {
        guard let image = UIImage(bundleImageName: name) else {
            assertionFailure("DIVO asset not found in bundle: \(name)")
            return UIImage()
        }
        return image
    }
}
