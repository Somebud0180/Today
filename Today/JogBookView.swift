//
//  JogBookView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/8/26.
//

import SwiftUI
import SwiftData

struct JogBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    @State var calendarGridColumn: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    @State var selectedMonth: Date = Date()
    @State var selectedDate: Date? = nil
    
    var body: some View {
        
        NavigationStack {
            VStack {
                HStack {
                    Button(action: {
                        
                    }, label: {
                        Label("May", systemImage: "chevron.left")
                            .font(.title3)
                            .padding(.horizontal, 8)
                    })
                    .buttonStyle(.glass)
                    .font(.title3)
                    
                    Spacer()
                    
                    Text("June")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        
                    }, label: {
                        Label("July", systemImage: "chevron.right")
                            .labelStyle(TrailingIcon())
                            .font(.title3)
                            .padding(.horizontal, 8)
                    })
                    .buttonStyle(.glass)
                    .font(.title3)
                }
                .padding(.horizontal, 16)
                
                jogGrid
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                        )
                    .aspectRatio(1, contentMode: .fill)
                
                VStack(alignment: .leading) {
                    Text("You have logged \(entryCount(for: selectedMonth, granularity: .month)) journal entries this \(selectedMonth.formatted(.dateTime.month(.wide))).")
                        .font(.headline)
                    
                    if selectedDate != nil, let selectedDate {
                        Text("You have \(entryCount(for: selectedDate, granularity: .day)) entries on \(selectedDate.formatted(.dateTime.day().month(.wide).year()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                )
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .navigationTitle("Jog Book")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var jogGrid: some View {
        LazyVGrid(columns: calendarGridColumn, spacing: 12) {
            let daysInCurrentMonth = Calendar.current.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
            let startOfSelectedMonth = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
            
            ForEach(0...daysInCurrentMonth, id: \.self) { index in
                let indexDate = Calendar.current.date(byAdding: .day, value: index, to: Calendar.current.date(from: startOfSelectedMonth)!)!
                
                Button(action: {
                    if selectedDate == indexDate {
                        selectedDate = nil
                        print("Cleared selection for \(indexDate)")
                    } else {
                        selectedDate = indexDate
                    }
                }, label: {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundStyle(hasJournalEntry(for: indexDate) ? Color.accentColor : Color.secondary)
                        .aspectRatio(1, contentMode: .fit)
                        .glassEffect(
                            .regular.interactive().tint(hasJournalEntry(for: indexDate) ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.5)),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                })
                .buttonStyle(.plain)
            }
        }
    }
        
    private func hasJournalEntry(for date: Date) -> Bool {
        return journalEntries.contains { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    private func entryCount(for date: Date, granularity: Calendar.Component) -> Int {
        return journalEntries.filter { entry in
            Calendar.current.isDate(entry.date, equalTo: date, toGranularity: granularity)
        }.count
    }
}

struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

#Preview {
    JogBookView()
        .modelContainer(for: JournalEntry.self)
}
