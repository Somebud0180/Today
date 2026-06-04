//
//  ContentView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/6/26.
//

import SwiftUI
import SwiftData

struct DefaultSettings {
    static let preferredColorTheme: PreferredColorScheme = .system
    static let enableNotifications: Bool = true
    static let autoPlayOnOpen: Bool = false
    static let remindMeToJournal: Bool = true
    static let reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var journalEntries: [JournalEntry]
    
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("enableNotifications") private var enableNotifications: Bool = DefaultSettings.enableNotifications
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen: Bool =
        DefaultSettings.autoPlayOnOpen
    @AppStorage("remindMeToJournal") private var remindMeToJournal: Bool
        = DefaultSettings.remindMeToJournal
    @AppStorage("reminderTime") private var reminderTime: Date =
        DefaultSettings.reminderTime
    
    @State var tabSelection: Int = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "note", value: 0) {
                HomeView()
                    .preferredColorScheme(preferredColorScheme.colorScheme)
            }
            
            Tab("Create Entry", systemImage: "note.text.badge.plus", value: 1) {
                CreateView(tabSelection: $tabSelection)
                    .preferredColorScheme(preferredColorScheme.colorScheme)
            }
            
            Tab("Settings", systemImage: "gearshape", value: 2) {
                SettingsView()
                    .preferredColorScheme(preferredColorScheme.colorScheme)
            }
        }
    }
}

extension Color {
    var light: Self {
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        return Color(resolve(in: environment))
    }
    
    var dark: Self {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        return Color(resolve(in: environment))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntry.self], inMemory: true)
}
