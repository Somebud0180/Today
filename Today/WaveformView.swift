//
//  WaveformView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/12/26.
//

import SwiftUI
import Combine

struct WaveformView: View {
    // Recording mode
    var levels: [CGFloat] = []
    var isRecording: Bool = false
    var resetToken: Int = 0
    
    // Playback mode
    var fullLevels: [CGFloat] = []
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaybackView: Bool = false
    
    @State private var displayLevels: [CGFloat] = []
    
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minAmplitude: CGFloat = 0.02
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    if isPlaybackView {
                        var ctx = context
                        drawPlaybackWaveform(&ctx, size: size)
                    } else {
                        var ctx = context
                        drawRecordingWaveform(&ctx, size: size)
                    }
                }
                .frame(height: 120)
            }
            .onChange(of: levels) { oldValue, newValue in
                if !isPlaybackView {
                    updateDisplayLevels(newValue)
                }
            }
            .onChange(of: resetToken) { _, _ in
                if !isPlaybackView {
                    displayLevels = []
                }
            }
            .onAppear {
                if !isPlaybackView {
                    // If the view appears with an existing levels buffer, seed the display with it.
                    displayLevels = levels
                }
            }
        }
    }
    
    private func drawRecordingWaveform(_ context: inout GraphicsContext, size: CGSize) {
        let barsToShow = max(1, Int(size.width / (barWidth + barSpacing)))
        
        var source: [CGFloat]
        if displayLevels.isEmpty {
            source = Array(repeating: minAmplitude, count: barsToShow)
        } else {
            let maxBars = min(barsToShow, displayLevels.count)
            source = Array(displayLevels.suffix(maxBars))
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
            
            context.fill(path, with: .color(.blue.opacity(0.85)))
        }
    }
    
    private func drawPlaybackWaveform(_ context: inout GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        
        // Draw center playhead line
        var playheadPath = Path()
        playheadPath.move(to: CGPoint(x: centerX, y: 0))
        playheadPath.addLine(to: CGPoint(x: centerX, y: size.height))
        context.stroke(playheadPath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
        
        // Guard against invalid state
        guard duration > 0, !fullLevels.isEmpty else {
            // Show idle state
            let idleBarCount = 5
            for i in 0..<idleBarCount {
                let x = centerX + CGFloat(i + 1) * (barWidth + barSpacing)
                let height = minAmplitude * size.height * 0.8
                let y = (size.height - height) / 2
                
                var path = Path()
                path.addRoundedRect(
                    in: CGRect(x: x, y: y, width: barWidth, height: height),
                    cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
                )
                context.fill(path, with: .color(.blue.opacity(0.85)))
            }
            return
        }
        
        // Calculate how many bars fit on each side of center
        let barsPerSide = max(1, Int((size.width / 2) / (barWidth + barSpacing)))
        
        // Calculate the current position in the waveform as an index
        let ratio = max(0, min(1, currentTime / duration))
        let centerWaveformIndex = Int(Double(fullLevels.count) * ratio)
        
        // Get the window of waveform data to display
        // We want to center on the current playback position
        let startIndex = max(0, centerWaveformIndex - barsPerSide)
        let endIndex = min(fullLevels.count, centerWaveformIndex + barsPerSide)
        let window = Array(fullLevels[startIndex..<endIndex])
        
        // Find where the playhead (center line) sits within this window
        let playheadPositionInWindow = centerWaveformIndex - startIndex
        
        // Draw the waveform, with the playhead at the center
        for i in 0..<window.count {
            let level = window[i]
            let height = max(minAmplitude, level) * size.height * 0.8
            
            // Calculate position: playhead is at center
            let offsetFromPlayhead = CGFloat(i - playheadPositionInWindow)
            let x = centerX + offsetFromPlayhead * (barWidth + barSpacing) + barSpacing
            let y = (size.height - height) / 2
            
            // Only draw if within bounds
            guard x >= 0 && x + barWidth <= size.width else { continue }
            
            var path = Path()
            path.addRoundedRect(
                in: CGRect(x: x, y: y, width: barWidth, height: height),
                cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
            )
            
            context.fill(path, with: .color(.blue.opacity(0.85)))
        }
    }
    
    private func updateDisplayLevels(_ newLevels: [CGFloat]) {
        // Only append the most recent sample to avoid duplicating entire buffers
        let maxBars = 200
        var updated = displayLevels
        
        // If the incoming array is empty, do nothing. If it contains multiple
        // items, assume the last item represents the newest sample.
        guard let newest = newLevels.last else { return }
        
        updated.append(newest)
        if updated.count > maxBars {
            updated.removeFirst(updated.count - maxBars)
        }
        
        withAnimation(.linear(duration: 0.06)) {
            displayLevels = updated
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack {
            Text("Recording Style")
            WaveformView(levels: [], isRecording: false)
                .frame(height: 120)
                .padding()
        }
        
        VStack {
            Text("Playback Style")
            let testLevels = (0..<100).map { _ in CGFloat.random(in: 0.2...1.0) }
            WaveformView(
                fullLevels: testLevels,
                currentTime: 5,
                duration: 10,
                isPlaybackView: true
            )
            .frame(height: 120)
            .padding()
        }
    }
}
