import Foundation

/// Описание result-экрана «YOU'RE A …» (Phase 3.3). Это один из 9 финальных экранов фазы
/// определения роли. Михаил вёрстает их одним конструктором `OnboardingRoleResultViewController`.
public struct OnboardingResultPresentation {
    public let id: OnboardingRoleResultID
    public let titleKey: String                // "YOU'RE A PROFESSIONAL MODEL"
    public let descriptionKey: String          // абзац под заголовком
    /// Имя ассета фонового фото из DivoCore xcassets (`DivoImage.<name>`).
    /// Если ассет ещё не подключен — Михаил при вёрстке временно ставит placeholder.
    public let imageAssetName: String
    public let primaryButtonKey: String        // "Sounds right — let's go"
    public let secondaryButtonKey: String      // "Choose a different role"

    public init(
        id: OnboardingRoleResultID,
        titleKey: String,
        descriptionKey: String,
        imageAssetName: String,
        primaryButtonKey: String = "onboarding.result.button.primary",
        secondaryButtonKey: String = "onboarding.result.button.secondary"
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.imageAssetName = imageAssetName
        self.primaryButtonKey = primaryButtonKey
        self.secondaryButtonKey = secondaryButtonKey
    }
}

/// Каталог всех 9 result-экранов. Регистри ролей знает, какой result-экран им положен;
/// здесь — конкретные тексты и ассеты для каждого экрана.
public struct OnboardingResultCatalog {

    private let byId: [OnboardingRoleResultID: OnboardingResultPresentation]

    public init(presentations: [OnboardingResultPresentation] = OnboardingResultCatalog.defaults) {
        var byId: [OnboardingRoleResultID: OnboardingResultPresentation] = [:]
        for p in presentations { byId[p.id] = p }
        self.byId = byId
    }

    public func presentation(for id: OnboardingRoleResultID) -> OnboardingResultPresentation? {
        return byId[id]
    }

    public func presentation(forRole roleId: OnboardingRoleID, registry: OnboardingRoleRegistry) -> OnboardingResultPresentation? {
        guard let def = registry.definition(for: roleId) else { return nil }
        return presentation(for: def.resultId)
    }

    // MARK: - Defaults

    /// 9 result-экранов по фреймам 3.3.* дизайна.
    /// Имена ассетов — placeholder'ы; Михаил привязывает финальные при подключении DivoCore xcassets.
    public static let defaults: [OnboardingResultPresentation] = [
        OnboardingResultPresentation(
            id: .modelVariant,
            titleKey: "onboarding.result.modelVariant.title",
            descriptionKey: "onboarding.result.modelVariant.description",
            imageAssetName: "onboarding.result.image.model"
        ),
        OnboardingResultPresentation(
            id: .newTalentVariant,
            titleKey: "onboarding.result.newTalentVariant.title",
            descriptionKey: "onboarding.result.newTalentVariant.description",
            imageAssetName: "onboarding.result.image.talent"
        ),
        OnboardingResultPresentation(
            id: .actor,
            titleKey: "onboarding.result.actor.title",
            descriptionKey: "onboarding.result.actor.description",
            imageAssetName: "onboarding.result.image.actor"
        ),
        OnboardingResultPresentation(
            id: .dancer,
            titleKey: "onboarding.result.dancer.title",
            descriptionKey: "onboarding.result.dancer.description",
            imageAssetName: "onboarding.result.image.dancer"
        ),
        OnboardingResultPresentation(
            id: .singerPerformer,
            titleKey: "onboarding.result.singerPerformer.title",
            descriptionKey: "onboarding.result.singerPerformer.description",
            imageAssetName: "onboarding.result.image.performer"
        ),
        OnboardingResultPresentation(
            id: .creativeProfessional,
            titleKey: "onboarding.result.creativeProfessional.title",
            descriptionKey: "onboarding.result.creativeProfessional.description",
            imageAssetName: "onboarding.result.image.creative.professional"
        ),
        OnboardingResultPresentation(
            id: .companiesBrands,
            titleKey: "onboarding.result.companiesBrands.title",
            descriptionKey: "onboarding.result.companiesBrands.description",
            imageAssetName: "onboarding.result.image.find.talent"
        ),
        OnboardingResultPresentation(
            id: .industryProfessional,
            titleKey: "onboarding.result.industryProfessional.title",
            descriptionKey: "onboarding.result.industryProfessional.description",
            imageAssetName: "onboarding.result.image.talent.industry.professional"
        ),
        OnboardingResultPresentation(
            id: .fan,
            titleKey: "onboarding.result.fan.title",
            descriptionKey: "onboarding.result.fan.description",
            imageAssetName: "onboarding.result.image.fashion.fan"
        ),
    ]
}
