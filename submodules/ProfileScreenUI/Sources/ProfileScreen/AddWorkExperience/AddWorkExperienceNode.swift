import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import DivoCore
import AccountContext
import AppBundle
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
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
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

    private let workInfoLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.workExperienceInfo
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let agencyNameLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.agencyName
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let agencyNameTextField: DivoTextField

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

        let uncheckedImage = UIImage(systemName: "circle")?
            .withTintColor(DivoColorPalette.primaryText.withAlphaComponent(0.4), renderingMode: .alwaysOriginal)
        let checkedImage = UIImage(systemName: "checkmark.circle.fill")?
            .withTintColor(DivoColorPalette.accent, renderingMode: .alwaysOriginal)

        button.setImage(uncheckedImage, for: .normal)
        button.setImage(checkedImage, for: .selected)

        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center

        return button
    }()

    private let currentlyWorkingLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.currentlyWorking
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = true
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
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.m
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
        tv.clipsToBounds = true
        tv.layer.cornerRadius = DivoDesignTokens.Radius.m
        tv.contentInsetAdjustmentBehavior = .never
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
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
    
    private let autocompleteErrorLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.secondaryText
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var autocompleteHeightConstraint: NSLayoutConstraint?
    private var autocompleteBottomConstraint: NSLayoutConstraint?
    private var currentAgencyResults: [AgencyItem] = []
    private var isScrollLocked = false
    
    private var searchTimer: Timer?
    private let dismissTapDelegate = DismissTapDelegate()
    
    var requestAgencySearch: ((String) -> Void)?
    
    private var selectedAgencyId: Int? = nil
    private var initialSnapshot: FormSnapshot?
    
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
        
        self.agencyNameTextField = DivoTextField(title: "", prefix: "")
        self.agencyNameTextField.textField.autocapitalizationType = .words
        self.agencyNameTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.enterAgencyName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        
        let today = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: today) ?? today
        
        startDateView = DateSelectionControl(placeholder: Int32(oneMonthAgo.timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier)
        endTimeView = DateSelectionControl(placeholder: Int32(today.timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier)

        super.init()
        
        // startDateView.datePicker.maximumDate = today
        // startDateView.datePicker.date = oneMonthAgo
        // endTimeView.datePicker.maximumDate = today
        // endTimeView.datePicker.minimumDate = oneMonthAgo
        // endTimeView.datePicker.date = Date()

        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: editItem != nil ? DivoStrings.navEditExperience.uppercased() : DivoStrings.navCreateExperience.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
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

        contentView.addSubview(workInfoLabel)
        contentView.addSubview(agencyNameLabel)
        
        agencyNameTextField.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(agencyNameTextField.view)
        
        contentView.addSubview(startDateLabel)
        contentView.addSubview(endTimeLabel)
        
        contentView.addSubview(startDateView)
        contentView.addSubview(endTimeView)

        contentView.addSubview(currentlyWorkingCheckbox)
        contentView.addSubview(currentlyWorkingLabel)
        
        contentView.addSubview(autocompleteContainer)
        autocompleteContainer.addSubview(autocompleteTableView)
        autocompleteContainer.addSubview(autocompleteLoader)
        autocompleteContainer.addSubview(autocompleteErrorLabel)
        
        autocompleteTableView.delegate = self
        autocompleteTableView.dataSource = self
        autocompleteTableView.register(AgencySearchCell.self, forCellReuseIdentifier: AgencySearchCell.reuseIdentifier)
        
        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)

        currentlyWorkingCheckbox.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        currentlyWorkingCheckbox.addDivoPressState(.pill)
        currentlyWorkingLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(checkboxTapped)))

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
            workInfoLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: DivoDesignTokens.Spacing.xl),
            workInfoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            workInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            // Name label & field
            agencyNameLabel.topAnchor.constraint(equalTo: workInfoLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            agencyNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            agencyNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            agencyNameTextField.view.topAnchor.constraint(equalTo: agencyNameLabel.bottomAnchor, constant: 6),
            agencyNameTextField.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            agencyNameTextField.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            agencyNameTextField.view.heightAnchor.constraint(equalToConstant: 48),
            
            autocompleteContainer.topAnchor.constraint(equalTo: agencyNameTextField.view.bottomAnchor, constant: 4),
            autocompleteContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            autocompleteContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            autocompleteTableView.topAnchor.constraint(equalTo: autocompleteContainer.topAnchor),
            autocompleteTableView.leadingAnchor.constraint(equalTo: autocompleteContainer.leadingAnchor),
            autocompleteTableView.trailingAnchor.constraint(equalTo: autocompleteContainer.trailingAnchor),
            autocompleteTableView.bottomAnchor.constraint(equalTo: autocompleteContainer.bottomAnchor),
            
            autocompleteLoader.centerXAnchor.constraint(equalTo: autocompleteContainer.centerXAnchor),
            autocompleteLoader.centerYAnchor.constraint(equalTo: autocompleteContainer.centerYAnchor),

            autocompleteErrorLabel.centerXAnchor.constraint(equalTo: autocompleteContainer.centerXAnchor),
            autocompleteErrorLabel.centerYAnchor.constraint(equalTo: autocompleteContainer.centerYAnchor),
            autocompleteErrorLabel.leadingAnchor.constraint(equalTo: autocompleteContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            autocompleteErrorLabel.trailingAnchor.constraint(equalTo: autocompleteContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            // Date labels
            startDateLabel.topAnchor.constraint(equalTo: agencyNameTextField.view.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            startDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),

            endTimeLabel.topAnchor.constraint(equalTo: agencyNameTextField.view.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
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
            currentlyWorkingCheckbox.widthAnchor.constraint(equalToConstant: 30),
            currentlyWorkingCheckbox.heightAnchor.constraint(equalToConstant: 30),

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
        autocompleteBottomConstraint?.priority = .defaultHigh
    }

    private func setupInteractions() {
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
        
        startDateView.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.start)
        }
        
        endTimeView.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.end)
        }
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTapDelegate.excludedView = autocompleteContainer
        dismissTap.delegate = dismissTapDelegate
        scrollView.addGestureRecognizer(dismissTap)
        scrollView.keyboardDismissMode = .interactive
        
        let fields = [agencyNameTextField]
        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 0,
            scrollToActiveField: { [weak self] in
                guard let self else { return }
                
                if isScrollLocked { return }

                if self.agencyNameTextField.textField.isFirstResponder {
                    self.scrollToView(self.agencyNameTextField.view)
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
                
                if field === self.agencyNameTextField {
                    self.scrollToViewToTop(self.workInfoLabel)
                } else {
                    self.scrollToView(field.view)
                }
            }
        }
        
        agencyNameTextField.textField.addTarget(self, action: #selector(agencyTextChanged), for: .editingChanged)
    }
    
    private func currentFormSnapshot() -> FormSnapshot {
        FormSnapshot(
            agencyName: agencyNameTextField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startTime,
            endTime: endTime,
            isCurrent: currentlyWorkingCheckbox.isSelected
        )
    }

    private func updateApplyButtonState() {
        let isCurrent = currentlyWorkingCheckbox.isSelected
        let isAgencyNameFilled = !(agencyNameTextField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isStartDateSelected = startDateView.hasSelection
        let isEndDateSelected = isCurrent || endTimeView.hasSelection

        let isDatesValid = isCurrent || (endTime ?? 0) >= (startTime ?? 0)
        var isFormValid = isAgencyNameFilled && isStartDateSelected && isEndDateSelected && isDatesValid

        if let initial = initialSnapshot {
            let isDirty = currentFormSnapshot() != initial
            isFormValid = isFormValid && isDirty
        }

        navigationBar.setEnableRightButton(isFormValid)
        applyButton.isEnabled = isFormValid
    }
    
    private func prefillEditData(_ item: WorkHistoryItem) {
        self.selectedAgencyId = item.agencyId
        agencyNameTextField.textField.text = item.agencyDisplayName ?? item.agencyName
        
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
        initialSnapshot = currentFormSnapshot()
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
            let targetY = max(workInfoLabel.frame.minY, 0)
            scrollView.contentOffset = CGPoint(x: 0, y: targetY)
        }
    }
    
    private func unlockScroll() {
        isScrollLocked = false
        scrollView.isScrollEnabled = true
    }
    
    private func showAutocompleteLoading() {
        autocompleteContainer.isHidden = false
        contentView.bringSubviewToFront(autocompleteContainer)
        autocompleteHeightConstraint?.constant = 44
        autocompleteTableView.isHidden = true
        autocompleteErrorLabel.isHidden = true
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
    
    private func dismissKeyboardAutocomplete() {
        autocompleteBottomConstraint?.isActive = false
        autocompleteHeightConstraint?.constant = 0
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
            self.autocompleteContainer.isHidden = true
        })
    }
    
    func updateAgencyResults(_ results: [AgencyItem]) {
        autocompleteLoader.stopAnimating()
        autocompleteErrorLabel.isHidden = true
        currentAgencyResults = results

        if results.isEmpty {
            hideAutocomplete()
        } else {
            autocompleteTableView.isHidden = false
            autocompleteTableView.reloadData()

            let height = CGFloat(results.count) * 64.0
            autocompleteHeightConstraint?.constant = height
            autocompleteBottomConstraint?.isActive = true

            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
                self.forceKeepScrollPosition()
            }
        }
    }

    func showAutocompleteError(message: String) {
        autocompleteLoader.stopAnimating()
        autocompleteTableView.isHidden = true
        autocompleteErrorLabel.text = message
        autocompleteErrorLabel.isHidden = false

        autocompleteContainer.isHidden = false
        autocompleteHeightConstraint?.constant = 44
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
            self.forceKeepScrollPosition()
        }
    }

    func updateTime(_ timestamp: Int32, type: TimeType) {
        switch type {
        case .start:
            startTime = timestamp
            startDateView.setDate(timestamp: timestamp)
            
            if !currentlyWorkingCheckbox.isSelected, let currentEnd = endTime {
                let startStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(timestamp)))
                let endStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(currentEnd)))
                
                if startStart > endStart {
                    endTime = nil
                    endTimeView.setDate(timestamp: Int32(Date().timeIntervalSince1970))
                }
            }
        case .end:
            endTime = timestamp
            endTimeView.setDate(timestamp: timestamp)
        }
        
        updateApplyButtonState()
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
    
    func getStartTime() -> Int32? {
        return startTime
    }
    
    func getEndTime() -> Int32? {
        return endTime
    }
    
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
        dismissKeyboardAutocomplete()
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
            let restored = initialSnapshot?.endTime ?? Int32(Date().timeIntervalSince1970)
            endTime = restored
            endTimeView.setDate(timestamp: restored)
            endTimeLabel.isHidden = false
            endTimeView.isHidden = false
        }
        updateApplyButtonState()
    }

    @objc func applyButtonTapped() {
        guard applyButton.isEnabled else { return }
        view.endEditing(true)

        let isCurrent = currentlyWorkingCheckbox.isSelected
        guard let startTime = startTime, startTime > 0 else { return }
        guard isCurrent || endTime != nil else { return }
        let agencyName = agencyNameTextField.textField.text ?? ""

        let body = CreateWorkHistoryRequest(
            agencyId: selectedAgencyId,
            agencyName: agencyName.isEmpty ? nil : agencyName,
            startDate: Self.formatDateForAPI(timestamp: startTime),
            endDate: isCurrent ? nil : (endTime.flatMap { $0 > 0 ? Self.formatDateForAPI(timestamp: $0) : nil }),
            isCurrent: isCurrent
        )
        
        self.toggleSpinner(active: true)
        onSave?(body)
    }
    
    @objc private func agencyTextChanged() {
        self.selectedAgencyId = nil
        updateApplyButtonState()
        
        let query = agencyNameTextField.textField.text ?? ""
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

}

// MARK: - UITableViewDelegate & DataSource
extension AddWorkExperience: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentAgencyResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AgencySearchCell.reuseIdentifier, for: indexPath) as! AgencySearchCell
        let item = currentAgencyResults[indexPath.row]
        let query = agencyNameTextField.textField.text ?? ""
        cell.configure(with: item, query: query, isSelected: item.id == selectedAgencyId)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = currentAgencyResults[indexPath.row]
        
        self.selectedAgencyId = selected.id
        self.agencyNameTextField.textField.text = selected.title

        updateApplyButtonState()
        
        onLoadPhoto?(selectedAgencyId)
        
        dismissKeyboard()
    }
}


// MARK: - FormSnapshot

private struct FormSnapshot: Equatable {
    let agencyName: String?
    let startTime: Int32?
    let endTime: Int32?
    let isCurrent: Bool
}

// MARK: - DismissTapDelegate

private final class DismissTapDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var excludedView: UIView?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let excluded = excludedView, !excluded.isHidden else { return true }
        let location = gestureRecognizer.location(in: excluded)
        return !excluded.bounds.contains(location)
    }
}

// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
