//
//  AudioPlayer.swift
//  Today
//
//  Created by Ethan John Lagera on 5/14/26.
//

import AVFAudio
import Combine
import SwiftUI

class AudioViewModel: ObservableObject {
    @Published private(set) var audioLevels: [CGFloat] = []
    @Published private(set) var isPlayerReady = false
    @Published var isPlaying = false
    @Published var duration = 0.0
    @Published private(set) var waveformDuration = 0.0
    @Published var currentTime = 0.0
    @Published var isScrubbing = false
    @Published private(set) var fullWaveformLevels: [CGFloat] = []

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?

    private var playbackOffset: TimeInterval = 0
    private var scheduleToken = UUID()
    private var waveformLevels: [CGFloat] = []
    private var lastWaveformIndex = 0
    private let waveformWindowSize = 200

    @Published private(set) var waveformResetToken = 0

    private var cancellables = Set<AnyCancellable>()

    /// Pre-loaded waveform from saved data (audio-only)
    private var savedWaveform: CodableAudioWaveform? = nil

    /// Expose waveform for debugging/inspection
    var debugWaveform: CodableAudioWaveform? { savedWaveform }

    init(fileURL: URL, preloadedWaveform: CodableAudioWaveform? = nil) {
        self.savedWaveform = preloadedWaveform
        self.loadAudio(fileURL: fileURL)
        self.observeAppLifecycle()
    }

    deinit {
        self.cancellables.forEach { $0.cancel() }
        self.stopPlaybackTimer()
        self.stopEngine()
    }

    private func loadAudio(fileURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            self.audioFile = audioFile
            self.duration =
                Double(audioFile.length) / audioFile.processingFormat.sampleRate
            self.waveformDuration = self.duration
            self.currentTime = 0
            self.playbackOffset = 0
            self.setupAudioEngine()

            // Load waveform from saved data if available
            if let savedWaveform {
                self.loadWaveformFromSavedWaveform(savedWaveform)
            }

            self.isPlayerReady = true
        } catch {
            print("Error loading audio: \(error)")
            self.isPlayerReady = false
        }
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()

        engine.attach(playerNode)

        // Connect player to output
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
            self.engine = engine
            self.playerNode = playerNode
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    private func loadWaveformFromSavedWaveform(_ waveform: CodableAudioWaveform)
    {
        DispatchQueue.main.async {
            let sampleDuration =
                waveform.sampleRateHz > 0
                ? Double(waveform.samplesLinear.count)
                    / Double(waveform.sampleRateHz)
                : 0
            let effectiveDuration =
                waveform.duration > 0 ? waveform.duration : sampleDuration
            self.waveformDuration = effectiveDuration
            self.waveformLevels = waveform.samplesLinear.map { CGFloat($0) }
            self.fullWaveformLevels = self.waveformLevels
            self.lastWaveformIndex = 0
            self.waveformResetToken += 1
            self.audioLevels = []
            self.refreshWaveformForCurrentTime()
        }
    }

    private func refreshWaveformForCurrentTime() {
        let index = waveformIndex(for: currentTime)
        setWaveformIndex(index)
    }

    private func waveformIndex(for time: TimeInterval) -> Int {
        guard waveformDuration > 0, !waveformLevels.isEmpty else { return 0 }
        let ratio = max(0, min(1, time / waveformDuration))
        return Int(Double(waveformLevels.count) * ratio)
    }

    private func setWaveformIndex(_ index: Int) {
        guard !waveformLevels.isEmpty else { return }
        let clampedIndex = max(0, min(index, waveformLevels.count))

        if clampedIndex < lastWaveformIndex {
            waveformResetToken += 1
            let windowStart = max(0, clampedIndex - waveformWindowSize)
            audioLevels = Array(waveformLevels[windowStart..<clampedIndex])
        } else if clampedIndex > lastWaveformIndex {
            let newLevels = waveformLevels[lastWaveformIndex..<clampedIndex]
            audioLevels = Array(newLevels)
        }

        lastWaveformIndex = clampedIndex
    }

    private func stopEngine() {
        if let playerNode = playerNode {
            engine?.mainMixerNode.removeTap(onBus: 0)
            playerNode.stop()
        }
        engine?.stop()
        engine = nil
        playerNode = nil
    }

