import UIKit
import Display

public enum DivoColorPalette {
    // MARK: - Brand
    public static let accent = UIColor(hexString: "#FF772D")!           // DIVO orange
    public static let accentPressed = UIColor(hexString: "#E0551A")!    // DIVO orange press state (darker)
    public static let accentSecondary = UIColor(hexString: "#BF7A54")!  // copper (hex-precise)
    /// Copper тёплый вариант 0.77/0.54/0.38 — Profile/Events/Auth buttons (визуально светлее accentSecondary).
    public static let accentCopperWarm = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
    /// Copper насыщённый 0.75/0.48/0.33 — Profile add-experience, Auth onTint.
    public static let accentCopperDeep = UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.0)
    /// Copper тёмный 0.73/0.44/0.28 — имя профиля в EventDetail.
    public static let accentCopperDark = UIColor(red: 0.73, green: 0.44, blue: 0.28, alpha: 1.0)
    /// Приглушённый copper border на картинках — 0.6/0.4/0.2 α0.8.
    public static let accentCopperMutedBorder = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8)
    /// #BC8461 — copper tint иконки «добавить» на nav bar.
    public static let accentCopperTint = UIColor(hexString: "#BC8461")!
    public static let roleBadgeBlue = UIColor(red: 34/255, green: 98/255, blue: 216/255, alpha: 1)
    public static let roleBadgeCopperTint = UIColor(red: 0.95, green: 0.92, blue: 0.90, alpha: 1)
    public static let borderWorkHistoryImage = UIColor(hexString: "#F6F6F6")!
    /// #F3E7E1 — фон информационной плашки face search при multiple faces без selection.
    public static let faceBannerMultipleBackground = UIColor(hexString: "#F3E7E1")!
    /// #C16B3E — приглушённый оранжевый текст плашки процента face search при совпадении < 89%.
    public static let matchPercentMuted = UIColor(hexString: "#C16B3E")!
    /// #1EDD4E — зелёный индикатор online-статуса в шапке профиля.
    public static let onlineIndicator = UIColor(hexString: "#1EDD4E")!
    
    // MARK: - Text (DIVO)
    public static let primaryText = UIColor(hexString: "#222222")!
    public static let secondaryText = UIColor(white: 153/255, alpha: 1) // #999999
    public static let disabledText = UIColor(white: 0.69, alpha: 1)     // #AFAFB1
    public static let primaryTextOnDark: UIColor = .white
    public static let bannerSecondary = UIColor(white: 195/255, alpha: 1) // #C3C3C3

    // MARK: - Text (iOS system-like labels)
    /// #17181C — почти-чёрный header text на светлых экранах.
    public static let systemLabelDark = UIColor(hexString: "#17181C")!
    /// #3C3C43 — iOS secondary label, input text, placeholder base.
    public static let systemLabelSecondary = UIColor(hexString: "#3C3C43")!
    /// #8E8E93 — iOS tertiary label, icons tint.
    public static let systemLabelTertiary = UIColor(hexString: "#8E8E93")!
    /// #C7C7CC — iOS systemGray3, tint у empty-search иконок.
    public static let systemGray3 = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1.0)
    /// iOS secondaryLabel-плейсхолдер (0.24/0.24/0.26 α0.6) — EventsSearch filter tint, placeholder.
    public static let systemLabelPlaceholder = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6)
    /// iOS secondaryLabel body (0.24/0.24/0.26 α1.0) — текст Multiline input, CreateEvent field.
    public static let systemLabelBody = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
    /// iOS search input fill (systemGray5 @ 12%) — EventsSearch текстовое поле.
    public static let searchInputFill = UIColor(red: 0.47, green: 0.47, blue: 0.50, alpha: 0.12)

    // MARK: - Text on dark surfaces
    public static let textOnDarkMuted = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
    public static let textOnDarkSecondary = UIColor(white: 0.85, alpha: 1.0)
    public static let textOnDarkTertiary = UIColor.white.withAlphaComponent(0.4)
    public static let textOnDarkLight = UIColor.white.withAlphaComponent(0.6)

    // MARK: - Surfaces (light)
    public static let cardBackground = UIColor.white
    public static let screenBackground = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1) // #F0F0F0
    /// #EFEFF0 — приглушённый input-background на светлой sheet.
    public static let inputBackgroundMuted = UIColor(hexString: "#EFEFF0")!
    /// 0.94 — стандартный field background на CreateEvent/EditProfile.
    public static let fieldBackgroundLight = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.00)
    /// 0.96 — фон bottom-sheet (EventParameters).
    public static let sheetBackgroundMuted = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
    /// 0.97 — фон DivoSettings.
    public static let sheetBackgroundLight = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)

    // MARK: - Surfaces (dark)
    public static let darkBackground = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
    /// 0.15 — banner/dropdown container на тёмном.
    public static let bannerBackgroundDark = UIColor(white: 0.15, alpha: 1)
    public static let dropdownBackgroundDark = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
    /// 0.2 — dark input/field background.
    public static let inputBackgroundDark = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    /// Для текстовых border на тёмных полях (0.4).
    public static let inputBorderDark = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
    /// Иконки-подсказки в Auth ("No account" icon).
    public static let iconOnDarkMuted = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)

    // MARK: - Separators
    public static let separatorSystem = UIColor(hexString: "#E5E5EA")!
    public static let separatorSoft = UIColor(red: 236/255.0, green: 236/255.0, blue: 236/255.0, alpha: 1.0)
    public static let separatorLight = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)
    public static let separatorDarkSheet = UIColor(red: 0.33, green: 0.33, blue: 0.34, alpha: 0.34)

    // MARK: - Controls
    public static let shadow = UIColor.black                            // применяется с alpha 0.08/0.1
    /// Фон splash- и onboarding-экранов. Совпадает с LaunchScreen, чтобы не было белой вспышки на старте.
    public static let splashBackground = UIColor.black
    public static let navBarDisabledButtonColor = UIColor(red: 0.322, green: 0.322, blue: 0.322, alpha: 1)
    /// #343434 — secondary button normal state.
    public static let secondaryButtonBackground = UIColor(hexString: "#343434")!
    /// #000000 — secondary button pressed state.
    public static let secondaryButtonPressed = UIColor.black
    /// #E4E4E4 — universal disabled button background (primary & secondary).
    public static let buttonDisabledBackground = UIColor(hexString: "#E4E4E4")!
    /// 0.55 — неактивная иконка таба (DivoSettings).
    public static let tabInactiveIcon = UIColor(white: 0.55, alpha: 1)
    /// 0.2 — активная иконка таба.
    public static let tabActiveIcon = UIColor(white: 0.2, alpha: 1)
    /// 0.45 — неактивная пилюля/иконка фида.
    public static let feedPillInactive = UIColor(white: 0.45, alpha: 1.0)
    /// 0.4 — иконка navigation button фида.
    public static let feedNavIcon = UIColor(white: 0.4, alpha: 1.0)
    /// Ручка bottom-sheet (grabber) — white 30%.
    public static let handleIndicator = UIColor.white.withAlphaComponent(0.3)
    /// Неактивный UISwitch background в Auth — black 30%.
    public static let switchOffBackground = UIColor.black.withAlphaComponent(0.3)

    // MARK: - Translucent overlays (поверх изображений/тёмных подложек)
    public static let overlayHighlight = UIColor.white.withAlphaComponent(0.16)
    public static let overlayCell = UIColor.white.withAlphaComponent(0.2)
    public static let overlayInput = UIColor.white.withAlphaComponent(0.1)
    public static let overlayInputIcon = UIColor.white.withAlphaComponent(0.5)
    public static let sectionIndex: UIColor = .white
    /// Border тёмной карточки 14%.
    public static let overlayDarkFieldBorderSoft = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14)
    /// Border тёмного поля 40%.
    public static let overlayDarkFieldBorder = UIColor.white.withAlphaComponent(0.4)
    /// Border/разделитель 60% — Auth линии.
    public static let overlayDarkMediumLine = UIColor.white.withAlphaComponent(0.6)
    /// Border тёмного textview 20%.
    public static let overlayDarkFieldBorderLight = UIColor.white.withAlphaComponent(0.2)

    // MARK: - Image scrims / dimming
    public static let dimScrim = UIColor(white: 0.0, alpha: 0.4)
    public static let imageScrimLight = UIColor(white: 0.0, alpha: 0.15)
    public static let imageScrimMedium = UIColor(white: 0.0, alpha: 0.2)
    public static let imageScrimHeavy = UIColor(white: 0.0, alpha: 0.7)
    public static let badgeOnImage = UIColor.white.withAlphaComponent(0.25)
    public static let badgeOnImageStrong = UIColor.white.withAlphaComponent(0.3)

    // MARK: - Stat pills (на карточках моделей)
    public static let statPillBackground = UIColor.white.withAlphaComponent(0.2)
    public static let statPillBorder = UIColor.white.withAlphaComponent(0.4)
    public static let statPillForeground = UIColor.white
    public static let statPillActiveBackground = UIColor.white
    public static let statPillActiveForeground = UIColor.black

    // MARK: - Placeholders / avatars
    /// 0.92 — светлый placeholder фото.
    public static let imagePlaceholderLight = UIColor(white: 0.92, alpha: 1.0)
    /// 0.9 — placeholder аватара (Interaction/SimilarProfile/Event).
    public static let imagePlaceholderMedium = UIColor(white: 0.9, alpha: 1.0)
    /// 0.2 — тёмный placeholder grid ячейки.
    public static let imagePlaceholderDark = UIColor(white: 0.2, alpha: 1.0)
    /// #E8E8E8 — placeholder стори/аватаров.
    public static let avatarPlaceholderCool = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.00)
    /// 0.8 — тёплый warm placeholder (event profile image).
    public static let avatarPlaceholderWarm = UIColor(white: 0.8, alpha: 1.0)

    // MARK: - Shimmer
    public static let shimmerBase = UIColor(white: 0.85, alpha: 1.0)
    public static let shimmerHighlight = UIColor(white: 0.95, alpha: 1.0)
    public static let shimmerDivoBase = UIColor(white: 0.88, alpha: 1.0)
    public static let shimmerDivoHighlight = UIColor(white: 0.96, alpha: 1.0)

    // MARK: - Empty-state text
    public static let emptyTitleText = UIColor(white: 0.15, alpha: 1)
    public static let emptySubtitleText = UIColor(white: 0.4, alpha: 1)
    public static let emptyPrimaryDark = UIColor(white: 0.1, alpha: 1)
    public static let emptySubtitleLight = UIColor(white: 0.5, alpha: 1)
    public static let emptyCircleBackground = UIColor(white: 1.0, alpha: 0.8) // #FFFFFFCC
    public static let emptyIconTint = UIColor(white: 0.4, alpha: 1.0)
    /// #FFFFFF — фон контейнера эмпти-стейта на профильных табах (поверх него рисуется серый круг).
    public static let profileEmptyBackground = UIColor.white
    /// #F0F0F0 — серый круг под иконкой в эмпти-стейтах профиля.
    public static let profileEmptyCircleBackground = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
    /// #22222299 — tint иконки в эмпти-стейтах профиля и алмаза в Agency-табе ленты.
    public static let profileEmptyIconTint = UIColor(red: 0x22/255, green: 0x22/255, blue: 0x22/255, alpha: 0x99/255)
    public static let placeholderCardBackground = UIColor(white: 0.96, alpha: 1)
    /// #E6E6E6 — skeleton-плейсхолдер (search grid, filter bar).
    public static let skeletonBackground = UIColor(white: 230/255, alpha: 1.0)

    // MARK: - Settings rows / misc
    public static let settingsUsernameIconText = UIColor(white: 0.45, alpha: 1)
    public static let settingsSecondaryText = UIColor(white: 0.45, alpha: 1)
    public static let settingsChevron = UIColor(white: 0.75, alpha: 1)
    public static let settingsBannerSubtitle = UIColor(white: 0.82, alpha: 1)
    public static let settingsNameText: UIColor = .black
    public static let settingsPhoneText = UIColor(white: 126/255, alpha: 1) // #7E7E82

    // MARK: - Feed typography
    public static let feedTitleText = UIColor(white: 0.2, alpha: 1.0)

    // MARK: - Semantic states
    /// Красная рамка / текст ошибки (face detect no-face, validation).
    public static let errorState = UIColor(red: 223/255, green: 28/255, blue: 65/255, alpha: 1)

    // MARK: - Snackbar
    public static let snackbarError = UIColor(red: 223/255, green: 28/255, blue: 65/255, alpha: 1)
    public static let snackbarSuccess = UIColor(red: 12/255, green: 138/255, blue: 81/255, alpha: 1)

    // MARK: - Avatar stroke / online border
    /// #E2E2E2 — рамка online-индикатора и «тихая» дуга AvatarStrokeView.
    public static let avatarStrokeQuiet = UIColor(hexString: "#E2E2E2")!
    /// #990000 — верхний стоп градиента AvatarStrokeView.
    public static let avatarStrokeRedDeep = UIColor(hexString: "#990000")!

    // MARK: - Bronze tag gradient (6 стопов)
    public static let bronzeGradientLight = UIColor(hexString: "#BB7148")!
    public static let bronzeGradientSheen = UIColor(hexString: "#D5B187")!
    public static let bronzeGradientMid = UIColor(hexString: "#A46B4C")!
    public static let bronzeGradientDark = UIColor(hexString: "#89503B")!
    public static let bronzeGradientDeep = UIColor(hexString: "#823F36")!

    // MARK: - Event confirm
    public static let applyBorder = UIColor(hexString: "#E8520A")!
    public static let warningApply = UIColor(hexString: "#DF1C41")!

    // MARK: - Event type badges

    public static let eventTypeCasting          = UIColor(hexString: "#185FA5")!
    public static let eventTypeParty            = UIColor(rgb: 0x9D2AEE)
    public static let eventTypePhotoshoot       = UIColor(rgb: 0xEE2A7B)
    public static let eventTypePromo            = UIColor(rgb: 0xEE7A2A)
    public static let eventTypeVideoShoot       = UIColor(rgb: 0xE53935)
    public static let eventTypeEvent            = UIColor(hexString: "#BD47CD")!
    public static let eventTypeShow             = UIColor(hexString: "#534AB7")!
    public static let eventTypeExhibition       = UIColor(hexString: "#0F6E56")!
    public static let eventTypeHairCut          = UIColor(rgb: 0xF50057)
    public static let eventTypeActorAnimator    = UIColor(rgb: 0x00ACC1)
    public static let eventTypeDancers          = UIColor(rgb: 0xFFB300)
    public static let eventTypeBodyArt          = UIColor(rgb: 0x00897B)
    public static let eventTypeHostess          = UIColor(rgb: 0x3949AB)
    public static let eventTypeForeignContracts = UIColor(rgb: 0x1E88E5)

    public static let pendingStatus = UIColor(hexString: "#E8520A")!
    public static let shortlistedStatus = UIColor(hexString: "#534AB7")!
    public static let acceptedStatus = UIColor(hexString: "#0F6E56")!
    public static let rejectedStatus = UIColor(hexString: "#DF1C41")!
}

