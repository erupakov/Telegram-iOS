import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
import DivoCore
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
    private var startTime: Int32?
    private var endTime: Int32?

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
        iv.image = DivoImage.emptyImageWork
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

    private let startDateView: DateSelectionControl
    private let endTimeView: DateSelectionControl

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
    
    // MARK: - Autocomplete Elements
    private let autocompleteContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 16
        view.isHidden = true
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let autocompleteTableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.clipsToBounds = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let autocompleteLoader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()
    
    private var autocompleteHeightConstraint: NSLayoutConstraint?
    private var autocompleteBottomConstraint: NSLayoutConstraint?
    private var currentAgencyResults: [AgencyItem] = []
    private var isScrollLocked = false
    
    private var searchTimer: Timer?
    
    var requestAgencySearch: ((String) -> Void)?
    
    private var selectedAgencyId: Int? = nil
    
    // MARK: - Callbacks
    
    var scheduleTimeController: ((TimeType) -> Void)?
    var onSave: ((CreateWorkHistoryRequest) -> Void)?
    var onLoadPhoto: ((Int?) -> Void)?
    var onBackTapped: (() -> Void)?
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
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
        
        let today = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: today) ?? today
        
        startDateView = DateSelectionControl(placeholder: Int32(oneMonthAgo.timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier)
        endTimeView = DateSelectionControl(placeholder: Int32(today.timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier)

        super.init()
        
        startDateView.datePicker.maximumDate = today
        startDateView.datePicker.date = oneMonthAgo
        endTimeView.datePicker.maximumDate = today
        endTimeView.datePicker.minimumDate = oneMonthAgo
        endTimeView.datePicker.date = Date()

        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: editItem != nil ? DivoStrings.navEditExperience.uppercased() : DivoStrings.navCreateExperience.uppercased(),
            backButtonConfiguration: .circle("chevron.left"),
            rightButtonConfiguration: editItem != nil ? .text(DivoStrings.save) : .text(DivoStrings.create),
            onBackTapped: { [weak self] in self?.onBackTapped?() },
            onCircleTextTapped: { [weak self] in self?.applyButtonTapped() }
        )
        
        applyButton.makeDivoButton(
            title: editItem != nil ? DivoStrings.saveChanges : DivoStrings.createNewWorkExperience,
            loading: editItem != nil ? DivoStrings.saving : DivoStrings.creatingNewWorkExperience
        )
        updateApplyButtonState()
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
        
        contentView.addSubview(currentlyWorkingLabel)
        
        contentView.addSubview(autocompleteContainer)
        autocompleteContainer.addSubview(autocompleteTableView)
        autocompleteContainer.addSubview(autocompleteLoader)
        
        autocompleteTableView.delegate = self
        autocompleteTableView.dataSource = self
        autocompleteTableView.register(UITableViewCell.self, forCellReuseIdentifier: "AgencyCell")
        
        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)

        currentlyWorkingCheckbox.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)

        setupConstraints()
    }

    private func setupConstraints() {
        let avatarSize: CGFloat = 94.0
        
        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns

        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
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
            avatarEmptyImageView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarEmptyImageView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),

            // Event info label
            eventInfoLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.xl),
            eventInfoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            eventInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            // Name label & field
            nameEventLabel.topAnchor.constraint(equalTo: eventInfoLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            nameEventLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            nameEventLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            nameEventTextField.view.topAnchor.constraint(equalTo: nameEventLabel.bottomAnchor, constant: 6),
            nameEventTextField.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            nameEventTextField.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),
            
            autocompleteContainer.topAnchor.constraint(equalTo: nameEventTextField.view.bottomAnchor, constant: 4),
            autocompleteContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            autocompleteContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            autocompleteTableView.topAnchor.constraint(equalTo: autocompleteContainer.topAnchor),
            autocompleteTableView.leadingAnchor.constraint(equalTo: autocompleteContainer.leadingAnchor),
            autocompleteTableView.trailingAnchor.constraint(equalTo: autocompleteContainer.trailingAnchor),
            autocompleteTableView.bottomAnchor.constraint(equalTo: autocompleteContainer.bottomAnchor),
            
            autocompleteLoader.centerXAnchor.constraint(equalTo: autocompleteContainer.centerXAnchor),
            autocompleteLoader.centerYAnchor.constraint(equalTo: autocompleteContainer.centerYAnchor),

            // Date labels
            startDateLabel.topAnchor.constraint(equalTo: nameEventTextField.view.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            startDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),

            endTimeLabel.topAnchor.constraint(equalTo: nameEventTextField.view.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            endTimeLabel.leadingAnchor.constraint(equalTo: endTimeView.leadingAnchor),
            
            startDateView.topAnchor.constraint(equalTo: startDateLabel.bottomAnchor, constant: 6),
            startDateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            startDateView.heightAnchor.constraint(equalToConstant: 46),
            
            endTimeView.topAnchor.constraint(equalTo: endTimeLabel.bottomAnchor, constant: 6),
            endTimeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            endTimeView.heightAnchor.constraint(equalToConstant: 46),

            startDateView.widthAnchor.constraint(equalTo: endTimeView.widthAnchor),
            startDateView.trailingAnchor.constraint(equalTo: endTimeView.leadingAnchor, constant: -12),

            currentlyWorkingCheckbox.topAnchor.constraint(equalTo: startDateView.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            currentlyWorkingCheckbox.topAnchor.constraint(equalTo: endTimeView.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            currentlyWorkingCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),

            currentlyWorkingLabel.centerYAnchor.constraint(equalTo: currentlyWorkingCheckbox.centerYAnchor),
            currentlyWorkingLabel.leadingAnchor.constraint(equalTo: currentlyWorkingCheckbox.trailingAnchor, constant: 6),
            currentlyWorkingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            currentlyWorkingCheckbox.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 160)
        ])

        autocompleteHeightConstraint = autocompleteContainer.heightAnchor.constraint(equalToConstant: 0)
        autocompleteHeightConstraint?.isActive = true
        
        autocompleteBottomConstraint = autocompleteContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
    }

    private func setupInteractions() {
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        startDateView.onDateSelected = { [weak self] timestamp in
            if let currentEndTime = self?.endTime {
                if timestamp > currentEndTime {
                    self?.endTime = timestamp
                    self?.endTimeView.setDate(timestamp: timestamp)
                }
            }
            self?.endTimeView.datePicker.minimumDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            self?.updateTime(timestamp, type: .start)
            self?.updateApplyButtonState()
        }
        
        endTimeView.onDateSelected = { [weak self] timestamp in
            self?.updateTime(timestamp, type: .end)
            self?.updateApplyButtonState()
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
                
                if isScrollLocked { return }

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
                field.onReturn = {[weak nextField] in
                    nextField?.textField.becomeFirstResponder()
                }
            }
            field.onBeginEditing = { [weak self, weak field] in
                guard let self, let field else { return }
                
                if field === self.nameEventTextField {
                    self.scrollToViewToTop(self.eventInfoLabel)
                } else {
                    self.scrollToView(field.view)
                }
            }
        }
        
        nameEventTextField.textField.addTarget(self, action: #selector(agencyTextChanged), for: .editingChanged)
    }
    
    private func updateApplyButtonState() {
        guard let startTime = startTime, let endTime = endTime else { return applyButton.isEnabled = false }
        let isAgencyNameFilled = !(nameEventTextField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        let isAgencySelected = selectedAgencyId != nil
        
        let isStartDateFilled = startTime > 0
        
        let isEndDateValid: Bool
        if currentlyWorkingCheckbox.isSelected {
            isEndDateValid = true
        } else {
            isEndDateValid = endTime > 0 && endTime >= startTime
        }
        
        let isFormValid = isAgencyNameFilled && isAgencySelected && isStartDateFilled && isEndDateValid
        applyButton.isEnabled = isFormValid
        
    }
    
    private func prefillEditData(_ item: WorkHistoryItem) {
        self.selectedAgencyId = item.agencyId
        nameEventTextField.textField.text = item.agencyDisplayName ?? item.agencyName
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM yyyy"
        displayFormatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)
        
        if let startStr = item.startDate, let startDate = inputFormatter.date(from: startStr) {
            startTime = Int32(startDate.timeIntervalSince1970)
            startDateView.setDate(timestamp: startTime)
        }
        
        if item.isCurrent == true {
            currentlyWorkingCheckbox.isSelected = true
            endTimeLabel.isHidden = true
            endTimeView.isHidden = true
        } else if let endStr = item.endDate, let endDate = inputFormatter.date(from: endStr) {
            endTime = Int32(endDate.timeIntervalSince1970)
            endTimeView.setDate(timestamp: endTime)
        }
        updateApplyButtonState()
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
    
    private func scrollToViewToTop(_ targetView: UIView) {
        guard !isScrollLocked else { return }
        
        let targetY = max(targetView.frame.minY, 0)
        isScrollLocked = true
        scrollView.isScrollEnabled = false
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
    }
    
    private func forceKeepScrollPosition() {
        if isScrollLocked {
            let targetY = max(eventInfoLabel.frame.minY, 0)
            scrollView.contentOffset = CGPoint(x: 0, y: targetY)
        }
    }
    
    private func unlockScroll() {
        isScrollLocked = false
        scrollView.isScrollEnabled = true
    }
    
    private func showAutocompleteLoading() {
        autocompleteContainer.isHidden = false
        autocompleteHeightConstraint?.constant = 44
        autocompleteTableView.isHidden = true
        autocompleteLoader.startAnimating()
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
            self.forceKeepScrollPosition()
        }
    }
    
    private func hideAutocomplete() {
        autocompleteBottomConstraint?.isActive = false
        autocompleteHeightConstraint?.constant = 0
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
            self.forceKeepScrollPosition()
        }) { _ in
            self.autocompleteContainer.isHidden = true
        }
    }
    
    private func dissmisKeyboardAutocomplete() {
        autocompleteBottomConstraint?.isActive = false
        autocompleteHeightConstraint?.constant = 0
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
            self.autocompleteContainer.isHidden = true
        })
    }
    
    func updateAgencyResults(_ results: [AgencyItem]) {
        autocompleteLoader.stopAnimating()
        currentAgencyResults = results
        
        if results.isEmpty {
            hideAutocomplete()
        } else {
            autocompleteTableView.isHidden = false
            autocompleteTableView.reloadData()
            
            let height = CGFloat(results.count) * 44.0
            autocompleteHeightConstraint?.constant = height
            autocompleteBottomConstraint?.isActive = true
            
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
                self.forceKeepScrollPosition()
            }
        }
    }

    func updateTime(_ timestamp: Int32, type: TimeType) {
        switch type {
        case .start:
            startTime = timestamp
            startDateView.setDate(timestamp: timestamp)
        case .end:
            endTime = timestamp
            endTimeView.setDate(timestamp: timestamp)
        }
    }
    
    func loadAvatar(isLoading: Bool) {
        isLoading ? avatarSpinner.startAnimating() : avatarSpinner.stopAnimating()
        avatarSpinner.isHidden = !isLoading
        if currentPhoto == nil {
            avatarEmptyImageView.isHidden = isLoading
        }
    }

    func toggleSpinner(active: Bool) {
        applyButton.setSaving(active, in: self.view)
    }
    
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
        dissmisKeyboardAutocomplete()
        unlockScroll()
    }
        
    @objc private func checkboxTapped() {
        currentlyWorkingCheckbox.isSelected.toggle()
        if currentlyWorkingCheckbox.isSelected {
            endTime = Int32(Date().timeIntervalSince1970)
            endTimeView.setDate(timestamp: endTime)
            endTimeLabel.isHidden = true
            endTimeView.isHidden = true
        } else {
            endTime = Int32(Date().timeIntervalSince1970)
            endTimeView.setDate(timestamp: endTime)
            endTimeLabel.isHidden = false
            endTimeView.isHidden = false
        }
        updateApplyButtonState()
    }

    @objc func applyButtonTapped() {
        guard applyButton.isEnabled else { return }
        view.endEditing(true)
        
        guard let startTime = startTime, let endTime = endTime else { return }
        let agencyName = nameEventTextField.textField.text ?? ""
        guard startTime > 0 else {
            return
        }
        let isCurrent = currentlyWorkingCheckbox.isSelected
        
        let body = CreateWorkHistoryRequest(
            agencyId: selectedAgencyId,
            agencyName: agencyName.isEmpty ? nil : agencyName,
            startDate: Self.formatDateForAPI(timestamp: startTime),
            endDate: isCurrent ? nil : (endTime > 0 ? Self.formatDateForAPI(timestamp: endTime) : nil),
            isCurrent: isCurrent
        )
        
        self.toggleSpinner(active: true)
        onSave?(body)
    }
    
    @objc private func agencyTextChanged() {
        self.selectedAgencyId = nil
        updateApplyButtonState()
        
        let query = nameEventTextField.textField.text ?? ""
        searchTimer?.invalidate()

        showAutocompleteLoading()
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.requestAgencySearch?(query)
        }
    }
    
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: 16,
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

// MARK: - UITableViewDelegate & DataSource
extension AddWorkExperience: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentAgencyResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AgencyCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.font = Font.regular(16)
        cell.textLabel?.textColor = DivoColorPalette.primaryText
        cell.textLabel?.text = currentAgencyResults[indexPath.row].title
        
        cell.selectionStyle = .none
        
        let isSelectedAgency = currentAgencyResults[indexPath.row].id == selectedAgencyId
        cell.accessoryType = isSelectedAgency ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = currentAgencyResults[indexPath.row]
        
        self.selectedAgencyId = selected.id
        self.nameEventTextField.textField.text = selected.title

        updateApplyButtonState()
        
        onLoadPhoto?(selectedAgencyId)
        
        dismissKeyboard()
    }
}


// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
