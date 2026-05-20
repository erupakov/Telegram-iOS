import Foundation

/// Описывает один экран-«вопрос с вариантами»: top-level / industry door / sub-role picker / experience quiz.
/// Все эти экраны Михаил вёрстает одним конструктором `OnboardingQuizViewController`.
public struct OnboardingQuizDescriptor {
    public struct Option {
        public let id: String
        public let titleKey: String
        public let subtitleKey: String?
        public let iconAssetName: String?
        public let rowType: OnboardingQuizOptionTypeRow?

        public init(id: String, titleKey: String, subtitleKey: String? = nil, iconAssetName: String? = nil, rowType: OnboardingQuizOptionTypeRow? = .big) {
            self.id = id
            self.titleKey = titleKey
            self.subtitleKey = subtitleKey
            self.iconAssetName = iconAssetName
            self.rowType = rowType
        }
    }

    /// Группа опций под общим заголовком. Для пикеров без секций — одна `Section` с `titleKey == nil`.
    /// Talent picker по дизайну имеет две секции — «TALENTS» и «CREATIVE» — заголовки берутся
    /// из `OnboardingRoleDefinition.pickerSectionKey`.
    public struct Section {
        public let titleKey: String?
        public let options: [Option]

        public init(titleKey: String?, options: [Option]) {
            self.titleKey = titleKey
            self.options = options
        }
    }

    public let step: OnboardingRegistrationStep
    public let titleKey: String
    public let subtitleKey: String?
    public let progressLabelKey: String?      // "Question 1 of 2" / nil
    public let sections: [Section]
    public let primaryButtonKey: String       // обычно "onboarding.button.continue"

    public init(
        step: OnboardingRegistrationStep,
        titleKey: String,
        subtitleKey: String? = nil,
        progressLabelKey: String? = nil,
        sections: [Section],
        primaryButtonKey: String
    ) {
        self.step = step
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.progressLabelKey = progressLabelKey
        self.sections = sections
        self.primaryButtonKey = primaryButtonKey
    }

    /// Плоский список опций по всем секциям, в порядке секций. Удобно для лукапа по `id`.
    public var allOptions: [Option] {
        return sections.flatMap { $0.options }
    }
}

/// Каталог всех quiz-экранов Phase 3. Сборка происходит на основе `OnboardingRoleRegistry` —
/// чтобы добавить роль в саб-пикер, достаточно указать ей `presentedIn` в registry.
public struct OnboardingQuizCatalog {

    private let registry: OnboardingRoleRegistry

    public init(registry: OnboardingRoleRegistry) {
        self.registry = registry
    }

