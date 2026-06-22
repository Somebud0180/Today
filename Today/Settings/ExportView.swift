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
    @State private var isExporting: Bool = false
    
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
        var exportImage: String {
            if organizationIndex == 1 {
                switch includedIndex {
                case 0: return "ExportM"
                case 1: return "ExportN"
                default: return "ExportMN"
                }
            } else {
                switch groupingIndex {
                case 0: return "ExportGroupD"
                case 1: return "ExportGroupM"
                default: return "ExportGroupY"
                }
            }
        }
        
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
                
                Section(header: Text("Folder Structure")) {
                    if includedIndex == 2 {
                        VStack(alignment: .leading) {
                            Text("Organize by")
                            Text("Group media and notes into one folder or group media and notes separately?")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            Picker("", selection: $organizationIndex) {
                                Text("Group by date").tag(0) // Scenario B
                                Text("Group media and notes").tag(1) // Scenario A
                            }
                            .pickerStyle(.palette)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Group by")
                        Text("How do you want your files grouped? By day, month, or year?")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        
                        Picker("", selection: $groupingIndex) {
                            Text("Day").tag(0)
                            Text("Month").tag(1)
                            Text("Year").tag(2)
                        }
                        .pickerStyle(.palette)
                    }
                }
                
                Section(header: Text("Preview & Export"), footer: Text("You can find your export in the app's folder in the Files app")) {
                    VStack(spacing: 6) {
                        Image("ExportBackground")
                            .resizable()
                            .scaledToFit()
                            .overlay(
                                Image(exportImage)
                                    .resizable()
                                    .scaledToFit()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Text("Your export will look something like this")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        showExportConfirmation = true
                    }) {
                        HStack {
                            Text(isExporting ? "Exporting..." : "Export")
                            if isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting)
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
                    Task {
                        isExporting = true
                        await exportEntries()
                        isExporting = false
                    }
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
    
    /// Async helper to pause execution until an iCloud file is downloaded locally
    private func ensureLocalDownload(at url: URL) async -> Bool {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do { try fm.startDownloadingUbiquitousItem(at: url) } catch { return false }
        }
        
        // Poll for up to 30 seconds to wait for iCloud download
        for _ in 0..<30 {
            if let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
               values.ubiquitousItemDownloadingStatus == .current {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        return false
    }
    
    private func exportEntries() async {
        let calendar = Calendar.current
        let now = Date()
        
        var startDate: Date? = nil
        var endDate: Date? = nil
        switch timeframeIndex {
        case 1:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(year: 1, second: -1), to: $0) }
        case 2:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(month: 1, second: -1), to: $0) }
        case 3:
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            endDate = startDate.flatMap { calendar.date(byAdding: DateComponents(day: 7, second: -1), to: $0) }
        case 4:
            startDate = calendar.startOfDay(for: timeframeCustomBegin)
            endDate = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: timeframeCustomEnd))
        default: break
        }
        
        // Filter entries
        let filtered = journalEntries.filter { entry in
            let d = entry.date
            if let s = startDate, d < s { return false }
            if let e = endDate, d > e { return false }
            return true
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let exportRoot = URL.documentsDirectory.appendingPathComponent("Today-Export_\(df.string(from: now))", isDirectory: true)
        
        do { try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true) }
        catch { print("Export: failed to create root folder: \(error)"); return }
        
        let entriesByGroup = Dictionary(grouping: filtered) { entry in groupKey(for: entry.date) }
        
        for (group, entries) in entriesByGroup.sorted(by: { $0.key < $1.key }) {
            
            if organizationIndex == 1 {
                // Group media and notes
                // Root -> Media -> [Day/Month/Year] -> Files
                let mediaGroupFolder = exportRoot.appendingPathComponent("Media").appendingPathComponent(group)
                let notesGroupFolder = exportRoot.appendingPathComponent("Notes").appendingPathComponent(group)
                
                do {
                    if includedIndex != 0 { try FileManager.default.createDirectory(at: notesGroupFolder, withIntermediateDirectories: true) }
                    if includedIndex != 1 { try FileManager.default.createDirectory(at: mediaGroupFolder, withIntermediateDirectories: true) }
                } catch { print("Export: failed to create grouped subfolders: \(error)") }
                
                for entry in entries {
                    let baseTitle = entry.title.isEmpty ? "Untitled" : safeName(entry.title)
                    let baseName = safeName("\(dayFormatter.string(from: entry.date)) - \(baseTitle)")
                    
                    if includedIndex != 1, let srcURL = entry.mediaURL {
                        _ = await ensureLocalDownload(at: srcURL)
                        let ext = srcURL.pathExtension.isEmpty ? (entry.mediaType == .audio ? "m4a" : "mov") : srcURL.pathExtension
                        var destURL = mediaGroupFolder.appendingPathComponent("\(baseName).\(ext)")
                        var attempt = 2
                        while FileManager.default.fileExists(atPath: destURL.path) {
                            destURL = mediaGroupFolder.appendingPathComponent("\(baseName) (\(attempt)).\(ext)")
                            attempt += 1
                        }
                        do { try FileManager.default.copyItem(at: srcURL, to: destURL) } catch { print("Export copy media error: \(error)") }
                    }
                    
                    if includedIndex != 0 {
                        let noteURL = notesGroupFolder.appendingPathComponent("\(baseName).txt")
                        do { try entry.note.data(using: .utf8)?.write(to: noteURL) } catch { print("Export write note error: \(error)") }
                    }
                }
            } else {
                // Group by date
                // Root -> [Day/Month/Year] -> Files (Media and notes side-by-side)
                let groupFolder = exportRoot.appendingPathComponent(group)
                do { try FileManager.default.createDirectory(at: groupFolder, withIntermediateDirectories: true) }
                catch { print("Export: failed to create flat group folder: \(error)"); continue }
                
                for entry in entries {
                    let baseTitle = entry.title.isEmpty ? "Untitled" : safeName(entry.title)
                    let baseName = safeName("\(dayFormatter.string(from: entry.date)) - \(baseTitle)")
                    
                    if includedIndex != 1, let srcURL = entry.mediaURL {
                        _ = await ensureLocalDownload(at: srcURL)
                        let ext = srcURL.pathExtension.isEmpty ? (entry.mediaType == .audio ? "m4a" : "mov") : srcURL.pathExtension
                        var destURL = groupFolder.appendingPathComponent("\(baseName).\(ext)")
                        var attempt = 2
                        while FileManager.default.fileExists(atPath: destURL.path) {
                            destURL = groupFolder.appendingPathComponent("\(baseName) (\(attempt)).\(ext)")
                            attempt += 1
                        }
                        do { try FileManager.default.copyItem(at: srcURL, to: destURL) } catch { print("Export copy media error: \(error)") }
                    }
                    
                    if includedIndex != 0 {
                        let noteURL = groupFolder.appendingPathComponent("\(baseName).txt")
                        do { try entry.note.data(using: .utf8)?.write(to: noteURL) } catch { print("Export write note error: \(error)") }
                    }
                }
            }
        }
        
        print("Export complete at: \(exportRoot.path)")
    }
}