    //MARK: - Observers
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(
            for: UIApplication.willResignActiveNotification
        )
        .sink { [weak self] _ in
            self?.pause()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )
        .sink { [weak self] _ in
            self?.play()
        }
        .store(in: &cancellables)
    }

    //MARK: - Playback Controls
    func togglePlayback() {
        guard isPlayerReady else { return }
        if playerNode?.isPlaying == true {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard isPlayerReady, let engine = engine else { return }

        // If we're at the end, reset to beginning before playing
        if currentTime >= duration - 0.01 {
            currentTime = 0
            playbackOffset = 0
            lastWaveformIndex = 0
            waveformResetToken += 1
            audioLevels = []
        }

        if !(playerNode?.isPlaying ?? false) {
            do {
                if !engine.isRunning {
                    try engine.start()
                }

                scheduleFromCurrentTime(playImmediately: true)
            } catch {
                print("Error starting playback: \(error)")
            }
        }
    }

    func pause() {
        scheduleToken = UUID()
        updateCurrentTime()
        playerNode?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func updateScrubTime(_ time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime
        playbackOffset = clampedTime
        refreshWaveformForCurrentTime()
    }

    func seek(to time: TimeInterval) {
        updateScrubTime(time)
        scheduleFromCurrentTime(playImmediately: false)
    }

    private func scheduleFromCurrentTime(playImmediately: Bool) {
        guard let audioFile = audioFile, let playerNode = playerNode else {
            return
        }
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(currentTime * sampleRate)

        if startFrame >= audioFile.length {
            if playImmediately {
                handlePlaybackEnded()
            } else {
                currentTime = duration
                playbackOffset = duration
            }
            return
        }

        let frameCount = AVAudioFrameCount(audioFile.length - startFrame)

        let token = UUID()
        scheduleToken = token

        playerNode.stop()
        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.scheduleToken == token else {
                    return
                }
                self.handlePlaybackEnded()
            }
        }

        if playImmediately {
            playerNode.play()
            playbackOffset = currentTime
            isPlaying = true
            startPlaybackTimer()
        }
    }

    private func handlePlaybackEnded() {
        scheduleToken = UUID()
        playerNode?.stop()
        isPlaying = false
        stopPlaybackTimer()
        // Keep position at end instead of resetting
        currentTime = duration
        playbackOffset = duration
        lastWaveformIndex = waveformLevels.count
        // Don't clear audioLevels - keep waveform visible
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        // Higher cadence keeps waveform progress visually in sync with playback near the end.
        playbackTimer = Timer.scheduledTimer(
            withTimeInterval: 0.033,
            repeats: true
        ) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updateCurrentTime() {
        guard let playerNode = playerNode,
            playerNode.isPlaying,
            let lastRenderTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime)
        else { return }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        let updatedTime = playbackOffset + elapsed
        currentTime = min(duration, max(0, updatedTime))
        refreshWaveformForCurrentTime()
    }

}

struct AudioPlayerView: View {
    @StateObject var viewModel: AudioViewModel
    @State private var wasPlayingBeforeScrub = false
    @State private var scrubStartTime: TimeInterval? = nil

    var body: some View {
        VStack {
            Text(
                "\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))"
            )
            .font(.headline)
            .monospacedDigit()
            .padding()

            Spacer()

            GeometryReader { proxy in
                WaveformView(
                    fullLevels: viewModel.fullWaveformLevels,
                    currentTime: viewModel.currentTime,
                    duration: viewModel.waveformDuration,
                    isPlaybackView: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if !viewModel.isScrubbing {
                                wasPlayingBeforeScrub = viewModel.isPlaying
                                viewModel.pause()
                                viewModel.isScrubbing = true
                                scrubStartTime = viewModel.currentTime
                            }

                            let startTime = scrubStartTime ?? viewModel.currentTime
                            let width = max(1, proxy.size.width)
                            let timeDelta = Double(value.translation.width / width)
                                * viewModel.duration * -1
                            let targetTime = startTime + timeDelta

                            viewModel.seek(to: targetTime)
                        }
                        .onEnded { _ in
                            viewModel.isScrubbing = false
                            scrubStartTime = nil
                            if wasPlayingBeforeScrub {
                                viewModel.play()
                            }
                        }
                )
            }
            .frame(height: 200)
            .padding()

            Spacer()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
