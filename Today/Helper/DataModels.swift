//
//  DataModels.swift
//  Today
//
//  Created by Ethan John Lagera on 5/9/26.
//

import Foundation
import SwiftData
import SwiftUI
import AVFoundation
import UIKit

// Unified media type
enum MediaType: String, Codable {
    case video
    case audio
}

// MARK: - Power Metrics Codable Models
/// Codable representation of power metrics for a single audio channel
struct CodablePowerMetrics: nonisolated Codable, Equatable, Hashable {
    var channelName: String?
    var channelNumber: Int
    var average: Float
    var peak: Float
}

/// Codable representation of recorded power frame with timestamp
struct CodableRecordedPowerFrame: nonisolated Codable, Equatable {
    var time: TimeInterval
    var metrics: [CodablePowerMetrics]
}

/// Codable representation of a fixed-rate audio waveform capture
struct CodableAudioWaveform: nonisolated Codable, Equatable {
    var samplesDb: [Float]
    var samplesLinear: [Float]
    var sampleRateHz: Int
    var duration: TimeInterval
}

@Model
class JournalEntry: Identifiable {
    var uuid: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var note: String = ""
    var transcript: String = ""
    var mediaTypeRaw: String = MediaType.video.rawValue
    var mediaURLString: String = ""
    var thumbnailURLString: String? = nil
    /// Encoded power metrics data (legacy audio recordings)
    var powerMetricsData: Data? = nil
    /// Encoded waveform data (audio recordings)
    var waveformData: Data? = nil

    init(title: String = "", note: String = "", transcript: String = "",
         mediaType: MediaType = .video, uuid: UUID = UUID(),
         mediaFilename: String = "", thumbnailFilename: String? = nil,
         waveformData: Data? = nil) {
        self.uuid = uuid
        self.title = title
        self.note = note
        self.transcript = transcript
        self.mediaTypeRaw = mediaType.rawValue
        self.mediaURLString = mediaFilename
        self.thumbnailURLString = thumbnailFilename
        self.waveformData = waveformData
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .video
    }

    var mediaURL: URL? {
        if mediaURLString.isEmpty { return nil }
        if let maybeURL = URL(string: mediaURLString), maybeURL.scheme != nil {
            // stored an absolute URL previously — prefer dynamic resolution by filename
            let filename = maybeURL.lastPathComponent
            return MediaStore.urlForMediaFilename(filename) ?? maybeURL
        }
        // stored as filename
        return MediaStore.urlForMediaFilename(mediaURLString)
    }

    var thumbnailURL: URL? {
        guard let s = thumbnailURLString, !s.isEmpty else { return nil }
        if let maybeURL = URL(string: s), maybeURL.scheme != nil {
            let filename = maybeURL.lastPathComponent
            return MediaStore.urlForMediaFilename(filename) ?? maybeURL
        }
        return MediaStore.urlForMediaFilename(s)
    }

    var videoThumbImage: Image? {
        guard let thumbURL = thumbnailURL,
              let data = try? Data(contentsOf: thumbURL),
              let ui = UIImage(data: data) else {
            return nil
        }

        return Image(uiImage: ui)
    }
}

// MARK: - Audio Decode
extension JournalEntry {
    /// Decodes power metrics data for this entry (legacy audio-only)
    func decodedPowerFrames() -> [CodableRecordedPowerFrame]? {
        guard let data = powerMetricsData else { return nil }
        do {
            return try JSONDecoder().decode([CodableRecordedPowerFrame].self, from: data)
        } catch {
            print("Failed to decode power metrics: \(error)")
            return nil
        }
    }
    
    /// Decodes waveform data for this entry (audio-only)
    func decodedWaveform() -> CodableAudioWaveform? {
        guard let data = waveformData else { return nil }
        do {
            return try JSONDecoder().decode(CodableAudioWaveform.self, from: data)
        } catch {
            print("Failed to decode waveform: \(error)")
            return nil
        }
    }
    
    func decodedWaveform(for url: URL) -> CodableAudioWaveform? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(CodableAudioWaveform.self, from: data)
        } catch {
            print("Failed to decode waveform: \(error)")
            return nil
        }
    }
}

// MARK: - Thumbnails
extension JournalEntry {
    /// Returns a short centered snippet of the audio waveform for grid thumbnails.
    func audioWaveformThumbnailLevels(maxBars: Int = 24) -> [CGFloat]? {
        guard mediaType == .audio,
              maxBars > 0,
              let waveform = decodedWaveform(),
              !waveform.samplesLinear.isEmpty else {
            return nil
        }
        
        let samples = waveform.samplesLinear
        let snippetCount = min(maxBars, samples.count)
        let startIndex = max(0, (samples.count - snippetCount) / 2)
        let endIndex = startIndex + snippetCount
        
        return samples[startIndex..<endIndex].map { CGFloat($0) }
    }
    
