//
//  ExportView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/4/26.
//

import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    
    @State var includedIndex: Int = 2
    @State var timeframeIndex: Int = 0
    @State var timeframeCustomBegin: Date = Date().addingTimeInterval(-7 * 24 * 60 * 60)
    @State var timeframeCustomEnd: Date = Date()
    @State var organizationIndex: Int = 0
    @State var groupingIndex: Int = 0
    @State var showExportConfirmation: Bool = false
    
    // Grouping formatters
    var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }
    
    var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df
    }
    
    var yearFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Image(systemName: "square.and.arrow.up.on.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .offset(x: -2)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 64, height: 64)
                            )
                            .frame(width: 64, height: 64)

                        Text("Export")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose how you prefer your entries to be exported. You can select multiple organizations, and your export will be prepared accordingly.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("What's included"), footer: Text("Pick which entries and parts you want to export. You can choose to include either media and notes")) {
                    Picker("Include", selection: $includedIndex) {
                        Text("Media only").tag(0)
                        Text("Notes only").tag(1)
                        Text("Both media and notes").tag(2)
                    }
                    
                    Picker("From", selection: $timeframeIndex) {
                        Text("All time").tag(0)
                        Text("This year").tag(1)
                        Text("This month").tag(2)
                        Text("This week").tag(3)
                        Text("Custom").tag(4)
                    }
                    
                    Group {
                        if timeframeIndex == 4 {
                            DatePicker("Start date", selection: $timeframeCustomBegin, displayedComponents: [.date])
                            
                            DatePicker("End date", selection: $timeframeCustomEnd, displayedComponents: [.date])
                        }
                    }
                    .transition(.push(from: .top))
                }
                
                if includedIndex == 2 {
                    Section(header: Text("Organization"), footer: Text("Create a folder per entry? Or group all media together and all notes together?")) {
                        Picker("Organize by", selection: $organizationIndex) {
                            Text("One folder per entry").tag(0)
                            Text("Group media and notes").tag(1)
                        }
                    }
                }
                
                Section(header: Text("Grouping"), footer: Text("How do you want your export grouped? By day, week, month, or year?")) {
                    Picker("Group by", selection: $groupingIndex) {
                        Text("Day").tag(0)
                        Text("Month").tag(1)
                        Text("Year").tag(2)
                    }
                }
                
                Section(header: Text("Preview & Export")) {
                    VStack(spacing: 12) {
                        NavigationLink {
                            NavigationStack {
                                Form {
                                    NavigationLink {
                                        NavigationStack {
                                            Form {
                                                Text("Notes.txt")
                                                Text("Media.mov")
                                            }
                                        }
                                    } label: {
                                        Text("May 30, 2026")
                                    }
                                    
                                    NavigationLink {
                                        NavigationStack {
                                            Form {
                                                Text("Notes.txt")
                                                Text("Media.mov")
                                            }
                                        }
                                    } label: {
                                        Text("May 31, 2026")
                                    }
                                }
                            }
                        } label: {
                            Text("May 2026")
                        }
                        
                        Divider()
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                        
                        NavigationLink {
                            
                        } label: {
                            Text("June 2026")
                        }
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    }
                    
                    Button("Export") {
                        showExportConfirmation = true
                    }
                    .padding(.leading, 2)
                }
            }
            .navigationTitle("Export Journal")
            .transition(.slide)
            .animation(.easeInOut(duration: 0.3), value: includedIndex)
            .animation(.easeInOut(duration: 0.3), value: timeframeIndex)
            .animation(.easeInOut(duration: 0.3), value: organizationIndex)
            .animation(.easeInOut(duration: 0.3), value: groupingIndex)
            .alert("Are you sure with your export choices?", isPresented: $showExportConfirmation, actions: {
                Button("Yes, export") {
                    exportEntries()
                }
                Button("Cancel", role: .cancel) {}
            })
        }
    }
    
    private func safeName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return raw.components(separatedBy: invalid).joined(separator: "_")
    }
    
    private func groupKey(for date: Date) -> String {
        switch groupingIndex {
        case 1: return monthFormatter.string(from: date)
        case 2: return yearFormatter.string(from: date)
        default: return dayFormatter.string(from: date)
        }
    }
    
    private func exportEntries() {
        let calendar = Calendar.current
        let now = Date()

        // Determine date range
        var startDate: Date? = nil
        var endDate: Date? = nil
        switch timeframeIndex {
        case 1: // This year
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(year: 1, second: -1), to: $0) }
        case 2: // This month
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(month: 1, second: -1), to: $0) }
        case 3: // This week
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(day: 7, second: -1), to: $0) }
        case 4: // Custom
            startDate = calendar.startOfDay(for: timeframeCustomBegin)
            endDate = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: timeframeCustomEnd))
        default:
            break // All time
        }

        // Filter entries
        let filtered = journalEntries.filter { entry in
            let d = entry.date
            if let s = startDate, d < s { return false }
            if let e = endDate, d > e { return false }
            return true
        }

        // Prepare export root
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let exportRoot = URL.documentsDirectory.appendingPathComponent("Today-Archive-\(df.string(from: now))", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        } catch {
            print("Export: failed to create root folder: \(error)")
            return
        }

        let entriesByGroup = Dictionary(grouping: filtered) { entry in groupKey(for: entry.date) }

        for (group, entries) in entriesByGroup.sorted(by: { $0.key < $1.key }) {
            let groupFolder = exportRoot.appendingPathComponent(group, isDirectory: true)
            do { try FileManager.default.createDirectory(at: groupFolder, withIntermediateDirectories: true) } catch {
                print("Export: failed to create group folder: \(error)")
                continue
            }

            if organizationIndex == 1 {
                // Group media/notes at group level
                let notesFolder = groupFolder.appendingPathComponent("Notes", isDirectory: true)
                let mediaFolder = groupFolder.appendingPathComponent("Media", isDirectory: true)
                do {
                    if includedIndex != 0 { try FileManager.default.createDirectory(at: notesFolder, withIntermediateDirectories: true) }
                    if includedIndex != 1 { try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true) }
                } catch { print("Export: failed to create grouped subfolders: \(error)") }

                for entry in entries {
                    let baseTitle = entry.title.isEmpty ? "Untitled" : entry.title
                    let baseName = safeName("\(dayFormatter.string(from: entry.date)) - \(baseTitle)")

                    if includedIndex != 1 {
                        if let srcURL = entry.mediaURL {
                            // Ensure file is local if in iCloud
                            _ = MediaStore.downloadIfNeeded(at: srcURL)
                            let ext = srcURL.pathExtension.isEmpty ? (entry.mediaType == .audio ? "m4a" : "mov") : srcURL.pathExtension
                            var destURL = mediaFolder.appendingPathComponent("\(baseName).\(ext)")
                            var attempt = 2
                            while FileManager.default.fileExists(atPath: destURL.path) {
                                destURL = mediaFolder.appendingPathComponent("\(baseName) (\(attempt)).\(ext)")
                                attempt += 1
                            }
                            do { try FileManager.default.copyItem(at: srcURL, to: destURL) } catch { print("Export: failed to copy media: \(error)") }
                        }
                    }

                    if includedIndex != 0 {
                        let text = entry.note
                        let noteURL = notesFolder.appendingPathComponent("\(baseName).txt")
                        do { try text.data(using: .utf8)?.write(to: noteURL) } catch { print("Export: failed to write note: \(error)") }
                    }
                }
            } else {
                // One folder per entry
                for entry in entries {
                    let baseTitle = entry.title.isEmpty ? "Untitled" : entry.title
                    let entryFolderName = safeName("\(dayFormatter.string(from: entry.date)) - \(baseTitle)")
                    let entryFolder = groupFolder.appendingPathComponent(entryFolderName, isDirectory: true)
                    do { try FileManager.default.createDirectory(at: entryFolder, withIntermediateDirectories: true) } catch { print("Export: failed to create entry folder: \(error)"); continue }

                    if includedIndex != 1 {
                        if let srcURL = entry.mediaURL {
                            _ = MediaStore.downloadIfNeeded(at: srcURL)
                            let mediaFolder = entryFolder.appendingPathComponent("Media", isDirectory: true)
                            do { try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true) } catch { print("Export: failed to create media folder: \(error)") }
                            let ext = srcURL.pathExtension.isEmpty ? (entry.mediaType == .audio ? "m4a" : "mov") : srcURL.pathExtension
                            var destURL = mediaFolder.appendingPathComponent("Media.\(ext)")
                            var attempt = 2
                            while FileManager.default.fileExists(atPath: destURL.path) {
                                destURL = mediaFolder.appendingPathComponent("Media (\(attempt)).\(ext)")
                                attempt += 1
                            }
                            do { try FileManager.default.copyItem(at: srcURL, to: destURL) } catch { print("Export: failed to copy media: \(error)") }
                        }
                    }

                    if includedIndex != 0 {
                        let text = entry.note
                        let noteURL = entryFolder.appendingPathComponent("Notes.txt")
                        do { try text.data(using: .utf8)?.write(to: noteURL) } catch { print("Export: failed to write note: \(error)") }
                    }
                }
            }
        }

        print("Export complete at: \(exportRoot.path)")
    }
}

#Preview {
    ExportView()
        .modelContainer(for: JournalEntry.self)
}
