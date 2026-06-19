//
//  VideoRecorderManager.swift
//  Today
//
//  Created by Ethan John Lagera on 5/15/26.
//

import AVFoundation
import SwiftUI
import UIKit
import Combine

final class VideoRecorderManager: NSObject, ObservableObject {
    struct LensOption: Identifiable, Equatable {
        let id: String
        let position: AVCaptureDevice.Position
        let deviceType: AVCaptureDevice.DeviceType
        let displayName: String
        let zoomHint: CGFloat
    }

    enum RecorderError: LocalizedError {
        case permissionDenied(String)
        case configurationFailed(String)
        case recordingFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied(let message):
                return message
            case .configurationFailed(let message):
                return message
            case .recordingFailed(let message):
                return message
            }
        }
    }

    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var activePosition: AVCaptureDevice.Position = .front
    @Published private(set) var availableLensOptions: [LensOption] = []
    @Published private(set) var selectedLens: LensOption?
    @Published private(set) var availableZoomStops: [CGFloat] = []
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var exposureBias: Float = 0
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var errorMessage: String?
    @Published var showConfirmation: Bool = false
    @Published var showError = false
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "VideoRecorderManager.session")
    private var isConfigured = false
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let movieOutput = AVCaptureMovieFileOutput()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObserverTokens: [NSKeyValueObservation] = []
    private var recordingStartDate: Date?
    private var durationCancellable: AnyCancellable?

    private var zoomBaseFactor: CGFloat = 1.0
    // zoomBaseFactor is stored in "display" zoom units (the user-facing zoom where 1.0 == wide lens)
    
    private func displayZoom(for device: AVCaptureDevice) -> CGFloat {
        return zoomHint(for: device) * device.videoZoomFactor
    }
    private var exposureBiasBase: Float = 0

    override init() {
        super.init()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        rotationObserverTokens.forEach { $0.invalidate() }
        rotationObserverTokens.removeAll()
        session.stopRunning()
        DispatchQueue.global(qos: .background).async {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate AVAudioSession: \(error)")
            }
        }
    }
    
    func restoreVideo(from url: URL) {
        lastRecordingURL = url
        showConfirmation = true
    }
}

// MARK: - Public session lifecycle
extension VideoRecorderManager {
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureRotationCoordinatorIfNeeded()
            self.syncVideoRotation()
        }
    }

    func startSession() async {
        let granted = await requestPermissions()
        guard granted else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
}

// MARK: - Recording controls
extension VideoRecorderManager {
    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            guard !self.movieOutput.isRecording else { return }

            self.syncVideoRotation()

            let url = self.makeRecordingURL()
            self.lastRecordingURL = url

            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }

            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
            self.showConfirmation = true
        }
    }

    func discardRecording() {
        sessionQueue.async {
            if let url = self.lastRecordingURL, FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            self.lastRecordingURL = nil
            self.showConfirmation = false
            
            DispatchQueue.main.async {
                self.recordingDuration = 0
                self.recordingStartDate = nil
            }
        }
    }
}

// MARK: - Camera selection
extension VideoRecorderManager {
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (activePosition == .back) ? .front : .back
        setActivePosition(newPosition)
    }

    func setActivePosition(_ position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            DispatchQueue.main.async {
                self.activePosition = position
            }
            self.refreshAvailableLenses(position: position)

            guard let device = self.defaultDevice(for: position) else {
                self.setErrorOnMain(RecorderError.configurationFailed("No camera available for position."))
                return
            }
            self.configureVideoInput(device: device)
        }
    }

    func selectLens(_ lens: LensOption) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.device(for: lens) else { return }
            self.configureVideoInput(device: device)
        }
    }
}

