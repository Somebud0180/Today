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

@Model
class JournalEntries: Identifiable {
    var uuid: UUID = UUID()
    @Relationship(deleteRule: .cascade) var entries: [JournalEntry] = []
    
    init(entries: [JournalEntry]) {
        self.entries = entries
    }
}

@Model
class JournalEntry: Identifiable{
    var uuid: UUID = UUID()
    var date: Date = Date()
    var videoName: String = ""
    var videoThumbData: Data? = nil
    var title: String = ""
    var note: String = ""
    
    init(videoName: String, note: String) {
        self.videoName = videoName
        self.note = note
        self.videoThumbData = Self.generateThumbnailData(videoName)
        
    }
    
    var videoThumbImage: Image? {
        guard let videoThumbData, let uiImage = UIImage(data: videoThumbData) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    private static func generateThumbnailData(_ videoName: String) -> Data? {
        final class ThumbnailDataBox: @unchecked Sendable {
            var data: Data?
        }

        // Step 1: Get video URL from bundle
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") else {
            print("Video file not found.")
            return nil
        }
        
        // Step 2: Create AVAsset
        let asset = AVURLAsset(url: videoURL)
        
        // Step 3: Configure image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 600, height: 400)
        
        // Step 4: Generate thumbnail at 1 second
        let time = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
        let box = ThumbnailDataBox()
        let semaphore = DispatchSemaphore(value: 0)
        
        imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
            defer { semaphore.signal() }

            if let error {
                print("Thumbnail generation error: \(error)")
                return
            }

            guard let cgImage else {
                return
            }

            let thumbnail = UIImage(cgImage: cgImage)
            box.data = thumbnail.jpegData(compressionQuality: 0.85)
        }

        semaphore.wait()
        return box.data
    }
}
