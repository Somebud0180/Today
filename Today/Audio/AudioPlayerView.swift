//
//  AudioPlayerView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/21/26.
//

import SwiftUI
import AVFAudio

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

            GeometryReader { _ in
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
                            guard !viewModel.fullWaveformLevels.isEmpty else { return }
                            let secondsPerSample = viewModel.waveformDuration
                                / Double(viewModel.fullWaveformLevels.count)
                            let timeDelta = -Double(value.translation.width / WaveformView.sampleSpacing)
                                * secondsPerSample
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
