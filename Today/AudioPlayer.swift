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
    @Published private(set) var audioLevels: [CGFloat] = []
    @Published private(set) var isPlayerReady = false
    @Published var isPlaying = false
    @Published var duration = 0.0
    @Published var currentTime = 0.0
    @Published var isScrubbing = false
    @Published private(set) var fullWaveformLevels: [CGFloat] = []
    
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var meterTimer: Timer?
    private var playbackTimer: Timer?
    
    private var playbackOffset: TimeInterval = 0
    private var scheduleToken = UUID()
    private var waveformLevels: [CGFloat] = []
    private var lastWaveformIndex = 0
    private let waveformWindowSize = 200
    
    @Published private(set) var waveformResetToken = 0
    
    // For real-time metering
    private var currentLevels: [Float] = []
    private let levelQueue = DispatchQueue(label: "com.audio.levels")
    
    // Noise gate threshold in dB - suppress levels below this
    private let noiseFloorThreshold: Float = -80
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Pre-loaded power frames from saved data (audio-only)
    private var savedPowerFrames: [CodableRecordedPowerFrame]? = nil
    
    init(fileURL: URL, preloadedPowerFrames: [CodableRecordedPowerFrame]? = nil) {
        self.savedPowerFrames = preloadedPowerFrames
        self.loadAudio(fileURL: fileURL)
        self.observeAppLifecycle()
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
        self.stopMeterTimer()
        self.stopPlaybackTimer()
        self.stopEngine()
    }
    
    private func loadAudio(fileURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            self.audioFile = audioFile
            self.duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            self.currentTime = 0
            self.playbackOffset = 0
            self.setupAudioEngine()
            
            // Load waveform from saved data or generate if not available
            if let savedFrames = savedPowerFrames {
                self.loadWaveformFromSavedFrames(savedFrames)
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
        
        // Setup audio tap for real-time metering
        setupAudioTap(playerNode: playerNode, engine: engine)
        
        do {
            try engine.start()
            self.engine = engine
            self.playerNode = playerNode
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
    
    private func setupAudioTap(playerNode: AVAudioPlayerNode, engine: AVAudioEngine) {
        guard let audioFile = audioFile else { return }
        let format = audioFile.processingFormat
        
        // Install a tap on the output to monitor levels
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.analyzeLevels(buffer: buffer)
        }
    }
    
    private func analyzeLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var levels: [Float] = []
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            
            // Find peak value for this channel (more responsive than RMS)
            var peak: Float = 0
            for i in 0..<frameLength {
                let absValue = abs(data[i])
                if absValue > peak {
                    peak = absValue
                }
            }
            
            // Convert to dB
            let db = peak > 0 ? 20 * log10(peak) : -160
            
            // Apply noise gate: suppress signals below noise floor threshold
            let gatedDb = db < noiseFloorThreshold ? -160 : db
            
            // Normalize to 0...1 using the range from noise floor to 0 dB
            let normalized = max(0, min(1, (gatedDb - noiseFloorThreshold) / (-noiseFloorThreshold)))
            levels.append(normalized)
        }
        
        levelQueue.async {
            self.currentLevels = levels
        }
    }
    
    private func loadWaveformFromSavedFrames(_ frames: [CodableRecordedPowerFrame]) {
        DispatchQueue.main.async {
            // Convert power metrics (dBFS) to normalized levels
            self.waveformLevels = frames.map { frame in
                // Use the peak dB value from the first channel if available
                if let firstMetric = frame.metrics.first {
                    return self.normalizeDbLevel(firstMetric.peak)
                }
                return 0.0
            }

            self.fullWaveformLevels = self.waveformLevels
            self.lastWaveformIndex = 0
            self.waveformResetToken += 1
            self.audioLevels = []
            self.refreshWaveformForCurrentTime()
        }
    }

    /// Normalize a linear peak amplitude (0..1) to 0..1 using noise floor -> 0 dB mapping
    private func normalizeLevel(_ peak: Float) -> CGFloat {
        let db = peak > 0 ? 20 * log10(peak) : -160
        return normalizeDbLevel(db)
    }

    /// Normalize a dBFS value (negative -> 0 dB range) into 0..1 for waveform rendering
    private func normalizeDbLevel(_ db: Float) -> CGFloat {
        return CGFloat(normalizeDbToLinear(db, noiseFloorThreshold: noiseFloorThreshold))
    }
    
    private func refreshWaveformForCurrentTime() {
        let index = waveformIndex(for: currentTime)
        setWaveformIndex(index)
    }
    
    private func waveformIndex(for time: TimeInterval) -> Int {
        guard duration > 0, !waveformLevels.isEmpty else { return 0 }
        let ratio = max(0, min(1, time / duration))
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
        stopMeterTimer()
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
        guard let audioFile = audioFile, let playerNode = playerNode else { return }
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
        playerNode.scheduleSegment(audioFile, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.scheduleToken == token else { return }
                self.handlePlaybackEnded()
            }
        }
        
        if playImmediately {
            playerNode.play()
            playbackOffset = currentTime
            isPlaying = true
            startMeterTimer()
            startPlaybackTimer()
        }
    }
    
    private func handlePlaybackEnded() {
        scheduleToken = UUID()
        playerNode?.stop()
        isPlaying = false
        stopMeterTimer()
        stopPlaybackTimer()
        // Keep position at end instead of resetting
        currentTime = duration
        playbackOffset = duration
        lastWaveformIndex = waveformLevels.count
        // Don't clear audioLevels - keep waveform visible
        levelQueue.async { [weak self] in
            self?.currentLevels = []
        }
    }
    
    //MARK: - Audio Metering
    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.updateAudioLevels()
        }
    }
    
    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }
    
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
              let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else { return }
        
        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = playbackOffset + elapsed
        refreshWaveformForCurrentTime()
    }
    
    private func updateAudioLevels() {
        guard playerNode?.isPlaying == true else { return }
        refreshWaveformForCurrentTime()
    }
}

