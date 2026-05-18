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
    
    @State var isShowingCreateView: Bool = false
    
    private let minimumCardWidth: CGFloat = 150
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: CGFloat = 24
    private let gridPadding: CGFloat = 10
    
    var body: some View {
        NavigationStack {
            ScrollView {
                GeometryReader { proxy in
                    let metrics = layoutMetrics(in: proxy.size)
                    
                    LazyVGrid(columns: metrics.columns, spacing: gridSpacing) {
                        ForEach(journalEntries) { journalEntry in
                            NavigationLink {
                                JournalView(selectedEntry: journalEntry)
                            } label: {
                                gridCard(for: journalEntry, size: metrics.cardSize)
                            }
                        }
                    }
                    .padding(gridPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingCreateView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateView) {
                CreateView()
            }
        }
    }
    
    private func calculateGridColumns(availableWidth: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int((availableWidth + gridSpacing) / (minimumCardWidth + gridSpacing)))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem]) -> CGFloat {
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing
        return max(minimumCardWidth, (availableWidth - totalSpacingWidth) / columnCount)
    }
    
    private func gridCard(for journalEntry: JournalEntry, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray)
                .glassEffect(
                    .clear,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            
            if let thumbnail = journalEntry.videoThumbImage {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo.on.rectangle.angled")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                    }
                    .frame(width: size.width, height: size.height)
            }
            
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
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func layoutMetrics(in  size: CGSize) -> ViewLayoutMetrics {
        let availableWidth = size.width - (gridPadding * 2)
        let columns = calculateGridColumns(availableWidth: availableWidth)
        let cardWidth = calculateCardWidth(availableWidth: availableWidth, columns: columns)
        let cardHeight = cardWidth / cardAspectRatio
        let cardSize = CGSize(width: cardWidth, height: cardHeight)
        
        return ViewLayoutMetrics(
            availableWidth: availableWidth,
            columns: columns,
            cardSize: cardSize
        )
    }

    
    private struct ViewLayoutMetrics {
        var availableWidth: CGFloat = 0
        var columns: [GridItem] = []
        var cardSize: CGSize = .zero
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntries.self, JournalEntry.self], inMemory: true)
}
