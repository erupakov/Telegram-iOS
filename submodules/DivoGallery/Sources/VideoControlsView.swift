import Foundation
import UIKit
import AVFoundation
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import PhotoResources

final class VideoControlsView: UIView {
    private let playPauseButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(12)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0:00"
        return label
    }()
    
    private let muteButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var onSeek: ((Float) -> Void)?
    var onPlayPause: (() -> Void)?
    var onMuteToggle: (() -> Void)?
    
    private var currentDuration: Float = 0
    private var currentProgress: Float = 0
    
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.layer.cornerRadius = 8
        self.clipsToBounds = true
        self.isUserInteractionEnabled = true
        
        self.addSubview(self.playPauseButton)
        self.addSubview(self.slider)
        self.addSubview(self.timeLabel)
        self.addSubview(self.muteButton)
        
        NSLayoutConstraint.activate([
            self.playPauseButton.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            self.playPauseButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            self.playPauseButton.heightAnchor.constraint(equalToConstant: 32),
            
            self.slider.leadingAnchor.constraint(equalTo: self.playPauseButton.trailingAnchor, constant: 8),
            self.slider.trailingAnchor.constraint(equalTo: self.timeLabel.leadingAnchor, constant: -8),
            self.slider.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            self.timeLabel.trailingAnchor.constraint(equalTo: self.muteButton.leadingAnchor, constant: -8),
            self.timeLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.timeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            self.muteButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            self.muteButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.muteButton.widthAnchor.constraint(equalToConstant: 32),
        ])
        
        self.playPauseButton.addTarget(self, action: #selector(self.playPausePressed), for: .touchUpInside)
        self.slider.addTarget(self, action: #selector(self.sliderChanged), for: .valueChanged)
        
        self.slider.isContinuous = true
        self.muteButton.addTarget(self, action: #selector(self.mutePressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Override
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        if hitView == self {
            return nil
        }
        
        return hitView
    }
    
    
    // MARK: - Internal
    
    func setMuted(_ muted: Bool) {
        let imageName = muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        self.muteButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func setPlaying(_ playing: Bool) {
        let imageName = playing ? "pause.fill" : "play.fill"
        self.playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func setDuration(_ duration: Float) {
        guard duration > 0 && !duration.isNaN && !duration.isInfinite else { return }
        
        self.currentDuration = duration
        self.slider.maximumValue = duration
        
        if self.currentDuration > 0 {
            self.updateTimeLabel()
        }
    }
    
    func setCurrentTime(_ currentTime: Float) {
        guard self.currentDuration > 0 && !self.currentDuration.isNaN else { return }
        
        let clampedCurrent = max(0, min(currentTime, self.currentDuration))
        
        let progress = clampedCurrent / self.currentDuration
        self.slider.value = progress
        self.currentProgress = progress
        
        self.updateTimeLabel(currentTime: clampedCurrent)
    }
    
    
    // MARK: - Private
    
    private func updateTimeLabel(currentTime: Float? = nil) {
        let current = currentTime ?? (self.currentProgress * self.currentDuration)
        let total = self.currentDuration
        
        let currentSeconds = Int(current)
        let totalSeconds = Int(total)
        
        let currentMinutes = currentSeconds / 60
        let currentRemainingSeconds = currentSeconds % 60
        
        let totalMinutes = totalSeconds / 60
        let totalRemainingSeconds = totalSeconds % 60
        
        if totalMinutes > 0 {
            self.timeLabel.text = String(format: "%d:%02d / %d:%02d", currentMinutes, currentRemainingSeconds, totalMinutes, totalRemainingSeconds)
        } else {
            self.timeLabel.text = String(format: "%d:%02d", currentMinutes, currentRemainingSeconds)
        }
    }
    
    
    // MARK: - @objc
    
    @objc private func playPausePressed() {
        self.onPlayPause?()
    }
    
    @objc private func sliderChanged() {
        let value = self.slider.value * self.currentDuration
        self.currentProgress = self.slider.value
        self.onSeek?(value)
        self.updateTimeLabel()
    }
    
    @objc private func mutePressed() {
        self.onMuteToggle?()
    }
}

// Helper function for back button icon
private func generateTintedImage(image: UIImage?, color: UIColor) -> UIImage? {
    guard let image = image else { return nil }
    return image.withRenderingMode(.alwaysTemplate)
}