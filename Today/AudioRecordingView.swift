//
//  AudioRecordingView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/12/26.
//

import SwiftUI
import UIKit
import Combine

struct AudioRecordingView: View {
    @StateObject var manager = AudioRecorderManager()
    @Binding var activePage: CreateView.Page
    @Binding var recordedURL: URL?
    @Binding var recordedWaveform: CodableAudioWaveform?
    @Binding var hasTemporaryRecording: Bool
    var onBack: () -> Void
    
    @State private var levels: [CGFloat] = []
    @State private var smoothedLevels: [Float] = [0, 0, 0, 0, 0]
    @State private var elapsedTime: TimeInterval = 0
    @State private var waveformResetToken: Int = 0
    @State private var isRecording: Bool = false
    @State private var isPlaying: Bool = false
    @State private var firstTimePlaying: Bool = true
    @State private var showDiscardConfirmation: Bool = false
    @State private var localRecordedURL: URL? = nil
    @State private var isLandscape: Bool = false
    
    private var hasRecording: Bool {
        localRecordedURL != nil
    }
    
    @State private var recordingTask: Task<Void, Never>?
    @State private var meterPollTask: Task<Void, Never>?
    @State private var playbackPollTask: Task<Void, Never>?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    
    var body: some View {
        Group {
            if isLandscape {
                HStack {
                    VStack(spacing: 0) {
                        stopwatchView()
                        Spacer()
                        waveformView()
                    }
                    
                    VStack(spacing: 0) {
                        buttonView()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    stopwatchView()
                    Spacer()
                    waveformView()
                    Spacer()
                    buttonView()
                }
            }
        }
        .navigationTitle("Audio Entry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
        .alert("Discard Recording?", isPresented: $showDiscardConfirmation) {
            Button("Discard", role: .destructive) {
                Task {
                    do {
                        try manager.discardRecording()
                        localRecordedURL = nil
                        recordedURL = nil
                        recordedWaveform = nil
                        isPlaying = false
                        firstTimePlaying = true
                        elapsedTime = 0
                        levels = []
                    } catch {
                        errorMessage = "Failed to discard recording: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Discarding will permanently delete this recording.")
        }
        .onChange(of: manager.recorderState) { oldValue, newValue in
            updateRecordingState(newValue)
        }
        .onChange(of: manager.didRecordingEnd) {
            if manager.didRecordingEnd {
                isPlaying = false
                playbackPollTask?.cancel()
                playbackPollTask = nil
                firstTimePlaying = true
            }
        }
        .onAppear {
            if let recordedURL = recordedURL, recordedWaveform != nil, localRecordedURL == nil {
                let fileName = recordedURL.lastPathComponent
                
                if let liveDirectory = manager.destinationURL?.deletingLastPathComponent() {
                    let liveRestoredURL = liveDirectory.appendingPathComponent(fileName)
                    
                    if FileManager.default.fileExists(atPath: liveRestoredURL.path) {
                        self.localRecordedURL = liveRestoredURL
                        manager.destinationURL = liveRestoredURL
                        manager.getRecordedWaveform(from: recordedWaveform)
                        
                        manager.stopRecording()
                    } else {
                        print("DEBUG: File could not be found at live path: \(liveRestoredURL.path)")
                    }
                }
            }
        }
        .onDisappear {
            stopRecording()
            manager.pausePlayingRecording()
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        isLandscape = proxy.size.width > proxy.size.height
                    }
                    .onChange(of: proxy.size) {
                        isLandscape = proxy.size.width > proxy.size.height
                    }
            }
        )
    }
    
    func stopwatchView() -> some View {
        VStack(spacing: 16) {
            Text(formatTime(elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    func waveformView() -> some View {
        VStack(spacing: 24) {
            if isRecording {
                Text("Recording...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            WaveformView(levels: levels, isRecording: isRecording || isPlaying, resetToken: waveformResetToken)
                .frame(height: 120)
        }
        .animation(.easeInOut, value: isRecording)
        .animation(.easeInOut, value: isPlaying)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
    
    func buttonView() -> some View {
        VStack {
            if !hasRecording {
                // Record button (red circle inside white ring)
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                
                // Back button
                Button(action: {
                    stopRecording()
                    recordedWaveform = nil
                    onBack()
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glass)
                .disabled(isRecording)
                .opacity(isRecording ? 0.5 : 1.0)
            } else {
                Button(action: {
                    if isPlaying {
                        manager.pausePlayingRecording()
                        isPlaying = false
                        playbackPollTask?.cancel()
                        playbackPollTask = nil
                    } else {
                        if firstTimePlaying {
                            waveformResetToken += 1
                            firstTimePlaying = false
                        }
                        
                        do {
                            try manager.resumePlayingRecording()
                            isPlaying = true
                            smoothedLevels = [0, 0, 0, 0, 0]
                            levels = []
                            startPlaybackMetering()
                        } catch {
                            errorMessage = "Failed to play recording: \(error.localizedDescription)"
                            showError = true
                        }
                    }
                }) {
                    Text(isPlaying ? "Pause" : "Play")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glass)
                
                Button(action: {
                    recordedURL = localRecordedURL
                    recordedWaveform = manager.makeRecordedWaveform()
                    activePage = .save
                }) {
                    Text("Confirm Recording")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glassProminent)
                .disabled(localRecordedURL == nil)
                
                Button(action: {
                    showDiscardConfirmation = true
                }) {
                    Text("Record again")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .padding(12)
                }
                .buttonStyle(.glass)
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        recordingTask = Task {
            do {
                try await manager.startRecording(
                    in: nil,
                    forDuration: nil,
                    recordingOption: .mono,
                    enableMetering: true
                )
                
                waveformResetToken += 1
                
                // Haptic feedback: medium impact
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                isRecording = true
                elapsedTime = 0
                levels = []
                smoothedLevels = [0, 0, 0, 0, 0]
                localRecordedURL = nil
                hasTemporaryRecording = false
                
                startMeterPolling()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                showError = true
                isRecording = false
            }
        }
    }
    
    private func stopRecording() {
        manager.stopRecording()
        isRecording = false
        // Capture the finished recording URL for post-recording UI
        if let url = manager.destinationURL, FileManager.default.fileExists(atPath: url.path) {
            localRecordedURL = url
            hasTemporaryRecording = true
        }
        
        // Haptic feedback: success notification
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        recordingTask?.cancel()
        recordingTask = nil
        
        meterPollTask?.cancel()
        meterPollTask = nil
    }
    
    private func startMeterPolling() {
        meterPollTask = Task {
            var updateCounter = 0
            while isRecording && !Task.isCancelled {
                let normalized = manager.latestWaveformSampleLinear
                
                // Seed the waveform immediately on the first captured sample so it doesn't ramp in late.
                if smoothedLevels.allSatisfy({ $0 == 0 }) {
                    smoothedLevels = Array(repeating: normalized, count: 5)
                } else {
                    // Apply low-pass smoothing
                    let alpha: Float = 0.99
                    let smoothed = smoothedLevels.last! * (1 - alpha) + normalized * alpha
                    smoothedLevels.append(smoothed)
                    if smoothedLevels.count > 50 {
                        smoothedLevels.removeFirst()
                    }
                }
                
                // Convert to CGFloat for display
                levels = smoothedLevels.map { CGFloat($0) }
                
                updateCounter += 1
                
                // Update elapsed time every second at 60 Hz
                if updateCounter % 60 == 0 {
                    if case .started(let elapsed, _) = manager.recorderState {
                        elapsedTime = elapsed
                    }
                }
                
                // Poll at ~60 FPS to match capture cadence
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }
    
    private func startPlaybackMetering() {
        playbackPollTask = Task {
            while !Task.isCancelled {
                // Stop if playback has stopped or we've been asked to halt
                if !isPlaying || !manager.isPlayingRecording {
                    break
                }
                
                let playbackTime = manager.playbackTime
                guard let normalized = manager.waveformSampleLinear(at: playbackTime) else {
                    break
                }
                
                // Seed playback immediately so the waveform follows audio onset rather than easing in.
                if smoothedLevels.allSatisfy({ $0 == 0 }) {
                    smoothedLevels = Array(repeating: normalized, count: 5)
                } else {
                    // Apply low-pass smoothing
                    let alpha: Float = 0.25
                    let smoothed = smoothedLevels.last! * (1 - alpha) + normalized * alpha
                    smoothedLevels.append(smoothed)
                    if smoothedLevels.count > 50 {
                        smoothedLevels.removeFirst()
                    }
                }
                
                // Convert to CGFloat for display
                levels = smoothedLevels.map { CGFloat($0) }
                
                // Poll at ~60 FPS to match capture cadence
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
            
            // Cleanup when loop exits. Don't clear levels immediately; allow WaveformView to animate to idle.
            DispatchQueue.main.async {
                if self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func updateRecordingState(_ state: AudioRecorderManager.RecorderState) {
        switch state {
        case .started(let elapsed, _):
            elapsedTime = elapsed
        case .paused(let elapsed, _):
            elapsedTime = elapsed
        case .reserved:
            break
        case .stopped:
            isRecording = false
            meterPollTask?.cancel()
            meterPollTask = nil
        }
    }
}

#Preview {
    NavigationStack {
        AudioRecordingView(
            manager: AudioRecorderManager(),
            activePage: .constant(.audio),
            recordedURL: .constant(nil),
            recordedWaveform: .constant(nil),
            hasTemporaryRecording: .constant(false),
            onBack: { }
        )
    }
}
