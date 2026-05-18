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
struct CodablePowerMetrics: Codable, Equatable, Hashable {
    var channelName: String?
    var channelNumber: Int
    var average: Float
    var peak: Float
}

/// Codable representation of recorded power frame with timestamp
struct CodableRecordedPowerFrame: Codable, Equatable {
    var time: TimeInterval
    var metrics: [CodablePowerMetrics]
}

@Model
class JournalEntries: Identifiable {
    var uuid: UUID = UUID()
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.journalEntries) var entries: [JournalEntry]? = nil
    
    init(entries: [JournalEntry] = []) {
        self.entries = entries.isEmpty ? nil : entries
    }
}

@Model
class JournalEntry: Identifiable {
    var uuid: UUID = UUID()
    var journalEntries: JournalEntries? = nil
    var date: Date = Date()
    var title: String = ""
    var note: String = ""
    var mediaTypeRaw: String = MediaType.video.rawValue
    var mediaURLString: String = ""
    var thumbnailURLString: String? = nil
    /// Encoded power metrics data (only for audio recordings)
    var powerMetricsData: Data? = nil
    
    init?(title: String,
          note: String,
          mediaData: Data,
          fileExtension: String,
          mediaType: MediaType,
          powerFrames: [CodableRecordedPowerFrame]? = nil) {
        
        let id = UUID()
        
        guard let mediaURL = MediaStore.saveMedia(data: mediaData, fileExtension: fileExtension, entryID: id) else {
            print("Failed to save media for entry")
            return nil
        }
        
        var thumbURLString: String? = nil
        if mediaType == .video {
            if let thumbData = Self.generateThumbnailData(from: mediaURL) {
                if let thumbURL = MediaStore.saveThumbnail(data: thumbData, entryID: id) {
                    // store only the filename so paths can be resolved dynamically later
                    thumbURLString = thumbURL.lastPathComponent
                }
            }
        }
        
        self.uuid = id
        self.date = Date()
        self.title = title
        self.note = note
        self.mediaTypeRaw = mediaType.rawValue
        // store only the filename to keep stored identifiers stable across container moves
        self.mediaURLString = mediaURL.lastPathComponent
        self.thumbnailURLString = thumbURLString
        
        // Only encode power frames for audio recordings
        if mediaType == .audio, let powerFrames = powerFrames, !powerFrames.isEmpty {
            do {
                self.powerMetricsData = try JSONEncoder().encode(powerFrames)
            } catch {
                print("Failed to encode power metrics: \(error)")
                self.powerMetricsData = nil
            }
        }
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
    
    /// Decodes power metrics data for this entry (audio-only)
    func decodedPowerFrames() -> [CodableRecordedPowerFrame]? {
        guard let data = powerMetricsData else { return nil }
        do {
            return try JSONDecoder().decode([CodableRecordedPowerFrame].self, from: data)
        } catch {
            print("Failed to decode power metrics: \(error)")
            return nil
        }
    }
    
    private static func generateThumbnailData(from videoURL: URL) -> Data? {
        final class ThumbnailDataBox: @unchecked Sendable { var data: Data? }
        
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 600, height: 400)
        
        let time = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
        let box = ThumbnailDataBox()
        let semaphore = DispatchSemaphore(value: 0)
        
        imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
            defer { semaphore.signal() }
            
            if let error {
                print("Thumbnail generation error: \(error)")
                return
            }
            
            guard let cgImage else { return }
            
            let thumbnail = UIImage(cgImage: cgImage)
            box.data = thumbnail.jpegData(compressionQuality: 0.85)
        }
        
        semaphore.wait()
        return box.data
    }
}
