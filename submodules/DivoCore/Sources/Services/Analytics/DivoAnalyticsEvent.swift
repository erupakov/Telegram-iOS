import Foundation

/// Типизированное событие аналитики. Имена событий и ключи параметров — строго по ТЗ
/// (`~/Documents/DIVO/События аналитики.xlsx`). На местах вызова используем фабрики,
/// чтобы не плодить «магические строки»: `divoTrack(.modelsFeedOpened)`,
/// `divoTrack(.likeToggled(targetUserId: id, isLiked: true))`.
public struct DivoAnalyticsEvent {
    public let name: String
    public let parameters: [String: Any]

    public init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

// MARK: - 1. Онбординг и Регистрация

public extension DivoAnalyticsEvent {
    static var onboardingStarted: DivoAnalyticsEvent { .init(name: "onboarding_started") }
    static var onboardingSkipped: DivoAnalyticsEvent { .init(name: "onboarding_skipped") }
    static var onboardingCompleted: DivoAnalyticsEvent { .init(name: "onboarding_completed") }

    /// method — 'phone' | 'google' | 'apple'
    static func authMethodSelected(method: String) -> DivoAnalyticsEvent {
        .init(name: "auth_method_selected", parameters: ["method": method])
    }

    static var termsAccepted: DivoAnalyticsEvent { .init(name: "terms_accepted") }
    static var termsDeclined: DivoAnalyticsEvent { .init(name: "terms_declined") }
    static var termsLinkClicked: DivoAnalyticsEvent { .init(name: "terms_link_clicked") }
    static var privacyPolicyLinkClicked: DivoAnalyticsEvent { .init(name: "privacy_policy_link_clicked") }

    static func signUpStart(method: String) -> DivoAnalyticsEvent {
        .init(name: "sign_up_start", parameters: ["method": method])
    }
    static func signInStart(method: String) -> DivoAnalyticsEvent {
        .init(name: "sign_in_start", parameters: ["method": method])
    }
    static func signUpIntentSelected(intent: String) -> DivoAnalyticsEvent {
        .init(name: "sign_up_intent_selected", parameters: ["intent": intent])
    }
    static func signUpRoleSelected(role: String) -> DivoAnalyticsEvent {
        .init(name: "sign_up_role_selected", parameters: ["role": role])
    }
    static func signUpStepCompleted(stepName: String, stepNumber: Int, totalSteps: Int) -> DivoAnalyticsEvent {
        .init(name: "sign_up_step_completed", parameters: [
            "step_name": stepName, "step_number": stepNumber, "total_steps": totalSteps
        ])
    }
    static func signUpError(errorMessage: String) -> DivoAnalyticsEvent {
        .init(name: "sign_up_error", parameters: ["error_message": errorMessage])
    }
    static func signUpComplete(method: String) -> DivoAnalyticsEvent {
        .init(name: "sign_up_complete", parameters: ["method": method])
    }
    static func signInComplete(method: String) -> DivoAnalyticsEvent {
        .init(name: "sign_in_complete", parameters: ["method": method])
    }
}

// MARK: - 2. Профиль и Портфолио

public extension DivoAnalyticsEvent {
    static func profileTabViewed(tabName: String) -> DivoAnalyticsEvent {
        .init(name: "profile_tab_viewed", parameters: ["tab_name": tabName])
    }
    static func profileInfoTabViewed(tabName: String) -> DivoAnalyticsEvent {
        .init(name: "profile_info_tab_viewed", parameters: ["tab_name": tabName])
    }
    static func profileOpened(targetUserId: Int64, source: String? = nil) -> DivoAnalyticsEvent {
        var p: [String: Any] = ["target_user_id": targetUserId]
        if let source = source { p["source"] = source }
        return .init(name: "profile_opened", parameters: p)
    }
    static var profileEditSaved: DivoAnalyticsEvent { .init(name: "profile_edit_saved") }
    static var parametersUpdated: DivoAnalyticsEvent { .init(name: "parameters_updated") }
    static var profileEditOpened: DivoAnalyticsEvent { .init(name: "profile_edit_opened") }
    static var profileAvatarUploaded: DivoAnalyticsEvent { .init(name: "profile_avatar_uploaded") }
    static var profileBackgroundChanged: DivoAnalyticsEvent { .init(name: "profile_background_changed") }
    static var socialLinksOpened: DivoAnalyticsEvent { .init(name: "social_links_opened") }
    static var socialLinksSaved: DivoAnalyticsEvent { .init(name: "social_links_saved") }

