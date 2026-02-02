import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchBarNode
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

final class EventsSearchControllerNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    private let searchBarNode: SearchBarNode
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let supportPeerDisposable = MetaDisposable()
    
    private let presentationDataPromise: Promise<PresentationData>
    private var searchQueryValue: String = ""
    
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
    private let filterByLabel: ASTextNode
    
    private let locationLabel: ASTextNode
    private let locationTextField: TextFieldNode
    
    private let eventTypeLabel: ASTextNode
    private let eventTypeTextField: TextFieldNode
    
    private let dateRangeLabel: ASTextNode
    
    private let fromDateControl: ASControlNode
    private let fromDateTitle: ASTextNode
    private let fromDateValue: ASTextNode
    private let fromDateSeparator: ASControlNode
    
    private let toDateControl: ASControlNode
    private let toDateTitle: ASTextNode
    private let toDateValue: ASTextNode
    private let toDateSeparator: ASControlNode
    
    private let applyButton: ASControlNode
    
    var selectCountryCode: (() -> Void)?
    var scheduleTimeController: (() -> Void)?
    private var countryId: String = ""
    private var lastActiveDate: ASTextNode? = nil
    
    init(context: AccountContext) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.presentationDataPromise = Promise(self.presentationData)
        
        let searchBarNodeTheme = SearchBarNodeTheme(
            background: .white,
            separator: .gray,
            inputFill: UIColor(red: 0.47, green: 0.47, blue: 0.50, alpha: 0.12),
            primaryText: .black,
            placeholder: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
            inputIcon: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
            inputClear: .gray,
            accent: .gray,
            keyboard: .light)
        
        self.searchBarNode = SearchBarNode(theme: searchBarNodeTheme, strings: presentationData.strings, fieldStyle: .modern)
        let placeholderText = presentationData.strings.Common_Search
        let searchBarFont = Font.regular(17.0)
        
        self.searchBarNode.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: presentationData.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        self.searchBarNode.hasCancelButton = false
        
        self.scrollNode = ASScrollNode()
        
        self.filterByLabel = ASTextNode()
        self.filterByLabel.attributedText = NSAttributedString(string: "Filter by:", font: Font.semibold(12), textColor: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6))
        
        self.locationLabel = ASTextNode()
        self.locationLabel.attributedText = NSAttributedString(string: "Location", font: Font.semibold(16), textColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.00))
        
        self.locationTextField = getTextFiel(title: "Choose a country")

        self.eventTypeLabel = ASTextNode()
        self.eventTypeLabel.attributedText = NSAttributedString(string: "Event Type", font: Font.semibold(16), textColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.00))
        
        self.eventTypeTextField = getTextFiel(title: "All Types")
        
        self.dateRangeLabel = ASTextNode()
        self.dateRangeLabel.attributedText = NSAttributedString(string: "Date Range", font: Font.semibold(16), textColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.00))
        
        self.fromDateControl = ASControlNode()
        self.fromDateControl.backgroundColor = .clear
        
        self.fromDateTitle = ASTextNode()
        self.fromDateTitle.attributedText = NSAttributedString(string: "From", font: Font.regular(17), textColor: .black)
        
        self.fromDateValue = ASTextNode()
        self.fromDateValue.attributedText = NSAttributedString(string: "Today, 24 Jun 2025", font: Font.regular(17), textColor: .black)
        
        self.fromDateSeparator = ASControlNode()
        self.fromDateSeparator.backgroundColor = UIColor(red: 0.33, green: 0.33, blue: 0.34, alpha: 0.34)
        
        self.toDateControl = ASControlNode()
        self.toDateControl.backgroundColor = .clear
        
        self.toDateTitle = ASTextNode()
        self.toDateTitle.attributedText = NSAttributedString(string: "To", font: Font.regular(17), textColor: .black)
        
        self.toDateValue = ASTextNode()
        self.toDateValue.attributedText = NSAttributedString(string: "24 Jul, 2025", font: Font.regular(17), textColor: .black)
        
        self.toDateSeparator = ASControlNode()
        self.toDateSeparator.backgroundColor = UIColor(red: 0.33, green: 0.33, blue: 0.34, alpha: 0.34)
        
        self.applyButton = ButtonWithIconNode(title: "Apply filter", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.locationTextField.textField.delegate = self
        
        self.backgroundColor = .white
        self.addSubnode(self.searchBarNode)
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.filterByLabel)
        self.scrollNode.addSubnode(self.locationLabel)
        self.scrollNode.addSubnode(self.locationTextField)
        self.scrollNode.addSubnode(self.eventTypeLabel)
        self.scrollNode.addSubnode(self.eventTypeTextField)
        self.scrollNode.addSubnode(self.dateRangeLabel)
        self.scrollNode.addSubnode(self.fromDateControl)
        self.fromDateControl.addSubnode(self.fromDateTitle)
        self.fromDateControl.addSubnode(self.fromDateValue)
        self.fromDateControl.addSubnode(self.fromDateSeparator)
        
        self.scrollNode.addSubnode(self.toDateControl)
        self.toDateControl.addSubnode(self.toDateTitle)
        self.toDateControl.addSubnode(self.toDateValue)
        self.toDateControl.addSubnode(self.toDateSeparator)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        self.scrollNode.view.addGestureRecognizer(tapGesture)
        
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
        self.searchBarNode.textUpdated = { [weak self] query, _ in
            self?.handleSearchQueryUpdate(query)
        }
        
        self.fromDateControl.addTarget(self, action: #selector(self.fromDateTapped), forControlEvents: .touchUpInside)
        self.toDateControl.addTarget(self, action: #selector(self.toDateTapped), forControlEvents: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == locationTextField.textField {
            selectCountryCode?()
            return false
        }
        return true
    }
    
    func updateCountry(countryId: String, countryName: String) {
        locationTextField.textField.text = countryName
        self.countryId = countryId
    }
    
    @objc private func applyButtonTapped() {
        
//
//        print("Apply filter button tapped!")
//        let supportPeer = Promise<String?>()
//        supportPeer.set(context.engine.peers.getCountries())
//        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
//            print("⛳️", peerId ?? "")
//        }))
        let id = Int(searchQueryValue) ?? 0
        let supportPeer = Promise<String?>()
        supportPeer.set(context.engine.eventsEngine.getEvent(eventId: id))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
            print("🔕", peerId ?? "")
        }))
    }
    
    @objc private func fromDateTapped() {
        scheduleTimeController?()
        lastActiveDate = fromDateValue
    }
    
    @objc private func toDateTapped() {
        scheduleTimeController?()
        lastActiveDate = toDateValue
    }
    
    func updateTime(_ timestamp: Int32) {
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateString = dateFormatter.string(from: date)
        
        
        let today = Date()
        let calendar = Calendar.current
        let prefix = calendar.isDate(date, inSameDayAs: today) ? "Today " : ""
        
        if lastActiveDate == fromDateValue {
            fromDateValue.attributedText = NSAttributedString(string: prefix + dateString, font: Font.regular(17), textColor: .black)
        } else {
            toDateValue.attributedText = NSAttributedString(string: dateString, font: Font.regular(17), textColor: .black)
        }
    }
    
    private func handleSearchQueryUpdate(_ query: String) {
        print("Search query updated: \(query)")
        searchQueryValue = query
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
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
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let searchBarHeight: CGFloat = 56.0
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: searchBarHeight))
        self.searchBarNode.frame = searchBarFrame
        self.searchBarNode.updateLayout(boundingSize: searchBarFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition)
        
        let topInset: CGFloat = navigationBarHeight + searchBarHeight
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemSpacing: CGFloat = 12.0
        let itemHeight: CGFloat = 48.0
        
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        var currentY: CGFloat = 20.0
        
        let filterBySize = self.filterByLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.filterByLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: filterBySize)
        currentY += filterBySize.height + sectionSpacing
        
        let locationLabelSize = self.locationLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.locationLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: locationLabelSize)
        currentY += locationLabelSize.height + itemSpacing
        
        self.locationTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let eventTypeLabelSize = self.eventTypeLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.eventTypeLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventTypeLabelSize)
        currentY += eventTypeLabelSize.height + itemSpacing
        
        self.eventTypeTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let dateRangeLabelSize = self.dateRangeLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.dateRangeLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: dateRangeLabelSize)
        currentY += dateRangeLabelSize.height + itemSpacing
        
        let dateItemHeight: CGFloat = 44.0
        let dateItemInnerPadding: CGFloat = 0
        
        self.fromDateControl.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: dateItemHeight))
        
        let fromTitleSize = self.fromDateTitle.measure(CGSize(width: layout.size.width / 2.0, height: dateItemHeight))
        self.fromDateTitle.frame = CGRect(origin: CGPoint(x: dateItemInnerPadding, y: (dateItemHeight - fromTitleSize.height) / 2.0), size: fromTitleSize)
        
        let fromValueSize = self.fromDateValue.measure(CGSize(width: layout.size.width - fromTitleSize.width - dateItemInnerPadding * 3, height: dateItemHeight))
        self.fromDateValue.frame = CGRect(origin: CGPoint(x: self.fromDateControl.frame.width - fromValueSize.width - dateItemInnerPadding, y: (dateItemHeight - fromValueSize.height) / 2.0), size: fromValueSize)
        
        self.fromDateSeparator.frame = CGRect(origin: CGPoint(x: dateItemInnerPadding, y: dateItemHeight - UIScreenPixel), size: CGSize(width: self.fromDateControl.frame.width - dateItemInnerPadding, height: UIScreenPixel))
        
        self.fromDateControl.clipsToBounds = true
        
        currentY += dateItemHeight
        
        self.toDateControl.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: dateItemHeight))
        
        let toTitleSize = self.toDateTitle.measure(CGSize(width: layout.size.width / 2.0, height: dateItemHeight))
        self.toDateTitle.frame = CGRect(origin: CGPoint(x: dateItemInnerPadding, y: (dateItemHeight - toTitleSize.height) / 2.0), size: toTitleSize)
        
        let toValueSize = self.toDateValue.measure(CGSize(width: layout.size.width - toTitleSize.width - dateItemInnerPadding * 3, height: dateItemHeight))
        self.toDateValue.frame = CGRect(origin: CGPoint(x: self.toDateControl.frame.width - toValueSize.width - dateItemInnerPadding, y: (dateItemHeight - toValueSize.height) / 2.0), size: toValueSize)
        
        self.toDateSeparator.frame = CGRect(origin: CGPoint(x: dateItemInnerPadding, y: dateItemHeight - UIScreenPixel), size: CGSize(width: self.toDateControl.frame.width - dateItemInnerPadding, height: UIScreenPixel))
        
        self.toDateControl.clipsToBounds = true
        
        currentY += dateItemHeight + sectionSpacing
        
        let buttonWidth = layout.size.width - sidePadding * 2
        let buttonHeight: CGFloat = 50.0
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: buttonWidth, height: buttonHeight))
        
        currentY += buttonHeight + sectionSpacing
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        
        self.readyValue = true
    }
}

private func getTextFiel(title: String) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    //    field.textField.keyboardType = .URL
    field.borderWidth = 1.0
    field.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    field.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.00)
    return field
}
