import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI
import Postbox
import ChatScheduleTimeController
import DivoUIKit

enum EventParameter: String, CaseIterable {
    case gender = "gender"
    case age = "age"
    case height = "height"
    case weight = "weight"
    case breast = "breast"
    case waist = "waist"
    case hips = "hips"
    case shoeSize = "shoeSize"
    case hairLength = "hairLength"
    case hairColor = "hairColor"
    case eyeColor = "eyeColor"
    case skinColor = "skinColor"

    var localizedTitle: String {
        switch self {
        case .gender: return DivoStrings.paramGender
        case .age: return DivoStrings.paramAge
        case .height: return DivoStrings.paramHeight
        case .weight: return DivoStrings.paramWeight
        case .breast: return DivoStrings.paramBreast
        case .waist: return DivoStrings.paramWaist
        case .hips: return DivoStrings.paramHips
        case .shoeSize: return DivoStrings.paramShoeSize
        case .hairLength: return DivoStrings.paramHairLength
        case .hairColor: return DivoStrings.paramHairColor
        case .eyeColor: return DivoStrings.paramEyeColor
        case .skinColor: return DivoStrings.paramSkinColor
        }
    }
}

private struct AppearanceEditItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

/// Основные режимы экрана
public enum CreateEventMode: Equatable {
    case create                  // создание нового события
    case edit(eventId: Int)      // редактирование существующего

    public var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    public var eventId: Int? {
        if case .edit(let id) = self { return id }
        return nil
    }
}

/// Валидация шага (для enable/disable кнопки)
enum StepValidationStatus {
    case valid
    case invalid(reason: String?)
}

/// Стадия загрузки всего экрана (= стадия профильного запроса).
enum ScreenLoadPhase: Equatable {
    case loading    // профильные шиммеры (header/info/social/segment) видны, scroll/swipe залочены
    case ready      // профиль загружен, шиммеры сняты, скролл/свайп активны
    case failed     // ошибка загрузки профиля (заглушка + снекбар)
}

// MARK: - CreateEventNode
final class CreateEventNode: ASDisplayNode {
    
    // MARK: - State Properties

    private var mode: CreateEventMode = .create {
        didSet {
            if oldValue != mode {
                self.containerLayoutUpdated(self.currentLayoutData?.0, navigationBarHeight: self.currentLayoutData?.1 ?? 0.0, actualNavigationBarHeight: self.currentLayoutData?.2 ?? 0.0)
                // В edit-режиме внизу появляется второй кнопочный ряд (Discard),
                // поэтому bottom-инсет шага 3 пересчитываем.
                self.refreshStepBottomInsets()
            }
        }
    }
    
    private var loadPhase: ScreenLoadPhase = .loading {
        didSet {
            if oldValue != loadPhase {
                applyLoadPhase()
            }
        }
    }
    
    private var hasLoadedInitialData: Bool = false
    
    // MARK: - State UI Elements

    private let errorPlaceholderView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        // ProfileTabErrorView по умолчанию использует cardBackground (под профиль),
        // а в CreateEvent основной фон ноды — screenBackground (серый),
        // поэтому переопределяем, чтобы error не выбивался из общего тона экрана.
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Core & Context
    private(set) var eventDateInt: Int32 = 0
    private(set) var eventTimeInt: Int32 = 0
    
    private(set) var deadlineDateInt: Int32 = 0
    private(set) var deadlineTimeInt: Int32 = 0
    
    // MARK: - Step Management
    private var currentStep: Int = 1
    
    // MARK: - Navigation Bar (Header)
    private let navigationBar = DivoNavigationBar()

    // MARK: - Layout Views (Paging)
    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.isScrollEnabled = false
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let pagerContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let step1ScrollView = UIScrollView()
    private let step2ScrollView = UIScrollView()
    private let step3ScrollView = UIScrollView()
    
    private let step1StackView = UIStackView()
    private let step2StackView = UIStackView()
    private let step3StackView = UIStackView()

    // MARK: - Global Action Button
    
    let stackButtons: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = DivoDesignTokens.Spacing.m
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let applyButton = DivoButton()
    private var applyButtonBottomConstraint: NSLayoutConstraint!
    
    private let discardChangesButton = DivoButton()
    private var discardChangesButtonBottomConstraint: NSLayoutConstraint!
    
    private let bottomFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?
    private var keyboardScroll1Handler: DivoKeyboardHandler?
    private var keyboardScroll2Handler: DivoKeyboardHandler?