    static func profileEditMenuTapped(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "profile_edit_menu_tapped", parameters: ["target_user_id": targetUserId])
    }
    static func profileEditOptionTapped(targetUserId: Int, option: String) -> DivoAnalyticsEvent {
        .init(name: "profile_edit_option_tapped", parameters: ["target_user_id": targetUserId, "option": option])
    }

    static var workHistoryCreated: DivoAnalyticsEvent { .init(name: "work_history_created") }
    static var workHistoryEdited: DivoAnalyticsEvent { .init(name: "work_history_edited") }
    static var workHistoryDeleted: DivoAnalyticsEvent { .init(name: "work_history_deleted") }
    static func workHistoryOpened(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "work_history_opened", parameters: ["target_user_id": targetUserId])
    }
    static var workHistoryCreateOpened: DivoAnalyticsEvent { .init(name: "work_history_create_opened") }
    static func workHistoryEditOpened(workId: Int) -> DivoAnalyticsEvent {
        .init(name: "work_history_edit_opened", parameters: ["work_id": workId])
    }

    static func profileMediaUploadTapped(mediaType: String, targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "profile_media_upload_tapped", parameters: ["media_type": mediaType, "target_user_id": targetUserId])
    }
    static func profileMediaUploaded(mediaType: String, targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "profile_media_uploaded", parameters: ["media_type": mediaType, "target_user_id": targetUserId])
    }
}

// MARK: - 3. Функционал Агентств

public extension DivoAnalyticsEvent {
    static func addModelStarted(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "add_model_started", parameters: ["target_user_id": targetUserId])
    }
    static func addModelSuccess(targetUserId: Int, agencyId: Int) -> DivoAnalyticsEvent {
        .init(name: "add_model_success", parameters: ["target_user_id": targetUserId, "agency_id": agencyId])
    }
    static func removeModelSuccess(targetUserId: Int, agencyId: Int) -> DivoAnalyticsEvent {
        .init(name: "remove_model_success", parameters: ["target_user_id": targetUserId, "agency_id": agencyId])
    }
}

// MARK: - 4. Каналы

public extension DivoAnalyticsEvent {
    static func channelCreateStarted(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "channel_create_started", parameters: ["target_user_id": targetUserId])
    }
    static func channelCreateSuccess(targetUserId: Int, channelId: Int64) -> DivoAnalyticsEvent {
        .init(name: "channel_create_success", parameters: ["target_user_id": targetUserId, "channel_id": channelId])
    }
    static func channelDeleteSuccess(targetUserId: Int, channelId: Int64) -> DivoAnalyticsEvent {
        .init(name: "channel_delete_success", parameters: ["target_user_id": targetUserId, "channel_id": channelId])
    }
}

// MARK: - 5. Поиск и Распознавание лиц

public extension DivoAnalyticsEvent {
    /// source — откуда открыт скан ('camera' | 'gallery' | 'profile')
    static func faceRecognitionOpened(source: String, targetUserId: Int? = nil) -> DivoAnalyticsEvent {
        var p: [String: Any] = ["source": source]
        if let targetUserId = targetUserId { p["target_user_id"] = targetUserId }
        return .init(name: "face_recognition_opened", parameters: p)
    }
    static var faceSearchStarted: DivoAnalyticsEvent { .init(name: "face_search_started") }
    static func faceSearchSuccess(matchesCount: Int) -> DivoAnalyticsEvent {
        .init(name: "face_search_success", parameters: ["matches_count": matchesCount])
    }
    static var faceSearchFindTapped: DivoAnalyticsEvent { .init(name: "face_search_find_tapped") }
    static var faceSearchHistoryOpened: DivoAnalyticsEvent { .init(name: "face_search_history_opened") }
    static var faceSearchHistoryCleared: DivoAnalyticsEvent { .init(name: "face_search_history_cleared") }

