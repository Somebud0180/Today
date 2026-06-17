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

@MainActor
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
        case reserved(TimeInterval)
        case stopped
        case paused(TimeInterval, [PowerMetrics])
        case started(TimeInterval, [PowerMetrics])
    }
    
    enum _Error: LocalizedError {
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
        
        var errorDescription: String? {
            switch self  {
                
            case .permissionDenied:
                "Recording Permission Denied."
            case .unknownPermission:
                "Unknown Recording Permission."
                
            case .builtinMicNotFound:
                "Built in microphone not found."
                
            case .failToGetDestinationURL:
                "Failed to get file."
            case .failToDeleteRecording(let s):
                s
            case .failToStartRecording(let s):
                s
            case .failToResumeRecording:
                "Failed to resume recording."
            case .failToStopRecording:
                "Failed to stop recording."
            case .failToResumePlaying(let s):
                s
            case .failToStopPlaying:
                "Failed to pause recording"
            }
        }
    }
    
    /// Power in decibels full-scale (dBFS)
    struct PowerMetrics: Equatable, Hashable {
        var channelName: String?
        var channelNumber: Int
        var average: Float // Ranges from –160 dBFS, indicating minimum power, to 0 dBFS.
        var peak: Float
    }
    
    /// Published UI State
    @Published private(set) var recorderState: RecorderState = .stopped
    @Published private(set) var isPlayingRecording: Bool = false
    @Published private(set) var didRecordingEnd: Bool = false
    
    @Published var activeMicrophoneName: String = "Select Audio Input"
    @Published var availableRecordingOptions: [RecordingOption] = []
    
    @Published var destinationURL: URL?
    @Published var recordedContentsDuration: TimeInterval?
    
    @Published var showError: Bool = false {
        didSet {
            if !showError { self.error = nil }
        }
    }
    var error: (any Error)? {
        didSet {
            if let error = self.error {
                print(error.localizedDescription)
                self.showError = true
            }
        }
    }
    
    /// Computed Properties
    var latestWaveformSampleLinear: Float {
        recordedWaveformSamplesLinear.last ?? 0
    }
    var playbackTime: TimeInterval {
        player?.currentTime ?? 0
    }
    
    /// Waveform State (High-Frequency)
    private(set) var recordedWaveformSamplesDb: [Float] = []
    private(set) var recordedWaveformSamplesLinear: [Float] = []
    private(set) var recordedWaveformDuration: TimeInterval = 0
    
    /// AVFoundation Core
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer? {
        didSet {
            self.recordedContentsDuration = self.player?.duration
        }
    }
    
    /// Configuration Constants
    private let waveformSampleRateHz: Int = 60
    private let waveformLeadingNoiseThreshold: Float = 0.035
    private let waveformLeadingPadSamples: Int = 1
    
    private var audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 22050,
        AVEncoderBitDepthHintKey: 16,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
    ]
    
    /// Combine Cancellables
    private var timerCancellable: AnyCancellable?
    private var waveformCancellable: AnyCancellable?
    
    override init() {
        super.init()
        
        do {
            try self.configureAudioSession()
            self.setupAvailableRecordingOptions()
            self.updateActiveMicrophoneName()
            self.setupRouteChangeListener()
        } catch(let error) {
            self.error = error
        }
    }
    
    isolated deinit {
        self.deactivateAudioSessionAndNotifyOthers()
        self.stopWaveformSampling()
        self.stopTimer()
    }
}

// MARK: - Microphone
extension AudioRecorderManager {
    private func updateActiveMicrophoneName() {
        // Grab the user-selected input data source name, or fallback to the generic port name
        if let currentInput = audioSession.currentRoute.inputs.first {
            let name = currentInput.selectedDataSource?.dataSourceName ?? currentInput.portName
            DispatchQueue.main.async {
                self.activeMicrophoneName = name
            }
        }
    }
    
    private func setupRouteChangeListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Whenever the route changes, refresh our published string
        updateActiveMicrophoneName()
    }
}

// MARK: - Recorder
extension AudioRecorderManager {
    
