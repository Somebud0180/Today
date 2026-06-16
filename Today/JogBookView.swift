//
//  JogBookView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/8/26.
//

import SwiftUI
import SwiftData
import UIKit

struct JogBookView: View {
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    
    @State var calendarGridColumn: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    @State var selectedMonthYear: Date = Calendar.current.dateComponents([.year, .month], from: Date()).date ?? Date()
    @State var selectedDay: Date? = nil
    @State var isLandscape: Bool = false
    
    let cardSize: CGSize = CGSize(width: 120, height: 200)
    let cardSizeCompact: CGSize = CGSize(width: 96, height: 160)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isLandscape {
                        VStack {
                            topBar
                                .padding(.horizontal, 16)
                            
                            HStack {
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
                                
                                monthSummary
                                    .padding(16)
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .glassEffect(
                                                .regular,
                                                in: RoundedRectangle(cornerRadius: 16)
                                            )
                                    )
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            topBar
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
                            
                            monthSummary
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .glassEffect(
                                            .regular,
                                            in: RoundedRectangle(cornerRadius: 16)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, isLandscape ? nil : 16)
                .padding(.top, isLandscape ? 16 : nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background {
                GeometryReader { proxy in
                    Image(selectedBackground)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.5), value: colorScheme)
                        .onAppear { isLandscape = proxy.size.width > proxy.size.height }
                        .onChange(of: proxy.size) { isLandscape = proxy.size.width > proxy.size.height }
                }
            }
        }
    }
    
    private var topBar: some View {
        VStack(spacing: 4) {
            if isLandscape {
                HStack {
                    monthButton(forPrevious: true)
                    Spacer()
                    monthTitleText
                    Spacer()
                    monthButton(forPrevious: false)
                }
            } else {
                monthTitleText
                
                HStack {
                    monthButton(forPrevious: true)
                    Spacer()
                    monthButton(forPrevious: false)
                }
            }
        }
    }
    
    private var monthTitleText: some View {
        MonthYearPicker(date: $selectedMonthYear) {
            Text(selectedMonthYear.formatted(.dateTime.month(.wide).year()))
        }
        .font(.title)
        .fontWeight(.bold)
    }
    
    private func monthButton(forPrevious: Bool) -> some View {
        var month: Date {
            if forPrevious {
                return Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthYear) ?? Date()
            } else {
                return Calendar.current.date(byAdding: .month, value: 1, to: selectedMonthYear) ?? Date()
            }
        }
        
        return Button(action: {
            withAnimation(.snappy) {
                selectedMonthYear = month
                selectedDay = nil
            }
        }, label: {
            Label(month.formatted(.dateTime.month(.wide)), systemImage: forPrevious ? "chevron.left" : "chevron.right")
                .font(.title3)
                .padding(.horizontal, 8)
        })
        .buttonStyle(.glass)
    }
    
    private var jogGrid: some View {
        GlassEffectContainer {
            LazyVGrid(columns: calendarGridColumn, spacing: 8) {
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
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clear)
                            .stroke(selectedDay != nil && Calendar.current.isDate(indexDate, inSameDayAs: selectedDay!) ? Color.primary : Color.clear, lineWidth: 3)
                    }
                }
            }
        }
    }
    
    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            let dateString = selectedDay != nil ? selectedDay!.formatted(.dateTime.day().month(.wide).year()) : selectedMonthYear.formatted(.dateTime.month(.wide).year())
            
            let entriesForSelected = journalEntries.filter { entry in
                if let selectedDay {
                    Calendar.current.isDate(entry.date, inSameDayAs: selectedDay)
                } else {
                    Calendar.current.isDate(entry.date, equalTo: selectedMonthYear, toGranularity: .month)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("\(dateString)'s entries")
                    .font(.title)
                
                if !entriesForSelected.isEmpty, let selectedDay {
                    Text("You have \(entryCount(for: selectedDay, granularity: .day)) entries on \(selectedDay.formatted(.dateTime.day().month(.wide).year()))")
                        .font(.headline)
                } else {
                    monthlyEntryText
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
    
    private var monthlyEntryText: some View {
        var endString: String {
            if Calendar.current.isDate(selectedMonthYear, equalTo: Date(), toGranularity: .year) {
                return "this \(selectedMonthYear.formatted(.dateTime.month(.wide)))"
            } else {
                return "in \(selectedMonthYear.formatted(.dateTime.month(.wide).year()))"
            }
        }
        
        return Text("You have logged \(entryCount(for: selectedMonthYear, granularity: .month)) journal entries \(endString).")
            .font(.headline)
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
                    GridCardView(for: entry, size: isLandscape ? cardSizeCompact : cardSize)
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
    ContentView(tabSelection: 2)
        .modelContainer(for: JournalEntry.self)
}
