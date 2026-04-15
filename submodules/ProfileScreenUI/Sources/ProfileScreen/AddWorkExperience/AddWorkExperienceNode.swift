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
import DivoUIKit

enum TimeType {
    case start
    case end
}

final class AddWorkExperience: ASDisplayNode, UITextFieldDelegate {

    private let context: AccountContext
    private let editItem: WorkHistoryItem?
    private var startTime: Int32 = 0
    private var endTime: Int32 = 0

    private let topBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
        
    private let navigationBar = DivoNavigationBar()
    
    // MARK: - UI Elements

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 47
        iv.backgroundColor = .white
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.accent.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarEmptyImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.image = UIImage(bundleImageName: "Components/EmptyImageWork")
        iv.isHidden = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarSpinner: DivoSegmentedSpinner = {
        let avatarSpinner = DivoSegmentedSpinner()
        avatarSpinner.isHidden = true
        return avatarSpinner
    }()

    private let eventInfoLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.workExperienceInfo
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameEventLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.agencyName
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameEventTextField: DivoTextField

    private let startDateLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.startDate
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()


    private let endTimeLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.endDate
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let startDateView = DateSelectionControl(placeholder: "27 Jun 2025")
    private let endTimeView = DateSelectionControl(placeholder: "27 Jun 2025")

    private let currentlyWorkingCheckbox: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let uncheckedImage = UIImage(systemName: "square")?
            .withTintColor(DivoColorPalette.primaryText.withAlphaComponent(0.4), renderingMode: .alwaysOriginal)
        let checkedImage = UIImage(systemName: "checkmark.square.fill")?
            .withTintColor(DivoColorPalette.accent, renderingMode: .alwaysOriginal)
        
        button.setImage(uncheckedImage, for: .normal)
        button.setImage(checkedImage, for: .selected)
        
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        button.imageView?.contentMode = .scaleAspectFit
        
