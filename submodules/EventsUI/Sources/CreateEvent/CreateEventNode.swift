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

final class CreateEventNode: ASDisplayNode, UITextFieldDelegate {

    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private(set) var eventDate: Int32 = 0
    private var eventTime: Int32 = 0

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let presentationDataPromise: Promise<PresentationData>

    private let _ready = Promise<Bool>()
    private var readyValue = false {
        didSet {
            if self.readyValue, self.readyValue != oldValue {
                self._ready.set(.single(self.readyValue))
            }
        }
    }
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }

    private var disposable: Disposable?

    private let scrollNode: ASScrollNode

    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode

    private let eventInfoLabel: ASTextNode

    private let nameEventLabel: ASTextNode
    private let nameEventTextField: TextFieldNode

    private let aboutEventLabel: ASTextNode
    private let aboutEventTextField: MultilineTextFieldNode

    private var eventTypeDropdown: DropdownNode

    private let eventDateLabel: ASTextNode
    private let eventDateTextField: TextFieldNode

    private let eventTimeLabel: ASTextNode
    private let eventTimeTextField: TextFieldNode

    private let venueEventLabel: ASTextNode
    private let venueEventTextField: TextFieldNode

    private let parametersApplyingLabel: ASTextNode
    private let addParametersButton: ASControlNode

    private var selectedParameters: Set<EventParameter> = []
    
    private var genderDropdown: DropdownNode?
    private var ageSlider: AgeSliderNode<Int>?
    private var heightSlider: AgeSliderNode<Double>?
    private var weightSlider: AgeSliderNode<Double>?
    private var breastSlider: AgeSliderNode<Double>?
    private var waistSlider: AgeSliderNode<Double>?
    private var hipsSlider: AgeSliderNode<Double>?
    private var shoeSizeSlider: AgeSliderNode<Double>?
    private var hairLengthDropdown: DropdownNode?
    private var hairColorDropdown: DropdownNode?
    private var eyeColorDropdown: DropdownNode?
    private var skinColorDropdown: DropdownNode?
    private var deleteButtons: [EventParameter: ASButtonNode] = [:]
    private var sliderTouchObservers: [ASDisplayNode: NSKeyValueObservation] = [:]

    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?
    
    private let eventGalleryLabel: ASTextNode
    
    var galleryItems: [EventGalleryItem] = []
    private let dashedUploadNode = DashedUploadNode()
    
    lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.isScrollEnabled = false
        collection.delaysContentTouches = false
        collection.register(EventGalleryCell.self, forCellWithReuseIdentifier: "EventGalleryCell")
        return collection
    }()

    private let applyButton: ASControlNode

    var onCreateEventTapped: (() -> Void)?
    var onAddParametersTapped: ((Set<EventParameter>) -> Void)?
    private let addPhoto: () -> Void
    var selectCountryCode: (() -> Void)?
    var scheduleTimeController: ((TimeControllerMode) -> Void)?
    var showAlert: ((String) -> Void)?
    var onAddGalleryPhotoTapped: (() -> Void)?
    var loadEventTypesList: ((Int, Int) -> Void)?

    // private var isLoadingAgencies: Bool = false
    private var countryId: String = ""

    private var eventTypeItems: [AgencyItem] = []
    private var selectedEventTypeId: Int?
    private var eventTypeOffset: Int = 0
    private var eventTypeLimit: Int = 20
    private var isLoadingEventTypes: Bool = false
    private var hasMoreEventTypes: Bool = true
    
    var avatarFileUuid: String? = nil
    var isAvatarUploading: Bool = false

    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                self.currentPhotoNode.image = generateImage(CGSize(width: 110.0, height: 110.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.draw(currentPhoto.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.destinationOut)
                    context.draw(roundCorners(diameter: size.width).cgImage!, in: CGRect(origin: CGPoint(), size: size))
                })
            } else {
                self.currentPhotoNode.image = nil
            }
        }
    }

    private var currentLayoutData: (ContainerViewLayout, CGFloat, CGFloat)?

    init(context: AccountContext, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData

        self.presentationDataPromise = Promise(self.presentationData)

        self.scrollNode = ASScrollNode()

        let iconColor = DivoColorPalette.accentCopperDeep

        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setImage(
            generateTintedImage(
                image: UIImage(bundleImageName: "Components/AddPhotoIcon"),
                color: iconColor),
            for: .normal)

        let buttonDiameter: CGFloat = 110.0

        self.addPhotoButton.setBackgroundImage(
            generateFilledCircleImage(diameter: buttonDiameter,
                                      color: .white,
                                      strokeColor: iconColor,
                                      strokeWidth: 1,
                                      backgroundColor: nil),
            for: .normal
        )

        self.addPhotoButton.allowsGroupOpacity = true

        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true

        let headerColor = DivoColorPalette.systemLabelDark
        let labelColor = DivoColorPalette.systemLabelSecondary
        let regularFont = Font.regular(16)
        let semiboldFont = Font.semibold(16)

        self.eventInfoLabel = ASTextNode()
        self.eventInfoLabel.attributedText = NSAttributedString(string: DivoStrings.eventInfo, font: semiboldFont, textColor: headerColor)

        self.nameEventLabel = ASTextNode()
        self.nameEventLabel.attributedText = NSAttributedString(string: DivoStrings.nameEvent, font: regularFont, textColor: labelColor)

        self.nameEventTextField = getTextFiel(title: DivoStrings.enterNameEvent)

        self.aboutEventLabel = ASTextNode()
        self.aboutEventLabel.attributedText = NSAttributedString(string: DivoStrings.aboutEvent, font: regularFont, textColor: labelColor)

        self.aboutEventTextField = getEditableText(placeholder: DivoStrings.descriptionEvent)

        let eventTypeDropdown = DropdownNode(
            title: DivoStrings.eventType,
            placeholder: DivoStrings.chooseEventType,
            options: [],
            backgroundColor: DivoColorPalette.inputBackgroundMuted,
            placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
            titleColor: DivoColorPalette.systemLabelSecondary,
            arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
            apperTitleColor: DivoColorPalette.systemLabelSecondary,
            allowsMultipleSelection: false
        )

        self.eventTypeDropdown = eventTypeDropdown

        self.eventDateLabel = ASTextNode()
        self.eventDateLabel.attributedText = NSAttributedString(string: DivoStrings.eventDate, font: regularFont, textColor: labelColor)
        self.eventDateTextField = getTextFiel(title: "27 Jun 2025")

        self.eventTimeLabel = ASTextNode()
        self.eventTimeLabel.attributedText = NSAttributedString(string: DivoStrings.eventTime, font: regularFont, textColor: labelColor)
        self.eventTimeTextField = getTextFiel(title: "00:00")

        self.venueEventLabel = ASTextNode()
        self.venueEventLabel.attributedText = NSAttributedString(string: DivoStrings.venueOfEvent, font: regularFont, textColor: labelColor)
        self.venueEventTextField = getTextFiel(title: DivoStrings.chooseCountry)

        self.parametersApplyingLabel = ASTextNode()
        self.parametersApplyingLabel.attributedText = NSAttributedString(string: DivoStrings.parametersForApplying, font: semiboldFont, textColor: headerColor)

        self.addParametersButton = ButtonWithIconNode(title: DivoStrings.addParameters, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.addParametersButton.backgroundColor = DivoColorPalette.accentCopperWarm
        self.addParametersButton.cornerRadius = 4.0
        self.addParametersButton.clipsToBounds = true

        self.applyButton = ButtonWithIconNode(title: DivoStrings.createEventButton, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = DivoColorPalette.accentCopperWarm

        self.eventGalleryLabel = ASTextNode()
        self.eventGalleryLabel.attributedText = NSAttributedString(string: DivoStrings.eventGallery, font: semiboldFont, textColor: headerColor)

        super.init()
        self.nameEventTextField.textField.delegate = self
        self.venueEventTextField.textField.delegate = self
        self.eventDateTextField.textField.delegate = self
        self.eventTimeTextField.textField.delegate = self

        self.backgroundColor = .white
        self.addSubnode(self.scrollNode)
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.scrollNode.addSubnode(self.addPhotoButton)
        self.scrollNode.addSubnode(self.eventInfoLabel)

        self.scrollNode.addSubnode(self.nameEventLabel)
        self.scrollNode.addSubnode(self.nameEventTextField)

        self.scrollNode.addSubnode(self.aboutEventLabel)
        self.scrollNode.addSubnode(self.aboutEventTextField)

        self.scrollNode.addSubnode(eventTypeDropdown)

        self.scrollNode.addSubnode(self.eventDateLabel)
        self.scrollNode.addSubnode(self.eventDateTextField)

        self.scrollNode.addSubnode(self.eventTimeLabel)
        self.scrollNode.addSubnode(self.eventTimeTextField)

        self.scrollNode.addSubnode(self.venueEventLabel)
        self.scrollNode.addSubnode(self.venueEventTextField)

        self.scrollNode.addSubnode(self.parametersApplyingLabel)
        self.scrollNode.addSubnode(self.addParametersButton)

        self.scrollNode.addSubnode(self.eventGalleryLabel)
        self.scrollNode.addSubnode(self.dashedUploadNode)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        self.scrollNode.view.addGestureRecognizer(tapGesture)
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        self.scrollNode.addSubnode(self.applyButton)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings

                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))

                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
    }

    deinit {
        self.disposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }

    override func didLoad() {
        super.didLoad()

        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        self.addParametersButton.addTarget(self, action: #selector(self.addParametersTapped), forControlEvents: .touchUpInside)
        self.dashedUploadNode.addTarget(self, action: #selector(dashedUploadTapped), forControlEvents: .touchUpInside)

        self.galleryCollectionView.delegate = self
        self.galleryCollectionView.dataSource = self
        
        self.scrollNode.view.addSubview(self.galleryCollectionView)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == eventDateTextField.textField {
            scheduleTimeController?(.date)
            return false
        }
        if textField == eventTimeTextField.textField {
            scheduleTimeController?(.time)
            return false
        }
        if textField == venueEventTextField.textField {
            selectCountryCode?()
            return false
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameEventTextField.textField {
            textField.resignFirstResponder()
            return true
        }
        return true
    }

    func updateCountry(countryId: String, countryName: String) {
        venueEventTextField.textField.text = countryName
        self.countryId = countryId
    }
    
    func populate(with detail: EventFullDetailData) {

        // Меняем текст кнопки на "Сохранить изменения" для режима редактирования
        (self.applyButton as? ButtonWithIconNode)?.setTitle(DivoStrings.saveChanges)

        // 1. Основная информация
        nameEventTextField.textField.text = detail.title
        aboutEventTextField.setText(detail.description ?? "")
        
        // 2. Тип эвента
        if let typeTitle = detail.type?.title {
            eventTypeDropdown.selectedValue = typeTitle
        }
        
        // 3. Локация
        if let address = detail.address {
            venueEventTextField.textField.text = address.formatted ?? address.city?.name
            if let cityId = address.city?.id {
                self.countryId = "\(cityId)"
            }
        }
        
        // 4. Дата и время
        if let dateString = detail.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: dateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                // Используем уже готовый метод для обновления UI и внутренних переменных
                self.updateTime(timestamp, .date)
                self.updateTime(timestamp, .time)
            }
        }
        
        // 5. Динамические параметры (Слайдеры и Дропдауны)
        var paramsToActivate: Set<EventParameter> = []
        
        if let attrs = detail.modelAttributes {
            // Определяем, какие параметры активны
            if attrs.age != nil { paramsToActivate.insert(.age) }
            if attrs.height != nil { paramsToActivate.insert(.height) }
            if attrs.weight != nil { paramsToActivate.insert(.weight) }
            if attrs.breastSize != nil { paramsToActivate.insert(.breast) }
            if attrs.waist != nil { paramsToActivate.insert(.waist) }
            if attrs.hips != nil { paramsToActivate.insert(.hips) }
            if attrs.shoesSize != nil { paramsToActivate.insert(.shoeSize) }
            
            if let gender = attrs.gender, !gender.isEmpty { paramsToActivate.insert(.gender) }
            if let hairColor = attrs.hairColor, !hairColor.isEmpty { paramsToActivate.insert(.hairColor) }
            if let hairLength = attrs.hairLength, !hairLength.isEmpty { paramsToActivate.insert(.hairLength) }
            if let eyeColor = attrs.eyeColor, !eyeColor.isEmpty { paramsToActivate.insert(.eyeColor) }
            if let skinColor = attrs.skinColor, !skinColor.isEmpty { paramsToActivate.insert(.skinColor) }
            
            // Активируем нужные UI элементы (вызовет перестроение интерфейса)
            self.updateSelectedParameters(paramsToActivate, animated: false)
            
            // Заполняем слайдеры значениями
            if let age = attrs.age, let min = age.from, let max = age.to {
                self.ageSlider?.setRange(min: Int(min), max: Int(max))
            }
            if let height = attrs.height, let min = height.from, let max = height.to {
                // Если сервер возвращает в см (170), а вы храните в метрах (1.70), разделите на 100
                self.heightSlider?.setRange(min: Double(min / 100.0), max: Double(max / 100.0))
            }
            if let weight = attrs.weight, let min = weight.from, let max = weight.to {
                self.weightSlider?.setRange(min: Double(min), max: Double(max))
            }
            if let breast = attrs.breastSize, let min = breast.from, let max = breast.to {
                self.breastSlider?.setRange(min: Double(min), max: Double(max))
            }
            if let waist = attrs.waist, let min = waist.from, let max = waist.to {
                self.waistSlider?.setRange(min: Double(min), max: Double(max))
            }
            if let hips = attrs.hips, let min = hips.from, let max = hips.to {
                self.hipsSlider?.setRange(min: Double(min), max: Double(max))
            }
            if let shoes = attrs.shoesSize, let min = shoes.from, let max = shoes.to {
                self.shoeSizeSlider?.setRange(min: Double(min), max: Double(max))
            }
            
            // Заполняем мульти-выбор (дропдауны)
            if let gender = attrs.gender {
                self.genderDropdown?.selectedValues = gender.compactMap { $0.title }
            }
            if let hairColor = attrs.hairColor {
                self.hairColorDropdown?.selectedValues = hairColor.compactMap { $0.title }
            }
            if let hairLength = attrs.hairLength {
                self.hairLengthDropdown?.selectedValues = hairLength.compactMap { $0.title }
            }
            if let eyeColor = attrs.eyeColor {
                self.eyeColorDropdown?.selectedValues = eyeColor.compactMap { $0.title }
            }
            if let skinColor = attrs.skinColor {
                self.skinColorDropdown?.selectedValues = skinColor.compactMap { $0.title }
            }
        }
        
        // 6. Галерея и Обложка (Фотографии)
        if let files = detail.files {
            loadExistingFiles(files)
        }
    }
    
    private func loadExistingFiles(_ files: [EventFile]) {
        // Очищаем текущие файлы на случай повторной загрузки
        self.galleryItems.removeAll()
        self.avatarFileUuid = nil
        
        // Сортируем по order (0 - это обычно обложка/аватарка)
        let sortedFiles = files.sorted { ($0.order ?? 99) < ($1.order ?? 99) }
        
        for file in sortedFiles {
            guard let urlString = file.fullUrl, let url = URL(string: urlString), let fileUuid = file.fileUuid else { continue }
            
            if file.order == 0 {
                // Это обложка (аватар эвента)
                self.avatarFileUuid = fileUuid
                
                // Используем ваш ImageLoader или URLSession для загрузки
                Task { @MainActor in
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            self.currentPhoto = image
                        }
                    } catch { }
                }
            } else {
                // Это картинка для галереи
                Task { @MainActor in
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            // Создаем готовый item (isUploading: false), так как он уже есть на сервере
                            let item = EventGalleryItem(image: image, isUploading: false, fileUuid: fileUuid)
                            self.galleryItems.append(item)
                            self.galleryCollectionView.reloadData()

                            if let (layout, navHeight, actualNavHeight) = self.currentLayoutData {
                                self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: .immediate)
                            }
                        }
                    } catch { }
                }
            }
        }
    }

    func updateTime(_ timestamp: Int32, _ mode: TimeControllerMode) {

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateString = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "HH:mm"
        let timeString = dateFormatter.string(from: date)

        switch mode {
        case .time:
            eventTime = timestamp
            eventTimeTextField.textField.text = timeString
        case .date:
            eventDate = timestamp
            eventDateTextField.textField.text = dateString
        }
    }

    func startPhotoUpload(image: UIImage) -> EventGalleryItem {
        let item = EventGalleryItem(image: image, isUploading: true)
        let wasEmpty = galleryItems.isEmpty
        galleryItems.append(item)
        
        if wasEmpty {
            galleryCollectionView.isHidden = false
        }
        galleryCollectionView.reloadData()
        if let (layout, navHeight, actualNavHeight) = self.currentLayoutData {
            self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: .immediate)
        }
        return item
    }
    
    func finishPhotoUpload(item: EventGalleryItem, fileUuid: String) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems[index].isUploading = false
        galleryItems[index].fileUuid = fileUuid
        galleryCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
    
    func cancelPhotoUpload(item: EventGalleryItem) {
        removePhoto(item: item)
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
        self.eventTypeDropdown.isLoading = false
        
        self.eventTypeDropdown.updateOptions(self.eventTypeItems.map { $0.title })

        if self.hasMoreEventTypes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.loadMoreEventTypes()
            }
        }
    }
    
    func configureEventTypeList(_ items: [AgencyItem], totalCount: Int) {
        self.eventTypeItems = items
        self.eventTypeDropdown.options = items.map { $0.title }
        self.eventTypeDropdown.isLoading = false
        self.eventTypeDropdown.setNeedsLayout()
        self.hasMoreEventTypes = self.eventTypeOffset + self.eventTypeLimit < totalCount
    }
    
    func appendEventTypeItems(_ items: [AgencyItem]) {
        self.eventTypeItems.append(contentsOf: items)
        self.eventTypeDropdown.options = self.eventTypeItems.map { $0.title }
        self.eventTypeDropdown.setNeedsLayout()
    }
    
    func removePhoto(item: EventGalleryItem) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems.remove(at: index)
        
        let indexPath = IndexPath(item: index, section: 0)
        galleryCollectionView.performBatchUpdates({
            galleryCollectionView.deleteItems(at: [indexPath])
            triggerLayoutUpdate()
        }, completion: { [weak self] _ in
            if self?.galleryItems.isEmpty == true {
                self?.galleryCollectionView.isHidden = true
            }
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        self.currentLayoutData = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        let avatarSize: CGSize = CGSize(width: 100.0, height: 100.0)
        let avatarX: CGFloat = floor((layout.size.width - avatarSize.width) / 2.0)
        
        transition.updateFrame(node: self.addPhotoButton, frame: CGRect(origin: CGPoint(x: avatarX, y: 20), size: avatarSize))
        transition.updateFrame(node: self.currentPhotoNode, frame: CGRect(origin: CGPoint(), size: avatarSize))
        
        let topInset: CGFloat = navigationBarHeight
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 20.0
        let itemSpacing: CGFloat = 12.0
        let itemHeight: CGFloat = 48.0
        let halfItemSpacing: CGFloat = 10.0
        let fullWidth = layout.size.width - sidePadding * 2
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        var currentY: CGFloat = 140.0
        
        let eventInfoSize = self.eventInfoLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.eventInfoLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventInfoSize))
        currentY += eventInfoSize.height + sectionSpacing
        
        let nameEventLabelSize = self.nameEventLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.nameEventLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: nameEventLabelSize))
        currentY += nameEventLabelSize.height + halfItemSpacing
        
        transition.updateFrame(node: self.nameEventTextField, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: fullWidth, height: itemHeight)))
        currentY += itemHeight + sectionSpacing
        
        let aboutEventLabelSize = self.aboutEventLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.aboutEventLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: aboutEventLabelSize))
        currentY += aboutEventLabelSize.height + halfItemSpacing
        
        let aboutEventHeight: CGFloat = 120.0
        transition.updateFrame(node: self.aboutEventTextField, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: fullWidth, height: aboutEventHeight)))
        currentY += aboutEventHeight + sectionSpacing
        
        transition.updateFrame(node: eventTypeDropdown, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: fullWidth, height: 80)))
        currentY += 80 + sectionSpacing
        
        let dateWidth: CGFloat = floor((layout.size.width - sidePadding * 3) / 2.0)
        
        let eventDateLabelSize = self.eventDateLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.eventDateLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventDateLabelSize))
        
        let eventTimeLabelSize = self.eventTimeLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.eventTimeLabel, frame: CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: eventTimeLabelSize))
        currentY += max(eventDateLabelSize.height, eventTimeLabelSize.height) + halfItemSpacing
        
        transition.updateFrame(node: self.eventDateTextField, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: dateWidth, height: itemHeight)))
        transition.updateFrame(node: self.eventTimeTextField, frame: CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: CGSize(width: dateWidth, height: itemHeight)))
        currentY += itemHeight + sectionSpacing
        
        let venueEventLabelSize = self.venueEventLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.venueEventLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: venueEventLabelSize))
        currentY += venueEventLabelSize.height + halfItemSpacing
        
        transition.updateFrame(node: self.venueEventTextField, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: fullWidth, height: itemHeight)))
        currentY += itemHeight + sectionSpacing
        
        let paramLabelSize = self.parametersApplyingLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.parametersApplyingLabel, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: paramLabelSize))

        var paramsStartY = currentY + paramLabelSize.height + itemSpacing

        if !self.addParametersButton.isHidden {
            let buttonSize = self.addParametersButton.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
            if !self.selectedParameters.isEmpty {
                let addParamsButtonHeight: CGFloat = 28.0
                let addParamsButtonWidth = max(buttonSize.width + 24.0, 70.0)
                let buttonX = layout.size.width - sidePadding - addParamsButtonWidth
                let buttonY = currentY + (paramLabelSize.height - addParamsButtonHeight) / 2.0
                transition.updateFrame(node: self.addParametersButton, frame: CGRect(x: buttonX, y: buttonY, width: addParamsButtonWidth, height: addParamsButtonHeight))
            } else {
                let addParamsButtonWidth = max(buttonSize.width + 32.0, 160.0)
                let addParamsButtonHeight: CGFloat = 35.0
                transition.updateFrame(node: self.addParametersButton, frame: CGRect(origin: CGPoint(x: sidePadding, y: paramsStartY), size: CGSize(width: addParamsButtonWidth, height: addParamsButtonHeight)))
                paramsStartY += addParamsButtonHeight + sectionSpacing
            }
        }

        currentY = paramsStartY

        for param in EventParameter.allCases {
            if selectedParameters.contains(param) {
                let node = getOrCreateNode(for: param)

                let nodeHeight: CGFloat = (node is DropdownNode) ? 80.0 : 80.0

                let deleteButtonSize: CGFloat = 24.0
                let deleteButtonFrame = CGRect(x: layout.size.width - sidePadding - deleteButtonSize, y: (node is DropdownNode) ? currentY + (nodeHeight - deleteButtonSize) / 2.0 + 14.0: currentY + (nodeHeight - deleteButtonSize) / 2.0 - 6.0, width: deleteButtonSize, height: deleteButtonSize)

                if let deleteButton = deleteButtons[param] {
                    transition.updateFrame(node: deleteButton, frame: deleteButtonFrame)
                }
                
                transition.updateFrame(node: node, frame: CGRect(x: sidePadding, y: currentY, width: fullWidth - deleteButtonSize - 10, height: nodeHeight))
                currentY += nodeHeight + sectionSpacing
            }
        }
        
        currentY += sectionSpacing
        
        let galleryLabelSize = self.eventGalleryLabel.measure(CGSize(width: fullWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.eventGalleryLabel, frame: CGRect(x: sidePadding, y: currentY, width: galleryLabelSize.width, height: galleryLabelSize.height))
        currentY += galleryLabelSize.height + itemSpacing
        
        if galleryItems.isEmpty {
            galleryCollectionView.isHidden = true
            dashedUploadNode.isHidden = false
            transition.updateFrame(node: self.dashedUploadNode, frame: CGRect(x: sidePadding, y: currentY, width: fullWidth, height: 100))
            currentY += 100 + sectionSpacing
        } else {
            galleryCollectionView.isHidden = false
            dashedUploadNode.isHidden = false

            let itemWidth = floor(fullWidth / 3.0)
            let rows = ceil(CGFloat(galleryItems.count) / 3.0)
            let collectionHeight = (rows * itemWidth) + ((rows - 1) * 4.0)

            transition.updateFrame(view: self.galleryCollectionView, frame: CGRect(x: sidePadding, y: currentY, width: fullWidth, height: collectionHeight))
            currentY += collectionHeight + 12
            
            transition.updateFrame(node: self.dashedUploadNode, frame: CGRect(x: sidePadding, y: currentY, width: fullWidth, height: 100))
            currentY += 100 + sectionSpacing
        }
        
        if self.applyButton.supernode != nil && !self.applyButton.isHidden {
            let buttonHeight: CGFloat = 50.0
            transition.updateFrame(node: self.applyButton, frame: CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: fullWidth, height: buttonHeight)))
            currentY += buttonHeight + sectionSpacing
        }

        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY + 20.0)

        self.readyValue = true
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict
        self.hairLengthDropdown?.options = dict.hairLength.map { $0.title }
        self.hairColorDropdown?.options = dict.hairColor.map { $0.title }
        self.eyeColorDropdown?.options = dict.eyeColor.map { $0.title }
        self.skinColorDropdown?.options = dict.skinColor.map { $0.title }
    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        self.genderDropdown?.options = dict.data.map { $0.title }
    }
    
    func updateSelectedParameters(_ params: Set<EventParameter>, animated: Bool = true) {
        self.selectedParameters = params

        let allParametersSet = Set(EventParameter.allCases)
        let shouldShowAddButton = params != allParametersSet
        self.addParametersButton.isHidden = !shouldShowAddButton

        if params.isEmpty {
            if let button = self.addParametersButton as? ButtonWithIconNode {
                button.setTitle(DivoStrings.addParameters)
            }
        } else {
            if let button = self.addParametersButton as? ButtonWithIconNode {
                button.setTitle(DivoStrings.addShort)
            }
        }

        var newNodes: [ASDisplayNode] = []

        for param in params {
            let node = getOrCreateNode(for: param)
            if node.supernode == nil {
                self.scrollNode.addSubnode(node)
                newNodes.append(node)
            }

            if deleteButtons[param] == nil {
                deleteButtons[param] = makeDeleteButton(for: param)
            }
            let deleteButton = deleteButtons[param]!
            if deleteButton.supernode == nil {
                self.scrollNode.addSubnode(deleteButton)
                newNodes.append(deleteButton)
            }
        }

        for (param, button) in deleteButtons {
            if !params.contains(param) {
                button.removeFromSupernode()
                deleteButtons.removeValue(forKey: param)
            }
        }

        let allNodes: [ASDisplayNode?] = [genderDropdown, ageSlider, heightSlider, weightSlider, breastSlider, waistSlider, hipsSlider, shoeSizeSlider, hairLengthDropdown, hairColorDropdown, eyeColorDropdown, skinColorDropdown]
        for node in allNodes {
            node?.isHidden = true
        }
        for param in params {
            getOrCreateNode(for: param).isHidden = false
        }

        if let (layout, navHeight, actualNavHeight) = self.currentLayoutData {
            if animated && !newNodes.isEmpty {
                for node in newNodes {
                    node.alpha = 0.0
                }
                self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: .immediate)
                UIView.animate(withDuration: 0.3) {
                    for node in newNodes {
                        node.alpha = 1.0
                    }
                }
            } else {
                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .spring) : .immediate
                self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: transition)
            }
        }
    }

    private func triggerLayoutUpdate() {
        if let (layout, navHeight, actualNavHeight) = self.currentLayoutData {
            self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: .animated(duration: 0.3, curve: .spring))
        }
    }

    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
    }
    
    private func getOrCreateNode(for param: EventParameter) -> ASDisplayNode {
        switch param {
        case .gender:
            if genderDropdown == nil {
                genderDropdown = DropdownNode(
                    title: DivoStrings.gender,
                    placeholder: DivoStrings.selectGender,
                    options: [],
                    backgroundColor: DivoColorPalette.inputBackgroundMuted,
                    placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    titleColor: DivoColorPalette.systemLabelSecondary,
                    arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    apperTitleColor: DivoColorPalette.systemLabelSecondary,
                    allowsMultipleSelection: true
                )
            }
            self.genderDropdown?.options = self.genderDictionaries?.data.map { $0.title } ?? []
            return genderDropdown!
        case .age:
            if ageSlider == nil {
                ageSlider = AgeSliderNode<Int>(
                    title: DivoStrings.ageYo,
                    type: "y.o",
                    mode: .range(minValue: 17, maxValue: 30),
                    minimumValue: 14,
                    maximumValue: 45,
                    configuration: .light
                )

            }
            return ageSlider!
        case .height:
            if heightSlider == nil {
                heightSlider = AgeSliderNode<Double>(
                    title: DivoStrings.heightCm,
                    type: "cm",
                    mode: .range(minValue: 1.78, maxValue: 2.20),
                    minimumValue: 1.68,
                    maximumValue: 2.50,
                    configuration: .light
                )

            }
            return heightSlider!
        case .weight:
            if weightSlider == nil {
                weightSlider = AgeSliderNode<Double>(
                    title: DivoStrings.weightKg,
                    type: "kg",
                    mode: .range(minValue: 50, maxValue: 70),
                    minimumValue: 48,
                    maximumValue: 90,
                    configuration: .light
                )

            }
            return weightSlider!
        case .breast:
            if breastSlider == nil {
                breastSlider = AgeSliderNode<Double>(
                    title: DivoStrings.breastCm,
                    type: "cm",
                    mode: .range(minValue: 70, maxValue: 100),
                    minimumValue: 60,
                    maximumValue: 110,
                    configuration: .light
                )

            }
            return breastSlider!
        case .waist:
            if waistSlider == nil {
                waistSlider = AgeSliderNode<Double>(
                    title: DivoStrings.waistCm,
                    type: "cm",
                    mode: .range(minValue: 55, maxValue: 85),
                    minimumValue: 48,
                    maximumValue: 90,
                    configuration: .light
                )

            }
            return waistSlider!
        case .hips:
            if hipsSlider == nil {
                hipsSlider = AgeSliderNode<Double>(
                    title: DivoStrings.hipsCm,
                    type: "cm",
                    mode: .range(minValue: 90, maxValue: 100),
                    minimumValue: 80,
                    maximumValue: 110,
                    configuration: .light
                )

            }
            return hipsSlider!
        case .shoeSize:
            if shoeSizeSlider == nil {
                shoeSizeSlider = AgeSliderNode<Double>(
                    title: DivoStrings.shoeSizeEU,
                    type: "",
                    mode: .range(minValue: 37, maxValue: 42),
                    minimumValue: 36,
                    maximumValue: 46,
                    configuration: .light
                )

            }
            return shoeSizeSlider!
            
            
        case .hairLength:
            if hairLengthDropdown == nil {
                hairLengthDropdown = DropdownNode(
                    title: DivoStrings.hairLength,
                    placeholder: DivoStrings.chooseHairLength,
                    options: [],
                    backgroundColor: DivoColorPalette.inputBackgroundMuted,
                    placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    titleColor: DivoColorPalette.systemLabelSecondary,
                    arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    apperTitleColor: DivoColorPalette.systemLabelSecondary,
                    allowsMultipleSelection: true
                )
            }
            self.hairLengthDropdown?.options = self.appearanceDictionaries?.hairLength.map { $0.title } ?? []
            return hairLengthDropdown!
        case .hairColor:
            if hairColorDropdown == nil {
                hairColorDropdown = DropdownNode(
                    title: DivoStrings.hairColor,
                    placeholder: DivoStrings.chooseHairColor,
                    options: [],
                    backgroundColor: DivoColorPalette.inputBackgroundMuted,
                    placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    titleColor: DivoColorPalette.systemLabelSecondary,
                    arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    apperTitleColor: DivoColorPalette.systemLabelSecondary,
                    allowsMultipleSelection: true
                )
            }
            self.hairColorDropdown?.options = self.appearanceDictionaries?.hairColor.map { $0.title } ?? []
            return hairColorDropdown!
        case .eyeColor:
            if eyeColorDropdown == nil {
                eyeColorDropdown = DropdownNode(
                    title: DivoStrings.eyeColor,
                    placeholder: DivoStrings.chooseEyeColor,
                    options: [],
                    backgroundColor: DivoColorPalette.inputBackgroundMuted,
                    placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    titleColor: DivoColorPalette.systemLabelSecondary,
                    arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    apperTitleColor: DivoColorPalette.systemLabelSecondary,
                    allowsMultipleSelection: true
                )
            }
            self.eyeColorDropdown?.options = self.appearanceDictionaries?.eyeColor.map { $0.title } ?? []
            return eyeColorDropdown!
        case .skinColor:
            if skinColorDropdown == nil {
                skinColorDropdown = DropdownNode(
                    title: DivoStrings.skinColor,
                    placeholder: DivoStrings.chooseSkinColor,
                    options: [],
                    backgroundColor: DivoColorPalette.inputBackgroundMuted,
                    placeholderColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    titleColor: DivoColorPalette.systemLabelSecondary,
                    arrowColor: DivoColorPalette.systemLabelSecondary.withAlphaComponent(0.6),
                    apperTitleColor: DivoColorPalette.systemLabelSecondary,
                    allowsMultipleSelection: true
                )
            }
            self.skinColorDropdown?.options = self.appearanceDictionaries?.skinColor.map { $0.title } ?? []
            return skinColorDropdown!
        }
    }
    
    private func makeDeleteButton(for param: EventParameter) -> ASButtonNode {
        let button = ASButtonNode()
        button.backgroundColor = .clear

        let basketButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Components/Basket"), color: DivoColorPalette.accentSecondary)
        button.setImage(basketButtonImg, for: .normal)
        button.addTarget(self, action: #selector(self.deleteParameterTapped(_:)), forControlEvents: .touchUpInside)
        
        return button
    }

    private func loadMoreEventTypesIfNeeded() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        
        let threshold = max(0, self.eventTypeItems.count - 2)
        let selectedIndex = self.eventTypeItems.firstIndex(where: { $0.id == self.selectedEventTypeId }) ?? -1
        
        if selectedIndex >= threshold {
            self.loadMoreEventTypes()
        }
    }
    
    private func loadMoreEventTypes() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        
        self.isLoadingEventTypes = true
        
        let currentOffset = self.eventTypeItems.count
        self.loadEventTypesList?(currentOffset, self.eventTypeLimit)
    }

    @objc private func addPhotoPressed() {
        self.addPhoto()
    }

    @objc func applyButtonTapped() {
        onCreateEventTapped?()
    }

    // MARK: - Сбор данных
    func collectEventData() throws -> CreateEventRequest {
        
        let title = nameEventTextField.textField.text ?? ""
        let description = aboutEventTextField.text
        let selectedTypeName = eventTypeDropdown.selectedValue

        let typeItem = eventTypeItems.first(where: { $0.title == selectedTypeName })
        let eventTypeId = typeItem?.id ?? 0

        let dateObj = Date(timeIntervalSince1970: TimeInterval(eventDate))
        let timeObj = Date(timeIntervalSince1970: TimeInterval(eventTime))
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeObj)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: dateObj) ?? dateObj
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: finalDate)
        
        let dateToObj = calendar.date(byAdding: .hour, value: 2, to: finalDate) ?? finalDate
        let dateToString = formatter.string(from: dateToObj)
        
        // TODO: DIVO — city picker not implemented, using 1 as hardcoded stub
        let cityId = Int(self.countryId) ?? 1
        let address = EventAddressRequest(
            street: nil,
            house: nil,
            apartment: nil,
            formatted: venueEventTextField.textField.text,
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
        
        var ageRange: EventRangeRequest?
        var heightRange: EventRangeRequest?
        var weightRange: EventRangeRequest?
        var breastRange: EventRangeRequest?
        var waistRange: EventRangeRequest?
        var hipsRange: EventRangeRequest?
        var shoesRange: EventRangeRequest?
        var genders: [String]?
        var hairColors: [Int]?
        var hairLengths: [Int]?
        var eyeColors: [Int]?
        var skinColors: [Int]?
        
        if selectedParameters.contains(.age) {
            let (min, max) = ageSlider?.currentRange ?? (0, 0)
            ageRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        if selectedParameters.contains(.height) {
            let (min, max) = heightSlider?.currentRange ?? (0, 0)
            heightRange = EventRangeRequest(from: Float(min*100), to: Float(max*100))
        }
        if selectedParameters.contains(.weight) {
            let (min, max) = weightSlider?.currentRange ?? (0, 0)
            weightRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        if selectedParameters.contains(.breast) {
            let (min, max) = breastSlider?.currentRange ?? (0, 0)
            breastRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        if selectedParameters.contains(.waist) {
            let (min, max) = waistSlider?.currentRange ?? (0, 0)
            waistRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        if selectedParameters.contains(.hips) {
            let (min, max) = hipsSlider?.currentRange ?? (0, 0)
            hipsRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        if selectedParameters.contains(.shoeSize) {
            let (min, max) = shoeSizeSlider?.currentRange ?? (0, 0)
            shoesRange = EventRangeRequest(from: Float(min), to: Float(max))
        }
        
        if selectedParameters.contains(.gender), let selectedGenders = genderDropdown?.selectedValues, !selectedGenders.isEmpty {
            var selectedIds:[String] = []
            for genderTitle in selectedGenders {
                if let id = genderDictionaries?.data.first(where: { $0.title == genderTitle })?.id {
                    selectedIds.append(id)
                }
            }
            if !selectedIds.isEmpty { genders = selectedIds }
        }
        
        if selectedParameters.contains(.hairColor), let selectedColors = hairColorDropdown?.selectedValues, !selectedColors.isEmpty {
            var selectedIds: [Int] = []
            for colorTitle in selectedColors {
                if let id = appearanceDictionaries?.hairColor.first(where: { $0.title == colorTitle })?.id {
                    selectedIds.append(id)
                }
            }
            if !selectedIds.isEmpty { hairColors = selectedIds }
        }
        
        if selectedParameters.contains(.hairLength), let selectedLengths = hairLengthDropdown?.selectedValues, !selectedLengths.isEmpty {
            var selectedIds: [Int] = []
            for lengthTitle in selectedLengths {
                if let id = appearanceDictionaries?.hairLength.first(where: { $0.title == lengthTitle })?.id {
                    selectedIds.append(id)
                }
            }
            if !selectedIds.isEmpty { hairLengths = selectedIds }
        }
        
        if selectedParameters.contains(.eyeColor), let selectedEyes = eyeColorDropdown?.selectedValues, !selectedEyes.isEmpty {
            var selectedIds: [Int] = []
            for eyeTitle in selectedEyes {
                if let id = appearanceDictionaries?.eyeColor.first(where: { $0.title == eyeTitle })?.id {
                    selectedIds.append(id)
                }
            }
            if !selectedIds.isEmpty { eyeColors = selectedIds }
        }
        
        if selectedParameters.contains(.skinColor), let selectedSkins = skinColorDropdown?.selectedValues, !selectedSkins.isEmpty {
            var selectedIds: [Int] = []
            for skinTitle in selectedSkins {
                if let id = appearanceDictionaries?.skinColor.first(where: { $0.title == skinTitle })?.id {
                    selectedIds.append(id)
                }
            }
            if !selectedIds.isEmpty { skinColors = selectedIds }
        }
        
        // 7. Собираем финальный запрос
        return CreateEventRequest(
            title: title,
            description: description,
            typeId: eventTypeId,
            date: dateString,
            dateTo: dateToString,
            address: address,
            files: eventFiles,
            paymentType: 1,
            paymentFrequency: 1,
            cost: "0",
            role: ["model"],
            gender: genders,
            age: ageRange,
            height: heightRange,
            weight: weightRange,
            breastSize: breastRange,
            waist: waistRange,
            hips: hipsRange,
            shoesSize: shoesRange,
            hairColor: hairColors,
            hairLength: hairLengths,
            eyeColor: eyeColors,
            skinColor: skinColors
        )
    }

    @objc private func addParametersTapped() {
        onAddParametersTapped?(selectedParameters)
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return
        }

        var currentInsets = self.scrollNode.view.contentInset
        currentInsets.bottom = 0

        UIView.animate(withDuration: duration.doubleValue, delay: 0.0, options: UIView.AnimationOptions(rawValue: curve.uintValue << 16), animations: {
            self.scrollNode.view.contentInset = currentInsets
            self.scrollNode.view.scrollIndicatorInsets = currentInsets
        }, completion: nil)
    }

    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return
        }

        let keyboardHeight = keyboardFrame.cgRectValue.height

        var currentInsets = self.scrollNode.view.contentInset

        currentInsets.bottom = keyboardHeight

        UIView.animate(withDuration: duration.doubleValue, delay: 0.0, options: UIView.AnimationOptions(rawValue: curve.uintValue << 16), animations: {
            self.scrollNode.view.contentInset = currentInsets
            self.scrollNode.view.scrollIndicatorInsets = currentInsets
        }, completion: nil)
    }

    @objc private func dashedUploadTapped() {
        onAddGalleryPhotoTapped?()
    }
    
    @objc private func deleteParameterTapped(_ button: ASButtonNode) {
        guard let param = deleteButtons.first(where: { $0.value === button })?.key else {
            return
        }

        self.selectedParameters.remove(param)

        button.removeFromSupernode()
        deleteButtons.removeValue(forKey: param)

        getOrCreateNode(for: param).isHidden = true

        let allParametersSet = Set(EventParameter.allCases)
        self.addParametersButton.isHidden = self.selectedParameters == allParametersSet
        
        if let addButton = self.addParametersButton as? ButtonWithIconNode {
            if self.selectedParameters.isEmpty {
                addButton.setTitle(DivoStrings.addParameters)
            } else {
                addButton.setTitle(DivoStrings.addShort)
            }
        }

        if let (layout, navHeight, actualNavHeight) = self.currentLayoutData {
            self.containerLayoutUpdated(layout, navigationBarHeight: navHeight, actualNavigationBarHeight: actualNavHeight, transition: .animated(duration: 0.3, curve: .spring))
        }
    }

}


// MARK: - Расширение UICollectionViewDataSource и Delegate

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
        let width = floor(collectionView.bounds.width / 3.0)
        return CGSize(width: width, height: width)
    }
}

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()

    field.textField.font = Font.regular(16.0)
    field.textField.textColor = DivoColorPalette.systemLabelBody
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: DivoColorPalette.systemLabelPlaceholder)
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.textField.keyboardType = .default
    field.borderWidth = 1.0
    field.borderColor = DivoColorPalette.overlayDarkFieldBorder.cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    field.backgroundColor = DivoColorPalette.fieldBackgroundLight

    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }

    return field
}

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

private func getEditableText(placeholder: String) -> MultilineTextFieldNode {
    return MultilineTextFieldNode(placeholder: placeholder)
}
