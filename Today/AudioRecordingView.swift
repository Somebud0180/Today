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
    @ObservedObject var manager: AudioRecorderManager
    @Binding var activePage: CreateView.Page
    @Binding var recordedURL: URL?
    var onBack: () -> Void
    
    @State private var levels: [CGFloat] = []
    @State private var smoothedLevels: [Float] = [0, 0, 0, 0, 0]
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRecording: Bool = false
    @State private var isPlaying: Bool = false
    @State private var showDiscardConfirmation: Bool = false
    @State private var localRecordedURL: URL? = nil

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
        VStack(spacing: 0) {
            // Top: Stopwatch
            VStack(spacing: 16) {
                Text(formatTime(elapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            
            Spacer()
            
            // Center: Waveform
            VStack(spacing: 24) {
                if isRecording {
                    Text("Recording...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if hasRecording {
                    Text("Recording complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                WaveformView(levels: levels, isRecording: isRecording || isPlaying, resetToken: 0)
                    .frame(height: 120)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Bottom: Record button and Back / Post-recording controls
            VStack(spacing: 24) {
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
                    // Post-recording: Play/Pause, Confirm, Record again
                    Button(action: {
                        if isPlaying {
                                    manager.pausePlayingRecording()
                                    isPlaying = false
                                    playbackPollTask?.cancel()
                                    playbackPollTask = nil
                                    // Keep last waveform levels so WaveformView can smoothly animate to idle.
                        } else {
                            do {
                                try manager.resumePlayingRecording()
                                isPlaying = true
                                // Reset smoothed levels to avoid artifacts when resuming
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
            .padding(.horizontal, 24)
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
                        // restore view state
                        recordedURL = nil
                        isPlaying = false
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
        .onChange(of: manager.isPlayingRecording) { oldValue, newValue in
            if !newValue && isPlaying {
                isPlaying = false
                playbackPollTask?.cancel()
                playbackPollTask = nil
            }
        }
        .onDisappear {
            stopRecording()
            manager.pausePlayingRecording()
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
                
                // Haptic feedback: medium impact
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                isRecording = true
                elapsedTime = 0
                levels = []
                smoothedLevels = [0, 0, 0, 0, 0]
                localRecordedURL = nil
                
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
                let powerMetrics = manager.getPowerMetrics()
                
                if !powerMetrics.isEmpty {
                    // Convert dBFS to linear amplitude
                    let averageDb = powerMetrics[0].average
                    let linearAmplitude = pow(10, averageDb / 20)
                    let normalizedAmplitude = min(1.0, max(0.0, linearAmplitude))
                    
                    // Apply low-pass smoothing
                    let alpha: Float = 0.3
                    let smoothed = smoothedLevels.last! * (1 - alpha) + Float(normalizedAmplitude) * alpha
                    smoothedLevels.append(smoothed)
                    if smoothedLevels.count > 50 {
                        smoothedLevels.removeFirst()
                    }
                    
                    // Convert to CGFloat for display
                    levels = smoothedLevels.map { CGFloat($0) }
                }
                
                updateCounter += 1
                
                // Update elapsed time every second
                if updateCounter % 3 == 0 {
                    if case .started(let elapsed, _) = manager.recorderState {
                        elapsedTime = elapsed
                    }
                }
                
                // Poll at ~30 FPS
                try? await Task.sleep(nanoseconds: 33_333_333)
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

                let powerMetrics = manager.getPlaybackPowerMetrics()

                if !powerMetrics.isEmpty {
                    // For playback, manager now returns dB-style metrics (or simulated dB) so reuse same conversion
                    let averageDb = powerMetrics[0].average
                    let linearAmplitude = pow(10, averageDb / 20)
                    let normalizedAmplitude = min(1.0, max(0.0, linearAmplitude))

                    // Apply low-pass smoothing
                    let alpha: Float = 0.25
                    let smoothed = smoothedLevels.last! * (1 - alpha) + Float(normalizedAmplitude) * alpha
                    smoothedLevels.append(smoothed)
                    if smoothedLevels.count > 50 {
                        smoothedLevels.removeFirst()
                    }

                    // Convert to CGFloat for display
                    levels = smoothedLevels.map { CGFloat($0) }
                } else {
                    // No metrics available - finish
                    break
                }

                // Poll at ~30 FPS
                try? await Task.sleep(nanoseconds: 33_333_333)
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
            onBack: { }
        )
    }
}