        return button
    }()

    private let currentlyWorkingLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.currentlyWorking
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let applyButton = DivoButton()
    private var applyButtonBottomConstraint: NSLayoutConstraint?
    
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
    
    private var keyboardHandler: DivoKeyboardHandler?

    // MARK: - Callbacks

    var scheduleTimeController: ((TimeType) -> Void)?
    var showAlert: ((String) -> Void)?
    var onSave: ((CreateWorkHistoryRequest) -> Void)?
    var onAddPhoto: (() -> Void)?
    var onBackTapped: (() -> Void)?

    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
            avatarEmptyImageView.isHidden = (currentPhoto != nil)
            
            if currentPhoto != nil {
                avatarImageView.alpha = 0
                self.avatarImageView.alpha = 1.0
            }
        }
    }

    // MARK: - Init

    init(context: AccountContext, editItem: WorkHistoryItem? = nil) {
        self.context = context
        self.editItem = editItem
        
        self.nameEventTextField = DivoTextField(title: "", prefix: "")
        self.nameEventTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.enterAgencyName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )

        super.init()

        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: title: editItem != nil ? DivoStrings.navEditExperience.uppercased() : DivoStrings.navCreateExperience.uppercased(),
            backButtonConfiguration: .circle("chevron.left"),
            rightButtonConfiguration: editItem != nil ? .text(DivoStrings.save) : .text(DivoStrings.create),
            onBackTapped: { [weak self] in self?.onBackTapped?() },
            onCircleTextTapped: { [weak self] in self?.applyButtonTapped() }
        )
        
        applyButton.makeDivoButton(
            title: editItem != nil ? DivoStrings.saveChanges : DivoStrings.createNewWorkExperience,
            loading: editItem != nil ? DivoStrings.saving : DivoStrings.creatingNewWorkExperience
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        setupInteractions()

        if let item = editItem {
            prefillEditData(item)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarEmptyImageView)
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarSpinner)

        contentView.addSubview(eventInfoLabel)
        contentView.addSubview(nameEventLabel)
        
        nameEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameEventTextField.view)
        
        contentView.addSubview(startDateLabel)
        contentView.addSubview(endTimeLabel)
        
        contentView.addSubview(startDateView)
        contentView.addSubview(endTimeView)

        contentView.addSubview(currentlyWorkingCheckbox)
        contentView.addSubview(currentlyWorkingLabel)

        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)

        currentlyWorkingCheckbox.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)

        setupConstraints()
    }

    private func setupConstraints() {
        let sidePadding: CGFloat = 16.0
        let avatarSize: CGFloat = 94.0
        
        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns

        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Avatar Container
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            avatarContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarContainer.heightAnchor.constraint(equalToConstant: avatarSize),

            // Avatar Image
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: avatarSize),

            // Add Photo Button
            avatarEmptyImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarEmptyImageView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarEmptyImageView.widthAnchor.constraint(equalToConstant: 32),
            avatarEmptyImageView.heightAnchor.constraint(equalToConstant: 32),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: 32),
            avatarSpinner.heightAnchor.constraint(equalToConstant: 32),

            // Event info label
            eventInfoLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: 32),
            eventInfoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            eventInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),

            // Name label & field
            nameEventLabel.topAnchor.constraint(equalTo: eventInfoLabel.bottomAnchor, constant: 16),
            nameEventLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            nameEventLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),

            nameEventTextField.view.topAnchor.constraint(equalTo: nameEventLabel.bottomAnchor, constant: 6),
            nameEventTextField.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            nameEventTextField.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),

            // Date labels
            startDateLabel.topAnchor.constraint(equalTo: nameEventTextField.view.bottomAnchor, constant: 16),
            startDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),

            endTimeLabel.topAnchor.constraint(equalTo: nameEventTextField.view.bottomAnchor, constant: 16),
            endTimeLabel.leadingAnchor.constraint(equalTo: endTimeView.leadingAnchor),
            
            startDateView.topAnchor.constraint(equalTo: startDateLabel.bottomAnchor, constant: 6),
            startDateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            startDateView.heightAnchor.constraint(equalToConstant: 46),
            
            endTimeView.topAnchor.constraint(equalTo: endTimeLabel.bottomAnchor, constant: 6),
            endTimeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            endTimeView.heightAnchor.constraint(equalToConstant: 46),

            startDateView.widthAnchor.constraint(equalTo: endTimeView.widthAnchor),
            startDateView.trailingAnchor.constraint(equalTo: endTimeView.leadingAnchor, constant: -12),

            currentlyWorkingCheckbox.topAnchor.constraint(equalTo: startDateView.bottomAnchor, constant: 16),
            currentlyWorkingCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),

            currentlyWorkingLabel.centerYAnchor.constraint(equalTo: currentlyWorkingCheckbox.centerYAnchor),
            currentlyWorkingLabel.leadingAnchor.constraint(equalTo: currentlyWorkingCheckbox.trailingAnchor, constant: 6),
            currentlyWorkingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),

            currentlyWorkingCheckbox.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            
            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 160)
        ])
    }

    private func setupInteractions() {
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        startDateView.onDateSelected = { [weak self] timestamp in
            self?.updateTime(timestamp, type: .start)
        }
        
        endTimeView.onDateSelected = { [weak self] timestamp in
            self?.updateTime(timestamp, type: .end)
        }
        
        startDateView.onBeginEditing = { [weak self] in
            guard let self else { return }
            self.scrollToView(self.startDateView)
        }
        
        endTimeView.onBeginEditing = { [weak self] in
            guard let self else { return }
            self.scrollToView(self.endTimeView)
        }
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(dismissTap)
        scrollView.keyboardDismissMode = .interactive
        
        let fields = [nameEventTextField]
        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 0,
            scrollToActiveField: { [weak self] in
                guard let self else { return }
                
                if self.nameEventTextField.textField.isFirstResponder {
                    self.scrollToView(self.nameEventTextField.view)
                }
                else if self.startDateView.isActive {
                    self.scrollToView(self.startDateView)
                }
                else if self.endTimeView.isActive {
                    self.scrollToView(self.endTimeView)
                }
            }
        )
        keyboardHandler?.subscribe()
        
        for (index, field) in fields.enumerated() {
            let isLast = index == fields.count - 1
            field.textField.returnKeyType = isLast ? .done : .next
            if !isLast {
                let nextField = fields[index + 1]
                field.onReturn = { [weak nextField] in
                    nextField?.textField.becomeFirstResponder()
                }
            }
            field.onBeginEditing = { [weak self, weak field] in
                guard let self, let field else { return }
                self.scrollToView(field.view)
            }
        }
    }
    private func prefillEditData(_ item: WorkHistoryItem) {
        nameEventTextField.textField.text = item.agencyDisplayName ?? item.agencyName
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM yyyy"
        displayFormatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)
        
        if let startStr = item.startDate, let startDate = inputFormatter.date(from: startStr) {
            startTime = Int32(startDate.timeIntervalSince1970)
            startDateView.setDate(timestamp: startTime, localeIdentifier: DivoStrings.current.localeIdentifier)
        }
        
        if item.isCurrent == true {
            currentlyWorkingCheckbox.isSelected = true
            endTimeLabel.isHidden = true
            endTimeView.isHidden = true
        } else if let endStr = item.endDate, let endDate = inputFormatter.date(from: endStr) {
            endTime = Int32(endDate.timeIntervalSince1970)
            endTimeView.setDate(timestamp: endTime, localeIdentifier: DivoStrings.current.localeIdentifier)
        }
    }

    private static func formatDateForAPI(timestamp: Int32) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func scrollToView(_ targetView: UIView) {
        let frame = targetView.frame.insetBy(dx: 0, dy: -16)
        scrollView.scrollRectToVisible(frame, animated: true)
    }

    func updateTime(_ timestamp: Int32, type: TimeType) {
        let locale = DivoStrings.current.localeIdentifier
        
        switch type {
        case .start:
            startTime = timestamp
            startDateView.setDate(timestamp: timestamp, localeIdentifier: locale)
        case .end:
            endTime = timestamp
            endTimeView.setDate(timestamp: timestamp, localeIdentifier: locale)
        }
    }
    
    func loadAvatar(isLoading: Bool) {
        isLoading ? avatarSpinner.startAnimating() : avatarSpinner.stopAnimating()
        avatarSpinner.isHidden = !isLoading
        avatarEmptyImageView.isHidden = isLoading
    }

    func toggleSpinner(active: Bool) {
        applyButton.setSaving(active, in: self.view)
    }
    
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func addPhotoPressed() {
        onAddPhoto?()
    }
    
    @objc private func checkboxTapped() {
        currentlyWorkingCheckbox.isSelected.toggle()
        if currentlyWorkingCheckbox.isSelected {
            endTimeLabel.isHidden = true
            endTimeView.isHidden = true
        } else {
            endTimeLabel.isHidden = false
            endTimeView.isHidden = false
        }
    }
    
    @objc private func backPressed() { onBackTapped?() }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.alpha = 0.6; sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95) }
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) { sender.alpha = 1.0; sender.transform = .identity }
    }

    @objc func applyButtonTapped() {
        let agencyName = nameEventTextField.textField.text ?? ""

        guard startTime > 0 else {
            showAlert?(DivoStrings.pleaseFillStartDate)
            return
        }

        let isCurrent = currentlyWorkingCheckbox.isSelected

        let body = CreateWorkHistoryRequest(
            agencyId: nil,
            agencyName: agencyName.isEmpty ? nil : agencyName,
            startDate: Self.formatDateForAPI(timestamp: startTime),
            endDate: isCurrent ? nil : (endTime > 0 ? Self.formatDateForAPI(timestamp: endTime) : nil),
            isCurrent: isCurrent
        )

        onSave?(body)
    }
}


// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