struct AudioPlayerView: View {
    @StateObject var viewModel: AudioViewModel
    @State private var wasPlayingBeforeScrub = false
    @State private var lastScrubUpdate: TimeInterval = 0
    @State private var initialScrubPosition: CGFloat? = nil
    
    private let scrubThrottle: TimeInterval = 0.05
    
    var body: some View {
        VStack {
            Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))")
                .font(.headline)
                .monospacedDigit()
                .padding()
            
            Spacer()
            
            GeometryReader { proxy in
                ZStack {
                    WaveformView(
                        fullLevels: viewModel.fullWaveformLevels,
                        currentTime: viewModel.currentTime,
                        duration: viewModel.duration,
                        isPlaybackView: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !viewModel.isScrubbing {
                                wasPlayingBeforeScrub = viewModel.isPlaying
                                viewModel.pause()
                                viewModel.isScrubbing = true
                                initialScrubPosition = value.location.x
                            }
                            
                            let width = max(1, proxy.size.width)
                            let clampedX = min(max(0, value.location.x), width)
                            let percentage = 1 - (clampedX / width)
                            let targetTime = viewModel.duration * Double(percentage)
                            
                            viewModel.updateScrubTime(targetTime)
                            
                            // Only seek after user has moved more than a small threshold from initial position
                            if let initialPos = initialScrubPosition, abs(value.location.x - initialPos) > 10 {
                                let now = CFAbsoluteTimeGetCurrent()
                                if now - lastScrubUpdate >= scrubThrottle {
                                    lastScrubUpdate = now
                                    viewModel.seek(to: targetTime)
                                }
                            }
                        }
                        .onEnded { _ in
                            viewModel.isScrubbing = false
                            lastScrubUpdate = 0
                            initialScrubPosition = nil
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
