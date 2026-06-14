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
    static let autoPlayOnOpen: Bool = false
    static let remindMeToJournal: Bool = true
    static let reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    static let enableTranscription: Bool = false
    static let transcribeOnSave: Bool = false
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var journalEntries: [JournalEntry]
    
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    
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
            
            Tab("Jog Book", systemImage: "ellipsis.calendar", value: 2) {
                JogBookView()
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
        .modelContainer(for: JournalEntry.self)
}
