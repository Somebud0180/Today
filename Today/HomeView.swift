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
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]
    
    @GestureState private var magnifyBy = 1.0
    @State private var gridZoomStep: Int = 0
    @State private var activeGridSpacing: CGFloat = 24
    @State private var scrollPosition: ScrollPosition = .init(idType: Date.self)
    @State private var isFollowingBottom = true
    @State private var didPerformInitialScroll = false
    
    private let minimumCardWidth: [CGFloat] = [150, 120, 100, 80, 60]
    private let gridSpacing: [CGFloat] = [24, 16, 12, 8, 4]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridPadding: CGFloat = 10
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let metrics = layoutMetrics(in: proxy.size)
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: metrics.columns, alignment: .center, spacing: activeGridSpacing) {
                        ForEach(journalEntries) { journalEntry in
                            NavigationLink {
                                JournalView(selectedEntry: journalEntry)
                                    .toolbar(.hidden, for: .tabBar)
                            } label: {
                                gridCard(for: journalEntry, size: metrics.cardSize)
                            }
                            .id(journalEntry.date)
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
                    .scrollTargetLayout()
                    .padding(gridPadding)
                    .frame(maxWidth: .infinity)
                    .gesture(
                        MagnifyGesture(minimumScaleDelta: 0.1)
                            .updating($magnifyBy) { value, gestureState, transaction in
                                gestureState = value.magnification
                            }
                    )
                    .onChange(of: magnifyBy) {
                        let zoomChange = magnifyBy - 1.0
                        let normalizedZoomChange = zoomChange.rounded(.toNearestOrAwayFromZero)
                        let newZoomStep = gridZoomStep + Int(normalizedZoomChange)
                        let normalizedNewZoomStep = max(0, min(gridSpacing.count - 1, newZoomStep))
                        if normalizedNewZoomStep != gridZoomStep {
                            gridZoomStep = normalizedNewZoomStep
                            activeGridSpacing = gridSpacing[gridZoomStep]
                        }
                    }
                }
                .scrollPosition($scrollPosition, anchor: .bottom)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .onAppear {
                    guard !didPerformInitialScroll, let lastDate = journalEntries.last?.date else { return }
                    didPerformInitialScroll = true
                    // Defer to next runloop to allow layout to stabilize, then jump to bottom without animation.
                    DispatchQueue.main.async {
                        // prefer bottom alignment when jumping
                        withTransaction(\.scrollTargetAnchor, .bottom) {
                            scrollPosition.scrollTo(id: lastDate)
                        }
                    }
                }
                .onChange(of: journalEntries.last?.date) { _, newDate in
                    guard let newDate else { return }
                    if isFollowingBottom {
                        // Animate when new items arrive while following.
                        withAnimation(.easeOut) {
                            scrollPosition.scrollTo(id: newDate)
                        }
                    }
                }
                .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.6) { visibleIDs in
                    if let lastDate = journalEntries.last?.date {
                        isFollowingBottom = visibleIDs.contains(lastDate)
                    } else {
                        isFollowingBottom = true
                    }
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
    
    // MARK: - Layout Calculations
    private func calculateGridColumns(availableWidth: CGFloat) -> [GridItem] {
        let int = gridZoomStep
        let columnCount = max(1, Int((availableWidth + gridSpacing[int]) / (minimumCardWidth[int] + gridSpacing[int])))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing[int]), count: columnCount)
    }
    
    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem]) -> CGFloat {
        let int = gridZoomStep
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing[int]
        return max(minimumCardWidth[int], (availableWidth - totalSpacingWidth) / columnCount)
    }
    
    private func chunkedEntries(_ entries: [JournalEntry], into columnCount: Int) -> [[JournalEntry]] {
        guard columnCount > 0 else { return [entries] }
        
        var rows: [[JournalEntry]] = []
        rows.reserveCapacity((entries.count + columnCount - 1) / columnCount)
        
        var index = 0
        while index < entries.count {
            let endIndex = min(index + columnCount, entries.count)
            rows.append(Array(entries[index..<endIndex]))
            index = endIndex
        }
        
        return rows
    }
    
    private func layoutMetrics(in size: CGSize) -> ViewLayoutMetrics {
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