public enum EventTypeStyle: Int {
    case casting = 1
    case party = 2
    case photoshoot = 3
    case promo = 4
    case videoShoot = 278
    case event = 279
    case show = 280
    case exhibition = 281
    case hairCut = 282
    case actorAnimator = 283
    case dancers = 284
    case bodyArt = 285
    case hostess = 286
    case foreignContracts = 287

    public var color: UIColor {
        switch self {
        case .casting:          return DivoColorPalette.eventTypeCasting
        case .party:            return DivoColorPalette.eventTypeParty
        case .photoshoot:       return DivoColorPalette.eventTypePhotoshoot
        case .promo:            return DivoColorPalette.eventTypePromo
        case .videoShoot:       return DivoColorPalette.eventTypeVideoShoot
        case .event:            return DivoColorPalette.eventTypeEvent
        case .show:             return DivoColorPalette.eventTypeShow
        case .exhibition:       return DivoColorPalette.eventTypeExhibition
        case .hairCut:          return DivoColorPalette.eventTypeHairCut
        case .actorAnimator:    return DivoColorPalette.eventTypeActorAnimator
        case .dancers:          return DivoColorPalette.eventTypeDancers
        case .bodyArt:          return DivoColorPalette.eventTypeBodyArt
        case .hostess:          return DivoColorPalette.eventTypeHostess
        case .foreignContracts: return DivoColorPalette.eventTypeForeignContracts
        }
    }

    /// Безопасное извлечение цвета по `id`.
    /// Если id неизвестен (или `nil`), возвращается дефолтный `DivoColorPalette.roleBadgeBlue`.
    public static func color(for id: Int?) -> UIColor {
        guard let id = id, let style = EventTypeStyle(rawValue: id) else {
            return DivoColorPalette.roleBadgeBlue
        }
        return style.color
    }
}
