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
    var onBack: () -> Void
    
    @State private var levels: [CGFloat] = []
    @State private var smoothedLevels: [Float] = [0, 0, 0, 0, 0]
    @State private var isRecording: Bool = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var recordingTask: Task<Void, Never>?
    @State private var meterPollTask: Task<Void, Never>?
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
                Text(isRecording ? "Recording..." : "Ready to record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                WaveformView(levels: levels, isRecording: isRecording)
                    .frame(height: 120)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Bottom: Record button and Back button
            VStack(spacing: 24) {
                // Record button (red circle inside white ring)
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                            .scaleEffect(isRecording ? 0.95 : 1.0)
                    }
                    .frame(height: 80)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
                .accessibilityAddTraits(.isButton)
                
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
        .onChange(of: manager.recorderState) { oldValue, newValue in
            updateRecordingState(newValue)
        }
        .onDisappear {
            stopRecording()
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
            onBack: { }
        )
    }
}
