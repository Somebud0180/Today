import Foundation
import Testing
import SwiftData
@testable import Today

@MainActor
struct TodayTests {
    @Test func searchMatchesTitleTranscriptAndDate() {
        let entry = JournalEntry(title: "Family Picnic", transcript: "We visited the botanical garden")
        #expect(entry.matchesSearch("picnic"))
        #expect(entry.matchesSearch("BOTANICAL"))
        #expect(entry.matchesSearch(entry.date.formatted(date: .numeric, time: .omitted)))
        #expect(entry.matchesSearch("   "))
        #expect(!entry.matchesSearch("unrelated"))
    }

    @Test func narrowGridRespectsMinimumCardWidth() {
        #expect(GridSizing.columnCount(width: 300, minimum: 120, spacing: 16) == 2)
        #expect(GridSizing.columnCount(width: 300, minimum: 240, spacing: 16) == 1)
        #expect(GridSizing.columnCount(width: 0, minimum: 120, spacing: 16) == 1)
    }

    @Test func playbackResumesOnlyWhenPreviouslyPlayingAndVisible() {
        var lifecycle = PlaybackLifecycle()
        lifecycle.interrupt(wasPlaying: false)
        let resumed1 = lifecycle.resumeIfNeeded()
        #expect(!resumed1)
        lifecycle.interrupt(wasPlaying: true)
        let resumed2 = lifecycle.resumeIfNeeded()
        #expect(resumed2)
        let resumed3 = lifecycle.resumeIfNeeded()
        #expect(!resumed3)
        lifecycle.interrupt(wasPlaying: true)
        lifecycle.setVisible(false)
        lifecycle.setVisible(true)
        let resumed4 = lifecycle.resumeIfNeeded()
        #expect(!resumed4)
    }

    @Test func skippingTodayPreservesTomorrowAcrossYearBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 10)))
        let time = try #require(calendar.date(bySettingHour: 20, minute: 30, second: 0, of: now))
        let dates = NotificationsManager.reminderDates(time: time, now: now, skipToday: true, calendar: calendar)
        #expect(dates.count == 59)
        let first = try #require(dates.first)
        #expect(calendar.component(.day, from: first) == 1)
        #expect(calendar.component(.year, from: first) == 2027)
        #expect(calendar.component(.hour, from: first) == 20)
        #expect(!dates.contains { calendar.isDate($0, inSameDayAs: now) })
    }

    @Test func localMediaRemainsResolvableWhenCloudReturns() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let local = root.appendingPathComponent("local")
        let cloud = root.appendingPathComponent("cloud")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        let source = local.appendingPathComponent("recording.m4a")
        try Data([1, 2, 3]).write(to: source)
        #expect(MediaStore.resolve("recording.m4a", local: local, cloud: cloud) == source)
        #expect(MediaStore.resolve("recording.m4a", local: local, cloud: nil) == source)
        #expect(MediaStore.resolve("remote.m4a", local: local, cloud: cloud) == cloud.appendingPathComponent("remote.m4a"))
    }

    @Test func identicalExportTitlesHaveIndependentDestinations() throws {
        let first = try ExportNaming.makeDirectory()
        let second = try ExportNaming.makeDirectory()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let name = ExportNaming.safeName("Day / night") + ".m4a"
        try Data([1]).write(to: first.appendingPathComponent(name))
        try Data([2]).write(to: second.appendingPathComponent(name))
        #expect(first != second)
        #expect(try Data(contentsOf: first.appendingPathComponent(name)) == Data([1]))
        #expect(!name.contains("/"))
    }

    @Test func existingJournalStoreMigratesWithoutLosingEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journal.store")
        try autoreleasepool {
            let legacy = try ModelContainer(for: JournalEntry.self,
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            legacy.mainContext.insert(JournalEntry(title: "Existing journal", note: "Preserve this note"))
            try legacy.mainContext.save()
        }
        let migrated = try ModelContainer(for: JournalEntry.self, MediaDeletion.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let entries = try migrated.mainContext.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.note == "Preserve this note")
        #expect(try migrated.mainContext.fetchCount(FetchDescriptor<MediaDeletion>()) == 0)
    }

    @Test func missingRecordingDoesNotInsertAnEntry() async throws {
        let container = try ModelContainer(for: JournalEntry.self, MediaDeletion.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        do {
            _ = try await JournalStore.saveRecording(source: URL(fileURLWithPath: "/missing-\(UUID()).m4a"),
                title: "Draft", note: "Keep me", transcript: "", mediaType: .audio, waveform: nil, context: context)
            Issue.record("Expected missing source to fail")
        } catch { }
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
    }

    @Test func failedPersistencePreservesDraftAndRemovesImportedCopy() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).m4a")
        try Data([9, 8, 7]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let container = try ModelContainer(for: JournalEntry.self, MediaDeletion.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var importedURL: URL?
        do {
            _ = try await JournalStore.saveRecording(source: source, title: "Draft", note: "Keep this note",
                transcript: "", mediaType: .audio, waveform: nil, context: context, persist: { context in
                    importedURL = try context.fetch(FetchDescriptor<JournalEntry>()).first?.mediaURL
                    throw CocoaError(.fileWriteOutOfSpace)
                })
            Issue.record("Expected a persistence failure")
        } catch { }
        #expect(try Data(contentsOf: source) == Data([9, 8, 7]))
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        let copied = try #require(importedURL)
        #expect(!FileManager.default.fileExists(atPath: copied.path))
    }

    @Test func savedRecordingSurvivesDraftRemovalAndDeletionCleansUp() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).m4a")
        try Data([1, 2, 3, 4]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let container = try ModelContainer(for: JournalEntry.self, MediaDeletion.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let entry = try await JournalStore.saveRecording(source: source, title: "Recording", note: "Note",
            transcript: "", mediaType: .audio, waveform: nil, context: context)
        let saved = try #require(entry.mediaURL)
        try FileManager.default.removeItem(at: source)
        #expect(try Data(contentsOf: saved) == Data([1, 2, 3, 4]))
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 1)
        try await JournalStore.delete([entry], context: context)
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: saved.path))
        #expect(try context.fetchCount(FetchDescriptor<MediaDeletion>()) == 1)
    }

    @Test func cancelledThumbnailDoesNotContinuePolling() async {
        let task = Task {
            try Task.checkCancellation()
            return try await ThumbnailLoader.shared.image(filename: "missing-thumb.jpg", pixelSize: 128)
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func waveformPreviewUsesCenterAndHandlesEmptySamples() async throws {
        let waveform = CodableAudioWaveform(samplesDb: [], samplesLinear: [0, 1, 2, 3, 4, 5], sampleRateHz: 1, duration: 6)
        let data = try JSONEncoder().encode(waveform)
        let levels = try await ThumbnailLoader.shared.waveform(id: UUID(), data: data, maxBars: 2)
        #expect(levels == [2, 3])
    }
}