    // Start in (time) seconds, for (duration) seconds
    func startRecording(in time: TimeInterval?, forDuration duration: TimeInterval?, recordingOption: RecordingOption, enableMetering: Bool) async throws {
        self.activateAudioSessionForAppAudio()
        
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
        
        self.stopPlayingRecording(deactivateAudio: false)
        
        let fileName = UUID().uuidString + ".m4a"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        self.destinationURL = fileURL
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        try self.configureStereo(recordingOption: recordingOption)
        self.audioSettings[AVNumberOfChannelsKey] = (recordingOption == .mono) ? 1 : 2
        
        self.recorder = try AVAudioRecorder(url: fileURL, settings: self.audioSettings)
        self.recorder?.delegate = self
        self.recorder?.isMeteringEnabled = enableMetering
        
        let currentTime = self.recorder?.deviceCurrentTime ?? 0
        
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
        
        // Clear any previous captured metrics for a fresh recording session
        self.recordedWaveformSamplesDb = []
        self.recordedWaveformSamplesLinear = []
        self.recordedWaveformDuration = 0
        
        if let time  {
            self.recorderState = .reserved(time)
        } else {
            self.recorderState = .started(0, self.getPowerMetrics())
        }
        
        self.startTimer()
        self.startWaveformSampling()
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
        self.startWaveformSampling()
    }
    
    func pauseRecording() {
        self.recorder?.pause()
        if case .started(let timeInterval, let powerMetrics) = recorderState {
            self.recorderState = .paused(timeInterval, powerMetrics)
        } else {
            self.recorderState = .paused(recorder?.currentTime ?? 0, self.getPowerMetrics())
        }
        self.stopTimer()
        self.stopWaveformSampling()
    }
    
    func stopRecording() {
        self.recorder?.stop()
        self.recorder = nil
        self.recorderState = .stopped
        self.stopTimer()
        self.stopWaveformSampling()
        self.preparePlayer()
        self.deactivateAudioSessionAndNotifyOthers()
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
        self.stopWaveformSampling()
        
        if let fileURL = self.destinationURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        // clear player metadata
        self.player = nil
        self.recordedContentsDuration = nil
        self.recordedWaveformSamplesDb = []
        self.recordedWaveformSamplesLinear = []
        self.recordedWaveformDuration = 0
    }
}

// MARK: - Player
extension AudioRecorderManager {
    private func preparePlayer() {
        if let fileURL = self.destinationURL {
            self.didRecordingEnd = false
            self.player = try? AVAudioPlayer(contentsOf: fileURL)
            self.player?.delegate = self
        }
    }
    
    func pausePlayingRecording() {
        self.player?.pause()
        self.isPlayingRecording = false
        self.deactivateAudioSessionAndNotifyOthers()
    }
    
    func resumePlayingRecording() throws {
        self.activateAudioSessionForAppAudio()
        
        guard let player = self.player else {
            throw _Error.failToResumePlaying("Failed to prepare player")
        }
        
        let result = player.play()
        if result == false {
            throw _Error.failToResumePlaying("Failed to resume playing recording.")
        }
        
        self.isPlayingRecording = true
        self.didRecordingEnd = false
    }
    
    
    private func stopPlayingRecording(deactivateAudio: Bool = true) {
        self.player?.stop()
        self.isPlayingRecording = false
        self.didRecordingEnd = true
        
        if deactivateAudio {
            self.deactivateAudioSessionAndNotifyOthers()
        }
    }
}


// MARK: - AVAudioRecorderDelegate
extension AudioRecorderManager: AVAudioRecorderDelegate {
    // Tells the delegate when recording stops or finishes due to reaching its time limit, for example, that defined by duration when calling AVAudioRecorder.record(forDuration:).
    // The system doesn’t call this method if the recorder stops due to an interruption.
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard recorder == self.recorder else {
                return
            }
            
            if !flag {
                self.error = _Error.failToStopRecording
            } else if self.recorderState != .stopped {
                self.stopRecording()
            }
        }
    }
    
    // Tells the delegate that the audio recorder encountered an encoding error during recording.
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor in
            guard recorder == self.recorder else {
                return
            }
            self.error = error
        }
    }
}


// MARK: - AVAudioPlayerDelegate
extension AudioRecorderManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
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
        guard player == self.player else {
            return
        }
        self.error = error
        
    }
}


// MARK: - Private helpers for managing recording session / permission
extension AudioRecorderManager {
    private func activateAudioSessionForAppAudio() {
        try? self.audioSession.setActive(true)
    }
    
