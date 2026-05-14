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
    
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var meterTimer: Timer?
    
    // For real-time metering
    private var currentLevels: [Float] = []
    private let levelQueue = DispatchQueue(label: "com.audio.levels")
    
    // Noise gate threshold in dB - suppress levels below this
    private let noiseFloorThreshold: Float = -80
    
    private var cancellables = Set<AnyCancellable>()
    
    init(fileURL: URL) {
        self.loadAudio(fileURL: fileURL)
        self.observeAppLifecycle()
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
        self.stopMeterTimer()
        self.stopEngine()
    }
    
    private func loadAudio(fileURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            self.audioFile = audioFile
            self.setupAudioEngine()
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
        guard isPlayerReady, let playerNode = playerNode, let audioFile = audioFile, let engine = engine else { return }
        
        if !playerNode.isPlaying {
            do {
                if !engine.isRunning {
                    try engine.start()
                }
                
                playerNode.scheduleFile(audioFile, at: nil)
                playerNode.play()
                
                isPlaying = true
                startMeterTimer()
            } catch {
                print("Error starting playback: \(error)")
            }
        }
    }
    
    func pause() {
        guard let playerNode = playerNode else { return }
        playerNode.pause()
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
        guard playerNode?.isPlaying == true else { return }
        
        levelQueue.async { [weak self] in
            let levels = self?.currentLevels.map { CGFloat($0) } ?? []
            
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.06)) {
                    self?.audioLevels = levels
                }
            }
        }
    }
}

struct AudioPlayerView: View {
    @StateObject var viewModel: AudioViewModel
    
    var body: some View {
        VStack {
            Text("Audio Player")
                .font(.largeTitle)
                .padding()
            Spacer()
            WaveformView(levels: viewModel.audioLevels, isRecording: viewModel.isPlaying)
                .frame(height: 200)
                .padding()
            Spacer()
        }
    }
}
