//
//  AudioPlayer.swift
//  Today
//
//  Created by Ethan John Lagera on 5/14/26.
//

import SwiftUI
import AVFAudio
import Combine

class AudioViewModel: ObservableObject {
    @Published private(set) var isPlayerReady = false
    @Published var isPlaying = false
    @Published private(set) var audioLevels: [CGFloat] = []
    private(set) var player = AVAudioPlayer()
    
    private var cancellables = Set<AnyCancellable>()
    private var playbackObserver: NSObjectProtocol?
    private var readyObserver: NSKeyValueObservation?
    private var meterTimer: Timer?
    
    init(fileURL: URL) {
        self.configurePlayer()
        self.loadAudio(fileURL: fileURL)
        self.observeAppLifecycle()
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
        self.removePlaybackObserver()
        self.readyObserver?.invalidate()
        self.readyObserver = nil
        self.stopMeterTimer()
    }
    
    private func configurePlayer() {
        player.prepareToPlay()
    }
        
    private func loadAudio(fileURL: URL) {
        do {
            self.player = try AVAudioPlayer(contentsOf: fileURL)
            self.isPlayerReady = true
        } catch {
            print("Error loading audio: \(error)")
            self.isPlayerReady = false
        }
    }
    
    //MARK: - Observers
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.play()
            }
            .store(in: &cancellables)
    }
    
    private func removePlaybackObserver() {
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    //MARK: - Playback Controls
    func togglePlayback() {
        guard isPlayerReady else { return }
        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard isPlayerReady else { return }
        player.play()
        isPlaying = true
        startMeterTimer()
    }
    
    func pause() {
        guard isPlayerReady else { return }
        player.pause()
        isPlaying = false
        stopMeterTimer()
    }
    
    //MARK: - Audio Metering
    private func startMeterTimer() {
        stopMeterTimer()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioLevels = []
    }
    
    private func updateAudioLevels() {
        guard player.isPlaying else { return }
        
        // Generate simulated audio levels for visualization
        // Using a combination of sine waves with random variation to simulate audio waveform
        let time = Float(player.currentTime)
        let baseFrequency = sin(time * 1.5) * 0.3 + 0.4
        let variation = Float.random(in: 0...0.3)
        let amplitude = (baseFrequency + variation).clamped(to: 0...1)
        
        // Generate 1 level per update call, creating a flowing waveform
        let level = CGFloat(amplitude)
        
        var updatedLevels = audioLevels
        updatedLevels.append(level)
        
        // Keep a reasonable history (cap at 200 levels)
        if updatedLevels.count > 200 {
            updatedLevels.removeFirst()
        }
        
        withAnimation(.linear(duration: 0.06)) {
            audioLevels = updatedLevels
        }
    }
}

struct AudioPlayerView: View {
    @StateObject var viewModel: AudioViewModel
    
    var body: some View {
        VStack {
            Text(Duration.seconds(viewModel.player.currentTime).formatted(.time(pattern: .minuteSecond)))
                .font(.largeTitle)
                .padding()
            Spacer()
            WaveformView(levels: viewModel.audioLevels, isRecording: false)
                .frame(height: 200)
                .padding()
            Spacer()
        }
    }
}
