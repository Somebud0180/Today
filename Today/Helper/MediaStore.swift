//
//  MediaStore.swift
//  Today
//
//  Created by automated change on 2026-05-13.
//

import Foundation

nonisolated struct MediaStore {
    private static let mediaFolderName = "TodayMedia"
    private static let thumbnailSuffix = "-thumb.jpg"
    private static let icloudContainerID = "iCloud.com.lagera.Today"
    
    static func localDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: Bundle.main.bundleIdentifier ?? "Today", directoryHint: .isDirectory)
            .appending(path: mediaFolderName, directoryHint: .isDirectory)
    }

    static func cloudDirectory() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: icloudContainerID)?
            .appending(path: mediaFolderName, directoryHint: .isDirectory)
    }

    private static func mediaDirectory() -> URL? {
        let directory = localDirectory()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch { return nil }
    }

    /// Prefer an available local copy, but retain cloud placeholders for downloading.
    static func resolve(_ filename: String, local: URL, cloud: URL?) -> URL {
        let localURL = local.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: localURL.path) { return localURL }
        return cloud?.appendingPathComponent(filename) ?? localURL
    }

    static func importRecording(from source: URL, filename: String) throws -> URL {
        let directory = localDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        do { try FileManager.default.copyItem(at: source, to: destination) }
        catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return destination
    }

    /// Copy local saves to iCloud without removing the playable local originals.
    /// Failed uploads remain local and are retried on the next foreground transition.
    static func synchronize(excluding deleted: Set<String> = []) throws {
        guard let cloud = cloudDirectory() else { return }
        let local = localDirectory()
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        for source in try FileManager.default.contentsOfDirectory(at: local, includingPropertiesForKeys: nil)
            where !source.lastPathComponent.hasPrefix(".") && !deleted.contains(source.lastPathComponent) {
            let destination = cloud.appendingPathComponent(source.lastPathComponent)
            let placeholder = cloud.appendingPathComponent(".\(source.lastPathComponent).icloud")
            guard !FileManager.default.fileExists(atPath: destination.path),
                  !FileManager.default.fileExists(atPath: placeholder.path) else { continue }
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(writingItemAt: destination, options: [], error: &coordinationError) { url in
                do { try FileManager.default.copyItem(at: source, to: url) }
                catch { copyError = error }
            }
            if let error = coordinationError ?? (copyError as NSError?) { throw error }
        }
    }

    static func removeFiles(_ filenames: [String]) throws {
        for directory in [localDirectory(), cloudDirectory()].compactMap({ $0 }) {
            for filename in filenames {
                let url = directory.appendingPathComponent(filename)
                let placeholder = directory.appendingPathComponent(".\(filename).icloud")
                guard FileManager.default.fileExists(atPath: url.path) || FileManager.default.fileExists(atPath: placeholder.path) else { continue }
                var coordinationError: NSError?
                var removalError: Error?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
                    do { try FileManager.default.removeItem(at: target) }
                    catch { removalError = error }
                }
                if let error = coordinationError ?? (removalError as NSError?) { throw error }
            }
        }
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
        guard !fileName.isEmpty else { return nil }
        let filename = URL(string: fileName).flatMap { $0.scheme != nil ? $0.lastPathComponent : nil } ?? fileName
        return resolve(filename, local: localDirectory(), cloud: cloudDirectory())
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
