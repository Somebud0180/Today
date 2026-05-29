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
    var spacing: CGFloat = 0
}

private struct ZoomTransitionState {
    var currentStep: Int
    var nextStep: Int
    var progress: CGFloat
    var currentMetrics: ViewLayoutMetrics
    var nextMetrics: ViewLayoutMetrics
    var currentOpacity: Double
    var nextOpacity: Double
    var currentScale: CGFloat
    var nextScale: CGFloat
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]

    @GestureState private var magnifyBy = 1.0
    @State private var gridZoomStep: Int = 4
    @State private var gestureStartZoomStep: Int? = nil
    @State private var continuousZoomFactor: CGFloat = 4.0
    @State private var scrollPosition: ScrollPosition = .init(idType: Date.self)
    @State private var isFollowingBottom = true
    @State private var didPerformInitialScroll = false

    private let minimumCardWidth: [CGFloat] = [60, 80, 100, 120, 150]
    private let gridSpacing: [CGFloat] = [4, 8, 12, 16, 20]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridPadding: CGFloat = 10

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let transition = zoomTransition(in: proxy.size)

                ZStack {
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            gridLayer(metrics: transition.currentMetrics)
                                .scaleEffect(transition.currentScale, anchor: .center)
                                .opacity(transition.currentOpacity)

                            if transition.nextStep != transition.currentStep {
                                gridLayer(metrics: transition.nextMetrics)
                                    .scaleEffect(transition.nextScale, anchor: .center)
                                    .opacity(transition.nextOpacity)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(gridPadding)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollPosition($scrollPosition, anchor: .bottom)
                    .defaultScrollAnchor(.bottom, for: .initialOffset)
                    .onAppear {
                        guard !didPerformInitialScroll, let lastDate = journalEntries.last?.date else { return }
                        didPerformInitialScroll = true
                        DispatchQueue.main.async {
                            withTransaction(\.scrollTargetAnchor, .bottom) {
                                scrollPosition.scrollTo(id: lastDate)
                            }
                        }
                    }
                    .onChange(of: journalEntries.last?.date) { _, newDate in
                        guard let newDate else { return }
                        if isFollowingBottom {
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
                .simultaneousGesture(
                    MagnifyGesture(minimumScaleDelta: 0.1)
                        .updating($magnifyBy) { value, gestureState, _ in
                            gestureState = value.magnification

                            if gestureStartZoomStep == nil {
                                gestureStartZoomStep = gridZoomStep
                            }

                            // Pinch out (> 1) zooms in; pinch in (< 1) zooms out.
                            let baseStep = gestureStartZoomStep ?? gridZoomStep
                            let maxStep = CGFloat(gridSpacing.count - 1)
                            let rawFactor = CGFloat(baseStep) + (value.magnification - 1.0) * maxStep
                            let clampedFactor = clamp(rawFactor, lower: 0, upper: maxStep)
                            continuousZoomFactor = clampedFactor

                            let lowerStep = clampStep(Int(floor(clampedFactor)))
                            let upperStep = clampStep(lowerStep + 1)
                            let progress = clampedFactor - CGFloat(lowerStep)

                            let direction = value.magnification > 1 ? "In" : "Out"
                            debugPrint("Zooming - Direction: \(direction), Base Step: \(baseStep), Raw Factor: \(rawFactor), Clamped Factor: \(clampedFactor), Lower Step: \(lowerStep), Upper Step: \(upperStep), Progress: \(progress)")
                        }
                        .onEnded { _ in
                            let finalStep = clampStep(Int(round(continuousZoomFactor)))

                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.78, blendDuration: 0.2)) {
                                gridZoomStep = finalStep
                                continuousZoomFactor = CGFloat(finalStep)
                            }

                            gestureStartZoomStep = nil
                        }
                )
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func gridLayer(metrics: ViewLayoutMetrics) -> some View {
        LazyVGrid(columns: metrics.columns, alignment: .center, spacing: metrics.spacing) {
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
    }

    private func gridCard(for journalEntry: JournalEntry, size: CGSize) -> some View {
        ZStack {
            if let thumbnail = journalEntry.videoThumbImage {
                thumbnail
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else if let waveformLevels = journalEntry.audioWaveformThumbnailLevels(maxBars: max(1, Int(size.width / 7))) {
                WaveformView(levels: waveformLevels, isThumbnailView: true)
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            
            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0), .black.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
            .blur(radius: 12)

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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Zoom Transition
    private func zoomTransition(in size: CGSize) -> ZoomTransitionState {
        let currentStep = clampStep(Int(floor(continuousZoomFactor)))
        let nextStep = clampStep(Int(ceil(continuousZoomFactor)))
        let progress = clamp(continuousZoomFactor - CGFloat(currentStep), lower: 0, upper: 1)
        
        let currentMetrics = layoutMetrics(forStep: currentStep, in: size)
        let nextMetrics = layoutMetrics(forStep: nextStep, in: size)
        
        // Calculate scaling by interpolating the physical card widths
        let wCurrent = currentMetrics.cardSize.width
        let wNext = nextMetrics.cardSize.width
        
        let currentScale: CGFloat
        let nextScale: CGFloat
        
        if currentStep == nextStep {
            currentScale = 1.0
            nextScale = 1.0
        } else {
            // Find the precise geometric width midway through the gesture
            let idealWidth = wCurrent + progress * (wNext - wCurrent)
            
            // Calculate how much to scale each layer to match the ideal width
            currentScale = wCurrent > 0 ? idealWidth / wCurrent : 1.0
            nextScale = wNext > 0 ? idealWidth / wNext : 1.0
        }
        
        return ZoomTransitionState(
            currentStep: currentStep,
            nextStep: nextStep,
            progress: progress,
            currentMetrics: currentMetrics,
            nextMetrics: nextMetrics,
            currentOpacity: 1.0 - Double(progress),
            nextOpacity: Double(progress),
            currentScale: currentScale,
            nextScale: nextScale
        )
    }

    // MARK: - Layout Calculations
    private func layoutMetrics(forStep step: Int, in size: CGSize) -> ViewLayoutMetrics {
        let safeStep = clampStep(step)
        let availableWidth = size.width - (gridPadding * 2)
        let columns = calculateGridColumns(availableWidth: availableWidth, forStep: safeStep)
        let cardWidth = calculateCardWidth(availableWidth: availableWidth, columns: columns, forStep: safeStep)
        let cardHeight = cardWidth / cardAspectRatio

        return ViewLayoutMetrics(
            availableWidth: availableWidth,
            columns: columns,
            cardSize: CGSize(width: cardWidth, height: cardHeight),
            spacing: gridSpacing[safeStep]
        )
    }

    private func calculateGridColumns(availableWidth: CGFloat, forStep step: Int) -> [GridItem] {
        let safeStep = clampStep(step)
        let columnCount = max(1, Int((availableWidth + gridSpacing[safeStep]) / (minimumCardWidth[safeStep] + gridSpacing[safeStep])))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing[safeStep]), count: columnCount)
    }

    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem], forStep step: Int) -> CGFloat {
        let safeStep = clampStep(step)
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing[safeStep]
        return max(minimumCardWidth[safeStep], (availableWidth - totalSpacingWidth) / columnCount)
    }

    private func clampStep(_ step: Int) -> Int {
        max(0, min(gridSpacing.count - 1, step))
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(upper, value))
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
}

#Preview {
    HomeView()
        .modelContainer(for: [JournalEntries.self, JournalEntry.self], inMemory: true)
}
