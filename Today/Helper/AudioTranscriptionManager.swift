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
    @AppStorage("transcriptionLocale") private var transcriptionLocale: String = DefaultSettings.transcriptionLocale
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var isReady: Bool = false
    @Published private(set) var error: String?
    @Published private(set) var supportedLocales: [Locale] = []
    
    private var transcriber: SpeechTranscriber?
    
    init() {
        initializeTranscriber()
    }
    
    /// Prepares the transcriber and resolves local language support
    func initializeTranscriber() {
        guard SpeechTranscriber.isAvailable else {
            self.error = "Speech transcription is not supported on this device hardware."
            return
        }
        
        let currentSavedLocale = Locale(identifier: transcriptionLocale)
        
        Task {
            if self.supportedLocales.isEmpty {
                let locales = await SpeechTranscriber.supportedLocales
                self.supportedLocales = locales.sorted {
                    ($0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) <
                        ($1.localizedString(forIdentifier: $1.identifier) ?? $1.identifier)
                }
            }
            
            if let verifiedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: currentSavedLocale) {
                if self.transcriptionLocale != verifiedLocale.identifier {
                    self.transcriptionLocale = verifiedLocale.identifier
                }
                
                _ = try? await AssetInventory.reserve(locale: verifiedLocale)
                self.transcriber = SpeechTranscriber(locale: verifiedLocale, preset: .transcription)
                self.isReady = true
            } else {
                let fallbackLocale = Locale(identifier: "en-US")
                if let verifiedFallback = await SpeechTranscriber.supportedLocale(equivalentTo: fallbackLocale) {
                    self.transcriptionLocale = verifiedFallback.identifier
                    _ = try? await AssetInventory.reserve(locale: verifiedFallback)
                    self.transcriber = SpeechTranscriber(locale: verifiedFallback, preset: .transcription)
                    self.isReady = true
                } else {
                    self.error = "The system locale is not supported by the transcriber."
                }
            }
        }
    }
    
    func downloadAsset() async {
        guard let transcriber = transcriber else {
            self.error = "Transcriber not initialized."
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installationRequest.downloadAndInstall()
            }
        } catch {
            self.error = "Failed to download asset: \(error.localizedDescription)"
        }
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Transcribe Functions
extension AudioTranscriptionManager {
    /// Transcribes an audio file using Apple's native SpeechAnalyzer
    func transcribeAudio(_ audioURL: URL) async -> (String?, Bool) {
        guard enableTranscription, let transcriber = transcriber, isReady else { return (nil, false) }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            
            _ = try await SpeechAnalyzer(
                inputAudioFile: audioFile,
                modules: [transcriber],
                options: nil,
                analysisContext: AnalysisContext(),
                finishAfterFile: true,
                volatileRangeChangedHandler: nil
            )
            
            var finalTranscript = ""
            for try await result in transcriber.results {
                if result.isFinal {
                    let chunk = String(result.text.characters)
                    finalTranscript += chunk + " "
                }
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
            print("Video transcription failed: \(error.localizedDescription)")
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
