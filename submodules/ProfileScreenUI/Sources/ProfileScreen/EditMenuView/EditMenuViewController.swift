//
//  EditMenuViewController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 11.03.2026.
//

import UIKit

final class EditMenuViewController: UIViewController {
    
    struct MenuItem {
        let title: String
        let action: () -> Void
    }
    
    private let items: [MenuItem]
    private let sourcePoint: CGPoint
    
    private let overlayButton = UIButton(type: .custom)
    private let shadowContainer = UIView()
    private let menuContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
    
    init(items: [MenuItem], sourcePoint: CGPoint) {
        self.items = items
        self.sourcePoint = sourcePoint
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .clear
        
        overlayButton.frame = view.bounds
        overlayButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayButton.addTarget(self, action: #selector(dismissMenu), for: .touchUpInside)
        view.addSubview(overlayButton)
        
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.layer.shadowColor = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.15
        shadowContainer.layer.shadowRadius = 20
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.addSubview(shadowContainer)
        
        menuContainer.layer.cornerRadius = 14
        menuContainer.clipsToBounds = true
        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.addSubview(menuContainer)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.contentView.addSubview(stackView)
        
        let menuWidth: CGFloat = 250
        
        NSLayoutConstraint.activate([
            shadowContainer.topAnchor.constraint(equalTo: view.topAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: sourcePoint.x - menuWidth - 60 - 20),
            shadowContainer.widthAnchor.constraint(equalToConstant: menuWidth),
            
            menuContainer.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            menuContainer.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),
            menuContainer.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            menuContainer.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: menuContainer.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: menuContainer.contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: menuContainer.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: menuContainer.contentView.trailingAnchor)
        ])
        
        for (index, item) in items.enumerated() {
            let row = createRow(for: item)
            stackView.addArrangedSubview(row)
            
            if index < items.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor.black.withAlphaComponent(0.1)
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stackView.addArrangedSubview(separator)
            }
        }
        
        shadowContainer.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        shadowContainer.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        shadowContainer.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.shadowContainer.transform = .identity
            self.shadowContainer.alpha = 1
        })
    }
    
    @objc private func dismissMenu() {
        UIView.animate(withDuration: 0.2, animations: {
            self.shadowContainer.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.shadowContainer.alpha = 0
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    private func createRow(for item: MenuItem) -> UIControl {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        control.addTarget(self, action: #selector(rowTouchDown(_:)), for: [.touchDown, .touchDragEnter])
        control.addTarget(self, action: #selector(rowTouchUp(_:)), for:[.touchDragExit, .touchCancel, .touchUpOutside])
        
        let actionClosure = ActionClosureWrapper(closure: { [weak self] in
            UIView.animate(withDuration: 0.2, animations: {
                self?.shadowContainer.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                self?.shadowContainer.alpha = 0
            }) { _ in
                self?.dismiss(animated: false) {
                    item.action()
                }
            }
        })

        control.addTarget(actionClosure, action: #selector(ActionClosureWrapper.invoke), for: .touchUpInside)
        objc_setAssociatedObject(control, UUID().uuidString, actionClosure, .OBJC_ASSOCIATION_RETAIN)
        
        let label = UILabel()
        label.text = item.title
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        
        control.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: control.trailingAnchor, constant: -16),
        ])
        
        return control
    }
    
    @objc private func rowTouchDown(_ sender: UIControl) {
        sender.backgroundColor = UIColor.black.withAlphaComponent(0.05)
    }
    
    @objc private func rowTouchUp(_ sender: UIControl) {
        sender.backgroundColor = .clear
    }
}

private final class ActionClosureWrapper: NSObject {
    let closure: () -> Void
    init(closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