    static func similarProfilesScreenOpened(hasResults: Bool) -> DivoAnalyticsEvent {
        .init(name: "similar_profiles_screen_opened", parameters: ["has_results": hasResults])
    }
    static var similarProfilesFiltersOpened: DivoAnalyticsEvent { .init(name: "similar_profiles_filters_opened") }
    static func similarProfilesFiltersApplied(activeFilters: String) -> DivoAnalyticsEvent {
        .init(name: "similar_profiles_filters_applied", parameters: ["active_filters": activeFilters])
    }
    static var similarProfileOpened: DivoAnalyticsEvent { .init(name: "similar_profile_opened") }

    static func searchPerformed(target: String, hasResults: Bool, query: String, activeFilters: String) -> DivoAnalyticsEvent {
        .init(name: "search_performed", parameters: [
            "target": target, "has_results": hasResults, "query": query, "active_filters": activeFilters
        ])
    }
    static func searchFiltersOpened(target: String) -> DivoAnalyticsEvent {
        .init(name: "search_filters_opened", parameters: ["target": target])
    }
    static func searchFiltersApplied(target: String, activeFilters: String) -> DivoAnalyticsEvent {
        .init(name: "search_filters_applied", parameters: ["target": target, "active_filters": activeFilters])
    }
    static func searchQueryEntered(target: String, queryLength: Int) -> DivoAnalyticsEvent {
        .init(name: "search_query_entered", parameters: ["target": target, "query_length": queryLength])
    }
    static func searchModelTapped(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "search_model_tapped", parameters: ["target_user_id": targetUserId])
    }
    static func engagementSearchPerformed(tabName: String, targetUserId: Int, query: String, hasResults: Bool) -> DivoAnalyticsEvent {
        .init(name: "engagement_search_performed", parameters: [
            "tab_name": tabName, "target_user_id": targetUserId, "query": query, "has_results": hasResults
        ])
    }
}

// MARK: - 6. Ивенты

public extension DivoAnalyticsEvent {
    static var eventListOpened: DivoAnalyticsEvent { .init(name: "event_list_opened") }
    static func eventCreateStarted(targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "event_create_started", parameters: ["target_user_id": targetUserId])
    }
    static func eventCreateSuccess(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_create_success", parameters: ["event_id": eventId])
    }
    static var eventCreatePreviewOpened: DivoAnalyticsEvent { .init(name: "event_create_preview_opened") }
    static func eventEditStarted(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_edit_started", parameters: ["event_id": eventId])
    }
    static func eventEdited(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_edited", parameters: ["event_id": eventId])
    }
    static func eventCancelled(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_cancelled", parameters: ["event_id": eventId])
    }
    static func eventApplicationsClosed(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_applications_closed", parameters: ["event_id": eventId])
    }
    static func eventDetailsMenuOpened(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_details_menu_opened", parameters: ["event_id": eventId])
    }
    static func eventParametersOpened(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_parameters_opened", parameters: ["event_id": eventId])
    }
    static func eventDetailsViewed(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_details_viewed", parameters: ["event_id": eventId])
    }
    static func eventFavoriteToggled(eventId: Int64, isFavorite: Bool) -> DivoAnalyticsEvent {
        .init(name: "event_favorite_toggled", parameters: ["event_id": eventId, "is_favorite": isFavorite])
    }
    static func eventApplyStarted(eventId: Int64, userId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_apply_started", parameters: ["event_id": eventId, "user_id": userId])
    }
    static func eventApplyConfirmed(eventId: Int64, userId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_apply_confirmed", parameters: ["event_id": eventId, "user_id": userId])
    }
    static func eventWithdraw(eventId: Int64, userId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_withdraw", parameters: ["event_id": eventId, "user_id": userId])
    }
    static func eventDeleted(eventId: Int64) -> DivoAnalyticsEvent {
        .init(name: "event_deleted", parameters: ["event_id": eventId])
    }
}

// MARK: - 7. Социальное взаимодействие и Чаты

