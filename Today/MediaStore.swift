//
//  MediaStore.swift
//  Today
//
//  Created by automated change on 2026-05-13.
//

import Foundation

struct MediaStore {
    private static let mediaFolderName = "TodayMedia"
    private static let thumbnailSuffix = "-thumb.jpg"

    /// Returns the base media directory. Prefer ubiquity container; fallback to Application Support.
    private static func mediaDirectory() -> URL? {
        let fm = FileManager.default

        // Try ubiquity container first (iCloud Drive / app container)
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
            let dir = ubiquity.appendingPathComponent(mediaFolderName, isDirectory: true)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            } catch {
                print("Failed to create ubiquity media directory: \(error)")
                // fall through to fallback
            }
        }

        // Fallback: Application Support/<bundle-id>/Media
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let bundleID = Bundle.main.bundleIdentifier ?? "Today"
            let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent(mediaFolderName, isDirectory: true)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            } catch {
                print("Failed to create Application Support media directory: \(error)")
                return nil
            }
        }

        return nil
    }

    /// Synchronously saves media data to the chosen media directory using a UUID-based filename.
    /// Returns the file URL on success.
    static func saveMedia(data: Data, fileExtension: String, entryID: UUID) -> URL? {
        guard let dir = mediaDirectory() else { return nil }

        let filename = "\(entryID.uuidString).\(fileExtension)"
        let url = dir.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("MediaStore: failed to write media file: \(error)")
            return nil
        }
    }

    /// Synchronously saves thumbnail data to the chosen media directory.
    static func saveThumbnail(data: Data, entryID: UUID) -> URL? {
        guard let dir = mediaDirectory() else { return nil }

        let filename = "\(entryID.uuidString)\(thumbnailSuffix)"
        let url = dir.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("MediaStore: failed to write thumbnail: \(error)")
            return nil
        }
    }

    /// Delete a media file at the given URL
    static func deleteMedia(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("MediaStore: failed to delete media at \(url): \(error)")
        }
    }

    /// Delete thumbnail for a given entry id (if present)
    static func deleteThumbnail(entryID: UUID) {
        guard let dir = mediaDirectory() else { return }
        let url = dir.appendingPathComponent("\(entryID.uuidString)\(thumbnailSuffix)")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("MediaStore: failed to delete thumbnail at \(url): \(error)")
            }
        }
    }
}
