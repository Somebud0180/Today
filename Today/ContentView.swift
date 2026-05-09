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
    let gridRows = [GridItem(.adaptive(minimum: 150))]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridRows, spacing: 24) {
                    ForEach(journalEntries) { journalEntry in
                        NavigationLink {
                            JournalView(selectedEntry: journalEntry)
                        } label: {
                            RoundedRectangle(cornerRadius: 16)
                                .foregroundStyle(.secondary)
                                .overlay {
                                    Text(journalEntry.title.isEmpty ? journalEntry.date.formatted(date: .numeric, time: .omitted) : journalEntry.title)
                                        .fontWeight(.medium)
                                }
                        }
                        .aspectRatio(2/3, contentMode: .fit)
                    }
                }
            }
            .padding(12)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        let newEntry = JournalEntry(videoName: "example", note: "")
                        modelContext.insert(newEntry)
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntries.self, inMemory: true)
}