public extension DivoAnalyticsEvent {
    static func likeToggled(targetUserId: Int64, isLiked: Bool) -> DivoAnalyticsEvent {
        .init(name: "like_toggled", parameters: ["target_user_id": targetUserId, "is_liked": isLiked])
    }
    static func bookmarkToggled(targetUserId: Int64, isBookmarked: Bool) -> DivoAnalyticsEvent {
        .init(name: "bookmark_toggled", parameters: ["target_user_id": targetUserId, "is_bookmarked": isBookmarked])
    }
    static func engagementTabViewed(tabName: String, targetUserId: Int) -> DivoAnalyticsEvent {
        .init(name: "engagement_tab_viewed", parameters: ["tab_name": tabName, "target_user_id": targetUserId])
    }
    static var modelsFeedOpened: DivoAnalyticsEvent { .init(name: "models_feed_opened") }
    static var modelsSearchOpened: DivoAnalyticsEvent { .init(name: "models_search_opened") }
    static var chatsOpened: DivoAnalyticsEvent { .init(name: "chats_opened") }
    static func chatViewed(targetUserId: Int64, chatId: Int64) -> DivoAnalyticsEvent {
        .init(name: "chat_viewed", parameters: ["target_user_id": targetUserId, "chat_id": chatId])
    }
    static func modelsTabViewed(tabName: String) -> DivoAnalyticsEvent {
        .init(name: "models_tab_viewed", parameters: ["tab_name": tabName])
    }
    static func galleryItemViewed(targetUserId: Int, mediaId: Int, mediaType: String) -> DivoAnalyticsEvent {
        .init(name: "gallery_item_viewed", parameters: [
            "target_user_id": targetUserId, "media_id": mediaId, "media_type": mediaType
        ])
    }
    static var storyAddClicked: DivoAnalyticsEvent { .init(name: "story_add_clicked") }
    static func storyOpened(source: String) -> DivoAnalyticsEvent {
        .init(name: "story_opened", parameters: ["source": source])
    }
    static func storyUploaded(isVideo: Bool) -> DivoAnalyticsEvent {
        .init(name: "story_uploaded", parameters: ["is_video": isVideo])
    }
    static func directMessageStarted(sourceUserId: Int, targetUserId: Int64) -> DivoAnalyticsEvent {
        .init(name: "direct_message_started", parameters: ["source_user_id": sourceUserId, "target_user_id": targetUserId])
    }
    static func attachmentMenuOpened(targetUserId: Int64) -> DivoAnalyticsEvent {
        .init(name: "attachment_menu_opened", parameters: ["target_user_id": targetUserId])
    }
    static func callStarted(targetUserId: Int64, isVideo: Bool) -> DivoAnalyticsEvent {
        .init(name: "call_started", parameters: ["target_user_id": targetUserId, "is_video": isVideo])
    }
    static func messageSent(targetUserId: Int64, chatId: Int64, messageType: String) -> DivoAnalyticsEvent {
        .init(name: "message_sent", parameters: [
            "target_user_id": targetUserId, "chat_id": chatId, "message_type": messageType
        ])
    }
    static func contentShared(contentType: String, contentId: Int64) -> DivoAnalyticsEvent {
        .init(name: "content_shared", parameters: ["content_type": contentType, "content_id": contentId])
    }
}

// MARK: - 8. Настройки приложения

public extension DivoAnalyticsEvent {
    static var settingsOpened: DivoAnalyticsEvent { .init(name: "settings_opened") }
    static func settingsOptionTapped(option: String) -> DivoAnalyticsEvent {
        .init(name: "settings_option_tapped", parameters: ["option": option])
    }
    static func appLanguageChanged(languageCode: String) -> DivoAnalyticsEvent {
        .init(name: "app_language_changed", parameters: ["language_code": languageCode])
    }
    static func measurementSystemChanged(system: String) -> DivoAnalyticsEvent {
        .init(name: "measurement_system_changed", parameters: ["system": system])
    }
    static func userReported(targetUserId: Int64, reason: String) -> DivoAnalyticsEvent {
        .init(name: "user_reported", parameters: ["target_user_id": targetUserId, "reason": reason])
    }
    static func userBlocked(targetUserId: Int64) -> DivoAnalyticsEvent {
        .init(name: "user_blocked", parameters: ["target_user_id": targetUserId])
    }
    static func userUnblocked(targetUserId: Int64) -> DivoAnalyticsEvent {
        .init(name: "user_unblocked", parameters: ["target_user_id": targetUserId])
    }
}
