//
//  AudioRecorderManager.swift
//  Today
//
//  Created by Ethan John Lagera on 5/12/26.
//
//  Referenced from "SwiftUI: Master Audio Recording With AVAudioRecorder" by Itsuki
//  https://levelup.gitconnected.com/swiftui-master-audio-recording-with-avaudiorecorder-bb02a0da9a6a

import SwiftUI
import AVFAudio
import UniformTypeIdentifiers
import Combine

class AudioRecorderManager: NSObject, ObservableObject {
    
    enum RecordingOption {
        case frontStereo
        case backStereo
        case mono
        
        var displayString: String {
            switch self {
            case .backStereo:
                "Back Stereo"
            case .frontStereo:
                "Front Stereo"
            case .mono:
                "Mono"
            }
        }
        
        var audioOrientation: AVAudioSession.Orientation {
            switch self {
            case .frontStereo:
                    .front
            case .backStereo:
                    .back
            case .mono:
                    .bottom
            }
        }
        
    }
    
    enum RecorderState: Equatable {
        // remaining time til start
        case reserved(TimeInterval)
        case stopped
        // time since stared, recording metrics
        case paused(TimeInterval, [PowerMetrics])
        
        // time since stared, recording metrics
        case started(TimeInterval, [PowerMetrics])
    }
    
    // Power in decibels full-scale (dBFS)
    // value ranges from –160 dBFS, indicating minimum power, to 0 dBFS, indicating maximum power.
    struct PowerMetrics: Equatable, Hashable {
        var channelName: String?
        var channelNumber: Int
        var average: Float
        var peak: Float
    }

    /// Recorded power frames captured during a recording session.
    /// Each frame contains the timestamp (seconds from recording start) and the power metrics for that moment.
    struct RecordedPowerFrame {
        var time: TimeInterval
        var metrics: [PowerMetrics]
    }
    
    enum _Error: Error {
        
        case permissionDenied
        case unknownPermission
        
        case builtinMicNotFound
        
        case failToGetDestinationURL
        
        case failToDeleteRecording(String)
        case failToStartRecording(String)
        
        case failToResumeRecording
        case failToStopRecording
        
        case failToResumePlaying(String)
        case failToStopPlaying
        
        var message: String {
            switch self  {
                
            case .permissionDenied:
                "Recording Permission Denied."
            case .unknownPermission:
                "Unknown Recording Permission."
                
            case .builtinMicNotFound:
                "Built in Mic is not found."
                
            case .failToGetDestinationURL:
                "Failed to get DestinationURL."
            case .failToDeleteRecording(let s):
                s
            case .failToStartRecording(let s):
                s
            case .failToResumeRecording:
                "Failed To Resume Recording."
            case .failToStopRecording:
                "Failed T oStop Recording."
            case .failToResumePlaying(let s):
                s
            case .failToStopPlaying:
                "Failed To Stop Playing Recording"
            }
        }
        
    }
    
    
    private(set) var isPlayingRecording: Bool = false
    private(set) var recorderState: RecorderState = .stopped
    
    
    var error: (any Error)? {
        didSet {
            if let error = self.error {
                print(error.localizedDescription)
                self.showError = true
            }
        }
    }
    
    var showError: Bool = false {
        didSet {
            if !showError {
                self.error = nil
            }
        }
    }
    
    var recordedContentsDuration: TimeInterval?
    var availableRecordingOptions: [RecordingOption] = []
    
