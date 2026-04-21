import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit

final class FaceSearchResultsController: ViewController {
    private let context: AccountContext
    private let results: [FRSearchResult]

    init(context: AccountContext, results: [FRSearchResult]) {
        self.context = context
        self.results = results
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(navigationBarPresentationData: nil)
        _ = presentationData
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = FaceSearchResultsNode(results: self.results)
        node.onBackPressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }
}

// MARK: - Node

private final class FaceSearchResultsNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onBackPressed: (() -> Void)?

    private let results: [FRSearchResult]

    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(DivoImage.searchChevronLeft, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.layer.applyDivoShadow()
        button.addDivoPressState(.pill)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: DivoStrings.faceSearchResultsTitle.uppercased(),
            attributes: [
                .font: Font.helveticaNeue(20),
                .foregroundColor: DivoColorPalette.primaryText,
                .kern: 0.5
            ]
        )
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = DivoDesignTokens.Spacing.s
        layout.minimumLineSpacing = DivoDesignTokens.Spacing.m
        layout.sectionInset = UIEdgeInsets(
            top: DivoDesignTokens.Spacing.m,
            left: DivoDesignTokens.Spacing.m,
            bottom: DivoDesignTokens.Spacing.m,
            right: DivoDesignTokens.Spacing.m
        )
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(FaceSearchResultCell.self, forCellWithReuseIdentifier: FaceSearchResultCell.reuseId)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.faceSearchNoResults
        label.textColor = DivoColorPalette.secondaryText
        label.font = Font.regular(15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    init(results: [FRSearchResult]) {
        self.results = results
        super.init()
        self.backgroundColor = DivoColorPalette.cardBackground
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        emptyLabel.isHidden = !results.isEmpty
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            collectionView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    @objc private func backTapped() { onBackPressed?() }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FaceSearchResultCell.reuseId, for: indexPath) as! FaceSearchResultCell
        cell.configure(with: results[indexPath.item])
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing = DivoDesignTokens.Spacing.s + DivoDesignTokens.Spacing.m * 2
        let width = (collectionView.bounds.width - spacing) / 2
        return CGSize(width: width, height: width * 1.4)
    }

}

// MARK: - Cell

private final class FaceSearchResultCell: UICollectionViewCell {
    static let reuseId = "FaceSearchResultCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(14)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let gradientView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        return v
    }()

    private var gradientLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.25 : 0.4, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }

    private func setupUI() {
        contentView.layer.cornerRadius = DivoDesignTokens.Radius.l
        contentView.clipsToBounds = true
        contentView.backgroundColor = DivoColorPalette.imagePlaceholderDark

        contentView.addSubview(imageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(scoreLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.3),

            scoreLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.s),
            scoreLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            scoreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if gradientLayer == nil {
            let gl = CAGradientLayer()
            gl.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
            gl.locations = [0.0, 1.0]
            gl.frame = gradientView.bounds
            gradientView.layer.insertSublayer(gl, at: 0)
            gradientLayer = gl
        } else {
            gradientLayer?.frame = gradientView.bounds
        }
    }

    func configure(with result: FRSearchResult) {
        let percent = Int(result.score * 100)
        scoreLabel.text = "\(percent)% \(DivoStrings.faceSearchMatchPercent)"

        if let urlString = result.image, let url = URL(string: urlString) {
            imageView.loadImage(from: url)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        imageView.image = nil
        scoreLabel.text = nil
    }
}