// MARK: - Focus, exposure, zoom
extension VideoRecorderManager {
    func focusAndExpose(at viewPoint: CGPoint) {
        guard let previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)

        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {
                self.setErrorOnMain(error)
            }
        }
    }

    func beginExposureAdjustment() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            self.exposureBiasBase = device.exposureTargetBias
        }
    }

    func adjustExposure(by normalizedDelta: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            let minBias = device.minExposureTargetBias
            let maxBias = device.maxExposureTargetBias
            let range = maxBias - minBias
            let target = self.exposureBiasBase + Float(normalizedDelta) * range
            let clamped = min(max(target, minBias), maxBias)
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.exposureBias = clamped
                }
            } catch {
                self.setErrorOnMain(error)
            }
        }
    }

    func beginZoom() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            // store base in display units so pinch scale is applied in user-facing zoom space
            self.zoomBaseFactor = self.displayZoom(for: device)
        }
    }

    func updateZoom(by scale: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            // Scale the current display zoom by the gesture delta.
            let desiredDisplay = self.zoomBaseFactor * scale
            let deviceHint = self.zoomHint(for: device)
            let minDeviceZoom = device.minAvailableVideoZoomFactor
            let maxDeviceZoom = device.maxAvailableVideoZoomFactor
            var targetDeviceZoom = desiredDisplay / deviceHint
            targetDeviceZoom = min(max(targetDeviceZoom, minDeviceZoom), maxDeviceZoom)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = targetDeviceZoom
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    // publish display zoom
                    self.zoomFactor = desiredDisplay
                }
            } catch {
                self.setErrorOnMain(error)
            }
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        // factor is a DISPLAY zoom (user-facing) where 1.0 = wide lens. Convert to device zoom.
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            let deviceHint = self.zoomHint(for: device)
            let minDeviceZoom = device.minAvailableVideoZoomFactor
            let maxDeviceZoom = device.maxAvailableVideoZoomFactor
            var targetDeviceZoom = factor / deviceHint
            targetDeviceZoom = min(max(targetDeviceZoom, minDeviceZoom), maxDeviceZoom)
            do {
                try device.lockForConfiguration()
                let rate: Float = 24.0
                device.ramp(toVideoZoomFactor: targetDeviceZoom, withRate: rate)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    // publish display zoom
                    self.zoomFactor = factor
                }
            } catch {
                self.setErrorOnMain(error)
            }
        }
    }
}

// MARK: - Orientation
extension VideoRecorderManager {
    @objc private func handleOrientationChange() {
        sessionQueue.async { [weak self] in
            self?.syncVideoRotation()
        }
    }

    private func configureRotationCoordinator(for device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        setRotationCoordinator(coordinator)
    }

    private func configureRotationCoordinatorIfNeeded() {
        guard let device = videoDeviceInput?.device else { return }

        if let rotationCoordinator,
           rotationCoordinator.device === device,
           rotationCoordinator.previewLayer === previewLayer {
            return
        }

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        setRotationCoordinator(coordinator)
    }

    private func setRotationCoordinator(_ coordinator: AVCaptureDevice.RotationCoordinator?) {
        rotationObserverTokens.forEach { $0.invalidate() }
        rotationObserverTokens.removeAll()
        rotationCoordinator = coordinator

        guard let coordinator else { return }

        // Keep preview and capture rotation in sync as the coordinator updates with motion.
        let previewObserver = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, _ in
            self?.sessionQueue.async { [weak self] in
                self?.syncVideoRotation()
            }
        }
        let captureObserver = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, _ in
            self?.sessionQueue.async { [weak self] in
                self?.syncVideoRotation()
            }
        }
        rotationObserverTokens = [previewObserver, captureObserver]
    }

    private func syncVideoRotation() {
        configureRotationCoordinatorIfNeeded()

        guard let rotationCoordinator else { return }

        let previewAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        let captureAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture

        if let connection = movieOutput.connection(with: .video) {
            applyVideoRotationAngle(captureAngle, to: connection)
        }
        if let connection = previewLayer?.connection {
            applyVideoRotationAngle(previewAngle, to: connection)
            if connection.isVideoMirroringSupported {
                if connection.responds(to: #selector(setter: AVCaptureConnection.automaticallyAdjustsVideoMirroring)) {
                    connection.automaticallyAdjustsVideoMirroring = false
                }
                connection.isVideoMirrored = (activePosition == .front)
            }
        }
    }

    private func applyVideoRotationAngle(_ angle: CGFloat, to connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            guard connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}

