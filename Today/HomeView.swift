//
//  HomeView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/27/26.
//

import SwiftUI
import SwiftData

private struct ViewLayoutMetrics {
    var availableWidth: CGFloat = 0
    var columns: [GridItem] = []
    var cardSize: CGSize = .zero
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    
    private let minimumCardWidth: CGFloat = 150
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: CGFloat = 24
    private let gridPadding: CGFloat = 10
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    let metrics = layoutMetrics(in: proxy.size)
                    
                    LazyVGrid(columns: metrics.columns, spacing: gridSpacing) {
                        ForEach(journalEntries) { journalEntry in
                            NavigationLink {
                                JournalView(selectedEntry: journalEntry)
                                    .toolbar(.hidden, for: .tabBar)
                            } label: {
                                gridCard(for: journalEntry, size: metrics.cardSize)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(journalEntry)
                                } label: {
                                    Label("Delete Entry", systemImage: "trash")
                                }
                                
                                Button(role: .close) {
                                    // No action needed, context menu will dismiss automatically
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                }
                            }
                        }
                    }
                    .padding(gridPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func gridCard(for journalEntry: JournalEntry, size: CGSize) -> some View {
        ZStack {
            if let thumbnail = journalEntry.videoThumbImage {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else if let waveformLevels = journalEntry.audioWaveformThumbnailLevels(maxBars: max(1, Int(size.width / 7))) {
                WaveformView(levels: waveformLevels, isThumbnailView: true)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.25))
                .glassEffect(
                    .clear.tint(.gray.opacity(0.25)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            
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
    
    //MARK: - Layout Calculations
    private func calculateGridColumns(availableWidth: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int((availableWidth + gridSpacing) / (minimumCardWidth + gridSpacing)))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem]) -> CGFloat {
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing
        return max(minimumCardWidth, (availableWidth - totalSpacingWidth) / columnCount)
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
}

#Preview {
    HomeView()
        .modelContainer(for: [JournalEntries.self, JournalEntry.self], inMemory: true)
}
