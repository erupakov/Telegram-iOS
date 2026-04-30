import UIKit
import Display

public final class DivoDatePickerController: UIViewController {
    
    public enum Mode {
        case date
        case time
    }
    
    private let mode: Mode
    private let initialTimestamp: Int32?
    private let minimumTimestamp: Int32?
    private let maximumTimestamp: Int32?
    public var onSave: ((Int32) -> Void)?
    
    private let datePickerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.backgroundColor = DivoColorPalette.cardBackground
        return view
    }()
    
    private let datePicker = UIDatePicker()
    private let navigationBar = DivoNavigationBar()
    
    public init(mode: Mode, initialTimestamp: Int32, title: String, minimumTimestamp: Int32? = nil, maximumTimestamp: Int32? = nil) {
        self.mode = mode
        self.initialTimestamp = initialTimestamp
        self.minimumTimestamp = minimumTimestamp
        self.maximumTimestamp = maximumTimestamp
        super.init(nibName: nil, bundle: nil)
        
        navigationBar.makeNavigationBar(
            title: title,
            font: Font.medium(16),
            backButtonConfiguration: .circle(UIImage(bundleImageName: "Components/SearchCloseIcon")!),
            rightButtonConfiguration: .circle(DivoColorPalette.accent, DivoColorPalette.cardBackground, UIImage(bundleImageName: "Components/whiteCheckmark")!, .primary),
            onBackTapped: { [weak self] in
                self?.navigationController?.dismiss(animated: true)
            },
            onCircleRightTapped: { [weak self] in
                self?.saveTapped()
            }
        )
        
        self.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = self.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        
        setupHeader()
        setupPicker()
    }
    
    private func setupHeader() {
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func setupPicker() {
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.tintColor = DivoColorPalette.accent
        
        if mode == .date {
            datePicker.datePickerMode = .date
            if #available(iOS 14.0, *) {
                datePicker.preferredDatePickerStyle = .inline
            }
        } else {
            datePicker.datePickerMode = .time
            if #available(iOS 13.4, *) {
                datePicker.preferredDatePickerStyle = .wheels
            }
        }
        
        if let minTs = minimumTimestamp, minTs > 0 {
            datePicker.minimumDate = Date(timeIntervalSince1970: TimeInterval(minTs))
        }
        
        if let maxTs = maximumTimestamp, maxTs > 0 {
            datePicker.maximumDate = Date(timeIntervalSince1970: TimeInterval(maxTs))
        }
        
        if let ts = initialTimestamp, ts > 0 {
            datePicker.date = Date(timeIntervalSince1970: TimeInterval(ts))
        }
        
        view.addSubview(datePickerContainer)
        datePickerContainer.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePickerContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 20),
            datePickerContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            datePickerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            datePickerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            datePicker.topAnchor.constraint(equalTo: datePickerContainer.topAnchor, constant: DivoDesignTokens.Spacing.s),
            datePicker.leadingAnchor.constraint(equalTo: datePickerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            datePicker.trailingAnchor.constraint(equalTo: datePickerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            datePicker.bottomAnchor.constraint(equalTo: datePickerContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.s),
        ])
    }
    
    @objc private func backTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        onSave?(Int32(datePicker.date.timeIntervalSince1970))
        dismiss(animated: true)
    }
}
