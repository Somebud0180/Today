//
//  AudioTranscriptionManager.swift
//  Today
//
//  Created by Ethan John Lagera on 6/15/26.
//

import Foundation
import AVFoundation
import FluidAudio
import SwiftUI
import Combine

enum ModelLoadState {
    case idle
    case downloading
    case loading
    case ready
    case unloading
    case failed(Error)
}

extension ModelLoadState: Equatable {
    static func == (lhs: ModelLoadState, rhs: ModelLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.downloading, .downloading),
            (.loading, .loading),
            (.ready, .ready):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

extension ModelLoadState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .downloading: return "Downloading"
        case .loading: return "Loading"
        case .ready: return "Ready"
        case .unloading: return "Unloading"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class AudioTranscriptionManager: ObservableObject {
    @AppStorage("asrModelsURL") private var asrModelsURL: URL?
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    @Published private(set) var modelLoadState: ModelLoadState = .idle
    
    private var transcriptionModels: AsrModels?
    private let asrManager = AsrManager()
    private var loadTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if enableTranscription {
            Task { try? await loadModels() }
        } else {
            cleanupModels()
        }
        
        enableTranscriptionPublisher()
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] isEnabled in
                Task.detached(priority: .background) {
                    await self?.handleTranscriptionToggle(isEnabled)
                }
            }
            .store(in: &cancellables)
    }
    
    private func enableTranscriptionPublisher() -> AnyPublisher<Bool, Never> {
        Just(enableTranscription)
            .append(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .map { [weak self] _ in self?.enableTranscription ?? false }
            )
            .eraseToAnyPublisher()
    }
    
    private func handleTranscriptionToggle(_ isEnabled: Bool) async {
        if isEnabled {
            do {
                try await loadModels()
            } catch {
                await MainActor.run { self.modelLoadState = .failed(error) }
            }
        } else {
            // Cancel work and free memory
            await cancelLoadingIfNeeded()
            cleanupModels()
        }
    }
    
    func loadModels() async throws {
        guard enableTranscription else { return }
        if case .ready = modelLoadState { return }
        if let existing = loadTask { return try await existing.value }
        
        loadTask = Task {
            do {
                self.modelLoadState = .downloading
                let modelsURL = try await AsrModels.download(version: .v3)
                self.asrModelsURL = modelsURL
                
                try Task.checkCancellation()
                guard self.enableTranscription else { throw CancellationError() }
                
                self.modelLoadState = .loading
                let models = try await AsrModels.load(from: modelsURL)
                
                try Task.checkCancellation()
                guard self.enableTranscription else { throw CancellationError() }
                
                try await self.asrManager.loadModels(models)
                
                try Task.checkCancellation()
                guard self.enableTranscription else { throw CancellationError() }
                
                self.transcriptionModels = models
                self.modelLoadState = .ready
            } catch is CancellationError {
                self.cleanupModels()
                throw CancellationError()
            } catch {
                self.modelLoadState = .failed(error)
                throw error
            }
        }
        
        do {
            try await loadTask?.value
            loadTask = nil
        } catch {
            loadTask = nil
            throw error
        }
    }
    
    func ensureModelsReady(timeout: Duration? = .seconds(20)) async throws {
        switch modelLoadState {
        case .ready: return
        case .failed(let error): throw error
        default: break
        }
        
        let waitForLoad = { try await self.loadModels() }
        
        if let timeout {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await waitForLoad() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw NSError(domain: "ASR", code: -2, userInfo: [NSLocalizedDescriptionKey: "Model load timed out"])
                }
                let first: Void? = try await group.next()
                group.cancelAll()
                _ = first
            }
        } else {
            try await waitForLoad()
        }
    }
    
    private func cancelLoadingIfNeeded() async {
        loadTask?.cancel()
        do {
            _ = try await loadTask?.value
        } catch is CancellationError {
        } catch {
        }
        loadTask = nil
    }
    
    private func cleanupModels() {
        Task { @MainActor in
            modelLoadState = .unloading
            transcriptionModels = nil
            await asrManager.cleanup()
            modelLoadState = .idle
        }
    }
}

extension AudioTranscriptionManager {
    func isModelDownloaded() -> Bool {
        guard let url = asrModelsURL else { return false }
        return AsrModels.modelsExist(at: url)
    }
    
    func deleteModel() async {
        guard let url = asrModelsURL else { return }
        
        await cancelLoadingIfNeeded()
        
        await MainActor.run {
            self.modelLoadState = .unloading
        }
        
        transcriptionModels = nil
        await asrManager.cleanup()
        
        self.enableTranscription = false
        
        do {
            try FileManager.default.removeItem(at: url)
            try clearAppCachesDirectory()
            
            await MainActor.run {
                self.modelLoadState = .idle
            }
        } catch {
            await MainActor.run {
                self.modelLoadState = .failed(error)
            }
        }
    }
    
    func clearAppCachesDirectory() throws {
        let fileManager = FileManager.default
        
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        
        let contents = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil, options: [])
        for url in contents {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw error
            }
        }
    }

}

extension AudioTranscriptionManager {
    func transcribeAudio(_ audioURL: URL) async -> (ASRResult?, Bool) {
        guard enableTranscription else {
            return (nil, false)
        }
        
        do {
            try await ensureModelsReady(timeout: .seconds(20))
            var localDecoderState = try TdtDecoderState()
            let result = try await asrManager.transcribe(audioURL, decoderState: &localDecoderState)
            return (result, true)
        } catch {
            await MainActor.run {
                self.modelLoadState = .failed(error)
            }
            return (nil, false)
        }
    }
    
    func transcribeVideo(_ videoURL: URL) async -> (ASRResult?, Bool) {
        guard enableTranscription else {
            return (nil, false)
        }
        
        do {
            let fileName = UUID().uuidString + ".m4a"
            let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try await extractAudio(from: videoURL, to: audioURL)
            
            let result = await transcribeAudio(audioURL)
            return result
        } catch {
            await MainActor.run {
                self.modelLoadState = .failed(error)
            }
            return (nil, false)
        }
    }
}

extension AudioTranscriptionManager {
    func extractAudio(from videoURL: URL, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: videoURL)
        
        guard try await asset.loadTracks(withMediaType: .audio).first != nil else {
            throw NSError(domain: "AudioExtraction", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioExtraction", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"])
        }
        
        exportSession.outputFileType = .m4a
        exportSession.timeRange = await CMTimeRange(start: .zero, duration: try asset.load(.duration))
        
        try? FileManager.default.removeItem(at: outputURL)
        
        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
