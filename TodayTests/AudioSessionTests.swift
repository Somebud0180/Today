import AVFoundation
import Foundation
import Testing
@testable import Today

@MainActor
@Suite(.serialized)
struct AudioSessionTests {
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

    @Test func recordingRestoresInputCategoryAfterPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }
        try AppAudioSession.activatePlayback()
        try AppAudioSession.configureRecording()
        #expect(session.category == .playAndRecord)
        #expect(session.categoryOptions.contains(.defaultToSpeaker))
    }

    @Test func recordingPreviewRestoresPlaybackCategory() throws {
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = AudioRecorderManager()
        try AppAudioSession.configureRecording()
        recorder.restoreAudio(from: url)
        try recorder.resumePlayingRecording()
        defer { recorder.pausePlayingRecording() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(recorder.isPlayingRecording)
    }

    @Test func journalAudioRestoresPlaybackAfterRecording() throws {
        let url = try makeAudioFile()
        defer {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? FileManager.default.removeItem(at: url)
        }
        try AppAudioSession.configureRecording()
        let player = AudioViewModel(fileURL: url)
        player.play()
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }

    @Test func journalVideoRestoresPlaybackAfterRecording() throws {
        let url = try makeAudioFile()
        defer {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? FileManager.default.removeItem(at: url)
        }
        try AppAudioSession.configureRecording()
        let player = VideoViewModel(fileURL: url)
        player.play()
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }

    @Test func releasedRecorderDoesNotDeactivateLaterPlayback() throws {
        let url = try makeAudioFile()
        defer {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? FileManager.default.removeItem(at: url)
        }
        var recorder: AudioRecorderManager? = AudioRecorderManager()
        recorder?.restoreAudio(from: url)
        try recorder?.resumePlayingRecording()
        recorder?.pausePlayingRecording()
        let player = AudioViewModel(fileURL: url)
        player.play()
        recorder = nil
        defer { player.pause() }
        #expect(AVAudioSession.sharedInstance().category == .playback)
        #expect(player.isPlaying)
    }
}