    static func audioWaveformThumbnailLevels(_ linearSamples: [Float], maxBars: Int = 24) -> [CGFloat]? {
        guard maxBars > 0, !linearSamples.isEmpty else {
            return nil
        }
        
        let snippetCount = min(maxBars, linearSamples.count)
        let startIndex = max(0, (linearSamples.count - snippetCount) / 2)
        let endIndex = startIndex + snippetCount
        
        return linearSamples[startIndex..<endIndex].map { CGFloat($0) }
    }
    

}

// MARK: - Quick Export
extension JournalEntry {
    /// Returns a URL suitable for sharing this entry's media (with note embedded as video metadata for videos)
    func exportMediaURLForSharing() async -> URL? {
        switch mediaType {
        case .audio:
            if let url = try? await exportAudioCopy() {
                return url
            } else {
                return mediaURL
            }
        case .video:
            // Try to embed the note as video metadata and return the new file's URL
            if let url = try? await exportVideoWithCaption(note: note) {
                return url
            } else {
                return mediaURL
            }
        }
    }
    
    /// Exports a copy of the audio to a custom-named file in the temporary directory.
    func exportAudioCopy() async throws -> URL? {
        guard mediaType == .audio, let originalURL = mediaURL else { return nil }
        
        let originalExt = originalURL.pathExtension
        let tempDir = try ExportNaming.makeDirectory()
        let outputURL = tempDir.appending(path: "\(ExportNaming.safeName(self.title.isEmpty ? self.date.formatted(date: .long, time: .omitted) : self.title)).\(originalExt)", directoryHint: .notDirectory)
        
        // Remove any existing file at destination
        try? FileManager.default.removeItem(at: outputURL)
        
        do {
            try await Task.detached { try FileManager.default.copyItem(at: originalURL, to: outputURL) }.value
            return outputURL
        } catch {
            print("Failed to copy audio: \(error)")
            return nil
        }
    }
    
    /// Exports a copy of the video with the note embedded as description metadata (MOV)
    private func exportVideoWithCaption(note: String) async throws -> URL? {
        guard let originalURL = mediaURL else { return nil }
        let asset = AVURLAsset(url: originalURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        
        // Prepare temp output URL
        let tempDir = try ExportNaming.makeDirectory()
        let outputURL = tempDir.appending(path: "\(ExportNaming.safeName(self.title.isEmpty ? self.date.formatted(date: .long, time: .omitted) : self.title)).mov", directoryHint: .notDirectory)
        // Remove any existing file
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // Copy existing metadata, add 'description' item
        var metadata = try await asset.load(.metadata)
        let descriptionItem = AVMutableMetadataItem()
        descriptionItem.keySpace = .common
        descriptionItem.key = AVMetadataKey.commonKeyDescription as NSString
        descriptionItem.value = note as NSString
        metadata.removeAll { ($0.key as? String) == (descriptionItem.key as? String) && $0.keySpace == descriptionItem.keySpace }
        metadata.append(descriptionItem)
        exportSession.metadata = metadata
        
        do {
            try await exportSession.export(to: outputURL, as: .mov)
            return outputURL
        } catch {
            return nil
        }
    }
}

extension JournalEntry {
    func matchesSearch(_ text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [title, transcript,
                date.formatted(date: .long, time: .omitted),
                date.formatted(date: .abbreviated, time: .omitted),
                date.formatted(date: .numeric, time: .omitted),
                date.formatted(.dateTime.year().month().day())]
            .contains { $0.localizedStandardContains(query) }
    }
}

/// Persisted in the same transaction as entry deletion, including across devices.
/// Retaining this record prevents an offline device from uploading a deleted file again.
@Model
final class MediaDeletion {
    var uuid: UUID = UUID()
    var mediaFilename: String = ""
    var thumbnailFilename: String? = nil

    init(entry: JournalEntry) {
        uuid = entry.uuid
        mediaFilename = URL(string: entry.mediaURLString)?.lastPathComponent ?? entry.mediaURLString
        thumbnailFilename = entry.thumbnailURLString.map { URL(string: $0)?.lastPathComponent ?? $0 }
    }

    var filenames: [String] {
        [mediaFilename, thumbnailFilename].compactMap { $0 }.filter { !$0.isEmpty }
    }
}