    // MARK: - Step 1 UI
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderColor = DivoColorPalette.accent.cgColor
        iv.layer.borderWidth = 1.0
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let avatarImageSpinnerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.backgroundColor = .clear
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let chancePhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = DivoImage.addPhotoIcon
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.accent
        button.layer.cornerRadius = DivoDesignTokens.Radius.l
        button.layer.borderColor = DivoColorPalette.accent.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        button.isHidden = true
        return button
    }()
    
    private let chanceCenterPhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = DivoImage.addMediaProfile
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.accent
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let avatarSpinner = DivoSegmentedSpinner()
    
    private var eventTypeDropdown = FilterRowView(title: DivoStrings.eventType + " *")
    private var eventTypeItems: [AgencyItem] = []
    private var eventTypeId: String?
    private var eventTypeTitle: String?

    private let nameEventTextField: DivoTextField
    private let aboutEventTextField: DivoTextView
    
    private let eventDate: DateSelectionControl
    private let eventTime: DateSelectionControl

    private let cityRow = FilterRowView(title: DivoStrings.debugCity + " *")
    private var rawCityId: String?
    var onCityChosen: ((String) -> Void)?

    // MARK: - Step 2 UI
    private let whoCanApplyDropdown = FilterRowView(title: DivoStrings.whoCanApply + " *")
    private var whoCanApplyIds: [String]?
    private var whoCanApplyTitles: [String]?
    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent)
    ]

    /// Сопоставляет выбранные ID с их локализованными названиями (Titles) для отображения в интерфейсе.
    /// Если список пуст (выбрано «Все»), возвращает название первого мастер-пункта.
    private func resolvedSelectionTitles(_ ids: [String]?, options: [FilterOptionItem]) -> [String]? {
        guard let ids = ids else { return nil }
        if ids.isEmpty {
            // Если массив пуст — значит выбран мастер-пункт «Все».
            // Возвращаем массив, содержащий название этого первого пункта (например, «Все роли»)
            return options.first.map { [$0.title] } ?? []
        }
        // Мапим выбранные ID в их локализованные названия из справочника
        return ids.compactMap { id in
            options.first(where: { $0.id == id })?.title
        }
    }

    /// Универсальный разворот выбора multi-select filter'а под отправку на бэк.
    /// Семантика FilterOptionsController: пустой selectedOptionIds = «Все»
    /// (мастер-пункт подсвечивается). На бэке мастер-id «all» не существует —
    /// разворачиваем пустой массив в полный список конкретных опций (всё, кроме first).
    /// Сохраняем nil как nil («пользователь не открывал picker»).
    private func resolvedSelection(_ ids: [String]?, options: [FilterOptionItem]) -> [String]? {
        guard let ids = ids else { return nil }
        if ids.isEmpty {
            return options.dropFirst().map { $0.id }
        }
        return ids
    }

    /// Восстанавливает массив title'ов из массива id с учётом семантики
    /// FilterOptionsController: пустой массив id = «Все» → возвращаем title
    /// мастер-пункта (первый элемент options).
    private func restoreSelectionTitles(ids: [String]?, options: [FilterOptionItem]) -> [String]? {
        guard let ids = ids else { return nil }
        if ids.isEmpty {
            return [options.first?.title].compactMap { $0 }
        }
        return ids.compactMap { id in
            options.first(where: { $0.id == id })?.title
        }
    }

    /// Универсальный helper для открытия multi-select picker'а.
    /// Загрузка: если currentIds == полный список конкретных id (например, в edit-mode
    /// сервер вернул все роли) — передаём пустой selectedOptionIds, чтобы
    /// FilterOptionsController подсветил мастер-пункт «Все».
    /// Сохранение: пустой выбор → state = [] (= «Все») и title мастер-пункта,
    /// иначе — массив id/title выбранных.
    private func presentMultiSelectFilter(
        title: String,
        options: [FilterOptionItem],
        currentIds: [String]?,
        bind: @escaping ([String], [String]) -> Void
    ) {
        self.view.endEditing(true)
        let concreteIds = Set(options.dropFirst().map { $0.id })
        let isAllSelected = currentIds.map { !$0.isEmpty && Set($0) == concreteIds } ?? false
        let selectedIds: [String] = isAllSelected ? [] : (currentIds ?? [])

        let vc = FilterOptionsController(
            title: title,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            // Если пользователь вручную выбрал все конкретные пункты — нормализуем
            // в state «выбрано Всё» (empty + title мастер-пункта), чтобы dropdown
            // в форме показал «Все», а не список из всех ролей.
            let selectedIds = Set(selectedItems.map { $0.id })
            let isAllExplicitlySelected = !selectedItems.isEmpty && selectedIds == concreteIds
            let ids: [String]
            let titles: [String]
            if selectedItems.isEmpty || isAllExplicitlySelected {
                ids = []
                titles = [options.first?.title].compactMap { $0 }
            } else {
                ids = selectedItems.map { $0.id }
                titles = selectedItems.map { $0.title }
            }
            bind(ids, titles)
            self.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    private let maxParticipantsDropdown = FilterRowView(title: DivoStrings.maxParticipants + " *")
    private var maxParticipants: Int?
    
    private let requirementsTextField: DivoTextView
    
    private let parametersForApplying: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.font = Font.regular(14)
        label.text = DivoStrings.parametersForApplying
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
        
    }()
    private var addParamsWidthConstraint: NSLayoutConstraint?
    
    private let ndaSwitch: UISwitch = UISwitch()
    
    private let appearanceBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let dynamicParametersStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    private var appearanceEditItems: [AppearanceEditItem] = []

    // MARK: - Step 3 UI
    private let deadlineDate: DateSelectionControl
    private let deadlineTime: DateSelectionControl
    
    private let paidEventSwitch: UISwitch = UISwitch()
    
    private let rateFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 23
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rateTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(16)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accent
        field.placeholder = "100"
        field.clearButtonMode = .never
        field.autocorrectionType = .no
        field.keyboardType = .numberPad
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let rateIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.paid
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var rateTime = FilterRowView()
    private var rateTimeId: String?
    private var rateTimeTitle: String = "per hour"
    var rateTimeOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "1", title: "per hour"),
        FilterOptionItem(id: "2", title: "per day"),
        FilterOptionItem(id: "3", title: "per month"),
        FilterOptionItem(id: "4", title: "per project")
    ]
    
    private let publicEventSwitch: UISwitch = UISwitch()

    var galleryItems: [EventGalleryItem] = []
    
    private let galleryLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.font = Font.regular(14)
        label.text = DivoStrings.galleryCreateEvent + " *"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let galleryAddButton: DivoButton = {
        let button = DivoButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var galleryHeightConstraint: NSLayoutConstraint!
    
    private let galleryCollectionContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.isScrollEnabled = false
        collection.delaysContentTouches = false
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(EventGalleryCell.self, forCellWithReuseIdentifier: "EventGalleryCell")
        return collection
    }()

    // MARK: - Parameters Data
    private var selectedParameters: Set<EventParameter> = []
    private var deleteButtons: [EventParameter: ASButtonNode] = [:]
    
    private var genderDropdown = FilterRowView(title: DivoStrings.paramGender)
    private var genderDropdownIds: [String]?
    private var genderDropdownTitles: [String]?
    var genderOptions: [FilterOptionItem] = []
    
    private var selectedAge: ClosedRange<Int>?
    private var selectedHeight: ClosedRange<Double>?
    private var selectedWeight: ClosedRange<Double>?
    private var selectedWaist: ClosedRange<Double>?
    private var selectedHips: ClosedRange<Double>?
    private var selectedShoeSize: ClosedRange<Double>?
    
    private var hairLengthDropdown = FilterRowView(title: DivoStrings.paramHairLength)
    private var hairLengthDropdownIds: [String]?
    private var hairLengthDropdownTitles: [String]?
    var hairLengthOptions: [FilterOptionItem] = []
    
    private var hairColorDropdown = FilterRowView(title: DivoStrings.paramHairColor)
    private var hairColorDropdownIds: [String]?
    private var hairColorDropdownTitles: [String]?
    var hairColorOptions: [FilterOptionItem] = []
    
    private var eyeColorDropdown = FilterRowView(title: DivoStrings.paramEyeColor)
    private var eyeColorDropdownIds: [String]?
    private var eyeColorDropdownTitles: [String]?
    var eyeColorOptions: [FilterOptionItem] = []
    
    private var skinColorDropdown = FilterRowView(title: DivoStrings.paramSkinColor)
    private var skinColorDropdownIds: [String]?
    private var skinColorDropdownTitles: [String]?
    var skinColorOptions: [FilterOptionItem] = []
    
    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?

    // MARK: - Callbacks
    var onCreateEventTapped: (() -> Void)?
    private let addPhoto: () -> Void
    var scheduleTimeController: ((TimeControllerMode) -> Void)?
    var scheduleDeadlineTimeController: ((TimeControllerMode) -> Void)?
    var onAddGalleryPhotoTapped: (() -> Void)?
    var loadEventTypesList: ((Int, Int) -> Void)?
    var onBackTapped: (() -> Void)?
    var onAvatarTap: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?
    var onGalleryItemTapped: ((String) -> Void)?
    var retryLoadEventData: (() -> Void)?

    private let countryRow = FilterRowView(title: DivoStrings.debugCountry + " *")
    lazy var countryOptions: [FilterOptionItem] = {
        var options: [FilterOptionItem] = []
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()
    
    private var countryId: String?
    private var countryTitle: String?

    private var cityId: String?
    private var cityTitle: String?
    private var countryCode: String?

    private var selectedEventTypeId: Int?
    private var eventTypeOffset: Int = 0
    private var eventTypeLimit: Int = 20
    private var isLoadingEventTypes: Bool = false
    private var hasMoreEventTypes: Bool = true
    
    var avatarFileUuid: String? = nil
    var isAvatarUploading: Bool = false
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.layer.borderColor = DivoColorPalette.cardBackground.cgColor
            avatarImageView.image = currentPhoto
            avatarImageView.applyAvatarTopCropIfNeeded(image: currentPhoto)
            chanceCenterPhotoView.isHidden = currentPhoto != nil
            chancePhotoView.isHidden = currentPhoto == nil
            validateCurrentStep()
            if initialSnapshot != nil && oldValue != nil {
                avatarChanged = true
            }
        }
    }

    private var currentLayoutData: (ContainerViewLayout?, CGFloat, CGFloat)?

    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let loadingSpinner = DivoSegmentedSpinner()

    private let rateTimeRowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private struct EventSnapshot: Equatable {
        let type: Int?
        let typeTitle: String?
        let name: String?
        let description: String?
        let date: String?
        let role: [String]?
        let maxAttendees: Int?
        let requirements: String?
        let genderId: [String]?
        let genderTitle: [String]?
        let age: ClosedRange<Int>?
        let height: ClosedRange<Double>?
        let weight: ClosedRange<Double>?
        let waist: ClosedRange<Double>?
        let hips: ClosedRange<Double>?
        let shoeSize: ClosedRange<Double>?
        let hairLengthId: [Int]?
        let hairLengthTitle: [String]?
        let hairColorId: [Int]?
        let hairColorTitle: [String]?
        let eyeColorId: [Int]?
        let eyeColorTitle: [String]?
        let skinColorId: [Int]?
        let skinColorTitle: [String]?
        let nda: Bool?
        let deadlineDate: String?
        let cost: String?
        let paymentType: Int?
        let paymentFrequency: Int?
        let paymentFrequencyTitle: String?
        let isPublic: Bool?
        let cityId: Int?
    }

    private var initialSnapshot: EventSnapshot?
    private var avatarChanged = false
    private var hasChanges = false
    private var changeGallery = false
    

    // MARK: - Init

    init(addPhoto: @escaping () -> Void) {
        self.addPhoto = addPhoto

        self.nameEventTextField = DivoTextField(title: "", prefix: "")
        self.nameEventTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.eventName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        self.nameEventTextField.isUserInteractionEnabled = true

        self.aboutEventTextField = DivoTextView(title: DivoStrings.descriptionCreateEvent, initialText: "", placeholder: DivoStrings.placeholderDescriptionCreateEvent)
        self.aboutEventTextField.textView.text = DivoStrings.placeholderDescriptionCreateEvent
        self.aboutEventTextField.textView.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
                
        eventDate = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: false)

        eventTime = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: true)
 
        self.requirementsTextField = DivoTextView(title: DivoStrings.requirementsCreateEvent + " *", initialText: "", placeholder: DivoStrings.placeholderRequirementsCreateEvent)
        self.requirementsTextField.textView.text = DivoStrings.placeholderRequirementsCreateEvent
        self.requirementsTextField.textView.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)

        deadlineDate = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: false)

        deadlineTime = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: true)
        
        super.init()
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.createEvent.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: .onlyText(DivoStrings.stepCreateEvent(currentStep)),
            onBackTapped: { [weak self] in self?.backButtonTapped() }
        )

        self.nameEventTextField.textField.delegate = self
        self.rateTextField.delegate = self
    }

    override func didLoad() {
        super.didLoad()

        self.backgroundColor = DivoColorPalette.screenBackground

        applyButton.addTarget(self, action: #selector(mainActionButtonTapped), for: .touchUpInside)

        discardChangesButton.isHidden = false
        discardChangesButton.addTarget(self, action: #selector(discardActionButtonTapped), for: .touchUpInside)
        
        chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        chancePhotoView.addDivoPressState(.pill)
        chanceCenterPhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        chanceCenterPhotoView.addDivoPressState(.pill)
        
        eventDate.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.date)
        }
                
        eventTime.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.time)
        }
        
        deadlineDate.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleDeadlineTimeController?(.date)
        }
                
        deadlineTime.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleDeadlineTimeController?(.time)
        }

        galleryAddButton.makeDivoButton(title: DivoStrings.addPhotoEvent, leadingIcon: DivoImage.addPhotoIcon.withRenderingMode(.alwaysTemplate), buttonFont: Font.helveticaNeue(16), radius: 20)
        galleryAddButton.addTarget(self, action: #selector(dashedUploadTapped), for: .touchUpInside)
        
        galleryCollectionView.delegate = self
        galleryCollectionView.dataSource = self

        setupAppearanceEditItems()
        setupLayout()
        updateHeaderAndButton()
        
        self.nameEventTextField.textField.returnKeyType = .next
        self.nameEventTextField.textField.delegate = self
        
        horizontalPager.keyboardDismissMode = .interactive

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        self.view.addGestureRecognizer(dismissTap)

        self.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        nameEventTextField.textField.addTarget(self, action: #selector(validateCurrentStep), for: .editingChanged)
        rateTextField.addTarget(self, action: #selector(switchChange), for: .editingChanged)
        paidEventSwitch.addTarget(self, action: #selector(switchChange), for: .valueChanged)
        publicEventSwitch.addTarget(self, action: #selector(switchChange), for: .valueChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(validateCurrentStep), name: UITextView.textDidChangeNotification, object: aboutEventTextField.textView)
        NotificationCenter.default.addObserver(self, selector: #selector(validateCurrentStep), name: UITextView.textDidChangeNotification, object: requirementsTextField.textView)

        updateDropdownsUI()
        validateCurrentStep()
        
        keyboardScroll1Handler = DivoKeyboardHandler(
            scrollView: step1ScrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 80,
            scrollToActiveField: { [weak self] in
                guard let self, self.aboutEventTextField.textView.isFirstResponder else { return }
                let frame = self.aboutEventTextField.convert(self.aboutEventTextField.bounds, to: self.step1ScrollView)
                self.step1ScrollView.scrollRectToVisible(frame, animated: false)
            }
        )
        keyboardScroll1Handler?.subscribe()
        
        keyboardScroll2Handler = DivoKeyboardHandler(
            scrollView: step2ScrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 80,
            scrollToActiveField: { [weak self] in
                guard let self, self.requirementsTextField.textView.isFirstResponder else { return }
                let frame = self.requirementsTextField.convert(self.requirementsTextField.bounds, to: self.step2ScrollView)
                self.step2ScrollView.scrollRectToVisible(frame, animated: false)
            }
        )
        keyboardScroll2Handler?.subscribe()
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }

    // MARK: - Auto Layout Configurations
    
    private func setupLayout() {
        // 1. Header Navigation
        view.addSubview(navigationBar)
        
        // 2. Horizontal Pager
        view.addSubview(horizontalPager)
        horizontalPager.addSubview(pagerContentView)
        
        // 3. Global Button
        view.addSubview(bottomFadeOverlay)
        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns
        
        stackButtons.addArrangedSubview(applyButton)
        stackButtons.addArrangedSubview(discardChangesButton)
        view.addSubview(stackButtons)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButtonBottomConstraint = stackButtons.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        discardChangesButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            horizontalPager.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            horizontalPager.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            horizontalPager.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            horizontalPager.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            pagerContentView.topAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.topAnchor),
            pagerContentView.bottomAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.bottomAnchor),
            pagerContentView.leadingAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.leadingAnchor),
            pagerContentView.trailingAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.trailingAnchor),
            pagerContentView.heightAnchor.constraint(equalTo: horizontalPager.frameLayoutGuide.heightAnchor),
            
            stackButtons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stackButtons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.heightAnchor.constraint(equalToConstant: 56),
            discardChangesButton.heightAnchor.constraint(equalToConstant: 56),
            applyButtonBottomConstraint,
            
            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        setupSteps()

        view.addSubview(loadingOverlay)
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingSpinner)
        view.addSubview(errorPlaceholderView)
        
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
            loadingSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            loadingSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            errorPlaceholderView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            errorPlaceholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorPlaceholderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorPlaceholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func applyLoadPhase() {
        switch loadPhase {
        case .loading:
            // Показываем лоадер, скрываем форму и ошибку
            loadingOverlay.isHidden = false
            loadingSpinner.startAnimating()
            errorPlaceholderView.isHidden = true
            
            // Блокируем взаимодействие с формой
            horizontalPager.isUserInteractionEnabled = false
            applyButton.isEnabled = false
            
        case .ready:
            // Скрываем лоадер, показываем форму
            loadingOverlay.isHidden = true
            loadingSpinner.stopAnimating()
            errorPlaceholderView.isHidden = true
            
            // Разблокируем форму
            horizontalPager.isUserInteractionEnabled = true
            validateCurrentStep()
            
        case .failed:
            // Показываем ошибку с кнопкой retry
            loadingOverlay.isHidden = true
            loadingSpinner.stopAnimating()
            
            errorPlaceholderView.isHidden = false
            errorPlaceholderView.configure(
                tab: .events,
                networkError: true
            ) { [weak self] in
                self?.loadPhase = .loading
                self?.retryLoadEventData?()
            }
            
            // Блокируем форму
            horizontalPager.isUserInteractionEnabled = false
            applyButton.isEnabled = false
        }
    }
    
    /// Высота нижнего content-инсета для каждого шага.
    /// Шаг 3 обязан полностью очищать кнопочный стек (apply [+ discard в edit] + margin от низа + padding),
    /// иначе последние строки контента уходят под кнопки и сам жест скролла не зацепляется.
    private func bottomInsetForStep(at index: Int) -> CGFloat {
        guard index == 2 else { return 80 }
        let buttonHeight: CGFloat = 56
        let buttonsBottomMargin: CGFloat = 40
        let buttonsExtraPadding: CGFloat = 32
        let stackHeight: CGFloat = self.mode.isEdit
            ? (buttonHeight + DivoDesignTokens.Spacing.m + buttonHeight)
            : buttonHeight
        return stackHeight + buttonsBottomMargin + buttonsExtraPadding
    }

    /// Обновляет bottom-инсет step-scroll'ов в соответствии с текущим mode.
    /// Top-инсет управляется отдельно через containerLayoutUpdated.
    private func refreshStepBottomInsets() {
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        for (index, scroll) in scrolls.enumerated() {
            var insets = scroll.contentInset
            insets.bottom = bottomInsetForStep(at: index)
            scroll.contentInset = insets
            scroll.scrollIndicatorInsets = insets
        }
    }

    private func setupSteps() {
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        let stacks = [step1StackView, step2StackView, step3StackView]
        
        for (index, scrollView) in scrolls.enumerated() {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.keyboardDismissMode = .interactive
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInsetForStep(at: index), right: 0)
            
            let stack = stacks[index]
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .vertical
            stack.spacing = DivoDesignTokens.Spacing.m
            stack.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
            stack.isLayoutMarginsRelativeArrangement = true
            
            pagerContentView.addSubview(scrollView)
            scrollView.addSubview(stack)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: pagerContentView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: pagerContentView.bottomAnchor),
                scrollView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
                
                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            ])
            
            if index == 0 {
                scrollView.leadingAnchor.constraint(equalTo: pagerContentView.leadingAnchor).isActive = true
            } else {
                scrollView.leadingAnchor.constraint(equalTo: scrolls[index - 1].trailingAnchor).isActive = true
            }
            if index == scrolls.count - 1 {
                scrollView.trailingAnchor.constraint(equalTo: pagerContentView.trailingAnchor).isActive = true
            }
        }
        
        buildStep1()
        buildStep2()
        buildStep3()
    }
    
    private func buildStep1() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarImageSpinnerView)
        avatarContainer.addSubview(chancePhotoView)
        avatarContainer.addSubview(chanceCenterPhotoView)
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarSpinner)
        avatarSpinner.isHidden = true

        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            avatarImageSpinnerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageSpinnerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageSpinnerView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageSpinnerView.heightAnchor.constraint(equalToConstant: 100),

            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            chancePhotoView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            chanceCenterPhotoView.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            chanceCenterPhotoView.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            chanceCenterPhotoView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            chanceCenterPhotoView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
        ])
        
        step1StackView.addArrangedSubview(avatarContainer)
        step1StackView.addArrangedSubview(eventTypeDropdown)
        eventTypeDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eventTypeTapped)))

        eventTypeDropdown.leadingAnchor.constraint(equalTo: step1StackView.leadingAnchor, constant: DivoDesignTokens.Spacing.m).isActive = true
        eventTypeDropdown.trailingAnchor.constraint(equalTo: step1StackView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m).isActive = true

        step1StackView.addArrangedSubview(nameEventTextField.view)
        nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        step1StackView.addArrangedSubview(aboutEventTextField)
        aboutEventTextField.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let dateTimeRow = UIStackView()
        dateTimeRow.axis = .horizontal
        dateTimeRow.spacing = 12
        dateTimeRow.distribution = .fillEqually
        
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.eventDate + " *", inputView: eventDate))
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.eventTime + " *", inputView: eventTime))
        step1StackView.addArrangedSubview(dateTimeRow)
        dateTimeRow.heightAnchor.constraint(equalToConstant: 68).isActive = true

        step1StackView.addArrangedSubview(countryRow)
        countryRow.heightAnchor.constraint(equalToConstant: 48).isActive = true
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))
        
        step1StackView.addArrangedSubview(cityRow)
        cityRow.heightAnchor.constraint(equalToConstant: 48).isActive = true
        cityRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cityTapped)))
    }
    
    private func buildStep2() {

        step2StackView.addArrangedSubview(whoCanApplyDropdown)
        whoCanApplyDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
                
        whoCanApplyDropdown.leadingAnchor.constraint(equalTo: step2StackView.leadingAnchor, constant: DivoDesignTokens.Spacing.m).isActive = true
        whoCanApplyDropdown.trailingAnchor.constraint(equalTo: step2StackView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m).isActive = true

        step2StackView.addArrangedSubview(maxParticipantsDropdown)
        maxParticipantsDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maxParticipantsTapped)))
        
        step2StackView.addArrangedSubview(requirementsTextField)
        requirementsTextField.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        step2StackView.addArrangedSubview(parametersForApplying)
        step2StackView.addArrangedSubview(genderDropdown)
        genderDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderDropdownTapped)))
                
        step2StackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(dynamicParametersStack)
        
        NSLayoutConstraint.activate([
            dynamicParametersStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            dynamicParametersStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            dynamicParametersStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            dynamicParametersStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor)
        ])
        
        reloadAppearanceOptions()
        
        step2StackView.addArrangedSubview(hairLengthDropdown)
        hairLengthDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairLengthDropdownTapped)))
        step2StackView.addArrangedSubview(hairColorDropdown)
        hairColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairColorDropdownTapped)))
        step2StackView.addArrangedSubview(eyeColorDropdown)
        eyeColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eyeColorDropdownTapped)))
        step2StackView.addArrangedSubview(skinColorDropdown)
        skinColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skinColorDropdownTapped)))
        
        step2StackView.addArrangedSubview(makeSwitchRow(title: DivoStrings.ndaRequiredCreateEvent, uiSwitch: ndaSwitch))
    }
    
    private func buildStep3() {
        
        let dateTimeRowContainer = UIView()
        dateTimeRowContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let dateTimeRow = UIStackView()
        dateTimeRow.translatesAutoresizingMaskIntoConstraints = false
        dateTimeRow.axis = .horizontal
        dateTimeRow.spacing = 12
        dateTimeRow.distribution = .fillEqually
        
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.deadlineDate, inputView: deadlineDate))
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.deadlineTime, inputView: deadlineTime))
        
        dateTimeRowContainer.addSubview(dateTimeRow)
        step3StackView.addArrangedSubview(dateTimeRowContainer)
        NSLayoutConstraint.activate([
            dateTimeRow.trailingAnchor.constraint(equalTo: dateTimeRowContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            dateTimeRow.leadingAnchor.constraint(equalTo: dateTimeRowContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            dateTimeRow.bottomAnchor.constraint(equalTo: dateTimeRowContainer.bottomAnchor),
            dateTimeRow.topAnchor.constraint(equalTo: dateTimeRowContainer.topAnchor),
            dateTimeRow.heightAnchor.constraint(equalToConstant: 68),
        ])
        

        let paidEventSwitchContainer = UIView()
        paidEventSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        let paidEventSwitchUI = makeSwitchRow(title: DivoStrings.paidEvent, uiSwitch: paidEventSwitch)
        paidEventSwitchUI.translatesAutoresizingMaskIntoConstraints = false
        paidEventSwitchContainer.addSubview(paidEventSwitchUI)
        step3StackView.addArrangedSubview(paidEventSwitchContainer)
        NSLayoutConstraint.activate([
            paidEventSwitchUI.trailingAnchor.constraint(equalTo: paidEventSwitchContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            paidEventSwitchUI.leadingAnchor.constraint(equalTo: paidEventSwitchContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            paidEventSwitchUI.bottomAnchor.constraint(equalTo: paidEventSwitchContainer.bottomAnchor),
            paidEventSwitchUI.topAnchor.constraint(equalTo: paidEventSwitchContainer.topAnchor),
        ])

        let rateTimeRow = UIStackView()
        rateTimeRow.axis = .horizontal
        rateTimeRow.spacing = 12
        rateTimeRow.distribution = .fillEqually
        
        rateFieldContainer.addSubview(rateTextField)
        rateFieldContainer.addSubview(rateIcon)
        
        NSLayoutConstraint.activate([
            rateFieldContainer.heightAnchor.constraint(equalToConstant: 46),
            
            rateTextField.leadingAnchor.constraint(equalTo: rateFieldContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            rateTextField.topAnchor.constraint(equalTo: rateFieldContainer.topAnchor),
            rateTextField.bottomAnchor.constraint(equalTo: rateFieldContainer.bottomAnchor),
            
            rateIcon.leadingAnchor.constraint(equalTo: rateTextField.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            rateIcon.trailingAnchor.constraint(equalTo: rateFieldContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rateIcon.centerYAnchor.constraint(equalTo: rateTextField.centerYAnchor),
            rateIcon.widthAnchor.constraint(equalToConstant: 20),
            rateIcon.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        rateTime.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rateTimeTapped)))
        
        rateTimeRow.addArrangedSubview(rateFieldContainer)
        rateTimeRow.addArrangedSubview(rateTime)
        rateTimeRow.heightAnchor.constraint(equalToConstant: 46).isActive = true
        
        let rateTimeRowhUI = makeInputStack(title: DivoStrings.rate, inputView: rateTimeRow)
        rateTimeRowhUI.translatesAutoresizingMaskIntoConstraints = false
        rateTimeRowContainer.addSubview(rateTimeRowhUI)
        step3StackView.addArrangedSubview(rateTimeRowContainer)
        NSLayoutConstraint.activate([
            rateTimeRowhUI.trailingAnchor.constraint(equalTo: rateTimeRowContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rateTimeRowhUI.leadingAnchor.constraint(equalTo: rateTimeRowContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            rateTimeRowhUI.bottomAnchor.constraint(equalTo: rateTimeRowContainer.bottomAnchor),
            rateTimeRowhUI.topAnchor.constraint(equalTo: rateTimeRowContainer.topAnchor),
        ])

        let publicEventContainer = UIView()
        publicEventContainer.translatesAutoresizingMaskIntoConstraints = false
        let publicEventUI = makeSwitchRow(title: DivoStrings.publicEvent, subtitle: DivoStrings.visibleAllUsers, uiSwitch: publicEventSwitch)
        publicEventUI.translatesAutoresizingMaskIntoConstraints = false
        publicEventContainer.addSubview(publicEventUI)
        step3StackView.addArrangedSubview(publicEventContainer)
        NSLayoutConstraint.activate([
            publicEventUI.trailingAnchor.constraint(equalTo: publicEventContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            publicEventUI.leadingAnchor.constraint(equalTo: publicEventContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            publicEventUI.bottomAnchor.constraint(equalTo: publicEventContainer.bottomAnchor),
            publicEventUI.topAnchor.constraint(equalTo: publicEventContainer.topAnchor),
        ])
        
        let stackGallery = UIStackView()
        stackGallery.axis = .horizontal
        stackGallery.translatesAutoresizingMaskIntoConstraints = false
        
        stackGallery.addArrangedSubview(galleryLabel)
        stackGallery.addArrangedSubview(UIView())
        
        let stackGalleryContainer = UIView()
        stackGalleryContainer.translatesAutoresizingMaskIntoConstraints = false
        stackGalleryContainer.addSubview(stackGallery)
        step3StackView.addArrangedSubview(stackGalleryContainer)
        
        NSLayoutConstraint.activate([
            stackGallery.trailingAnchor.constraint(equalTo: stackGalleryContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stackGallery.leadingAnchor.constraint(equalTo: stackGalleryContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stackGallery.topAnchor.constraint(equalTo: stackGalleryContainer.topAnchor),
            stackGallery.bottomAnchor.constraint(equalTo: stackGalleryContainer.bottomAnchor),
            stackGallery.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        step3StackView.setCustomSpacing(12, after: stackGalleryContainer)

        step3StackView.addArrangedSubview(galleryCollectionContainerView)
        galleryCollectionContainerView.addSubview(galleryCollectionView)
        
        NSLayoutConstraint.activate([
            galleryCollectionView.topAnchor.constraint(equalTo: galleryCollectionContainerView.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: galleryCollectionContainerView.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: galleryCollectionContainerView.trailingAnchor),
            galleryCollectionView.bottomAnchor.constraint(equalTo: galleryCollectionContainerView.bottomAnchor)
        ])
        
        galleryHeightConstraint = galleryCollectionContainerView.heightAnchor.constraint(equalToConstant: 0)
        galleryHeightConstraint.isActive = true
        
        step3StackView.setCustomSpacing(12, after: galleryCollectionContainerView)

        let addButtonContainer = UIView()
        addButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        addButtonContainer.addSubview(galleryAddButton)
        
        step3StackView.addArrangedSubview(addButtonContainer)
        
        NSLayoutConstraint.activate([
            addButtonContainer.heightAnchor.constraint(equalToConstant: 40),
            galleryAddButton.heightAnchor.constraint(equalToConstant: 40),
            galleryAddButton.centerXAnchor.constraint(equalTo: addButtonContainer.centerXAnchor),
            galleryAddButton.centerYAnchor.constraint(equalTo: addButtonContainer.centerYAnchor),
        ])
    }
    
    private func reloadAppearanceOptions() {
        dynamicParametersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, item) in appearanceEditItems.enumerated() {
            let isLast = index == appearanceEditItems.count - 1
            let cell = AppearanceFilterRowView(title: item.title, isLast: isLast)
            cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(appearanceCellTapped(_:)))
            cell.addGestureRecognizer(tap)
            cell.tag = index
            dynamicParametersStack.addArrangedSubview(cell)
        }
    }
    
    private func setupAppearanceEditItems() {
        appearanceEditItems = [
            AppearanceEditItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in
                    guard let range = self?.selectedAge else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.ageYo,
                        currentRange: self?.selectedAge,
                        min: 16,
                        max: 70,
                        onUpdate: { newRange in
                            self?.selectedAge = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedHeight else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.heightCm,
                        currentRange: self?.selectedHeight,
                        min: 100,
                        max: 250,
                        onUpdate: { newRange in
                            self?.selectedHeight = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.weightKg,
                getValues: { [weak self] in
                    guard let range = self?.selectedWeight else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.weightKg,
                        currentRange: self?.selectedWeight,
                        min: 40,
                        max: 120,
                        onUpdate: { newRange in
                            self?.selectedWeight = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.waistCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedWaist else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.waistCm,
                        currentRange: self?.selectedWaist,
                        min: 50,
                        max: 120,
                        onUpdate: { newRange in
                            self?.selectedWaist = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedHips else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.hipsCm,
                        currentRange: self?.selectedHips,
                        min: 70,
                        max: 130,
                        onUpdate: { newRange in
                            self?.selectedHips = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.shoeSizeEU,
                getValues: { [weak self] in
                    guard let range = self?.selectedShoeSize else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.shoeSizeEU,
                        currentRange: self?.selectedShoeSize,
                        min: 25,
                        max: 38,
                        onUpdate: { newRange in
                            self?.selectedShoeSize = newRange
                        }
                    )
                }
            ),
        ]
    }
    
    private func showRangeFilter<T>(
        title: String,
        currentRange: ClosedRange<T>?,
        min: T,
        max: T,
        onUpdate: @escaping (ClosedRange<T>?) -> Void
    ) where T: RangeFilterable {

        self.view.endEditing(true)

        var currentMin: Double? = nil
        var currentMax: Double? = nil

        if let currentRange = currentRange {
            currentMin = currentRange.lowerBound.doubleValue
            currentMax = currentRange.upperBound.doubleValue
        }

        let vc = RangeFilterController(
            title: title,
            min: min.doubleValue,
            max: max.doubleValue,
            currentLower: currentMin,
            currentUpper: currentMax,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { [weak self] firstValue, secondValue in
            guard let self = self else { return }
            
            if let firstValue = firstValue, let secondValue = secondValue {
                let newClosedRange = T(firstValue)...T(secondValue)
                onUpdate(newClosedRange)
            } else {
                onUpdate(nil)
            }
            
            self.updateAppearanceValues()
        }
        
        presentSheet(vc)
    }
    
    private func updateAppearanceValues() {
        for (index, item) in appearanceEditItems.enumerated() {
            if index < dynamicParametersStack.arrangedSubviews.count,
               let cell = dynamicParametersStack.arrangedSubviews[index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            }
        }
        validateCurrentStep()
    }
    
    private func scrollToCurrentStep() {
        updateHeaderAndButton()
        validateCurrentStep()
        let offsetX = CGFloat(currentStep - 1) * self.view.bounds.width
        horizontalPager.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }
    
    private func updateHeaderAndButton() {
        navigationBar.setRightTitle(DivoStrings.stepCreateEvent(currentStep))
        if currentStep == 3 {
            discardChangesButton.isHidden = !self.mode.isEdit
            discardChangesButton.makeDivoButton(title: DivoStrings.discardChanges, divoButtonStyle: .secondary)
            discardChangesButton.backgroundColor = DivoColorPalette.secondaryButtonBackground

            applyButton.makeDivoButton(title: self.mode.isEdit ? DivoStrings.saveChanges : DivoStrings.previewEvent)
            let hasChanges = makeSnapshot() != initialSnapshot || avatarChanged || changeGallery
            if self.mode.isEdit {
                self.hasChanges = hasChanges
            } else {
                self.hasChanges = true
            }
        } else {
            discardChangesButton.isHidden = true
            applyButton.makeDivoButton(title: DivoStrings.continueButton)
        }
    }
    
    private func updateDropdownsUI() {
        eventTypeDropdown.setItems(eventTypeTitle.map { [$0] } ?? [], emptyTitle: DivoStrings.chooseEvent)
        countryRow.setItems(countryTitle.map { [$0] } ?? [], emptyTitle: "")
        
        let flagEmoji = emojiFlag(from: self.countryCode)
        let formattedCity = self.cityTitle.map { ["\(flagEmoji) \($0)".trimmingCharacters(in: .whitespaces)] } ?? []
        cityRow.setItems(formattedCity, emptyTitle: "")
        
        let hasCountry = countryId != nil && !countryId!.isEmpty
        cityRow.alpha = hasCountry ? 1.0 : 0.5
        cityRow.isUserInteractionEnabled = hasCountry
        
        whoCanApplyDropdown.setItems(whoCanApplyTitles ?? [], emptyTitle: DivoStrings.notSet)
        maxParticipantsDropdown.setItems(maxParticipants.map {["\($0)"] } ?? [], emptyTitle: DivoStrings.notSet)
        genderDropdown.setItems(genderDropdownTitles ?? [], emptyTitle: DivoStrings.notSet)
        hairLengthDropdown.setItems(hairLengthDropdownTitles ?? [], emptyTitle: DivoStrings.notSet)
        hairColorDropdown.setItems(hairColorDropdownTitles ?? [], emptyTitle: DivoStrings.notSet)
        eyeColorDropdown.setItems(eyeColorDropdownTitles ?? [], emptyTitle: DivoStrings.notSet)
        skinColorDropdown.setItems(skinColorDropdownTitles ?? [], emptyTitle: DivoStrings.notSet)
        rateTime.setTitle(rateTimeTitle)
        updateHeaderAndButton()
        validateCurrentStep()
    }
    
    private func updateGalleryHeight() {
        if galleryItems.isEmpty {
            galleryHeightConstraint.constant = 0
            galleryCollectionView.isHidden = true
        } else {
            galleryCollectionView.isHidden = false
            let fullWidth = UIScreen.main.bounds.width
            let itemWidth = floor(fullWidth / 3.0)
            let rows = ceil(CGFloat(galleryItems.count) / 3.0)
            let newHeight = (rows * itemWidth) + ((rows - 1) * 4.0)
            galleryHeightConstraint.constant = newHeight
        }
        
        self.view.layoutIfNeeded()

        updateHeaderAndButton()
        validateCurrentStep()
    }

    private func loadExistingFiles(_ files: [EventFile]) {
        setAvatarLoading(true)
        self.galleryItems.removeAll()
        self.avatarFileUuid = nil
        let sortedFiles = files.sorted { file1, file2 in
            guard let order1 = file1.order else { return false }
            guard let order2 = file2.order else { return true }
            return order1 < order2
        }
        
        if let avatarFile = sortedFiles.first(where: { $0.order == 0 }), let uuid = avatarFile.fileUuid, let urlString = avatarFile.fullUrl, let url = URL(string: urlString) {
            self.avatarFileUuid = uuid
            Task { @MainActor in
                if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
                    self.currentPhoto = image
                    self.setAvatarLoading(false)
                }
            }
        } else {
            self.setAvatarLoading(false)
        }
        
        let galleryFiles = sortedFiles.filter { $0.order != 0 }
        self.galleryItems = galleryFiles.compactMap { file in
            guard let uuid = file.fileUuid else { return nil }
            return EventGalleryItem(image: nil, isUploading: false, fileUuid: uuid)
        }
        self.galleryCollectionView.reloadData()
        self.updateGalleryHeight()
        
        for (index, file) in galleryFiles.enumerated() {
            guard let urlString = file.fullUrl, let url = URL(string: urlString) else { continue }
            Task { @MainActor in
                if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
                    self.galleryItems[index].image = image
                    self.galleryCollectionView.reloadItems(at:[IndexPath(item: index, section: 0)])
                }
            }
        }
    }
    
    private func loadMoreEventTypesIfNeeded() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        let threshold = max(0, self.eventTypeItems.count - 2)
        let selectedIndex = self.eventTypeItems.firstIndex(where: { $0.id == self.selectedEventTypeId }) ?? -1
        if selectedIndex >= threshold { self.loadMoreEventTypes() }
    }
    
    private func loadMoreEventTypes() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        self.isLoadingEventTypes = true
        self.loadEventTypesList?(self.eventTypeItems.count, self.eventTypeLimit)
    }
    
    private func presentSheet(_ vc: UIViewController) {
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        presentController?(nav)
    }
    
    private func makeInputStack(title: String, inputView: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        let stack = UIStackView(arrangedSubviews: [label, inputView])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }
    
    private func makeSwitchRow(title: String, subtitle: String? = nil, uiSwitch: UISwitch) -> UIStackView {
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = DivoColorPalette.cardBackground
        container.layer.cornerRadius = 23
        
        let switchStack = UIStackView()
        switchStack.axis = .horizontal
        switchStack.alignment = .center
        switchStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(switchStack)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 46),
            
            switchStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            switchStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            switchStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        
        let row = UIStackView()
        row.axis = .vertical
        row.spacing = 4
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Font.regular(16)
        titleLabel.textColor = DivoColorPalette.primaryText
        switchStack.addArrangedSubview(titleLabel)
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        switchStack.addArrangedSubview(spacer)
        
        uiSwitch.onTintColor = DivoColorPalette.accent
        switchStack.addArrangedSubview(uiSwitch)
        
        row.addArrangedSubview(container)
        
        if let sub = subtitle {
            
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            
            let subLabel = UILabel()
            subLabel.text = sub
            subLabel.font = Font.regular(12)
            subLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
            subLabel.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(subLabel)
            
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: 18),
                
                subLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                subLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                subLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            row.addArrangedSubview(container)
        }
        
        return row
    }

    // TODO DIVO: убрать round-trip String↔Int и `?? 0` для type / `?? "1"` для rateTimeId
    // после переезда формы на новый контракт бэка. Сейчас защищено validateCurrentStep() —
    // обязательные id не должны доходить сюда nil; силовой фоллбек оставлен как сетка безопасности.
    private func makeSnapshot() -> EventSnapshot {
        let dateObj = Date(timeIntervalSince1970: TimeInterval(eventDateInt))
        let timeObj = Date(timeIntervalSince1970: TimeInterval(eventTimeInt))
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeObj)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: dateObj) ?? dateObj
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: finalDate)
        
        let dateDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineDateInt))
        let timeDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineTimeInt))
        
        let deadlineCalendar = Calendar.current
        let deadlineTimeComponents = deadlineCalendar.dateComponents([.hour, .minute], from: timeDeadlineObj)
        let deadlineFinalDate = calendar.date(bySettingHour: deadlineTimeComponents.hour ?? 0, minute: deadlineTimeComponents.minute ?? 0, second: 0, of: dateDeadlineObj) ?? dateDeadlineObj
        
        let deadlineFormatter = DateFormatter()
        deadlineFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let deadlineDateString = formatter.string(from: deadlineFinalDate)
        
        return EventSnapshot(
            type: eventTypeId.flatMap { Int($0) } ?? 0,
            typeTitle: eventTypeTitle,
            name: nameEventTextField.textField.text?.trimmingCharacters(in: .whitespaces),
            description: aboutEventTextField.text,
            date: dateString,
            role: resolvedSelection(whoCanApplyIds, options: roleOptions),
            maxAttendees: maxParticipants,
            requirements: requirementsTextField.text.trimmingCharacters(in: .whitespaces),
            genderId: resolvedSelection(genderDropdownIds, options: genderOptions),
            genderTitle: genderDropdownTitles,
            age: selectedAge,
            height: selectedHeight,
            weight: selectedWeight,
            waist: selectedWaist,
            hips: selectedHips,
            shoeSize: selectedShoeSize,
            hairLengthId: resolvedSelection(hairLengthDropdownIds, options: hairLengthOptions)?.compactMap { Int($0) } ?? [],
            hairLengthTitle: hairLengthDropdownTitles,
            hairColorId: resolvedSelection(hairColorDropdownIds, options: hairColorOptions)?.compactMap { Int($0) } ?? [],
            hairColorTitle: hairColorDropdownTitles,
            eyeColorId: resolvedSelection(eyeColorDropdownIds, options: eyeColorOptions)?.compactMap { Int($0) } ?? [],
            eyeColorTitle: eyeColorDropdownTitles,
            skinColorId: resolvedSelection(skinColorDropdownIds, options: skinColorOptions)?.compactMap { Int($0) } ?? [],
            skinColorTitle: skinColorDropdownTitles,
            nda: ndaSwitch.isOn,
            deadlineDate: deadlineDateString,
            cost: rateTextField.text?.trimmingCharacters(in: .whitespaces),
            paymentType: paidEventSwitch.isOn ? 1 : 2,
            paymentFrequency: Int(rateTimeId ?? "1"),
            paymentFrequencyTitle: rateTimeTitle,
            isPublic: publicEventSwitch.isOn,
            cityId: self.cityId.flatMap(Int.init) ?? 1
        )
    }
    
    private func formatCost(_ costString: String?) -> String? {
        guard let costString = costString else { return nil }
        guard let doubleValue = Double(costString) else { return costString }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        formatter.decimalSeparator = "."
        
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00a0}"
        
        return formatter.string(from: NSNumber(value: doubleValue))
    }

    private func emojiFlag(from countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "🌍" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }


    // MARK: - Internal

    func setCityRowLoading(_ isLoading: Bool) {
        self.cityRow.setLoading(isLoading)
    }

    func updateCity(id: String?, title: String?, code: String?) {
        self.cityId = id
        self.cityTitle = title
        self.countryCode = code
        self.updateDropdownsUI()
    }
    
    func startPhotoUpload(image: UIImage) -> EventGalleryItem {
        let item = EventGalleryItem(image: image, isUploading: true)
        galleryItems.append(item)
        galleryCollectionView.reloadData()
        updateGalleryHeight()
        return item
    }
    
    func finishPhotoUpload(item: EventGalleryItem, fileUuid: String) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems[index].isUploading = false
        galleryItems[index].fileUuid = fileUuid
        galleryCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        if initialSnapshot != nil {
            changeGallery = true
            updateHeaderAndButton()
            validateCurrentStep()
        }
    }
    
    func cancelPhotoUpload(item: EventGalleryItem) {
        removePhoto(item: item)
    }
    
    func removePhoto(item: EventGalleryItem) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems.remove(at: index)
        
        if initialSnapshot != nil {
            changeGallery = true
            updateHeaderAndButton()
            validateCurrentStep()
        }
        
        galleryCollectionView.performBatchUpdates({
            galleryCollectionView.deleteItems(at:[IndexPath(item: index, section: 0)])
        }, completion: { [weak self] _ in
            self?.updateGalleryHeight()
        })
    }
    
    func showScreenLoading() {
        loadingOverlay.isHidden = false
        loadingSpinner.isHidden = false
        loadingSpinner.startAnimating()
        self.view.bringSubviewToFront(loadingSpinner)
    }
    
    func hideScreenLoading() {
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimating()
        loadingSpinner.isHidden = true
    }
    
    func loadEventTypesComplete(_ items: [AgencyItem], totalCount: Int, offset: Int) {
        self.isLoadingEventTypes = false
        if offset == 0 {
            self.eventTypeItems = items
        } else {
            let existingIds = Set(self.eventTypeItems.map { $0.id })
            let newItems = items.filter { !existingIds.contains($0.id) }
            self.eventTypeItems.append(contentsOf: newItems)
        }
        self.hasMoreEventTypes = self.eventTypeItems.count < totalCount
        if self.hasMoreEventTypes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.loadMoreEventTypes() }
        }
    }
    
    func configureEventTypeList(_ items: [AgencyItem], totalCount: Int) {
        self.eventTypeItems = items
        self.hasMoreEventTypes = self.eventTypeOffset + self.eventTypeLimit < totalCount
    }
    
    func appendEventTypeItems(_ items: [AgencyItem]) {
        self.eventTypeItems.append(contentsOf: items)
    }
    
    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict

        self.hairLengthOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for hairLength in dict.hairLength {
            self.hairLengthOptions.append(
                FilterOptionItem(id: String(hairLength.id), title: hairLength.title)
            )
        }
        
        self.hairColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for hairColor in dict.hairColor {
            self.hairColorOptions.append(
                FilterOptionItem(id: String(hairColor.id), title: hairColor.title)
            )
        }
        
        self.eyeColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for eyeColor in dict.eyeColor {
            self.eyeColorOptions.append(
                FilterOptionItem(id: String(eyeColor.id), title: eyeColor.title)
            )
        }
        
        self.skinColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for skinColor in dict.skinColor {
            self.skinColorOptions.append(
                FilterOptionItem(id: String(skinColor.id), title: skinColor.title)
            )
        }
    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        self.genderOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for gender in dict.data {
            self.genderOptions.append(
                FilterOptionItem(id: gender.id, title: gender.title)
            )
        }
    }

    /// Дефолтные значения параметров шага 2: мультивыборы → «Все»
    /// (мастер-пункт), диапазоны → полный диапазон, maxParticipants → 100.
    /// В режиме создания вызывается с overrideExisting=true сразу после
    /// загрузки словарей. В режиме редактирования — с overrideExisting=false
    /// после populate, чтобы дозаполнить только те поля, что сервер вернул
    /// пустыми/нулевыми.
    func applyDefaultStep2Parameters(overrideExisting: Bool) {
        applyDefaultMultiSelect(
            ids: &whoCanApplyIds,
            titles: &whoCanApplyTitles,
            options: roleOptions,
            overrideExisting: overrideExisting
        )
        applyDefaultMultiSelect(
            ids: &genderDropdownIds,
            titles: &genderDropdownTitles,
            options: genderOptions,
            overrideExisting: overrideExisting
        )
        applyDefaultMultiSelect(
            ids: &hairLengthDropdownIds,
            titles: &hairLengthDropdownTitles,
            options: hairLengthOptions,
            overrideExisting: overrideExisting
        )
        applyDefaultMultiSelect(
            ids: &hairColorDropdownIds,
            titles: &hairColorDropdownTitles,
            options: hairColorOptions,
            overrideExisting: overrideExisting
        )
        applyDefaultMultiSelect(
            ids: &eyeColorDropdownIds,
            titles: &eyeColorDropdownTitles,
            options: eyeColorOptions,
            overrideExisting: overrideExisting
        )
        applyDefaultMultiSelect(
            ids: &skinColorDropdownIds,
            titles: &skinColorDropdownTitles,
            options: skinColorOptions,
            overrideExisting: overrideExisting
        )

        if overrideExisting || maxParticipants == nil {
            maxParticipants = 100
        }

        applyDefaultRange(range: &selectedAge, defaultRange: 16...70, overrideExisting: overrideExisting)
        applyDefaultRange(range: &selectedHeight, defaultRange: 100...250, overrideExisting: overrideExisting)
        applyDefaultRange(range: &selectedWeight, defaultRange: 40...120, overrideExisting: overrideExisting)
        applyDefaultRange(range: &selectedWaist, defaultRange: 50...120, overrideExisting: overrideExisting)
        applyDefaultRange(range: &selectedHips, defaultRange: 70...130, overrideExisting: overrideExisting)
        applyDefaultRange(range: &selectedShoeSize, defaultRange: 25...38, overrideExisting: overrideExisting)

        updateDropdownsUI()
        updateAppearanceValues()
    }

    private func applyDefaultMultiSelect(
        ids: inout [String]?,
        titles: inout [String]?,
        options: [FilterOptionItem],
        overrideExisting: Bool
    ) {
        let isMissing = (ids == nil) || (ids?.isEmpty == true && titles?.isEmpty != false)
        guard overrideExisting || isMissing else { return }
        ids = []
        titles = [options.first?.title].compactMap { $0 }
    }

    private func applyDefaultRange<T: AdditiveArithmetic & Comparable>(
        range: inout ClosedRange<T>?,
        defaultRange: ClosedRange<T>,
        overrideExisting: Bool
    ) {
        let isMissing: Bool
        if let current = range {
            isMissing = current.lowerBound == .zero && current.upperBound == .zero
        } else {
            isMissing = true
        }
        guard overrideExisting || isMissing else { return }
        range = defaultRange
    }

    /// Округляет значение слайдера до 2 знаков после запятой и конвертит в Float.
    /// Слайдер выдаёт сырой Double (например, 76.79375 из интерполяции по позиции),
    /// бэк ожидает аккуратные значения — режем хвост на границе сериализации.
    private func rangeFloat(_ value: Double?) -> Float {
        guard let value = value else { return 0 }
        return Float((value * 100).rounded() / 100)
    }

    // MARK: - Populate & Collect Data
    
    func updateTime(_ timestamp: Int32, _ mode: TimeControllerMode) {
        switch mode {
        case .time:
            eventTimeInt = timestamp
            eventTime.setDate(timestamp: timestamp)
        case .date:
            eventDateInt = timestamp
            eventDate.setDate(timestamp: timestamp)
        }
        validateCurrentStep()
    }
    
    func updateDeadlineTime(_ timestamp: Int32, _ mode: TimeControllerMode) {
        switch mode {
        case .time:
            deadlineTimeInt = timestamp
            deadlineTime.setDate(timestamp: timestamp)
        case .date:
            deadlineDateInt = timestamp
            deadlineDate.setDate(timestamp: timestamp)
        }
        updateHeaderAndButton()
        validateCurrentStep()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout? = nil, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat) {
        self.currentLayoutData = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        guard let layout = layout else { return }
        
        if !errorPlaceholderView.isHidden {
            let topInset = navigationBarHeight
            errorPlaceholderView.frame = CGRect(
                x: 0,
                y: topInset,
                width: layout.size.width,
                height: layout.size.height - topInset
            )
        }
        
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        for (_, scroll) in scrolls.enumerated() {
            var insets = scroll.contentInset
            insets.top = navigationBarHeight
            
            scroll.contentInset = insets
            scroll.scrollIndicatorInsets = insets
        }
    }
    
    func setAvatarLoading(_ loading: Bool) {
        if loading {
            avatarSpinner.startAnimating()
            avatarSpinner.isHidden = false
            avatarImageView.alpha = 0.0
            avatarImageSpinnerView.backgroundColor = DivoColorPalette.cardBackground
            avatarImageSpinnerView.isHidden = false
            chanceCenterPhotoView.isHidden = true
        } else {
            avatarSpinner.stopAnimating()
            avatarSpinner.isHidden = true
            avatarImageView.alpha = 1.0
            avatarImageSpinnerView.backgroundColor = .clear
            avatarImageSpinnerView.isHidden = true
        }
    }
 
    // TODO DIVO: убрать round-trip String↔Int и `?? 0` для eventTypeId / `?? "1"` для rateTimeId
    // после переезда формы на новый контракт бэка. См. комментарий над makeSnapshot().
    func collectEventData() throws -> CreateEventRequest {
        
        let title = nameEventTextField.textField.text ?? ""
        let description = aboutEventTextField.text
        let eventTypeId = Int(eventTypeId ?? "0") ?? 0

        let dateObj = Date(timeIntervalSince1970: TimeInterval(eventDateInt))
        let timeObj = Date(timeIntervalSince1970: TimeInterval(eventTimeInt))
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeObj)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: dateObj) ?? dateObj
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: finalDate)
        
        let dateToObj = calendar.date(byAdding: .hour, value: 2, to: finalDate) ?? finalDate
        let dateToString = formatter.string(from: dateToObj)
        
        let dateDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineDateInt))
        let timeDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineTimeInt))
        
        let deadlineCalendar = Calendar.current
        let deadlineTimeComponents = deadlineCalendar.dateComponents([.hour, .minute], from: timeDeadlineObj)
        let deadlineFinalDate = calendar.date(bySettingHour: deadlineTimeComponents.hour ?? 0, minute: deadlineTimeComponents.minute ?? 0, second: 0, of: dateDeadlineObj) ?? dateDeadlineObj
        
        let deadlineFormatter = DateFormatter()
        deadlineFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let deadlineDateString = formatter.string(from: deadlineFinalDate)
        
        let cityId = self.cityId.flatMap(Int.init) ?? 1
        let address = EventAddressRequest(
            street: nil,
            house: nil,
            apartment: nil,
            formatted: nil,
            latitude: nil,
            longitude: nil,
            cityId: cityId
        )
        
        var eventFiles: [EventFileRequest] = []
        var currentOrder = 0
                
        if let avatarUuid = avatarFileUuid {
            eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: avatarUuid))
            currentOrder += 1
        }
        
        for item in galleryItems {
            if let uuid = item.fileUuid {
                eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: uuid))
                currentOrder += 1
            }
        }
        
        let roles = resolvedSelection(whoCanApplyIds, options: roleOptions)
        var ageRange: EventRangeRequest?
        var heightRange: EventRangeRequest?
        var weightRange: EventRangeRequest?
        var waistRange: EventRangeRequest?
        var hipsRange: EventRangeRequest?
        var shoesRange: EventRangeRequest?
        let genders = resolvedSelection(genderDropdownIds, options: genderOptions)
        let hairColors: [Int] = resolvedSelection(hairColorDropdownIds, options: hairColorOptions)?.compactMap { Int($0) } ?? []
        let hairLengths: [Int] = resolvedSelection(hairLengthDropdownIds, options: hairLengthOptions)?.compactMap { Int($0) } ?? []
        let eyeColors: [Int] = resolvedSelection(eyeColorDropdownIds, options: eyeColorOptions)?.compactMap { Int($0) } ?? []
        let skinColors: [Int] = resolvedSelection(skinColorDropdownIds, options: skinColorOptions)?.compactMap { Int($0) } ?? []
        
        ageRange = EventRangeRequest(from: Float(selectedAge?.lowerBound ?? 0), to: Float(selectedAge?.upperBound ?? 0))
        heightRange = EventRangeRequest(from: rangeFloat(selectedHeight?.lowerBound), to: rangeFloat(selectedHeight?.upperBound))
        weightRange = EventRangeRequest(from: rangeFloat(selectedWeight?.lowerBound), to: rangeFloat(selectedWeight?.upperBound))
        waistRange = EventRangeRequest(from: rangeFloat(selectedWaist?.lowerBound), to: rangeFloat(selectedWaist?.upperBound))
        hipsRange = EventRangeRequest(from: rangeFloat(selectedHips?.lowerBound), to: rangeFloat(selectedHips?.upperBound))
        shoesRange = EventRangeRequest(from: rangeFloat(selectedShoeSize?.lowerBound), to: rangeFloat(selectedShoeSize?.upperBound))
        
        let paymentType = paidEventSwitch.isOn ? 1 : 2
        
        let costClean = rateTextField.text?.replacingOccurrences(of: "\u{00a0}", with: "").replacingOccurrences(of: " ", with: "")
        let cost = (costClean == "" || costClean == nil) ? nil : costClean
        
        let requirements = requirementsTextField.text == "" ? nil : requirementsTextField.text
        
        return CreateEventRequest(
            title: title,
            description: description,
            typeId: eventTypeId,
            date: dateString,
            dateTo: dateToString,
            address: address,
            files: eventFiles,
            paymentType: paymentType,
            paymentFrequency: Int(rateTimeId ?? "1"),
            cost: cost,
            isPublic: publicEventSwitch.isOn,
            ndaRequired: ndaSwitch.isOn,
            applicationDeadline: deadlineDateString,
            maxAttendees: maxParticipants,
            requirements: requirements,
            role: roles,
            gender: genders,
            age: ageRange,
            height: heightRange,
            weight: weightRange,
            breastSize: nil,
            waist: waistRange,
            hips: hipsRange,
            shoesSize: shoesRange,
            hairColor: hairColors,
            hairLength: hairLengths,
            eyeColor: eyeColors,
            skinColor: skinColors,
            measuringSystem: "metric"
        )
    }

    func collectPreviewEventData() throws -> CreateEventPreview {
        
        let title = nameEventTextField.textField.text ?? ""
        let description = aboutEventTextField.text
        let requirements = requirementsTextField.text

        let dateObj = Date(timeIntervalSince1970: TimeInterval(eventDateInt))
        let timeObj = Date(timeIntervalSince1970: TimeInterval(eventTimeInt))
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeObj)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: dateObj) ?? dateObj
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: finalDate)
        
        let dateDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineDateInt))
        let timeDeadlineObj = Date(timeIntervalSince1970: TimeInterval(deadlineTimeInt))
        
        let timeDeadlineComponents = calendar.dateComponents([.hour, .minute], from: timeDeadlineObj)
        let finalDeadlineDate = calendar.date(bySettingHour: timeDeadlineComponents.hour ?? 0, minute: timeDeadlineComponents.minute ?? 0, second: 0, of: dateDeadlineObj) ?? dateDeadlineObj

        let dateDeadlineString = formatter.string(from: finalDeadlineDate)

        let cityId = self.cityId.flatMap(Int.init) ?? 1
        let address = EventAddressRequest(
            street: nil,
            house: nil,
            apartment: nil,
            formatted: nil,
            latitude: nil,
            longitude: nil,
            cityId: cityId
        )
        
        var eventFiles: [EventFileRequest] = []
        var currentOrder = 0
                
        if let avatarUuid = avatarFileUuid {
            eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: avatarUuid))
            currentOrder += 1
        }
        
        for item in galleryItems {
            if let uuid = item.fileUuid {
                eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: uuid))
                currentOrder += 1
            }
        }
        
        let roles = resolvedSelection(whoCanApplyIds, options: roleOptions)
        var ageRange: EventRangeRequest?
        var heightRange: EventRangeRequest?
        var weightRange: EventRangeRequest?
        var waistRange: EventRangeRequest?
        var hipsRange: EventRangeRequest?
        var shoesRange: EventRangeRequest?
        let genders = resolvedSelectionTitles(genderDropdownIds, options: genderOptions)
        let hairColors: [String]? = resolvedSelectionTitles(hairColorDropdownIds, options: hairColorOptions)
        let hairLengths: [String]? = resolvedSelectionTitles(hairLengthDropdownIds, options: hairLengthOptions)
        let eyeColors: [String]? = resolvedSelectionTitles(eyeColorDropdownIds, options: eyeColorOptions)
        let skinColors: [String]? = resolvedSelectionTitles(skinColorDropdownIds, options: skinColorOptions)

        if let selectedAge = selectedAge {
            ageRange = EventRangeRequest(from: Float(selectedAge.lowerBound), to: Float(selectedAge.upperBound))
        }
        if let selectedHeight = selectedHeight {
            heightRange = EventRangeRequest(from: rangeFloat(selectedHeight.lowerBound), to: rangeFloat(selectedHeight.upperBound))
        }
        if let selectedWeight = selectedWeight {
            weightRange = EventRangeRequest(from: rangeFloat(selectedWeight.lowerBound), to: rangeFloat(selectedWeight.upperBound))
        }
        if let selectedWaist = selectedWaist {
            waistRange = EventRangeRequest(from: rangeFloat(selectedWaist.lowerBound), to: rangeFloat(selectedWaist.upperBound))
        }
        if let selectedHips = selectedHips {
            hipsRange = EventRangeRequest(from: rangeFloat(selectedHips.lowerBound), to: rangeFloat(selectedHips.upperBound))
        }
        if let selectedShoeSize = selectedShoeSize {
            shoesRange = EventRangeRequest(from: rangeFloat(selectedShoeSize.lowerBound), to: rangeFloat(selectedShoeSize.upperBound))
        }
        
        let paymentType = paidEventSwitch.isOn ? 1 : 2
        
        let costClean = rateTextField.text?.replacingOccurrences(of: "\u{00a0}", with: "").replacingOccurrences(of: " ", with: "")
        let cost = paymentType == 1 ? ((costClean == "" || costClean == nil) ? nil : costClean) : nil
        
        return CreateEventPreview(
            title: title,
            description: description,
            type: eventTypeTitle ?? DivoStrings.eventFallbackName,
            typeId: Int(eventTypeId ?? "0") ?? 0,
            date: dateString,
            address: address,
            countryCode: countryCode,
            cityName: cityTitle,
            files: eventFiles,
            isFree: !paidEventSwitch.isOn,
            cost: cost,
            isPublic: publicEventSwitch.isOn,
            ndaRequired: ndaSwitch.isOn,
            applicationDeadline: dateDeadlineString,
            maxAttendees: maxParticipants ?? 0,
            requirements: requirements,
            role: roles,
            gender: genders,
            age: ageRange,
            height: heightRange,
            weight: weightRange,
            breastSize: nil,
            waist: waistRange,
            hips: hipsRange,
            shoesSize: shoesRange,
            hairColor: hairColors,
            hairLength: hairLengths,
            eyeColor: eyeColors,
            skinColor: skinColors
        )
    }
    
    func populate(with detail: EventFullDetailData) {

        guard mode.isEdit else {
            divoLog("⚠️ Попытка заполнить форму в режиме создания")
            return
        }
        
        guard let typeId = detail.type?.id else { return }
        
        eventTypeId = "\(typeId)"
        eventTypeTitle = detail.type?.title
        
        nameEventTextField.textField.text = detail.title
        
        aboutEventTextField.textView.text = detail.description ?? ""
        aboutEventTextField.textView.textColor = DivoColorPalette.primaryText
        
        if let dateString = detail.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: dateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                self.updateTime(timestamp, .date)
                self.updateTime(timestamp, .time)
            }
        }
        
        if let city = detail.address?.city {
            let cityName = city.name ?? ""
            let countryName = city.countryName ?? ""
            let countryCode = city.countryCode ?? ""
            
            self.rawCityId = cityName + "|||" + countryName
            self.cityId = String(city.id ?? 1)
            self.cityTitle = cityName
            self.countryCode = countryCode
            
            self.countryId = countryCode
            
            let locale = Locale(identifier: DivoStrings.current.rawValue)
            if let localizedCountry = locale.localizedString(forRegionCode: countryCode) {
                let flag = emojiFlag(from: countryCode)
                self.countryTitle = "\(flag) \(localizedCountry)"
            }
        }
        
        whoCanApplyIds = detail.modelAttributes?.role
        whoCanApplyTitles = whoCanApplyIds?.compactMap { id in
            roleOptions.first(where: { $0.id == id })?.title
        }
        
        maxParticipants = detail.maxAttendees
        
        requirementsTextField.textView.text = detail.requirements
        requirementsTextField.textView.textColor = DivoColorPalette.primaryText
        
        genderDropdownIds = detail.modelAttributes?.gender?.map(\.id!)
        genderDropdownTitles = detail.modelAttributes?.gender?.map(\.title!)
        
        hairLengthDropdownIds = detail.modelAttributes?.hairLength?.compactMap { String($0.id!) }
        hairLengthDropdownTitles = detail.modelAttributes?.hairLength?.map(\.title!)
        
        hairColorDropdownIds = detail.modelAttributes?.hairColor?.compactMap { String($0.id!) }
        hairColorDropdownTitles = detail.modelAttributes?.hairColor?.map(\.title!)
        
        eyeColorDropdownIds = detail.modelAttributes?.eyeColor?.compactMap { String($0.id!) }
        eyeColorDropdownTitles = detail.modelAttributes?.eyeColor?.map(\.title!)
        
        skinColorDropdownIds = detail.modelAttributes?.skinColor?.compactMap { String($0.id!) }
        skinColorDropdownTitles = detail.modelAttributes?.skinColor?.map(\.title!)
        
        selectedAge = Int(detail.modelAttributes?.age?.from ?? 0)...Int(detail.modelAttributes?.age?.to ?? 0)
        selectedHeight = Double(detail.modelAttributes?.height?.from ?? 0)...Double(detail.modelAttributes?.height?.to ?? 0)
        selectedWeight = Double(detail.modelAttributes?.weight?.from ?? 0)...Double(detail.modelAttributes?.weight?.to ?? 0)
        selectedWaist = Double(detail.modelAttributes?.waist?.from ?? 0)...Double(detail.modelAttributes?.waist?.to ?? 0)
        selectedHips = Double(detail.modelAttributes?.hips?.from ?? 0)...Double(detail.modelAttributes?.hips?.to ?? 0)
        selectedShoeSize = Double(detail.modelAttributes?.shoesSize?.from ?? 0)...Double(detail.modelAttributes?.shoesSize?.to ?? 0)
        
        ndaSwitch.isOn = detail.ndaRequired ?? false
        
        if let deadlineDateString = detail.applicationDeadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: deadlineDateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                self.updateDeadlineTime(timestamp, .date)
                self.updateDeadlineTime(timestamp, .time)
            }
        }
        
        paidEventSwitch.isOn = detail.paymentType?.id == 1
        rateTextField.text = formatCost(detail.cost)
        rateTimeId = String(detail.paymentFrequency?.id ?? 0)
        rateTimeTitle = detail.paymentFrequency?.title ?? ""
        
        publicEventSwitch.isOn = detail.isPublic ?? false
        
        // Дозаполняем пустые/нулевые поля шага 2 дефолтами (мультивыборы → «Все»,
        // диапазоны → полный диапазон). До снятия initialSnapshot, чтобы
        // hasChanges не срабатывал на восстановленные дефолты.
        applyDefaultStep2Parameters(overrideExisting: false)

        updateDropdownsUI()
        updateAppearanceValues()

        // 6. Галерея и Обложка (Фотографии)
        if let files = detail.files {
            loadExistingFiles(files)
        }
        initialSnapshot = makeSnapshot()
        markDataLoaded()
    }
    
    // MARK: - Public State Methods

    /// Настройка режима экрана (вызывается перед показом)
    func configure(mode: CreateEventMode) {
        self.mode = mode

        navigationBar.setTitle((mode.isEdit ? DivoStrings.editEvent : DivoStrings.createEvent).uppercased())

        // Обновляем UI в зависимости от режима
        if mode.isEdit {
            navigationBar.setRightTitle(DivoStrings.stepCreateEvent(currentStep))
            loadPhase = .loading
        } else {
            loadPhase = .ready // Для создания сразу показываем форму
        }

        // Меняем заголовок кнопки на последнем шаге
        updateHeaderAndButton()
    }

    /// Отметить, что данные успешно загружены (вызывается из контроллера)
    func markDataLoaded() {
        loadPhase = .ready
        hasLoadedInitialData = true
    }

    /// Отметить, что загрузка данных завершилась ошибкой
    func markDataLoadFailed(networkError: Bool) {
        loadPhase = .failed
    }

    /// Сбросить в начальное состояние (для retry)
    func resetToInitialLoading() {
        loadPhase = .loading
        hasLoadedInitialData = false
    }

    
    // MARK: - Handlers & Navigations
    
    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceEditItems.count else { return }
        appearanceEditItems[view.tag].onTap()
    }
    
    @objc private func mainActionButtonTapped() {
        self.view.endEditing(true)
        if currentStep < 3 {
            currentStep += 1
            scrollToCurrentStep()
        } else {
            onCreateEventTapped?()
        }
    }

    @objc private func discardActionButtonTapped() {
        guard mode.isEdit else {
            divoLog("⚠️ Попытка заполнить форму в режиме создания")
            return
        }
        
        eventTypeId = "\(initialSnapshot?.type ?? 0)"
        eventTypeTitle = initialSnapshot?.typeTitle
        
        nameEventTextField.textField.text = initialSnapshot?.name
        
        aboutEventTextField.textView.text = initialSnapshot?.description
        aboutEventTextField.textView.textColor = DivoColorPalette.primaryText
        
        if let dateString = initialSnapshot?.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: dateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                self.updateTime(timestamp, .date)
                self.updateTime(timestamp, .time)
            }
        }
        
        // НИЧЕГО НЕ ПРО СТРАНУ И НЕПОНЯТНО КАК ЗАПОЛНЯТЬ АДРЕС
        
        whoCanApplyIds = initialSnapshot?.role
        whoCanApplyTitles = restoreSelectionTitles(ids: whoCanApplyIds, options: roleOptions)
        
        maxParticipants = initialSnapshot?.maxAttendees
        
        requirementsTextField.textView.text = initialSnapshot?.requirements
        requirementsTextField.textView.textColor = DivoColorPalette.primaryText
        
        genderDropdownIds = initialSnapshot?.genderId
        genderDropdownTitles = initialSnapshot?.genderTitle
        
        hairLengthDropdownIds = initialSnapshot?.hairLengthId?.compactMap({String($0)})
        hairLengthDropdownTitles = initialSnapshot?.hairLengthTitle
        
        hairColorDropdownIds = initialSnapshot?.hairColorId?.compactMap({String($0)})
        hairColorDropdownTitles = initialSnapshot?.hairColorTitle
        
        eyeColorDropdownIds = initialSnapshot?.eyeColorId?.compactMap({String($0)})
        eyeColorDropdownTitles = initialSnapshot?.eyeColorTitle
        
        skinColorDropdownIds = initialSnapshot?.skinColorId?.compactMap({String($0)})
        skinColorDropdownTitles = initialSnapshot?.skinColorTitle
        
        selectedAge = initialSnapshot?.age
        selectedHeight = initialSnapshot?.height
        selectedWeight = initialSnapshot?.weight
        selectedWaist = initialSnapshot?.waist
        selectedHips = initialSnapshot?.hips
        selectedShoeSize = initialSnapshot?.shoeSize
        
        ndaSwitch.isOn = initialSnapshot?.nda ?? false
        
        if let deadlineDateString = initialSnapshot?.deadlineDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: deadlineDateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                self.updateDeadlineTime(timestamp, .date)
                self.updateDeadlineTime(timestamp, .time)
            }
        }
        
        paidEventSwitch.isOn = initialSnapshot?.paymentType == 1
        rateTextField.text = initialSnapshot?.cost
        rateTimeId = String(initialSnapshot?.paymentFrequency ?? 0)
        rateTimeTitle = initialSnapshot?.paymentFrequencyTitle ?? ""
        
        publicEventSwitch.isOn = initialSnapshot?.isPublic ?? false
        
        updateDropdownsUI()
        updateAppearanceValues()

        onBackTapped?()
    }
    
    @objc private func backButtonTapped() {
        self.view.endEditing(true)
        if currentStep > 1 {
            currentStep -= 1
            scrollToCurrentStep()
        } else {
            onBackTapped?()
        }
    }
    
    @objc private func avatarTapped() {
        self.view.endEditing(true)
        onAvatarTap?()
    }
    
    @objc private func eventTypeTapped() {
        self.view.endEditing(true)
        
        let options = eventTypeItems.map { FilterOptionItem(id: String($0.id), title: $0.title) }
        let selectedIds = eventTypeId != nil ? [String(eventTypeId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.eventType,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.eventTypeId = selected.id
                self?.eventTypeTitle = selected.title
            } else {
                self?.eventTypeId = nil
                self?.eventTypeTitle = nil
            }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func countryTapped() {
        self.view.endEditing(true)
        let selectedIds = countryId != nil ? [String(countryId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.debugCountry,
            options: countryOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: true,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                let oldCountryId = self.countryId
                
                self.countryId = selected.id
                self.countryTitle = selected.title
                
                if oldCountryId != selected.id {
                    self.cityId = nil
                    self.cityTitle = nil
                    self.rawCityId = nil
                    self.countryCode = nil
                }
            } else {
                self.countryId = nil
                self.countryTitle = nil
                self.cityId = nil
                self.cityTitle = nil
                self.rawCityId = nil
                self.countryCode = nil
            }
            self.updateDropdownsUI()
        }
        
        presentSheet(vc)
    }
    
    @objc private func cityTapped() {
        self.view.endEditing(true)
        
        guard let selectedCountryCode = self.countryId, !selectedCountryCode.isEmpty else {
            return
        }
        
        let preselected: [FilterOptionItem]
        if let rawId = self.rawCityId, let title = self.cityTitle {
            preselected = [FilterOptionItem(id: rawId, title: title)]
        } else {
            preselected = []
        }
        
        let vc = CitySearchController(
            title: DivoStrings.chooseCity,
            preselectedItems: preselected,
            isOpenPresent: true,
            filterCountryCode: selectedCountryCode
        )
        
        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                self.rawCityId = selected.id
                
                let rawParts = selected.id.components(separatedBy: "|||")
                let cityName = rawParts.joined(separator: ", ")
                
                self.onCityChosen?(cityName)
            } else {
                self.rawCityId = nil
                self.updateCity(id: nil, title: nil, code: nil)
            }
        }
        
        presentSheet(vc)
    }
    
    @objc private func roleTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.whoCanApply,
            options: roleOptions,
            currentIds: whoCanApplyIds
        ) { [weak self] ids, titles in
            self?.whoCanApplyIds = ids
            self?.whoCanApplyTitles = titles
        }
    }
    
    @objc private func genderDropdownTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.gender,
            options: genderOptions,
            currentIds: genderDropdownIds
        ) { [weak self] ids, titles in
            self?.genderDropdownIds = ids
            self?.genderDropdownTitles = titles
        }
    }
    
    @objc private func rateTimeTapped() {
        self.view.endEditing(true)
        let selectedIds = rateTimeId != nil ? [String(rateTimeId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.rateTime,
            options: rateTimeOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false,
        )

        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.rateTimeId = selected.id
                self?.rateTimeTitle = selected.title
            } else {
                self?.rateTimeId = nil
                self?.rateTimeTitle = "per hour"
            }
            self?.updateDropdownsUI()
        }
        
        presentSheet(vc)
    }
    
    @objc private func hairLengthDropdownTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.attrHairLength,
            options: hairLengthOptions,
            currentIds: hairLengthDropdownIds
        ) { [weak self] ids, titles in
            self?.hairLengthDropdownIds = ids
            self?.hairLengthDropdownTitles = titles
        }
    }

    @objc private func hairColorDropdownTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.attrHairColor,
            options: hairColorOptions,
            currentIds: hairColorDropdownIds
        ) { [weak self] ids, titles in
            self?.hairColorDropdownIds = ids
            self?.hairColorDropdownTitles = titles
        }
    }

    @objc private func eyeColorDropdownTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.attrEyeColor,
            options: eyeColorOptions,
            currentIds: eyeColorDropdownIds
        ) { [weak self] ids, titles in
            self?.eyeColorDropdownIds = ids
            self?.eyeColorDropdownTitles = titles
        }
    }
    
    @objc private func skinColorDropdownTapped() {
        presentMultiSelectFilter(
            title: DivoStrings.attrSkinColor,
            options: skinColorOptions,
            currentIds: skinColorDropdownIds
        ) { [weak self] ids, titles in
            self?.skinColorDropdownIds = ids
            self?.skinColorDropdownTitles = titles
        }
    }
    
    @objc private func maxParticipantsTapped() {
        self.view.endEditing(true)
        let vc = RangeFilterController(
            title: DivoStrings.maxParticipants,
            min: 10,
            max: 100,
            currentLower: nil,
            currentUpper: maxParticipants.map{Double($0)},
            isSingleValue: true,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = {[weak self] _, upperVal in
            self?.maxParticipants = upperVal.map { Int($0) }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
        
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    @objc private func dashedUploadTapped() { onAddGalleryPhotoTapped?() }
    @objc private func deleteParameterTapped(_ button: ASButtonNode) {
        guard let param = deleteButtons.first(where: { $0.value === button })?.key else { return }
        self.selectedParameters.remove(param)
    }
    
    @objc private func switchChange() {
        updateHeaderAndButton()
        validateCurrentStep()
    }
    
    @objc private func validateCurrentStep() {
        // Если данные ещё не загружены (режим редактирования) — кнопка неактивна
        if mode.isEdit && loadPhase != .ready {
            applyButton.isEnabled = false
            return
        }
        
        var isValid = false
        
        switch currentStep {
        case 1:
            let hasPhoto = currentPhoto != nil || avatarFileUuid != nil
            let hasEventType = eventTypeId != nil && !eventTypeId!.isEmpty
            let hasName = !(nameEventTextField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            
            let descText = aboutEventTextField.textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasDesc = !descText.isEmpty && descText != DivoStrings.placeholderDescriptionCreateEvent
            
            let hasDate = eventDateInt > 0
            let hasTime = eventTimeInt > 0
            let hasCountry = cityId != nil && !cityId!.isEmpty
            
            isValid = hasPhoto && hasEventType && hasName && hasDesc && hasDate && hasTime && hasCountry
            
        case 2:
            // Пустой массив тоже валиден — означает выбор мастер-пункта «Все»
            // (см. семантику FilterOptionsController). Невалидно только nil — когда
            // пользователь ни разу не открывал picker.
            let hasRoles = whoCanApplyIds != nil
            let hasMaxParticipants = maxParticipants != nil
            
            let reqText = requirementsTextField.textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasReq = !reqText.isEmpty && reqText != DivoStrings.placeholderRequirementsCreateEvent
            
            isValid = hasRoles && hasMaxParticipants && hasReq
            
        case 3:
            let hasDate = deadlineDateInt > 0
            let hasTime = deadlineTimeInt > 0
            var hasRate = true
            
            rateTimeRowContainer.isHidden = !paidEventSwitch.isOn
            if paidEventSwitch.isOn {
                hasRate = !(rateTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
            
            let hasGallery = !galleryItems.isEmpty
            isValid = hasDate && hasTime && hasRate && hasGallery && self.hasChanges
            
        default:
            isValid = true
        }
        
        applyButton.isEnabled = isValid
    }
    
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: applyButton.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}


// MARK: - UICollectionViewDataSource & Delegate

extension CreateEventNode: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventGalleryCell", for: indexPath) as! EventGalleryCell
        let item = galleryItems[indexPath.row]
        cell.configure(with: item)
        cell.onDelete = { [weak self, item] in
            self?.removePhoto(item: item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = floor((UIScreen.main.bounds.width) / 3.0)
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = galleryItems[indexPath.item]
        guard !item.isUploading, let uuid = item.fileUuid else { return }
        onGalleryItemTapped?(uuid)
    }
}


// MARK: - UITextFieldDelegate

extension CreateEventNode: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == rateTextField {
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            if !string.isEmpty && !allowedCharacters.isSuperset(of: characterSet) {
                return false
            }
            
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return false }
            let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
            
            let cleanText = updatedText.replacingOccurrences(of: " ", with: "")
                                       .replacingOccurrences(of: "\u{00a0}", with: "")
            
            if cleanText.isEmpty {
                textField.text = ""
                self.switchChange()
                return false
            }
            
            if cleanText.count > 9 {
                return false
            }
            
            if let doubleValue = Double(cleanText) {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
                formatter.usesGroupingSeparator = true
                formatter.groupingSeparator = "\u{00a0}"
                
                if let formattedText = formatter.string(from: NSNumber(value: doubleValue)) {
                    let selectedRange = textField.selectedTextRange
                    
                    textField.text = formattedText
                    
                    if let selectedRange = selectedRange {
                        let cursorOffsetFromEnd = currentText.count - textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
                        let newCursorOffset = max(0, formattedText.count - cursorOffsetFromEnd)
                        if let newPosition = textField.position(from: textField.beginningOfDocument, offset: newCursorOffset) {
                            textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
                        }
                    }
                }
            }
            
            self.switchChange()
            return false
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == rateTextField {
            rateFieldContainer.layer.borderWidth = 1.0
            rateFieldContainer.layer.borderColor = DivoColorPalette.accent.cgColor
        } else {
            textField.layer.borderWidth = 1.0
            textField.layer.borderColor = DivoColorPalette.accent.cgColor
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == rateTextField {
            rateFieldContainer.layer.borderWidth = 0.0
        } else {
            textField.layer.borderWidth = 0.0
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameEventTextField.textField {
            aboutEventTextField.textView.becomeFirstResponder()
        }
        
        return false
    }
}


// MARK: - UIGestureRecognizerDelegate

extension CreateEventNode: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}

