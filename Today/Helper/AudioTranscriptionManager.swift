//
//  AudioTranscriptionManager.swift
//  Today
//
//  Created by Ethan John Lagera on 6/15/26.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI
import Combine

@MainActor
final class AudioTranscriptionManager: ObservableObject {
    @AppStorage("enableTranscription") private var enableTranscription: Bool = DefaultSettings.enableTranscription
    
    @Published private(set) var isProcessing: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        enableTranscriptionPublisher()
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] isEnabled in
                if !isEnabled {
                    try? self?.clearAppCachesDirectory()
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
    
    func clearAppCachesDirectory() throws {
        let fileManager = FileManager.default
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        let contents = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil, options: [])
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Transcribe Functions
extension AudioTranscriptionManager {
    /// Transcribes an audio file using Apple's native SpeechAnalyzer
    func transcribeAudio(_ audioURL: URL) async -> (String?, Bool) {
        guard enableTranscription else { return (nil, false) }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            
            let locale = Locale.current
            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
            
            let analyzer = try await SpeechAnalyzer(
                inputAudioFile: audioFile,
                modules: [transcriber],
                options: nil,
                analysisContext: AnalysisContext(),
                finishAfterFile: true,
                volatileRangeChangedHandler: nil
            )
            
            var finalTranscript = ""
            for try await result in transcriber.results {
                // The exact property for the text depends on the Result structure,
                // typically you would append the resolved text from the phrases.
                // Assuming `result.text` or similar holds the string payload:
                // finalTranscript += result.text + " "
            }
            
            return (finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines), true)
            
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
            return (nil, false)
        }
    }
    
    func transcribeVideo(_ videoURL: URL) async -> (String?, Bool) {
        guard enableTranscription else { return (nil, false) }
        
        do {
            let fileName = UUID().uuidString + ".m4a"
            let audioURL = FileManager.default.temporaryDirectory.appending(path: fileName, directoryHint: .notDirectory)
            
            try await extractAudio(from: videoURL, to: audioURL)
            
            let result = await transcribeAudio(audioURL)
            
            try? FileManager.default.removeItem(at: audioURL)
            
            return result
        } catch {
            print("Video extraction/transcription failed: \(error.localizedDescription)")
            return (nil, false)
        }
    }
}

// MARK: - Audio Extraction
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
        exportSession.timeRange = try await CMTimeRange(start: .zero, duration: asset.load(.duration))
        
        try? FileManager.default.removeItem(at: outputURL)
        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
