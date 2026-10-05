import AVFAudio

/// The audio session is shared by AVAudioRecorder, AVAudioEngine, and AVPlayer.
/// Each operation establishes its own configuration instead of inheriting the last recorder's route.
@MainActor
enum AppAudioSession {
    static func configureRecording() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .default,
            options: [
                .defaultToSpeaker,
                .allowAirPlay,
                .allowBluetoothA2DP,
                .allowBluetoothHFP,
                .bluetoothHighQualityRecording,
                .interruptSpokenAudioAndMixWithOthers
            ]
        )
    }

    static func activatePlayback() throws {
        let session = AVAudioSession.sharedInstance()
        // Playback has no input requirement and follows the user's selected output route.
        // Do not force an output override: headphones and AirPlay must keep working.
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }
}
