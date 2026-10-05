import Foundation
import SwiftData
import AVFoundation
import UIKit

nonisolated enum ExportNaming {
    static func safeName(_ title: String) -> String {
        let name = title.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r"))
            .joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == "." || name == ".." ? "Untitled" : String(name.prefix(120))
    }

    static func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Today-Share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// Serializes cloud copying and deferred deletion. Tombstones survive offline launches.
actor MediaMaintenance {
    static let shared = MediaMaintenance()
    private var tombstoneURL: URL { MediaStore.localDirectory().appendingPathComponent(".deleted.json") }

    private func deletedFiles() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: tombstoneURL.path) else { return [] }
        return try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: tombstoneURL))
    }

    func enqueueDeletion(_ filenames: [String]) throws {
        let deleted = try deletedFiles().union(filenames)
        try FileManager.default.createDirectory(at: MediaStore.localDirectory(), withIntermediateDirectories: true)
        try JSONEncoder().encode(deleted).write(to: tombstoneURL, options: .atomic)
        // The durable queue retries transient cloud/file-provider failures.
        try? MediaStore.removeFiles(filenames)
    }

    func run(deletions: Set<String> = []) throws {
        if !deletions.isEmpty { try enqueueDeletion(Array(deletions)) }
        let deleted = try deletedFiles()
        // Keep tombstones to retry cloud deletion when iCloud becomes available.
        try MediaStore.removeFiles(Array(deleted))
        try MediaStore.synchronize(excluding: deleted)
    }
}

@MainActor
enum JournalStore {
    static func saveRecording(source: URL, title: String, note: String, transcript: String,
                              mediaType: MediaType, waveform: CodableAudioWaveform?,
                              context: ModelContext,
                              persist: (ModelContext) throws -> Void = { try $0.save() }) async throws -> JournalEntry {
        let id = UUID()
        let ext = source.pathExtension.isEmpty ? (mediaType == .audio ? "m4a" : "mov") : source.pathExtension
        let filename = "\(id.uuidString).\(ext)"
        let isVideo = mediaType == .video
        let prepared = try await Task.detached {
            let url = try MediaStore.importRecording(from: source, filename: filename)
            do {
                let waveformData = try waveform.map { try JSONEncoder().encode($0) }
                var thumbnail: String?
                if isVideo, let data = try? await ThumbnailLoader.videoData(url: url) {
                    thumbnail = MediaStore.saveThumbnail(data: data, entryID: id)?.lastPathComponent
                }
                return (thumbnail, waveformData)
            } catch {
                try? MediaStore.removeFiles([filename, "\(id.uuidString)-thumb.jpg"])
                throw error
            }
        }.value
        let entry = JournalEntry(title: title, note: note, transcript: transcript, mediaType: mediaType,
                                 uuid: id, mediaFilename: filename, thumbnailFilename: prepared.0,
                                 waveformData: prepared.1)
        context.insert(entry)
        do { try persist(context) }
        catch {
            context.delete(entry)
            _ = try? await MediaMaintenance.shared.enqueueDeletion([filename, "\(id.uuidString)-thumb.jpg"])
            throw error
        }
        let deletions = (try? context.fetch(FetchDescriptor<MediaDeletion>())) ?? []
        let deletedFilenames = Set(deletions.flatMap(\.filenames))
        Task { try? await MediaMaintenance.shared.run(deletions: deletedFilenames) }
        return entry
    }

    static func delete(_ entries: [JournalEntry], context: ModelContext) async throws {
        // Persist existing edits first, so rollback only undoes this deletion.
        try context.save()
        let filenames = entries.flatMap { entry in
            [entry.mediaURLString, entry.thumbnailURLString].compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return URL(string: value)?.lastPathComponent ?? value
            }
        }
        for entry in entries {
            context.insert(MediaDeletion(entry: entry))
            context.delete(entry)
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        // Cleanup can retry from the durable SwiftData deletion records if storage is unavailable.
        try? await MediaMaintenance.shared.enqueueDeletion(filenames)
    }
}
