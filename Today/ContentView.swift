//
//  ContentView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/6/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    
    @State var tabSelection: Int = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "note", value: 0) {
                HomeView()
            }
            
            Tab("Create Entry", systemImage: "note.text.badge.plus", value: 1) {
                CreateView(tabSelection: $tabSelection)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntries.self, JournalEntry.self], inMemory: true)
}
