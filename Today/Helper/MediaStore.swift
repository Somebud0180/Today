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
    private static let icloudContainerID = "iCloud.com.lagera.Today"
    
    /// Returns the base media directory. Prefer ubiquity container; fallback to Application Support.
    private static func mediaDirectory() -> URL? {
        let fm = FileManager.default
        
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: icloudContainerID) {
            let dir = ubiquity.appending(path: mediaFolderName, directoryHint: .isDirectory)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            } catch {
                print("Failed to create ubiquity media directory: \(error)")
            }
        } else {
            print("iCloud container '\(icloudContainerID)' is temporarily unavailable. Using local fallback.")
        }
        
        // Fallback: Application Support/<bundle-id>/Media
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let bundleID = Bundle.main.bundleIdentifier ?? "Today"
            let dir = appSupport.appending(path: bundleID, directoryHint: .isDirectory).appending(path: mediaFolderName, directoryHint: .isDirectory)
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
        
        let fileName = "\(entryID.uuidString).\(fileExtension)"
        let url = dir.appending(path: fileName, directoryHint: .notDirectory)
        
        // Coordinate the write operation to alert the system's iCloud daemon
        let coordinator = NSFileCoordinator()
        var writeError: NSError?
        var success = false
        
        coordinator.coordinate(writingItemAt: url, options: [], error: &writeError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                success = true
            } catch {
                print("MediaStore: failed to write media file: \(error)")
            }
        }
        
        if let writeError {
            print("File coordination error during save: \(writeError)")
            return nil
        }
        
        return success ? url : nil
    }

    /// Synchronously saves thumbnail data to the chosen media directory.
    static func saveThumbnail(data: Data, entryID: UUID) -> URL? {
        guard let dir = mediaDirectory() else { return nil }

        let fileName = "\(entryID.uuidString)\(thumbnailSuffix)"
        let url = dir.appending(path: fileName, directoryHint: .notDirectory)

        // Coordinate the write operation to alert the system's iCloud daemon
        let coordinator = NSFileCoordinator()
        var writeError: NSError?
        var success = false
        
        coordinator.coordinate(writingItemAt: url, options: [], error: &writeError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                success = true
            } catch {
                print("MediaStore: failed to write media file: \(error)")
            }
        }
        
        if let writeError {
            print("File coordination error during save: \(writeError)")
            return nil
        }
        
        return success ? url : nil
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
        let url = dir.appending(path: "\(entryID.uuidString)\(thumbnailSuffix)", directoryHint: .notDirectory)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("MediaStore: failed to delete thumbnail at \(url): \(error)")
            }
        }
    }

    /// Resolve a stored media filename to an absolute file URL in the current media directory.
    /// Filenames are kept stable; paths are resolved dynamically so stored values remain valid across container moves.
    static func urlForMediaFilename(_ fileName: String) -> URL? {
        guard !fileName.isEmpty, let dir = mediaDirectory() else { return nil }
        return dir.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Delete a media file by its stored filename.
    static func deleteMedia(filename: String) {
        guard let url = urlForMediaFilename(filename) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("MediaStore: failed to delete media at \(url): \(error)")
            }
        }
    }
    
    /// Checks if a file is stored locally or needs downloading from iCloud.
    static func downloadIfNeeded(at url: URL) -> Bool {
        let fm = FileManager.default
        
        // If it doesn't even exist at the path, it might be an un-downloaded iCloud placeholder
        if !fm.fileExists(atPath: url.path) {
            // Check if a hidden placeholder file exists (.filename.icloud)
            let directory = url.deletingLastPathComponent()
            let placeholderURL = directory.appending(path: ".\(url.lastPathComponent).icloud", directoryHint: .notDirectory)
            
            if fm.fileExists(atPath: placeholderURL.path) {
                do {
                    try fm.startDownloadingUbiquitousItem(at: url)
                } catch {
                    print("Failed to start iCloud download: \(error)")
                }
            }
            return false
        }
        
        // Check iCloud download status values
        do {
            let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
            if let isUbiquitous = values.isUbiquitousItem, isUbiquitous {
                if let status = values.ubiquitousItemDownloadingStatus {
                    if status == .current {
                        return true // File is local and fully downloaded
                    } else {
                        // File exists but is outdated or not downloaded yet
                        try fm.startDownloadingUbiquitousItem(at: url)
                        return false
                    }
                }
            }
        } catch {
            print("Error checking iCloud resource values: \(error)")
        }
        
        return true // Fallback assuming it's a normal local file
    }
}
