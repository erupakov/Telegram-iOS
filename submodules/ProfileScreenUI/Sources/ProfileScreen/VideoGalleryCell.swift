import UIKit
import AVKit
import AVFoundation
import Display
import TelegramCore
import DivoCore
import DivoUIKit

final class VideoGalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoGalleryCell"

    private enum Constants {
        static let softTimeoutSeconds: TimeInterval = 30.0
        static let hardTimeoutSeconds: TimeInterval = 60.0
        static let softTimeoutMessage = "Загрузка…"
        static let hardTimeoutMessage = "Не удалось загрузить"

        // Генерация first-frame из remote-URL через AVAssetImageGenerator может быть дорогой.
        // Поэтому:
        // - ограничиваем параллелизм
        // - кешируем результат в памяти на время сессии
        static let thumbnailGenerationParallelism: Int = 3
        static let thumbnailMaximumSize = CGSize(width: 480.0, height: 480.0)
    }

    private static let firstFrameCache = NSCache<NSString, UIImage>()
    private static let thumbnailGenerationSemaphore = DispatchSemaphore(value: Constants.thumbnailGenerationParallelism)

    /// Возвращает закешированный first-frame для указанного URL (CDN-строка).
    /// Используется в PreviewCell, чтобы не генерировать миниатюру повторно если
    /// VideoGalleryCell уже сделал это раньше (надёжный кадр с ретраями).
    static func cachedFirstFrame(for urlString: String) -> UIImage? {
        return firstFrameCache.object(forKey: urlString as NSString)
    }

    private static let previewFrameCache = NSCache<NSString, UIImage>()

    static func cachedPreviewFrame(for urlString: String) -> UIImage? {
        return previewFrameCache.object(forKey: urlString as NSString)
    }

    static func cachePreviewFrame(_ image: UIImage, for urlString: String) {
        previewFrameCache.setObject(image, forKey: urlString as NSString)
    }

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.clear.cgColor
        return layer
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        return label
    }()

    private let durationContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(10)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return label
    }()

    private let shimmerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fallbackContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let fallbackIconView: UIImageView = {
        let imageView = UIImageView()
        if #available(iOS 13.0, *) {
            imageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        }
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(11)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.videoUnavailable
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return label
    }()

    // Сейчас fallback UI отключён (по требованию): не показываем плашки ошибок/загрузки,
    // чтобы не мигало поверх превью/плеера. Оставляем инфраструктуру (view) на будущее.
    private let isFallbackEnabled: Bool = false

    private var player: AVPlayer?
    private var isPlaying: Bool = false
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var canAutoPlay: Bool = false
    private var shouldAutoPlayWhenReady: Bool = false

    private var configurationId: Int = 0

    private var currentVideoUrl: URL?
    private var retryCount = 0
    private let maxRetries = 3

    private var showPreviewURL: URL?
    private var previewUrlString: String?
    private var shimmerTimeoutWorkItem: DispatchWorkItem?
    private var hardFailureWorkItem: DispatchWorkItem?

    private var thumbnailGenerator: AVAssetImageGenerator?
    private var isGeneratingThumbnail: Bool = false

    private var thumbnailGenerationWatchdogWorkItem: DispatchWorkItem?

    /// Становится true, когда в ячейке появился любой реальный визуальный контент
    /// (превью-картинка, сгенерированный кадр или готовый к показу плеер).
    /// Используется, чтобы не показывать fallback поверх уже появившегося контента.
    private var hasVisualContent: Bool = false

    private var timeObserverToken: Any?
    private var totalDurationSeconds: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.clipsToBounds = true
        contentView.backgroundColor = .black

        // Z-порядок (снизу вверх): thumbnail → playerLayer → shimmer → UI.
        // playerLayer НАД thumbnail — при воспроизведении плеер закрывает превью,
        // а при удалении плеера thumbnail виден без каких-либо манипуляций с alpha.
        contentView.addSubview(thumbnailImageView)
        contentView.layer.insertSublayer(playerLayer, above: thumbnailImageView.layer)
        contentView.addSubview(shimmerContainer)
        contentView.addSubview(fallbackContainer)
        contentView.addSubview(titleLabel)

        contentView.addSubview(durationContainer)
        durationContainer.addSubview(durationLabel)

        fallbackContainer.addSubview(fallbackIconView)
        fallbackContainer.addSubview(fallbackLabel)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            shimmerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            shimmerContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            shimmerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shimmerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.xs),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.xs),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),

            durationContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            durationContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            durationLabel.topAnchor.constraint(equalTo: durationContainer.topAnchor, constant: 2),
            durationLabel.bottomAnchor.constraint(equalTo: durationContainer.bottomAnchor, constant: -2),
            durationLabel.leadingAnchor.constraint(equalTo: durationContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.xs),
            durationLabel.trailingAnchor.constraint(equalTo: durationContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.xs)
        ])

        NSLayoutConstraint.activate([
            fallbackContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fallbackContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fallbackContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            fallbackContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),

            fallbackIconView.topAnchor.constraint(equalTo: fallbackContainer.topAnchor, constant: DivoDesignTokens.Spacing.s),
            fallbackIconView.centerXAnchor.constraint(equalTo: fallbackContainer.centerXAnchor),
            fallbackIconView.widthAnchor.constraint(equalToConstant: 18),
            fallbackIconView.heightAnchor.constraint(equalToConstant: 18),

            fallbackLabel.topAnchor.constraint(equalTo: fallbackIconView.bottomAnchor, constant: 6),
            fallbackLabel.leadingAnchor.constraint(equalTo: fallbackContainer.leadingAnchor, constant: 10),
            fallbackLabel.trailingAnchor.constraint(equalTo: fallbackContainer.trailingAnchor, constant: -10),
            fallbackLabel.bottomAnchor.constraint(equalTo: fallbackContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.s)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = contentView.bounds
        if self.window != nil && !shimmerContainer.isHidden {
            shimmerContainer.stopShimmering()
            shimmerContainer.startShimmering()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        layoutIfNeeded()
    }

    func configureUploading(thumbnail: UIImage?) {
        configurationId &+= 1
        fallbackContainer.isHidden = true
        if let thumbnail = thumbnail {
            thumbnailImageView.image = thumbnail
            thumbnailImageView.alpha = 0.6
            shimmerContainer.isHidden = true
            hasVisualContent = true
        } else {
            shimmerContainer.isHidden = false
            shimmerContainer.alpha = 1.0
            shimmerContainer.startShimmering()
        }
    }

    func configure(with videoUrl: String, previewUrl: String? = nil, title: String? = nil) {
        configurationId &+= 1
        let currentConfigurationId = configurationId

        titleLabel.text = title ?? ""
        durationContainer.isHidden = true
        durationLabel.text = ""

        self.canAutoPlay = Int.random(in: 1...4) == 1
        // willDisplay может случиться до readyToPlay, поэтому запоминаем желание автозапуска.
        self.shouldAutoPlayWhenReady = false

        shimmerContainer.isHidden = false
        shimmerContainer.alpha = 1.0
        hideFallback()
        if self.window != nil && !shimmerContainer.isHidden {
            shimmerContainer.stopShimmering()
            shimmerContainer.startShimmering()
        }

        guard let url = URL(string: videoUrl) else {
            hideShimmer()
            return
        }

        self.currentVideoUrl = url
        self.previewUrlString = previewUrl
        self.retryCount = 0
        self.hasVisualContent = false

        // Длительность считаем независимо от плеера (плеер будем создавать лениво).
        // Для remote-URL просим "не точную" длительность — обычно быстрее.
        loadDuration(
            from: AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false]),
            expectedUrl: url,
            configurationId: currentConfigurationId
        )

        // Попробуем быстро показать превью, чтобы не видеть черный экран,
        // пока AVPlayer подгружает asset.
        if let previewUrl, let preview = URL(string: previewUrl) {
            showPreviewURL = preview
            ImageLoader.shared.load(url: preview) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard self.configurationId == currentConfigurationId, self.showPreviewURL == preview else { return }

                    if let image {
                        self.thumbnailImageView.image = image
                        self.hasVisualContent = true
                        self.hideFallback()
                        // Как только у нас есть хоть что-то (превью) — можно убрать шиммер.
                        if !self.shimmerContainer.isHidden {
                            self.hideShimmer()
                        }
                    } else {
                        // Preview URL вернул nil (404, битый файл и т.п.) —
                        // сбрасываем previewUrlString чтобы loadThumbnail не вышел раньше времени,
                        // и генерируем first-frame из самого видео как fallback.
                        self.previewUrlString = nil
                        self.showPreviewURL = nil
                        if let videoUrl = self.currentVideoUrl {
                            self.loadThumbnail(for: videoUrl, fallbackPreviewUrl: nil, attempt: 1, configurationId: currentConfigurationId)
                        }
                    }
                }
            }
        } else {
            showPreviewURL = nil
            thumbnailImageView.image = nil
        }

        scheduleShimmerTimeout()
    }

    /// Вызываем из `willDisplay`. Если контент уже загружен — ничего не делаем.
    /// Иначе принудительно запускаем генерацию thumbnail из видео как fallback,
    /// даже если previewUrl ещё грузится (ImageLoader и thumbnail работают параллельно —
    /// кто первый, тот и покажет картинку).
    func willDisplay() {
        guard let url = currentVideoUrl else { return }
        guard !hasVisualContent else { return }

        // Ячейка могла уехать с экрана и вернуться без prepareForReuse.
        // Сбрасываем флаг, чтобы loadThumbnail не был заблокирован
        // предыдущей незавершённой попыткой.
        isGeneratingThumbnail = false
        loadThumbnail(for: url, fallbackPreviewUrl: nil, attempt: 1, configurationId: configurationId)
    }

    private func scheduleShimmerTimeout() {
        shimmerTimeoutWorkItem?.cancel()
        hardFailureWorkItem?.cancel()

        // 1) Мягкий таймаут: при отключённом fallback UI ничего не показываем.
        // Оставляем этот таймер только чтобы иметь точку расширения, но по факту не меняем UI.
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isFallbackEnabled {
                // legacy behavior: keep for future
                if !self.shimmerContainer.isHidden {
                    self.hideShimmer()
                    if !self.hasVisualContent {
                        self.showFallback(message: Constants.softTimeoutMessage)
                    }
                }
            }
        }
        shimmerTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.softTimeoutSeconds, execute: workItem)

        // 2) Жёсткий таймаут: через длительное время останавливаем shimmer,
        // чтобы не крутить вечную анимацию. Сообщение НЕ показываем.
        let hardFailureItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.hasVisualContent else { return }
            self.hideShimmer()
            if self.isFallbackEnabled {
                self.showFallback(message: Constants.hardTimeoutMessage)
            }
        }
        hardFailureWorkItem = hardFailureItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.hardTimeoutSeconds, execute: hardFailureItem)
    }

    private func setupPlayer(with url: URL) {
        cleanUpPlayerObservers()

        // Ячейки сетки автоматически воспроизводят видео без звука.
        // Используем .ambient + .mixWithOthers, чтобы не прерывать фоновую музыку других приложений.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        // NOTE: Для remote-URL подсказка "precise duration" может сильно замедлять старт.
        // Нам достаточно приблизительной длительности (таймер в углу), поэтому отключаем.
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        )

        let playerItem = AVPlayerItem(asset: asset)
        if #available(iOS 10.0, *) {
            // Меньше ждать буферизации перед стартом (быстрее первый кадр).
            // Риск: на плохой сети может чаще подстопорить.
            playerItem.preferredForwardBufferDuration = 1.0
        }
        player = AVPlayer(playerItem: playerItem)
        if #available(iOS 10.0, *) {
            // Снижает стартовую задержку, но может увеличить шанс stalling на плохой сети.
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        player?.isMuted = true
        player?.actionAtItemEnd = .none
        playerLayer.player = player

        setupTimeObserver()

        playerItemStatusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.shimmerTimeoutWorkItem?.cancel()
                    self.hardFailureWorkItem?.cancel()
                    self.hideShimmer()
                    self.hasVisualContent = true
                    self.hideFallback()

                    // playerLayer теперь НАД thumbnailImageView — плеер закроет превью
                    // автоматически при воспроизведении. Анимировать alpha не нужно.

                    // Автопроигрывание (рандомно canAutoPlay) — запускаем когда player готов.
                    if self.canAutoPlay, self.shouldAutoPlayWhenReady {
                        self.player?.play()
                        self.isPlaying = true
                    }
                } else if item.status == .failed {
                    self.handlePlayerError()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    private func handlePlayerError() {
        guard retryCount < maxRetries, let url = currentVideoUrl else {
            shimmerTimeoutWorkItem?.cancel()
            hideShimmer()
            showFallback(message: DivoStrings.videoUnavailable)
            return
        }

        retryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !self.shimmerContainer.isHidden else { return }
            self.setupPlayer(with: url)
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.totalDurationSeconds > 0 else { return }

            let currentSeconds = CMTimeGetSeconds(time)
            let remainingSeconds = max(0, self.totalDurationSeconds - currentSeconds)

            self.durationLabel.text = self.formatDuration(seconds: remainingSeconds)
        }
    }

    private func loadDuration(from asset: AVAsset, expectedUrl: URL, configurationId: Int) {
        asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)

            if status == .loaded {
                let duration = asset.duration
                let seconds = CMTimeGetSeconds(duration)

                if !seconds.isNaN && !seconds.isInfinite && seconds > 0 {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        // Ячейка могла переиспользоваться, игнорируем результаты старого запроса.
                        guard self.configurationId == configurationId, self.currentVideoUrl == expectedUrl else { return }

                        self.totalDurationSeconds = seconds
                        self.durationLabel.text = self.formatDuration(seconds: seconds)
                        self.durationContainer.isHidden = false
                    }
                } else if seconds == 0 {
                    // Нулевая длительность означает, что moov-атом находится в конце файла.
                    // Повторяем запрос с точным режимом — он скачает достаточно данных для метаданных.
                    let preciseAsset = AVURLAsset(
                        url: expectedUrl,
                        options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    )
                    self?.loadDuration(from: preciseAsset, expectedUrl: expectedUrl, configurationId: configurationId)
                }
            }
        }
    }

    private func formatDuration(seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func loadThumbnail(for videoUrl: URL, fallbackPreviewUrl: String?, attempt: Int, configurationId: Int) {
        // Если превью задано — мы уже показываем его через ImageLoader.
        // Здесь оставляем генерацию thumbnail из видео только как fallback.
        if fallbackPreviewUrl != nil {
            return
        }

        let cacheKey = videoUrl.absoluteString as NSString
        if let cachedImage = Self.firstFrameCache.object(forKey: cacheKey) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.configurationId == configurationId, self.currentVideoUrl == videoUrl else { return }
                self.thumbnailImageView.image = cachedImage
                self.hasVisualContent = true
                self.hideFallback()
                if !self.shimmerContainer.isHidden {
                    self.hideShimmer()
                }
            }
            return
        }

        if let previewImage = Self.previewFrameCache.object(forKey: cacheKey) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.configurationId == configurationId, self.currentVideoUrl == videoUrl else { return }
                if !self.hasVisualContent {
                    self.thumbnailImageView.image = previewImage
                    self.hasVisualContent = true
                    self.hideFallback()
                    if !self.shimmerContainer.isHidden {
                        self.hideShimmer()
                    }
                }
            }
        }

        guard !isGeneratingThumbnail else {
            return
        }
        isGeneratingThumbnail = true

        // Если генератор "зависнет" и не вызовет callback (такое бывает на remote asset),
        // обязательно освобождаем слот семафора и разрешаем повторную попытку.
        thumbnailGenerationWatchdogWorkItem?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            // Если состояние уже не актуально — ничего не делаем.
            guard self.configurationId == configurationId, self.currentVideoUrl == videoUrl else {
                return
            }
            guard self.isGeneratingThumbnail else {
                return
            }
            self.thumbnailGenerator?.cancelAllCGImageGeneration()
            self.thumbnailGenerator = nil
            self.isGeneratingThumbnail = false

            // Дадим шанс повторной попытке.
            if attempt < self.maxRetries {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.loadThumbnail(for: videoUrl, fallbackPreviewUrl: fallbackPreviewUrl, attempt: attempt + 1, configurationId: configurationId)
                }
            }
        }
        thumbnailGenerationWatchdogWorkItem = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: watchdog)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Ограничиваем параллельную генерацию, чтобы быстрый скролл не создавал
            // десятки тяжелых операций одновременно.
            Self.thumbnailGenerationSemaphore.wait()

            // Семафор мы захватили — сигналим строго один раз через замыкание.
            // Используем os_unfair_lock, чтобы не задерживать signal() диспатчем на main.
            let signalLock = NSLock()
            var didSignal = false
            let signalOnce: () -> Void = {
                signalLock.lock()
                defer { signalLock.unlock() }
                guard !didSignal else { return }
                didSignal = true
                Self.thumbnailGenerationSemaphore.signal()
            }

            guard let self = self else {
                signalOnce()
                return
            }
            guard self.configurationId == configurationId, self.currentVideoUrl == videoUrl else {
                signalOnce()
                DispatchQueue.main.async { [weak self] in
                    self?.isGeneratingThumbnail = false
                }
                return
            }

            // На первой попытке используем быстрый режим (moov в начале файла — норма).
            // На повторных — включаем точный: он справится с файлами, где moov в конце.
            let asset = AVURLAsset(
                url: videoUrl,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: attempt > 1]
            )
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = Constants.thumbnailMaximumSize
            self.thumbnailGenerator = imageGenerator

            // Прогрессивные временные метки: попытка 1 → 0.1 с, 2 → 1.5 с, 3 → 30 % длины видео (мин. 3 с).
            let seekSeconds: Double
            switch attempt {
            case 1:  seekSeconds = 0.1
            case 2:  seekSeconds = 1.5
            default: seekSeconds = max(self.totalDurationSeconds * 0.3, 3.0)
            }
            let time = CMTime(seconds: seekSeconds, preferredTimescale: 600)
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, result, _ in
                signalOnce()

                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    self.thumbnailGenerationWatchdogWorkItem?.cancel()
                    self.isGeneratingThumbnail = false
                    self.thumbnailGenerator = nil

                    guard self.configurationId == configurationId, self.currentVideoUrl == videoUrl else { return }

                    if result == .succeeded, let cgImage {
                        // Если кадр почти чёрный (fade-in / тёмное начало) — повторяем
                        // с более поздней меткой, чтобы не кешировать чёрное превью.
                        if self.isEssentiallyBlack(cgImage), attempt < self.maxRetries {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                self?.loadThumbnail(for: videoUrl, fallbackPreviewUrl: fallbackPreviewUrl, attempt: attempt + 1, configurationId: configurationId)
                            }
                            return
                        }
                        let image = UIImage(cgImage: cgImage)
                        Self.firstFrameCache.setObject(image, forKey: cacheKey)
                        self.thumbnailImageView.image = image
                        self.hasVisualContent = true
                        self.hideFallback()
                        // Как только смогли показать кадр — прекращаем shimmer,
                        // чтобы не видеть «черный экран» на медленной загрузке плеера.
                        if !self.shimmerContainer.isHidden {
                            self.hideShimmer()
                        }
                    } else {
                        if attempt < self.maxRetries {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                self?.loadThumbnail(for: videoUrl, fallbackPreviewUrl: fallbackPreviewUrl, attempt: attempt + 1, configurationId: configurationId)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Возвращает `true`, если изображение почти полностью чёрное (средняя яркость < 15/255).
    /// Используется для обнаружения кадра fade-in / тёмного начала видео.
    private func isEssentiallyBlack(_ cgImage: CGImage) -> Bool {
        let size = CGSize(width: 1, height: 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(
            data: &pixel,
            width: 1, height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        let brightness = (Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / 3
        return brightness < 15
    }

    private func hideShimmer() {
        shimmerContainer.stopShimmering()
        UIView.animate(withDuration: 0.3) {
            self.shimmerContainer.alpha = 0
        } completion: { _ in
            self.shimmerContainer.isHidden = true
        }
    }

    private func showFallback(message: String) {
        guard isFallbackEnabled else {
            return
        }
        fallbackLabel.text = message
        fallbackContainer.isHidden = false
    }

    private func hideFallback() {
        fallbackContainer.isHidden = true
    }

    func play() {
        guard canAutoPlay else {
            return
        }

        // willDisplay сообщает, что ячейка на экране — хотим автоплей.
        shouldAutoPlayWhenReady = true

        // Плеер создаем лениво — только для тех ячеек, которые реально должны автопроигрываться.
        if player == nil, let url = currentVideoUrl {
            setupPlayer(with: url)
        }

        guard let player = player, !isPlaying else { return }

        // Если player ещё не readyToPlay — реально стартанём в observe(status).
        if player.currentItem?.status == .readyToPlay {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    func stop() {
        guard let player = player else { return }
        player.pause()
        player.seek(to: .zero)
        isPlaying = false
        shouldAutoPlayWhenReady = false
        durationLabel.text = formatDuration(seconds: totalDurationSeconds)
    }

    /// Вызывать, когда ячейка уехала с экрана — освобождаем AVPlayer, чтобы не копить ресурсы.
    func stopAndReleasePlayer() {
        stop()
        cleanUpPlayerObservers()
        playerLayer.player = nil
        player = nil
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        // Лупаем только если видео реально играет (иначе можно получить скрытое воспроизведение/нагрузку).
        guard isPlaying else { return }
        player?.seek(to: .zero)
        player?.play()
    }

    private func cleanUpPlayerObservers() {
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAndReleasePlayer()

        thumbnailGenerator?.cancelAllCGImageGeneration()
        thumbnailGenerator = nil
        isGeneratingThumbnail = false
        thumbnailGenerationWatchdogWorkItem?.cancel()
        thumbnailGenerationWatchdogWorkItem = nil

        shimmerTimeoutWorkItem?.cancel()
        shimmerTimeoutWorkItem = nil
        hardFailureWorkItem?.cancel()
        hardFailureWorkItem = nil

        playerLayer.player = nil
        player = nil
        titleLabel.text = nil
        thumbnailImageView.cancelImageLoad()
        thumbnailImageView.image = nil
        canAutoPlay = false
        shouldAutoPlayWhenReady = false
        configurationId &+= 1
        currentVideoUrl = nil
        showPreviewURL = nil
        previewUrlString = nil
        totalDurationSeconds = 0
        hasVisualContent = false

        durationContainer.isHidden = true
        durationLabel.text = ""

        shimmerContainer.layer.removeAllAnimations()
        shimmerContainer.alpha = 1.0
        shimmerContainer.isHidden = false
        fallbackContainer.isHidden = true
    }

    deinit {
        cleanUpPlayerObservers()
        shimmerTimeoutWorkItem?.cancel()
        hardFailureWorkItem?.cancel()
        thumbnailGenerator?.cancelAllCGImageGeneration()
        thumbnailGenerationWatchdogWorkItem?.cancel()
    }
}

