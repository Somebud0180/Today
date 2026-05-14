//
//  WaveformView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/12/26.
//

import SwiftUI
import Combine

struct WaveformView: View {
    var levels: [CGFloat]
    var isRecording: Bool
    var resetToken: Int
    
    @State private var displayLevels: [CGFloat] = []
    @State private var animationPhase: CGFloat = 0
    // Task used to smoothly decay displayLevels to idle
    @State private var decayTask: Task<Void, Never>? = nil
    
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minAmplitude: CGFloat = 0.02
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Always draw the bars in a Canvas so recording, playback and idle share the same layout/width.
                Canvas { context, size in
                    let barsToShow = max(1, Int(size.width / (barWidth + barSpacing)))

                    // Determine which source levels to draw. Prefer displayLevels (real captured levels).
                    // If displayLevels is empty (no data), synthesize a flat idle waveform of the same width.
                    var source: [CGFloat]
                    if displayLevels.isEmpty {
                        // Flat idle: all bars at minAmplitude
                        source = Array(repeating: minAmplitude, count: barsToShow)
                    } else {
                        let maxBars = min(barsToShow, displayLevels.count)
                        source = Array(displayLevels.suffix(maxBars))
                        // If there are fewer levels than barsToShow, pad the left with flat idle values
                        if source.count < barsToShow {
                            let padCount = barsToShow - source.count
                            let pads = Array(repeating: minAmplitude, count: padCount)
                            source = pads + source
                        }
                    }

                    for i in 0..<source.count {
                        let level = source[i]
                        let height = max(minAmplitude, level) * size.height * 0.8

                        let x = CGFloat(i) * (barWidth + barSpacing) + barSpacing
                        let y = (size.height - height) / 2

                        var path = Path()
                        path.addRoundedRect(
                            in: CGRect(x: x, y: y, width: barWidth, height: height),
                            cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
                        )

                        context.fill(
                            path,
                            with: .color(.blue.opacity(0.85))
                        )
                    }
                }
                .frame(height: 120)
                .transition(.opacity)
            }
            .onChange(of: levels) { oldValue, newValue in
                updateDisplayLevels(newValue)
            }
            .onChange(of: resetToken) { _, _ in
                displayLevels = []
            }
            .onChange(of: isRecording) { oldValue, newValue in
                if !newValue {
                    // When stopping recording/playback, smoothly decay the visible displayLevels
                    // down to the flat idle amplitude instead of abruptly clearing them.
                    decayTask?.cancel()
                    decayTask = Task { @MainActor in
                        let steps = 12
                        // If no current displayLevels, nothing to do
                        guard !displayLevels.isEmpty else {
                            displayLevels = []
                            return
                        }

                        let target = Array(repeating: minAmplitude, count: displayLevels.count)
                        for step in 1...steps {
                            if Task.isCancelled { return }
                            let t = CGFloat(step) / CGFloat(steps)
                            // Interpolate each value towards target
                            displayLevels = zip(displayLevels, target).map { current, tgt in
                                current + (t) * (tgt - current)
                            }
                            try? await Task.sleep(nanoseconds: 30_000_000)
                        }

                        // Finally set to empty so Canvas will render flat idle consistently
                        displayLevels = []
                        decayTask = nil
                    }
                } else {
                    // If recording/resuming, cancel any decay in progress
                    decayTask?.cancel()
                    decayTask = nil
                }
            }
            .onAppear {
                updateDisplayLevels(levels)
            }
        }
    }
    
    private func updateDisplayLevels(_ newLevels: [CGFloat]) {
        let maxBars = 200 // Cap at reasonable number depending on width
        var updated = displayLevels

        for level in newLevels {
            updated.append(level)
            if updated.count > maxBars {
                updated.removeFirst()
            }
        }

        // Smoothly animate the append for cohesive motion. Cancel any decay in progress.
        decayTask?.cancel()
        withAnimation(.linear(duration: 0.06)) {
            displayLevels = updated
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        WaveformView(levels: [], isRecording: false, resetToken: 0)
            .frame(height: 120)
            .padding()
        
        WaveformView(
            levels: (0..<10).map { _ in CGFloat.random(in: 0.2...1.0) },
            isRecording: true,
            resetToken: 0
        )
        .frame(height: 120)
        .padding()
    }
}