    var destinationURL: URL? {
        let directoryPath = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: .documentsDirectory, create: true)
        let fileURL = directoryPath?.appendingPathComponent("recording", conformingTo: .mpeg4Audio)
        return fileURL
    }
    
    private var player: AVAudioPlayer? {
        didSet {
            self.recordedContentsDuration = self.player?.duration
        }
    }
    
    private var recorder: AVAudioRecorder?
    /// Power frames captured while recording. Cleared when a new recording starts or when discarded.
    private(set) var recordedPowerFrames: [RecordedPowerFrame] = []
    
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // https://developer.apple.com/documentation/avfaudio/avaudiorecorder/init(url:settings:)#Discussion
    private var audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 12000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    
    private var timerCancellable: AnyCancellable?
    
    override init() {
        super.init()
        
        do {
            try self.configureAudioSession()
            self.setupAvailableRecordingOptions()
        } catch(let error) {
            self.error = error
        }
    }
    
    deinit {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Recorder
extension AudioRecorderManager {
    
    // Start in (time) seconds, for (duration) seconds
    func startRecording(in time: TimeInterval?, forDuration duration: TimeInterval?, recordingOption: RecordingOption, enableMetering: Bool) async throws {
        print(#function)
        
        guard self.recorderState == .stopped else {
            return
        }
        
        if let time, time < 0 {
            throw _Error.failToStartRecording("Invalid Time.")
        }
        
        if let duration, duration <= 0 {
            throw _Error.failToStartRecording("Invalid Duration.")
        }
        
        try await self.checkPermission()
        
        self.stopPlayingRecording()
        
        guard let fileURL = self.destinationURL else {
            throw _Error.failToGetDestinationURL
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        try self.configureStereo(recordingOption: recordingOption)
        self.audioSettings[AVNumberOfChannelsKey] = (recordingOption == .mono) ? 1 : 2
        
        self.recorder = try AVAudioRecorder(url: fileURL, settings: self.audioSettings)
        self.recorder?.delegate = self
        
        // A Boolean value that indicates whether you’ve enabled the recorder to generate audio-level metering data.
        // By default, the recorder doesn’t generate audio-level metering data.
        // Because metering uses computing resources, enable it only if you intend to use it.
        self.recorder?.isMeteringEnabled = enableMetering
        
        let currentTime = recorder!.deviceCurrentTime
        
        let result = switch (time == nil, duration == nil) {
        case (true, true) :
            self.recorder?.record()
        case (true, false):
            self.recorder?.record(forDuration: duration!)
        case (false, true):
            self.recorder?.record(atTime: currentTime + time!)
        case (false, false):
            self.recorder?.record(atTime: currentTime + time!, forDuration: duration!)
        }
        
        if result == false {
            throw _Error.failToStartRecording("Fail to start playing")
        }
        
        if let time  {
            self.recorderState = .reserved(time)
        } else {
            // Clear any previous captured power frames for a fresh recording session
            self.recordedPowerFrames = []
            self.recorderState = .started(0, self.getPowerMetrics())
        }
        
        self.startTimer()
    }
    
    
    func resumeRecording() throws {
        guard let recorder = self.recorder else {
            return
        }
        let result = recorder.record()
        if result == false {
            throw _Error.failToResumeRecording
        }
        self.recorderState = .started(recorder.currentTime, self.getPowerMetrics())
        self.startTimer()
    }
    
    func pauseRecording() {
        self.recorder?.pause()
        if case .started(let timeInterval, let powerMetrics) = recorderState {
            self.recorderState = .paused(timeInterval, powerMetrics)
        } else {
            self.recorderState = .paused(recorder?.currentTime ?? 0, self.getPowerMetrics())
        }
        self.stopTimer()
    }
    
    func stopRecording() {
        self.recorder?.stop()
        self.recorder = nil
        self.recorderState = .stopped
        self.stopTimer()
        self.preparePlayer()
    }
    
    // not used in this demo
    func deleteRecording() throws {
        guard self.recorder?.isRecording == false else {
            throw _Error.failToDeleteRecording("Please stop recording before delete.")
        }
        
        let result = self.recorder?.deleteRecording()
        if result == false {
            throw _Error.failToDeleteRecording("Failed To delete recording.")
        }
    }

    /// Discard the recorded file and clear internal playback metadata.
    /// This will stop any playback/recording and remove the destination file on disk.
    func discardRecording() throws {
        // stop any playing
        self.stopPlayingRecording()

        // ensure recorder is stopped
        self.recorder?.stop()
        self.recorder = nil
        self.recorderState = .stopped
        self.stopTimer()

        if let fileURL = self.destinationURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        // clear player metadata
        self.player = nil
        self.recordedContentsDuration = nil
        // clear captured power frames
        self.recordedPowerFrames = []
    }
}

// MARK: - Player
extension AudioRecorderManager {
    private func preparePlayer() {
        if let fileURL = self.destinationURL {
            self.player = try? AVAudioPlayer(contentsOf: fileURL)
        }
    }
    
    func pausePlayingRecording() {
        self.player?.pause()
        self.isPlayingRecording = false
    }
    
    func resumePlayingRecording() throws {
        guard let player = self.player else {
            throw _Error.failToResumePlaying("Failed to prepare player")
        }
        
        let result = player.play()
        if result == false {
            throw _Error.failToResumePlaying("Failed to resume playing recording.")
        }
        self.isPlayingRecording = true
    }
    
    
    private func stopPlayingRecording() {
        self.player?.stop()
        self.player = nil
        self.isPlayingRecording = false
    }
}


// MARK: - AVAudioRecorderDelegate
extension AudioRecorderManager: AVAudioRecorderDelegate {
    // Tells the delegate when recording stops or finishes due to reaching its time limit, for example, that defined by duration when calling AVAudioRecorder.record(forDuration:).
    // The system doesn’t call this method if the recorder stops due to an interruption.
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print(#function)
        print("Finishes successfully: \(flag)")
        
        guard recorder == self.recorder else {
            return
        }
        
        if !flag {
            self.error = _Error.failToStopRecording
        } else if self.recorderState != .stopped {
            self.stopRecording()
        }
    }
    
    // Tells the delegate that the audio recorder encountered an encoding error during recording.
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        print(#function)
        guard recorder == self.recorder else {
            return
        }
        self.error = error
    }
}


// MARK: - AVAudioPlayerDelegate
extension AudioRecorderManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print(#function)
        print("Finishes successfully: \(flag)")
        
        guard player == self.player else {
            return
        }
        
        if !flag {
            self.error = _Error.failToStopPlaying
        } else if self.isPlayingRecording {
            self.stopPlayingRecording()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print(#function)
        guard player == self.player else {
            return
        }
        self.error = error
        
    }
}

// MARK: - Playback metering
extension AudioRecorderManager {
    /// Get power metrics for playback audio
    /// Note: AVAudioPlayer doesn't provide real-time metering like AVAudioRecorder.
    /// This returns simulated metrics for visualization purposes.
    func getPlaybackPowerMetrics() -> [PowerMetrics] {
        guard let player = self.player, player.isPlaying else {
            return []
        }

        // Prefer using captured metrics from the recording session, if available.
        if !self.recordedPowerFrames.isEmpty {
            let playbackTime = player.currentTime

            // Find the most recent recorded frame at or before the playback time.
            // Iterate in reverse for efficiency assuming playback progresses forward.
            if let frame = self.recordedPowerFrames.reversed().first(where: { $0.time <= playbackTime }) {
                return frame.metrics
            }

            // If none found (playback earlier than first frame), return the first frame's metrics.
            return self.recordedPowerFrames.first?.metrics ?? []
        }

        // Fallback: simulate playback metrics when no recorded metrics are available.
        let channelCount = self.audioSettings[AVNumberOfChannelsKey] as? Int ?? 1

        // Generate a realistic-looking simulated waveform for visualization
        // Use a combination of sine waves with random variation to simulate audio
        let time = Float(player.currentTime)
        let baseFrequency = sin(time * 1.5) * 0.3 + 0.4
        let variation = Float.random(in: 0...0.3)
        let amplitude = (baseFrequency + variation).clamped(to: 0...1)

        return (0..<channelCount).map { channel in
            let channelVariance = Float.random(in: -0.05...0.05)
            let finalAmplitude = (amplitude + channelVariance).clamped(to: 0...1)
            // NOTE: These simulated values are in normalized linear amplitude (0..1).
            // To keep the API consistent with recorder metrics (dBFS), we map them into a small
            // dB range so downstream code that expects dB values can still operate.
            let approxDb = log10(max(0.0001, finalAmplitude)) * 20
            return PowerMetrics(
                channelName: nil,
                channelNumber: channel,
                average: approxDb,
                peak: approxDb
            )
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}


// MARK: - Private helpers for managing recording session / permission
extension AudioRecorderManager {
    private func checkPermission() async throws {
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
            
        case .undetermined:
            let result = await AVAudioApplication.requestRecordPermission()
            if !result {
                throw _Error.permissionDenied
            }
            return
            
        case .denied:
            throw _Error.permissionDenied
            
        case .granted:
            return
            
        @unknown default:
            throw _Error.unknownPermission
        }
        
    }
    
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP, .bluetoothHighQualityRecording])
        try audioSession.setActive(true)
        
        // not required, only for retrieving the input source a little easier
        // when configuring for stereo
        guard let availableInputs = audioSession.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            throw _Error.builtinMicNotFound
        }
        try audioSession.setPreferredInput(builtInMicInput)
    }
    
    private func setupAvailableRecordingOptions() {
        
        // datasources will be nil on simulators
        guard let dataSources = audioSession.preferredInput?.dataSources else {
            self.availableRecordingOptions = []
            return
        }
        
        var options: [RecordingOption] = []
        
        dataSources.forEach { dataSource in
            switch dataSource.orientation {
            case .front:
                options.append(.frontStereo)
            case .back:
                options.append(.backStereo)
            case .bottom:
                options.append(.mono)
            default: ()
            }
        }
        
        self.availableRecordingOptions = options
        
    }
    
    
    // Important: setPreferredInputOrientation should not be called after recording stared
    // ie: should only be called when recorderState is .stopped
    private func configureStereo(recordingOption: RecordingOption) throws {
        guard let preferredInput = audioSession.preferredInput,
              let dataSources = preferredInput.dataSources,
              let newDataSource = dataSources.first(where: { $0.orientation == recordingOption.audioOrientation }),
              let supportedPolarPatterns = newDataSource.supportedPolarPatterns else {
            return
        }
        
        // false if RecordingOption is .mono (ie: orientation is .bottom)
        // true for the rest options
        let isStereoSupported = supportedPolarPatterns.contains(.stereo)
        
        if isStereoSupported {
            // Set the preferred polar pattern to stereo.
            try newDataSource.setPreferredPolarPattern(.stereo)
        }
        
        // Set the preferred data source and polar pattern.
        try preferredInput.setPreferredDataSource(newDataSource)
        
        // Update the input orientation to match the current user interface orientation.
        let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.effectiveGeometry.interfaceOrientation ?? .portrait
        
        let audioOrientation: AVAudioSession.StereoOrientation
        switch interfaceOrientation {
        case .portrait:
            audioOrientation = .portrait
        case .portraitUpsideDown:
            audioOrientation = .portraitUpsideDown
        case .landscapeLeft:
            audioOrientation = .landscapeLeft
        case .landscapeRight:
            audioOrientation = .landscapeRight
        default:
            audioOrientation = .portrait
        }
            
        try audioSession.setPreferredInputOrientation(audioOrientation)
    }
}


// MARK: - Private helpers for updating recording status (elapsed time, power metrics, and etc.)
extension AudioRecorderManager {
    
    private func startTimer() {
        print(#function)
        self.stopTimer()
        self.timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
            .sink(receiveValue: { [weak self] _  in
                guard let self = self else { return }
                
                if case .reserved(_) = self.recorderState {
                    let currentTime = self.recorder?.currentTime ?? 0
                    
                    if currentTime >= 0 {
                        self.recorderState = .started(currentTime, self.getPowerMetrics())
                    } else {
                        self.recorderState = .reserved(-currentTime)
                    }
                    return
                }
                
                if case .started(let elapsed, _) = self.recorderState {
                    self.recorderState = .started(self.recorder?.currentTime ?? elapsed + 1, self.getPowerMetrics())
                    return
                }
            })
        
    }
    
    private func stopTimer() {
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }
    
    
    func getPowerMetrics() -> [PowerMetrics] {
        guard let recorder = self.recorder else {
            return []
        }
        guard recorder.isMeteringEnabled else {
            return []
        }
        
        let channels = self.getChannels()
        
        // Refreshes the average and peak power values for all channels of an audio recorder.
        // Call this method to update the level meter data before calling averagePower(forChannel:) or peakPower(forChannel:).
        recorder.updateMeters()
        let metrics = channels.map({ PowerMetrics(
            channelName: $0.0,
            channelNumber: $0.1,
            average: recorder.averagePower(forChannel: $0.1),
            peak: recorder.peakPower(forChannel: $0.1)) }
        )

        // Capture the metrics with a timestamp so we can reuse them for playback visualization.
        let currentTime = recorder.currentTime
        let frame = RecordedPowerFrame(time: currentTime, metrics: metrics)
        self.recordedPowerFrames.append(frame)

        return metrics
    }
    
    private func getChannels() -> [(String?, Int)] {
        guard let recorder = self.recorder else {
            return []
        }
        
        // The default value of this property is nil.
        // When the value is non-nil, this value must have the same number of channels as defined in the settings property for the AVNumberOfChannelsKey value. Use this property to help record specific audio channels.
        guard let channelAssignments = recorder.channelAssignments else {
            let channelCount = self.audioSettings[AVNumberOfChannelsKey] as? Int ?? 1
            return (0..<channelCount).map({ index in (nil, index)})
        }
        
        return channelAssignments.map({($0.channelName, $0.channelNumber)})
    }
    
}
