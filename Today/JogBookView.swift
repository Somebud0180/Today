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
    @State var selectedMonthYear: Date = Calendar.current.dateComponents([.year, .month], from: Date()).date ?? Date()
    @State var selectedDay: Date? = nil
    
    let cardSize: CGSize = CGSize(width: 120, height: 200)
    
    var body: some View {
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthYear) ?? Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonthYear) ?? Date()
        
        NavigationStack {
            VStack {
                Text(selectedMonthYear.formatted(.dateTime.month(.wide).year()))
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack {
                    Button(action: {
                        withAnimation(.snappy) {
                            selectedMonthYear = previousMonth
                        }
                    }, label: {
                        Label(previousMonth.formatted(.dateTime.month(.wide)), systemImage: "chevron.left")
                            .font(.title3)
                            .padding(.horizontal, 8)
                    })
                    .buttonStyle(.glass)
                    .font(.title3)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.snappy) {
                            selectedMonthYear = nextMonth
                        }
                    }, label: {
                        Label(nextMonth.formatted(.dateTime.month(.wide)), systemImage: "chevron.right")
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
                    Text("You have logged \(entryCount(for: selectedMonthYear, granularity: .month)) journal entries this \(selectedMonthYear.formatted(.dateTime.month(.wide))).")
                        .font(.headline)
                    
                    Divider()
                    
                    entryPreview
                }
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
        GlassEffectContainer {
            LazyVGrid(columns: calendarGridColumn, spacing: 12) {
                let daysInCurrentMonth = Calendar.current.range(of: .day, in: .month, for: selectedMonthYear)?.count ?? 30
                let startOfselectedMonthYear = Calendar.current.dateComponents([.year, .month], from: selectedMonthYear)
                
                ForEach(0..<daysInCurrentMonth, id: \.self) { index in
                    let indexDate = Calendar.current.date(byAdding: .day, value: index, to: Calendar.current.date(from: startOfselectedMonthYear)!)!
                    
                    Button(action: {
                        withAnimation(.snappy) {
                            selectedDay = selectedDay == indexDate ? nil : indexDate
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    private var entryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            let dateString = selectedDay != nil ? selectedDay!.formatted(.dateTime.day().month(.wide).year()) : selectedMonthYear.formatted(.dateTime.month(.wide).year())
            
            let entriesForSelected = journalEntries.filter { entry in
                if let selectedDay {
                    Calendar.current.isDate(entry.date, inSameDayAs: selectedDay)
                } else {
                    Calendar.current.isDate(entry.date, equalTo: selectedMonthYear, toGranularity: .month)
                }
            }
            
            Group {
                Text("\(dateString)'s entries")
                    .font(.title)
                
                if !entriesForSelected.isEmpty, let selectedDay {
                    Text("You have \(entryCount(for: selectedDay, granularity: .day)) entries on \(selectedDay.formatted(.dateTime.day().month(.wide).year()))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
                .contentTransition(.numericText())
            
            if entriesForSelected.isEmpty {
                emptyCarouselText
            } else {
                entryCarousel(for: entriesForSelected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var emptyCarouselText: some View {
        var messageString: String {
            if let selectedDay {
                return "You have \(entryCount(for: selectedDay, granularity: .day)) entries on \(selectedDay.formatted(.dateTime.day().month(.wide).year()))"
            } else {
                return "No entries for this date."
            }
        }
        
        return Text(messageString)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: 200, alignment: .center)
    }
        
    private func entryCarousel(for entries: [JournalEntry]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(entries) { entry in
                    GridCardView(for: entry, size: cardSize)
                }
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
