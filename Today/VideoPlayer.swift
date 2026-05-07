//
//  VideoPlayer.swift
//  Today
//
//  Created by Ethan John Lagera on 5/7/26.
//
//  Derived from a tutorial from Medium from Anie A P
//  https://medium.com/@aniepeterjy/building-a-custom-swiftui-video-player-with-avplayer-bd69a85cfc23

import SwiftUI
import AVKit
internal import Combine


class VideoViewModel: ObservableObject {
    @Published private(set) var isPlayerReady = false
    @Published var isPlaying = false
    private(set) var player = AVPlayer()
    
    private var cancellables = Set<AnyCancellable>()
    private var playbackObserver: NSObjectProtocol?
    private var readyObserver: NSKeyValueObservation?
    
    init(video: String = "example") {
        self.configurePlayer()
        self.loadVideo(named: video)
        self.observeAppLifecycle()
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
        self.removePlaybackObserver()
        self.readyObserver?.invalidate()
        self.readyObserver = nil
    }
    
    //MARK: - Setup
    private func configurePlayer() {
        player.automaticallyWaitsToMinimizeStalling = false
    }
    
    private func loadVideo(named name: String) {
        guard let localURL = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            print("Video \(name).mp4 not found.")
            return
        }
        
        let item = AVPlayerItem(url: localURL)
        self.player.replaceCurrentItem(with: item)
        self.observeReady(item: item)
    }
    
    //MARK: - Observers
    private func observeReady(item: AVPlayerItem) {
        self.readyObserver?.invalidate()
        self.readyObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] playerItem, _ in
            guard let self else { return }
            
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.isPlayerReady = true
                }
            }
            self.observePlaybackEnd(item: playerItem)
        }
    }
    
    private func observePlaybackEnd(item: AVPlayerItem) {
        self.removePlaybackObserver()
        
        self.playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main) { [weak self] _ in
                guard let self else { return }
                self.player.seek(to: .zero)
                self.player.play()
            }
    }
    
    private func observeAppLifecycle() {
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &self.cancellables)
        
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.play()
            }
            .store(in: &self.cancellables)
    }
    
    private func removePlaybackObserver() {
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    //MARK: - Playback Controls
    func togglePlayback() {
        self.isPlaying ? self.pause() : self.play()
    }
    
    func play() {
        self.player.play()
        isPlaying = true
    }
    
    func pause() {
        self.player.pause()
        isPlaying = false
    }
}

struct WrappedVideoView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(player: player)
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.updatePlayer(player)
    }
}

class PlayerView: UIView {
    private var playerLayer: AVPlayerLayer?
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        setupPlayer(player)
    }
    
    func updatePlayer(_ player: AVPlayer) {
        playerLayer?.player = player
    }
    
    private func setupPlayer(_ player: AVPlayer) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        self.playerLayer = layer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
