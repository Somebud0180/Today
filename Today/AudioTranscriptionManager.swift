//
//  AudioTranscriptionManager.swift
//  Today
//
//  Created by Ethan John Lagera on 6/15/26.
//

import Foundation
import FluidAudio

class AudioTranscriptionManager {
    private var transcriptionModels: AsrModels?
    private var asrManager: AsrManager
   
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
    
    init() {
        self.asrManager = AsrManager()
        
        Task {
            do {
                let models = try await AsrModels.downloadAndLoad(version: .v3)
                self.transcriptionModels = models
                try await self.asrManager.loadModels(models)
            } catch {
                self.error = error
            }
        }
    }
    
    deinit {
        Task.detached { [weak self] in
            await self?.asrManager.cleanup()
        }
    }
    
    private func waitUntilASRReady(timeout: Duration = .seconds(15)) async -> Bool {
        let start = ContinuousClock.now
        while await !asrManager.isAvailable {
            // Check for timeout
            if ContinuousClock.now - start > timeout {
                return false
            }
            // Sleep briefly to yield the executor
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        return true
    }
    
    func transcribeAudio(_ audioURL: URL) async -> ASRResult? {
        let ready = await waitUntilASRReady()
        
        guard ready else {
            self.error = NSError(domain: "ASR", code: -1, userInfo: [NSLocalizedDescriptionKey: "ASR not ready after timeout"])
            return .none
        }
        
        do {
            var localDecoderState = try TdtDecoderState()
            let result = try await asrManager.transcribe(audioURL, decoderState: &localDecoderState)
            return result
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
        
        return .none
    }
}
