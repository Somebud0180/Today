//
//  WaveformView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/12/26.
//

import SwiftUI

struct WaveformView: View {
    var levels: [CGFloat]
    var isRecording: Bool
    
    @State private var displayLevels: [CGFloat] = []
    @State private var animationPhase: CGFloat = 0
    
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minAmplitude: CGFloat = 0.02
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isRecording && !levels.isEmpty {
                    // Recording mode: show animated bars
                    Canvas { context, size in
                        let barsToShow = Int(size.width / (barWidth + barSpacing))
                        let maxBars = min(barsToShow, displayLevels.count)
                        
                        for i in 0..<maxBars {
                            let index = displayLevels.count - maxBars + i
                            if index >= 0 && index < displayLevels.count {
                                let level = displayLevels[index]
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
                                    with: .color(.blue.opacity(0.8))
                                )
                            }
                        }
                    }
                    .frame(height: 120)
                    .transition(.opacity)
                } else {
                    // Idle mode: show 5 dots
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.blue.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(isRecording ? 0.8 : 1.0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 120)
                    .transition(.opacity)
                }
            }
            .onChange(of: levels) { oldValue, newValue in
                updateDisplayLevels(newValue)
            }
            .onChange(of: isRecording) { oldValue, newValue in
                if !newValue {
                    // Reset to idle state
                    withAnimation(.easeOut(duration: 0.3)) {
                        displayLevels = []
                    }
                }
            }
            .onAppear {
                updateDisplayLevels(levels)
            }
        }
    }
    
    private func updateDisplayLevels(_ newLevels: [CGFloat]) {
        let maxBars = 50 // Cap at reasonable number
        var updated = displayLevels
        
        for level in newLevels {
            updated.append(level)
            if updated.count > maxBars {
                updated.removeFirst()
            }
        }
        
        withAnimation(.easeInOut(duration: 0.05)) {
            displayLevels = updated
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        WaveformView(levels: [], isRecording: false)
            .frame(height: 120)
            .padding()
        
        WaveformView(
            levels: (0..<10).map { _ in CGFloat.random(in: 0.2...1.0) },
            isRecording: true
        )
        .frame(height: 120)
        .padding()
    }
}
