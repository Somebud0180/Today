import AVFAudio
import Foundation

/// Serialize hardware changes without blocking the main actor. Ownership prevents
/// delayed recorder cleanup from deactivating a newer player's session.
enum AppAudioSession {
    private nonisolated final class Worker: @unchecked Sendable {
        let queue = DispatchQueue(label: "Today.audio-session", qos: .userInitiated)
        var owner: UUID?
    }
    private nonisolated static let worker = Worker()

    nonisolated static func perform<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            worker.queue.async {
                continuation.resume(with: Result { try operation() })
            }
        }
    }

    nonisolated static func configureRecording(
        owner: UUID? = nil,
        preferredInputUID: String? = nil,
        microphoneOrientation: AVAudioSession.Orientation? = nil,
        stereoOrientation: AVAudioSession.StereoOrientation = .portrait
    ) async throws -> String? {
        try await perform {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [
                .defaultToSpeaker, .allowAirPlay, .allowBluetoothA2DP,
                .allowBluetoothHFP, .bluetoothHighQualityRecording,
                .interruptSpokenAudioAndMixWithOthers
            ])
            let preferredUID = session.preferredInput?.uid ?? preferredInputUID
            let inputs = session.availableInputs ?? []
            let input = inputs.first { $0.uid == preferredUID }
                ?? inputs.first { $0.portType == .builtInMic }
                ?? inputs.first
            if let input { try session.setPreferredInput(input) }
            if let owner {
                try session.setActive(true)
                worker.owner = owner
            }
            if let orientation = microphoneOrientation,
               let input, input.portType == .builtInMic,
               let source = input.dataSources?.first(where: { $0.orientation == orientation }),
               let patterns = source.supportedPolarPatterns {
                if patterns.contains(.stereo) {
                    try source.setPreferredPolarPattern(.stereo)
                }
                try input.setPreferredDataSource(source)
                try session.setPreferredInputOrientation(stereoOrientation)
            }
            return input?.uid
        }
    }

    nonisolated static func activatePlayback(owner: UUID) async throws {
        try await perform {
            let session = AVAudioSession.sharedInstance()
            // Keep the user's selected headphone, speaker, or AirPlay route.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            worker.owner = owner
        }
    }

    /// Capture configures its session itself. Drain older hardware changes and
    /// protect it from delayed cleanup belonging to the previous audio entry.
    nonisolated static func handOffToCapture(owner: UUID) async throws {
        try await perform { worker.owner = owner }
    }

    /// Enqueue immediately so stop/teardown retains its order relative to starts.
    nonisolated static func deactivate(owner: UUID) {
        worker.queue.async {
            guard worker.owner == owner else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                worker.owner = nil
            } catch {
                print("Error deactivating audio session: \(error)")
            }
        }
    }
}