// MARK: - Private configuration helpers
extension VideoRecorderManager {
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }

        if let videoDeviceInput {
            session.removeInput(videoDeviceInput)
        }
        if let audioDeviceInput {
            session.removeInput(audioDeviceInput)
        }

        if session.outputs.contains(movieOutput) == false, session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.configuresApplicationAudioSessionToMixWithOthers = true

        // Use the runtime-preferred default device so virtual multi-camera hardware
        // can expose its native switch-over behavior instead of bypassing it.
        guard let defaultDevice = defaultDevice(for: activePosition) else {
            setErrorOnMain(RecorderError.configurationFailed("No default camera device found."))
            return
        }

        configureVideoInput(device: defaultDevice)
        configureAudioInput()
        refreshAvailableLenses(position: activePosition)
        isConfigured = true
    }

    private func configureVideoInput(device: AVCaptureDevice) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let videoDeviceInput {
            session.removeInput(videoDeviceInput)
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                setErrorOnMain(RecorderError.configurationFailed("Unable to add video input."))
                return
            }
            session.addInput(input)
            videoDeviceInput = input

            if let defaultZoom = defaultZoomFactor(for: device) {
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = min(max(defaultZoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                    device.unlockForConfiguration()
                } catch {
                    setErrorOnMain(error)
                }
            }

            let option = lensOption(for: device)
            DispatchQueue.main.async {
                self.selectedLens = option
                self.activePosition = option.position
            }
            configureRotationCoordinator(for: device)
            syncVideoRotation()
            updateZoomStops(for: device)
        } catch {
            setErrorOnMain(error)
        }
    }

    private func configureAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(input) {
                session.addInput(input)
                audioDeviceInput = input
            }
        } catch {
            setErrorOnMain(error)
        }
    }

    private func refreshAvailableLenses(position: AVCaptureDevice.Position? = nil) {
        let pos = position ?? activePosition
        let devices = discoverDevices(for: pos)
        let options = devices.map { lensOption(for: $0) }.sorted { $0.zoomHint < $1.zoomHint }
        DispatchQueue.main.async {
            self.availableLensOptions = options

            // Prefer the currently active device's lens option if available, otherwise fall back to first
            if let currentDevice = self.videoDeviceInput?.device {
                let preferred = self.lensOption(for: currentDevice)
                if let match = options.first(where: { $0.id == preferred.id }) {
                    self.selectedLens = match
                    return
                }
            }

            if self.selectedLens == nil, let first = options.first {
                self.selectedLens = first
            }
        }
    }

    private func updateZoomStops(for device: AVCaptureDevice) {
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        debugPrint("Device zoom range: \(minZoom)x - \(maxZoom)x")

        // Re-discover devices for the device's position to avoid stale availableLensOptions
        let devicesAtPosition = discoverDevices(for: device.position)
        let options = devicesAtPosition.map { lensOption(for: $0) }.sorted { $0.zoomHint < $1.zoomHint }
//        let hints = devicesAtPosition.map { zoomHint(for: $0.deviceType) }
        
        let stops = Array(Set(options.map { $0.zoomHint })).sorted()
//        stops.insert(1.0)
//        let filtered = stops.filter { $0 >= minZoom && $0 <= maxZoom }
//        let sorted = filtered.sorted()

        DispatchQueue.main.async {
            self.availableZoomStops = stops
            self.zoomFactor = self.displayZoom(for: device)
            self.exposureBias = device.exposureTargetBias
        }
    }

    private func discoverDevices(for position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInTrueDepthCamera,
            .continuityCamera
        ]

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return discovery.devices
    }

    private func defaultDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let preference: [AVCaptureDevice.DeviceType]
        if position == .back {
            preference = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera
            ]
        } else {
            preference = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
                .builtInUltraWideCamera
            ]
        }

        for type in preference {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                return device
            }
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func device(for lens: LensOption) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(lens.deviceType, for: .video, position: lens.position) {
            return device
        }
        return discoverDevices(for: lens.position).first { $0.deviceType == lens.deviceType }
    }

    private func lensOption(for device: AVCaptureDevice) -> LensOption {
        let label = lensLabel(for: device.deviceType)
        let name = "\(device.position == .front ? "Front" : "Back") \(label)"
        return LensOption(
            id: "\(device.position.rawValue)-\(device.deviceType.rawValue)",
            position: device.position,
            deviceType: device.deviceType,
            displayName: name,
            zoomHint: zoomHint(for: device)
        )
    }

    private func lensLabel(for type: AVCaptureDevice.DeviceType) -> String {
        switch type {
        case .builtInUltraWideCamera:
            return "Ultra Wide"
        case .builtInWideAngleCamera:
            return "Wide"
        case .builtInTelephotoCamera:
            return "Telephoto"
        case .builtInTrueDepthCamera:
            return "TrueDepth"
        case .builtInDualWideCamera:
            return "Dual Wide"
        case .builtInDualCamera:
            return "Dual"
        case .builtInTripleCamera:
            return "Triple"
        case .continuityCamera:
            return "Continuity"
        default:
            return "Camera"
        }
    }

    /// Determines the display zoom multiplier for a concrete capture device.
    /// Physical ultra-wide cameras stay at a 1.0 device zoom baseline, while
    /// virtual multi-camera devices use their switch-over factors so 1.0 display
    /// zoom maps to the familiar wide view instead of the ultra-wide baseline.
    private func zoomHint(for device: AVCaptureDevice) -> CGFloat {
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return 0.5
        case .builtInWideAngleCamera, .builtInTrueDepthCamera:
            return 1.0
        case .builtInTelephotoCamera:
            return 2.0
        case .builtInDualWideCamera, .builtInDualCamera, .builtInTripleCamera:
            if #available(iOS 15.1, *) {
                if let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue, switchOver > 0 {
                    return 1.0 / CGFloat(switchOver)
                }
            }
            return 0.5
        default:
            return 1.0
        }
    }

    private func defaultZoomFactor(for device: AVCaptureDevice) -> CGFloat? {
        switch device.deviceType {
        case .builtInDualWideCamera, .builtInDualCamera, .builtInTripleCamera:
            if #available(iOS 15.1, *) {
                return device.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) } ?? 2.0
            }
            return 2.0
        default:
            return nil
        }
    }

    private func makeRecordingURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let filename = "video-\(UUID().uuidString).mov"
        return directory.appendingPathComponent(filename)
    }

    private func requestPermissions() async -> Bool {
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        if !videoGranted || !audioGranted {
            setErrorOnMain(RecorderError.permissionDenied("Camera and microphone permission is required."))
        }
        return videoGranted && audioGranted
    }

    private func setErrorOnMain(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecorderManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStartDate = Date()
            self.recordingDuration = 0
            
            self.durationCancellable?.cancel()
            self.durationCancellable = Timer.publish(every: 0.2, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self = self] _ in
                    guard let self, let start = self.recordingStartDate else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)
                }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.durationCancellable?.cancel()
            self.durationCancellable = nil
        }
        
        if let error {
            let nsError = error as NSError
            // Ignore normal stop flow errors (19914, -19431) from AVFoundation
            if nsError.code == 19914 || nsError.code == -19431 || error.localizedDescription.lowercased().contains("recording stopped") {
                DispatchQueue.main.async {
                    self.lastRecordingURL = outputFileURL
                }
                return
            }
            setErrorOnMain(RecorderError.recordingFailed(error.localizedDescription))
            return
        }
        
        DispatchQueue.main.async {
            self.lastRecordingURL = outputFileURL
        }
    }
}
