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

    init?(title: String,
          note: String,
          mediaData: Data,
          fileExtension: String,
          mediaType: MediaType) {

        let id = UUID()

        guard let mediaURL = MediaStore.saveMedia(data: mediaData, fileExtension: fileExtension, entryID: id) else {
            print("Failed to save media for entry")
            return nil
        }

        var thumbURLString: String? = nil
        if mediaType == .video {
            if let thumbData = Self.generateThumbnailData(from: mediaURL) {
                if let thumbURL = MediaStore.saveThumbnail(data: thumbData, entryID: id) {
                    thumbURLString = thumbURL.absoluteString
                }
            }
        }

        self.uuid = id
        self.date = Date()
        self.title = title
        self.note = note
        self.mediaTypeRaw = mediaType.rawValue
        self.mediaURLString = mediaURL.absoluteString
        self.thumbnailURLString = thumbURLString
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .video
    }

    var mediaURL: URL? {
        URL(string: mediaURLString)
    }

    var thumbnailURL: URL? {
        if let s = thumbnailURLString { return URL(string: s) }
        return nil
    }

    var videoThumbImage: Image? {
        guard let thumbURL = thumbnailURL,
              let data = try? Data(contentsOf: thumbURL),
              let ui = UIImage(data: data) else {
            return nil
        }

        return Image(uiImage: ui)
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
