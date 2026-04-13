//
//  WorkHistoryView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit

// Делегат для обработки нажатия на кнопку
protocol CurrentAgencyViewDelegate: AnyObject {
    func didTapSeeHistory()
}

final class CurrentAgencyView: UIView {
    
    weak var delegate: CurrentAgencyViewDelegate?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.12)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.currentAgency
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let agencyNameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        return label
    }()
    
    private let seeHistoryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        button.setTitleColor(.white.withAlphaComponent(0.82), for: .normal)
        button.setTitle(DivoStrings.seeHistory, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var lastLogoURL: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(logoImageView)
        containerView.addSubview(agencyNameLabel)
        containerView.addSubview(seeHistoryButton)
        
        seeHistoryButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        
        seeHistoryButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        agencyNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            logoImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            logoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            logoImageView.widthAnchor.constraint(equalToConstant: 24),
            logoImageView.heightAnchor.constraint(equalToConstant: 24),
            logoImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),
            
            agencyNameLabel.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            agencyNameLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            agencyNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: seeHistoryButton.leadingAnchor, constant: -8),
            
            seeHistoryButton.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            seeHistoryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func historyTapped() {
        delegate?.didTapSeeHistory()
    }
    
    func configure(name: String?, logoURL: URL?) {
        // Обновление текста может попасть внутрь чужих animation-блоков (layoutIfNeeded),
        // поэтому делаем его явно без анимации и сразу фиксируем layout.
        UIView.performWithoutAnimation {
            self.agencyNameLabel.text = name?.uppercased() ?? DivoStrings.unknownAgency
            self.agencyNameLabel.layer.removeAllAnimations()
            self.layoutIfNeeded()
        }

        // Не сбрасываем картинку каждый раз в nil — это вызывает заметное «мигание/анимацию» блока.
        // Перезагружаем только если URL действительно изменился.
        guard lastLogoURL != logoURL else { return }
        lastLogoURL = logoURL

        // Если url нет — чистим изображение (без анимации).
        guard let url = logoURL else {
            UIView.performWithoutAnimation {
                self.logoImageView.image = nil
                self.layoutIfNeeded()
            }
            return
        }

        ImageLoader.shared.load(url: url) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                UIView.performWithoutAnimation {
                    self.logoImageView.image = image
                    self.layoutIfNeeded()
                }
            }
        }
    }
}
