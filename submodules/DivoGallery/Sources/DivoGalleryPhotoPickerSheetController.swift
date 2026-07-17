import UIKit
import Display
import DivoCore
import DivoUIKit

/// Модалка выбора фото из галереи профиля (DIVI-70).
///
/// Кастомный грид под системный фото-пикер (3 колонки, квадраты, мелкий гэп), но без
/// системных контролов — сегмента и поиска. Данные грузит сама по `/user-gallery/list`
/// для переданного `userId`, с состояниями лоадинг/пусто/ошибка (без тихих фолбэков).
/// Возвращает выбранное `UserPhoto` через `onPhotoSelected`; закрытие — на совести вызвавшего.
public final class DivoGalleryPhotoPickerSheetController: UIViewController {

    public var onPhotoSelected: ((UserPhoto) -> Void)?

    private enum Phase: Equatable {
        case loading
        case content
        case empty
        case failed
    }

    private let userId: Int
    private let pageLimit = 30

    private var photos: [UserPhoto] = []
    private var isFetching = false
    private var reachedEnd = false
    private var currentTask: Task<Void, Never>?

    private var phase: Phase = .loading {
        didSet { if oldValue != phase { applyPhase() } }
    }

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(DivoImage.searchCloseIcon, for: .normal)
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
        label.textAlignment = .center
        label.attributedText = DivoTypography.sheetTitle(DivoStrings.faceSearchPickPhotoTitle)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        layout.sectionInset = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let loader: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView(style: .medium)
        loader.color = DivoColorPalette.accent
        loader.hidesWhenStopped = true
        loader.translatesAutoresizingMaskIntoConstraints = false
        return loader
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.noPhotosYet
        label.font = Font.regular(15)
        label.textColor = DivoColorPalette.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let snackbar = DivoSnackbar()

    public init(userId: Int) {
        self.userId = userId
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DivoDesignTokens.Radius.sheet
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { currentTask?.cancel() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DivoGalleryPickerCell.self, forCellWithReuseIdentifier: DivoGalleryPickerCell.reuseId)

        applyPhase()
        fetch(offset: 0)
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let columns: CGFloat = 3
        let spacing = layout.minimumInteritemSpacing
        let available = collectionView.bounds.width - spacing * (columns - 1)
        guard available > 0 else { return }
        let side = floor(available / columns)
        if layout.itemSize.width != side {
            layout.itemSize = CGSize(width: side, height: side)
            layout.invalidateLayout()
        }
    }

    private func setupUI() {
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(collectionView)
        view.addSubview(loader)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),

            collectionView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loader.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),
        ])
    }

    // MARK: - State

    private func applyPhase() {
        switch phase {
        case .loading:
            loader.startAnimating()
            collectionView.isHidden = true
            emptyLabel.isHidden = true
        case .content:
            loader.stopAnimating()
            collectionView.isHidden = false
            emptyLabel.isHidden = true
        case .empty:
            loader.stopAnimating()
            collectionView.isHidden = true
            emptyLabel.isHidden = false
        case .failed:
            // Пустой экран без грида — ошибка покрыта persistent-снекбаром с Retry ниже.
            loader.stopAnimating()
            collectionView.isHidden = true
            emptyLabel.isHidden = true
        }
    }

    // MARK: - Loading

    private func fetch(offset: Int) {
        currentTask?.cancel()
        if offset == 0 { phase = .loading }
        isFetching = true
        currentTask = Task { @MainActor in
            do {
                let body = GalleryListRequest(offset: offset, limit: pageLimit, userId: userId)
                let response: UserGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/user-gallery/list",
                    method: "POST",
                    body: body
                )
                guard !Task.isCancelled else { return }

                if offset == 0 {
                    self.photos = response.data.items
                } else {
                    let existingIds = Set(self.photos.map { $0.id })
                    self.photos.append(contentsOf: response.data.items.filter { !existingIds.contains($0.id) })
                }
                self.reachedEnd = response.data.items.isEmpty || self.photos.count >= response.data.pagination.meta.totalCount
                self.isFetching = false
                self.collectionView.reloadData()
                self.phase = self.photos.isEmpty ? .empty : .content
            } catch {
                if Task.isCancelled { return }
                self.isFetching = false
                divoLog("[GalleryPicker] /user-gallery/list failed: \(error)", level: .error)
                // На ошибке пагинации грид остаётся — .failed только когда показывать нечего.
                if self.photos.isEmpty { self.phase = .failed }
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.faceSearchGalleryLoadFailed
                self.snackbar.show(
                    in: self.view,
                    message: message,
                    style: .error,
                    bottomInset: DivoDesignTokens.Spacing.m,
                    bottomAnchor: self.view.safeAreaLayoutGuide.bottomAnchor,
                    retryTitle: DivoStrings.retry,
                    retryAction: { [weak self] in
                        guard let self else { return }
                        self.fetch(offset: self.photos.count)
                    },
                    persistent: true
                )
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionView

extension DivoGalleryPhotoPickerSheetController: UICollectionViewDataSource, UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DivoGalleryPickerCell.reuseId, for: indexPath) as! DivoGalleryPickerCell
        cell.configure(with: photos[indexPath.item])
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard phase == .content, !isFetching, !reachedEnd else { return }
        if indexPath.item >= photos.count - 6 {
            fetch(offset: photos.count)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < photos.count else { return }
        onPhotoSelected?(photos[indexPath.item])
    }
}

// MARK: - Cell

private final class DivoGalleryPickerCell: UICollectionViewCell {

    static let reuseId = "DivoGalleryPickerCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = DivoColorPalette.imagePlaceholderDark
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.cancelImageLoad()
        imageView.image = nil
    }

    func configure(with photo: UserPhoto) {
        let rawUrl = photo.preview?.fullUrl ?? photo.photo.fullUrl
        if let url = CDNURLHelper.convertToCDNURL(rawUrl) {
            imageView.loadImage(from: url)
        }
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.7 : 1.0
        }
    }
}