    public func descriptor(for step: OnboardingRegistrationStep) -> OnboardingQuizDescriptor? {
        switch step {

        case .topLevelChoice:
            return OnboardingQuizDescriptor(
                step: step,
                titleKey: "onboarding.quiz.topLevel.title",
                subtitleKey: "onboarding.quiz.topLevel.subtitle",
                progressLabelKey: nil,
                sections: [
                    .init(titleKey: nil, options: [
                        .init(id: OnboardingTopLevelCategory.getHired.rawValue,
                              titleKey: "onboarding.quiz.topLevel.option.getHired.title",
                              subtitleKey: "onboarding.quiz.topLevel.option.getHired.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .big),
                        .init(id: OnboardingTopLevelCategory.lookingForTalent.rawValue,
                              titleKey: "onboarding.quiz.topLevel.option.lookingForTalent.title",
                              subtitleKey: "onboarding.quiz.topLevel.option.lookingForTalent.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .big),
                        .init(id: OnboardingTopLevelCategory.hereToFollow.rawValue,
                              titleKey: "onboarding.quiz.topLevel.option.hereToFollow.title",
                              subtitleKey: "onboarding.quiz.topLevel.option.hereToFollow.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .big),
                    ]),
                ],
                primaryButtonKey: "onboarding.button.continue"
                // На первом шаге back через state-машину возвращает nil → coordinator делает
                // cancelFromTopLevel() и закрывает онбординг. Отдельная кнопка close не нужна.
            )

        case .industryDoor:
            return OnboardingQuizDescriptor(
                step: step,
                titleKey: "onboarding.quiz.industryDoor.title",
                subtitleKey: "onboarding.quiz.industryDoor.subtitle",
                progressLabelKey: "onboarding.quiz.progress.1of2",
                sections: [
                    .init(titleKey: nil, options: [
                        .init(id: OnboardingIndustryDoor.representCompany.rawValue,
                              titleKey: "onboarding.quiz.industryDoor.option.representCompany.title",
                              subtitleKey: "onboarding.quiz.industryDoor.option.representCompany.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .medium),
                        .init(id: OnboardingIndustryDoor.industryProfessional.rawValue,
                              titleKey: "onboarding.quiz.industryDoor.option.industryProfessional.title",
                              subtitleKey: "onboarding.quiz.industryDoor.option.industryProfessional.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .medium),
                    ]),
                ],
                primaryButtonKey: "onboarding.button.continue"
            )

        case .talentSubRolePicker:
            return descriptorForSubRolePicker(
                step: step,
                titleKey: "onboarding.quiz.talentPicker.title",
                subtitleKey: "onboarding.quiz.talentPicker.subtitle",
                progressLabelKey: "onboarding.quiz.progress.1of2",
                picker: .talent,
                rowType: .small
            )

        case .industryProSubRolePicker:
            return descriptorForSubRolePicker(
                step: step,
                titleKey: "onboarding.quiz.industryProPicker.title",
                subtitleKey: "onboarding.quiz.industryProPicker.subtitle",
                progressLabelKey: "onboarding.quiz.progress.2of2",
                picker: .industryPro,
                rowType: .medium
            )

        case .companiesSubRolePicker:
            return descriptorForSubRolePicker(
                step: step,
                titleKey: "onboarding.quiz.companiesPicker.title",
                subtitleKey: "onboarding.quiz.companiesPicker.subtitle",
                progressLabelKey: "onboarding.quiz.progress.2of2",
                picker: .companies,
                rowType: .medium
            )

        case .talentExperienceQuiz:
            return OnboardingQuizDescriptor(
                step: step,
                titleKey: "onboarding.quiz.experience.title",
                subtitleKey: "onboarding.quiz.experience.subtitle",
                progressLabelKey: "onboarding.quiz.progress.2of2",
                sections: [
                    .init(titleKey: nil, options: [
                        .init(id: "yes",
                              titleKey: "onboarding.quiz.experience.option.yes.title",
                              subtitleKey: "onboarding.quiz.experience.option.yes.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .medium),
                        .init(id: "no",
                              titleKey: "onboarding.quiz.experience.option.no.title",
                              subtitleKey: "onboarding.quiz.experience.option.no.subtitle",
                              iconAssetName: "onboarding.quiz.topLevel.option.circle",
                              rowType: .medium),
                    ]),
                ],
                primaryButtonKey: "onboarding.button.continue"
            )

        case .roleResult, .formStep, .submitting, .completed:
            return nil
        }
    }

    /// Сборка дескриптора для саб-пикера. Роли группируются в секции по `pickerSectionKey`:
    /// первая встреченная секция идёт первой в выдаче. Это позволяет управлять секциями и порядком
    /// прямо из массива `OnboardingRoleRegistry.defaultRoles` — без изменений каталога/контроллера.
    private func descriptorForSubRolePicker(
        step: OnboardingRegistrationStep,
        titleKey: String,
        subtitleKey: String?,
        progressLabelKey: String,
        picker: OnboardingSubRolePicker,
        rowType: OnboardingQuizOptionTypeRow
    ) -> OnboardingQuizDescriptor {
        let roles = registry.roles(presentedIn: picker)

        // Группируем, сохраняя порядок первого появления секции в массиве registry.
        var sectionKeyOrder: [String?] = []
        var rolesByKey: [String?: [OnboardingRoleDefinition]] = [:]
        for role in roles {
            let key = role.pickerSectionKey
            if rolesByKey[key] == nil {
                sectionKeyOrder.append(key)
            }
            rolesByKey[key, default: []].append(role)
        }

        let sections: [OnboardingQuizDescriptor.Section] = sectionKeyOrder.map { key in
            let options = (rolesByKey[key] ?? []).map { def in
                OnboardingQuizDescriptor.Option(
                    id: def.id.rawValue,
                    titleKey: def.displayNameKey,
                    subtitleKey: def.pickerSubtitleKey,
                    iconAssetName: def.pickerIconAssetName,
                    rowType: rowType
                )
            }
            return OnboardingQuizDescriptor.Section(titleKey: key, options: options)
        }

        return OnboardingQuizDescriptor(
            step: step,
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            progressLabelKey: progressLabelKey,
            sections: sections,
            primaryButtonKey: "onboarding.button.continue"
        )
    }
}