    private func deactivateAudioSessionAndNotifyOthers() {
        try? self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
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
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [
                .allowAirPlay,
                .allowBluetoothA2DP,
                .allowBluetoothHFP,
                .bluetoothHighQualityRecording,
                .interruptSpokenAudioAndMixWithOthers
            ]
        )
        
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
              preferredInput.portType == .builtInMic,
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
    
    private func startWaveformSampling() {
        self.stopWaveformSampling()
        let interval = 1.0 / Double(waveformSampleRateHz)
        self.waveformCancellable = Timer.publish(every: interval, on: .main, in: .common).autoconnect()
            .sink(receiveValue: { [weak self] _ in
                self?.captureWaveformSample()
            })
    }
    
    private func stopWaveformSampling() {
        self.waveformCancellable?.cancel()
        self.waveformCancellable = nil
    }
    
    private func captureWaveformSample() {
        guard let recorder = self.recorder, recorder.isRecording, recorder.isMeteringEnabled else { return }
        recorder.updateMeters()
        
        let channelCount = self.getChannels().count
        // Capture both peak and average to get a better sense of energy
        let peak = (0..<channelCount).map { recorder.peakPower(forChannel: $0) }.max() ?? -160
        let avg = (0..<channelCount).map { recorder.averagePower(forChannel: $0) }.max() ?? -160
        
        // Use a weighted blend. This makes the waveform "body" collapse faster
        // when the loud sound ends, because the average power drops quicker than the peak.
        let blendedDb = (peak * 0.3) + (avg * 0.7)
        
        recordedWaveformSamplesDb.append(blendedDb)
        recordedWaveformSamplesLinear.append(normalizeDbToLinear(blendedDb))
        recordedWaveformDuration = recorder.currentTime
    }
    
    func waveformSampleLinear(at time: TimeInterval) -> Float? {
        guard waveformSampleRateHz > 0, !recordedWaveformSamplesLinear.isEmpty else { return nil }
        let index = Int(time * Double(waveformSampleRateHz))
        let clampedIndex = max(0, min(index, recordedWaveformSamplesLinear.count - 1))
        return recordedWaveformSamplesLinear[clampedIndex]
    }
    
    func getRecordedWaveform(from audioWaveform: CodableAudioWaveform?) {
        guard audioWaveform != nil else { return }
        recordedWaveformSamplesDb = audioWaveform?.samplesDb ?? []
        recordedWaveformSamplesLinear = audioWaveform?.samplesLinear ?? []
        recordedWaveformDuration = audioWaveform?.duration ?? 0
    }
    
    func makeRecordedWaveform() -> CodableAudioWaveform? {
        guard !recordedWaveformSamplesDb.isEmpty else { return nil }
        
        let sampleDuration = Double(recordedWaveformSamplesDb.count) / Double(waveformSampleRateHz)
        let duration = recordedWaveformDuration > 0 ? recordedWaveformDuration : sampleDuration
        return CodableAudioWaveform(
            samplesDb: recordedWaveformSamplesDb,
            samplesLinear: recordedWaveformSamplesLinear,
            sampleRateHz: waveformSampleRateHz,
            duration: duration
        )
    }
    
    private func trimmedRecordedWaveformSamples() -> (db: [Float], linear: [Float]) {
        guard !recordedWaveformSamplesDb.isEmpty, recordedWaveformSamplesDb.count == recordedWaveformSamplesLinear.count else {
            return (recordedWaveformSamplesDb, recordedWaveformSamplesLinear)
        }
        
        guard let firstMeaningfulIndex = recordedWaveformSamplesLinear.firstIndex(where: { $0 >= waveformLeadingNoiseThreshold }) else {
            return (recordedWaveformSamplesDb, recordedWaveformSamplesLinear)
        }
        
        let trimStart = max(0, firstMeaningfulIndex - waveformLeadingPadSamples)
        guard trimStart > 0, trimStart < recordedWaveformSamplesDb.count else {
            return (recordedWaveformSamplesDb, recordedWaveformSamplesLinear)
        }
        
        return (
            Array(recordedWaveformSamplesDb[trimStart...]),
            Array(recordedWaveformSamplesLinear[trimStart...])
        )
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

