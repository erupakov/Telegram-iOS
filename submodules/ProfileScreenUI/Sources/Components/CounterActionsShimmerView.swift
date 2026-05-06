//
//  ShimmerActionsStack.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import DivoCore
import DivoUIKit

class CounterActionsShimmerView: UIView {
    
    // MARK: - UI Elements
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Создаем 4 заглушки. Используем lazy var или функцию-фабрику, чтобы не дублировать код
    private lazy var placeholder1 = createPlaceholder()
    private lazy var placeholder2 = createPlaceholder()
    private lazy var placeholder3 = createPlaceholder()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Запускаем анимацию тут, чтобы градиент знал правильные размеры frame
        startAnimation()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(stackView)
        
        stackView.addArrangedSubview(placeholder1)
        stackView.addArrangedSubview(placeholder2)
        stackView.addArrangedSubview(placeholder3)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    // Фабричный метод для создания одинаковых серых блоков
    private func createPlaceholder() -> UIView {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.statPillForeground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    // MARK: - Animation Logic
    
    func startAnimation() {
        // Запускаем шиммер на каждом из 4 элементов
        [placeholder1, placeholder2, placeholder3].forEach {
            $0.stopShimmering() // на всякий случай сбрасываем старую
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [placeholder1, placeholder2, placeholder3].forEach {
            $0.stopShimmering()
        }
    }
}
