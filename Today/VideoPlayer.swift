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
import Combine


class VideoViewModel: ObservableObject {
    @Published private(set) var isPlayerReady = false
    @Published var isPlaying = false
    private(set) var player = AVPlayer()
    
    private var cancellables = Set<AnyCancellable>()
    private var playbackObserver: NSObjectProtocol?
    private var readyObserver: NSKeyValueObservation?
    
    init(fileURL: URL?) {
        self.configurePlayer()
        self.loadVideo(fileURL: fileURL)
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
    
    func loadVideo(fileURL: URL?) {
        guard let file = fileURL else { return }
        let item = AVPlayerItem(url: file)
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
                // Just pause at the end, don't auto-reset
                self.player.pause()
                self.isPlaying = false
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
        // If we're at the end, reset to beginning before playing
        if let currentItem = player.currentItem {
            let duration = CMTimeGetSeconds(currentItem.duration)
            let currentTime = CMTimeGetSeconds(player.currentTime())
            if currentTime >= duration - 0.01 {
                player.seek(to: .zero)
            }
        }
        
        player.volume = 0.0
        self.player.play()
        isPlaying = true
        
        _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] t in
            player.volume += 0.1
            
            if player.volume >= 1.0 {
                player.volume = 1.0
                t.invalidate()
            }
        }
    }
    
    func pause() {
        self.player.pause()
        isPlaying = false
    }
}

struct VideoPlayerView: View {
    let player: AVPlayer
    
    var body: some View {
        ZStack {
            WrappedVideoView(player: player, videoGravity: .resize)
                .blur(radius: 12)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            WrappedVideoView(player: player, videoGravity: .resizeAspect)
                .padding(4)
                .compositingGroup()
                .mask(
                    ZStack {
                        // vertical fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0), location: 0),
                                .init(color: Color.white, location: 0.1),
                                .init(color: Color.white, location: 0.9),
                                .init(color: Color.white.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // horizontal fade multiplied with vertical fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0), location: 0),
                                .init(color: Color.white, location: 0.1),
                                .init(color: Color.white, location: 0.9),
                                .init(color: Color.white.opacity(0), location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blendMode(.multiply)
                    }
                        .blur(radius: 12)
                )
        }
    }
}

struct WrappedVideoView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    
    func makeUIView(context: Context) -> PlayerView {
        return PlayerView(player: player, videoGravity: videoGravity)
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.updatePlayer(player)
    }
}

class PlayerView: UIView {
    private var playerLayer: AVPlayerLayer?
    
    init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        super.init(frame: .zero)
        setupPlayer(player, videoGravity: videoGravity)
    }
    
    func updatePlayer(_ player: AVPlayer) {
        playerLayer?.player = player
    }
    
    private func setupPlayer(_ player: AVPlayer, videoGravity: AVLayerVideoGravity) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = videoGravity
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
