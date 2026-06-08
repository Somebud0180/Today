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
    
    let cardSize: CGSize = CGSize(width: 120, height: 200)
    
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
                
                entryPreview
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                    )
                    .aspectRatio(1, contentMode: .fill)

                
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
                let daysInCurrentMonth = Calendar.current.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
                let startOfSelectedMonth = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
                
                ForEach(0...daysInCurrentMonth, id: \.self) { index in
                    let indexDate = Calendar.current.date(byAdding: .day, value: index, to: Calendar.current.date(from: startOfSelectedMonth)!)!
                    
                    Button(action: {
                        withAnimation(.snappy(duration: 0.3)) {
                            selectedDate = selectedDate == indexDate ? nil : indexDate
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
    }
    
    private var entryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            let dateString = selectedDate != nil ? selectedDate!.formatted(.dateTime.day().month(.wide).year()) : selectedMonth.formatted(.dateTime.month(.wide).year())
            
            let entriesForSelected = journalEntries.filter { entry in
                if let selectedDate {
                    Calendar.current.isDate(entry.date, inSameDayAs: selectedDate)
                } else {
                    Calendar.current.isDate(entry.date, equalTo: selectedMonth, toGranularity: .month)
                }
            }
            
            Text("\(dateString)'s entries")
                .font(.title)
            
            if entriesForSelected.isEmpty {
                emptyCarouselText
            } else {
                entryCarousel(for: entriesForSelected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var emptyCarouselText: some View {
        Text("No entries for this date.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: 200, alignment: .center)
    }
        
    private func entryCarousel(for entries: [JournalEntry]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(entries) { entry in
                    let size = CGSize(width: 120, height: 200)
                    gridCard(for: entry, size: size)
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
    
    private func gridCard(for journalEntry: JournalEntry, size: CGSize) -> some View {
        ZStack {
            if journalEntry.mediaType == .video {
                AsyncThumbnailView(entry: journalEntry, targetSize: size)
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else if let waveformLevels = journalEntry.audioWaveformThumbnailLevels(maxBars: max(1, Int(size.width / 7))) {
                WaveformView(levels: waveformLevels, isThumbnailView: true)
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            
            if size.width > 100 {
                VStack(alignment: .leading) {
                    Text(
                        journalEntry.title.isEmpty ? journalEntry.date.formatted(date: .numeric, time: .omitted) : journalEntry.title
                    )
                    .lineLimit(2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !journalEntry.title.isEmpty {
                        Text(journalEntry.date.formatted(date: .numeric, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    
                    Spacer()
                }
                .padding(12)
            } else {
                VStack(alignment: .leading) {
                    let date = journalEntry.date.formatted(date: .abbreviated, time: .omitted)
                    Text(date.dropLast(6))
                        .lineLimit(2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing)
                    
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: size.width, height: size.height)
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
