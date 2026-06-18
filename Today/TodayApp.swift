//
//  TodayApp.swift
//  Today
//
//  Created by Ethan John Lagera on 5/6/26.
//

import SwiftUI
import SwiftData

@main
struct TodayApp: App {
    @StateObject private var transcriptionManager = AudioTranscriptionManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([JournalEntry.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization { _, error in
            if let error = error {
                print("Error requesting permissions: \(error)")
            }
        }
    }
}
