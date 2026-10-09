import AVFoundation
import Foundation
import Testing
@testable import Today

@MainActor
@Suite(.serialized)
struct AudioSessionTests {
    @Test func sessionHardwareWorkDoesNotRunOnMainThread() async throws {
        let onMainThread = try await AppAudioSession.perform { Thread.isMainThread }
        #expect(!onMainThread)
    }

    /// Hold the hardware queue while a playback request is paused on the UI actor.
    private func checkPendingPlaybackCancellation(video: Bool) async throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let audioPlayer = AudioViewModel(fileURL: url)
        let videoPlayer = VideoViewModel(fileURL: url)
        let gate = DispatchSemaphore(value: 0)
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let blocker = Task {
            try await AppAudioSession.perform {
                continuation.yield(())
                continuation.finish()
                gate.wait()
            }
        }
        var iterator = started.makeAsyncIterator()
        _ = await iterator.next()
        defer { gate.signal() }

        let playback = Task {
            if video { await videoPlayer.play() }
            else { await audioPlayer.play() }
        }
        for _ in 0..<1_000 {
            if video ? videoPlayer.isPreparingPlayback : audioPlayer.isPreparingPlayback { break }
            await Task.yield()
        }
        #expect(video ? videoPlayer.isPreparingPlayback : audioPlayer.isPreparingPlayback)
        if video { videoPlayer.pause() }
        else { audioPlayer.pause() }
        gate.signal()
        try await blocker.value
        await playback.value
        #expect(!audioPlayer.isPlaying)
        #expect(!videoPlayer.isPlaying)
    }

    @Test func pauseCancelsPendingAudioPlayback() async throws {
        try await checkPendingPlaybackCancellation(video: false)
    }

    @Test func pauseCancelsPendingVideoPlayback() async throws {
        try await checkPendingPlaybackCancellation(video: true)
    }

    private func makeAudioFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("session-test-\(UUID()).caf")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100))
        buffer.frameLength = buffer.frameCapacity
        let samples = try #require(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) {
            samples[index] = 0.01 * sin(2 * .pi * 440 * Float(index) / 44_100)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    @Test func recordingRestoresInputCategoryAfterPlayback() async throws {
        let session = AVAudioSession.sharedInstance()
        let owner = UUID()
        defer { AppAudioSession.deactivate(owner: owner) }
        try await AppAudioSession.activatePlayback(owner: owner)
        _ = try await AppAudioSession.configureRecording()
        #expect(session.category == .playAndRecord)
        #expect(session.categoryOptions.contains(.defaultToSpeaker))
    }

    @Test func recordingKeepsSystemInputPreference() async throws {
        let session = AVAudioSession.sharedInstance()
        let owner = UUID()
        defer { AppAudioSession.deactivate(owner: owner) }
        _ = try await AppAudioSession.configureRecording(owner: owner)
        try await AppAudioSession.perform {
            try AVAudioSession.sharedInstance().setPreferredInput(nil)
        }
        _ = try await AppAudioSession.configureRecording(owner: owner)
        #expect(session.preferredInput == nil)
    }

    @Test func recordingPreviewRestoresPlaybackCategory() async throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = AudioRecorderManager()
        _ = try await AppAudioSession.configureRecording()
        recorder.restoreAudio(from: url)
        try await recorder.resumePlayingRecording()
        defer { recorder.pausePlayingRecording() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(recorder.isPlayingRecording)
    }

    @Test func journalAudioRestoresPlaybackAfterRecording() async throws {
        let url = try makeAudioFile()
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        _ = try await AppAudioSession.configureRecording()
        let player = AudioViewModel(fileURL: url)
        await player.play()
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }

    @Test func journalVideoRestoresPlaybackAfterRecording() async throws {
        let url = try makeAudioFile()
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        _ = try await AppAudioSession.configureRecording()
        let player = VideoViewModel(fileURL: url)
        await player.play()
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }

    @Test func releasedRecorderDoesNotDeactivateLaterPlayback() async throws {
        let url = try makeAudioFile()
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        var recorder: AudioRecorderManager? = AudioRecorderManager()
        recorder?.restoreAudio(from: url)
        try await recorder?.resumePlayingRecording()
        recorder?.pausePlayingRecording()
        let player = AudioViewModel(fileURL: url)
        await player.play()
        recorder = nil
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }

    @Test func restoredVideoConfirmationDoesNotRestartCapture() async throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = VideoRecorderManager()
        recorder.restoreVideo(from: url)
        await recorder.startSession()
        #expect(recorder.showConfirmation)
        #expect(!recorder.isSessionRunning)
    }
}
