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

private struct ZoomTransitionState {
    var currentStep: Int
    var nextStep: Int
    var progress: CGFloat
    var currentMetrics: ViewLayoutMetrics
    var nextMetrics: ViewLayoutMetrics
    var currentOpacity: Double
    var nextOpacity: Double
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]

    @GestureState private var magnifyBy = 1.0
    @State private var gridZoomStep: Int = 4
    @State private var gestureStartZoomStep: Int? = nil
    @State private var zoomDirection: Int = -1
    @State private var continuousZoomFactor: CGFloat = 4.0
    @State private var activeGridSpacing: CGFloat = 20
    @State private var scrollPosition: ScrollPosition = .init(idType: Date.self)
    @State private var isFollowingBottom = true
    @State private var didPerformInitialScroll = false

    private let minimumCardWidth: [CGFloat] = [60, 80, 100, 120, 150]
    private let gridSpacing: [CGFloat] = [4, 8, 12, 16, 20]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridPadding: CGFloat = 10
    private let thresholdForNextStep: CGFloat = 0.5

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let transition = zoomTransition(in: proxy.size)

                ZStack {
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            gridLayer(metrics: transition.currentMetrics)
                                .opacity(transition.currentOpacity)

                            if transition.nextStep != transition.currentStep {
                                gridLayer(metrics: transition.nextMetrics)
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

                            // Pinch out (> 1) zooms out to smaller cards / more columns.
                            zoomDirection = value.magnification >= 1 ? -1 : 1

                            let baseStep = gestureStartZoomStep ?? gridZoomStep
                            let rawFactor = CGFloat(baseStep) + (1.0 - value.magnification) * CGFloat(gridSpacing.count - 1)
                            let clampedFactor = clamp(rawFactor, lower: 0, upper: CGFloat(gridSpacing.count - 1))
                            continuousZoomFactor = clampedFactor

                            let liveStep = zoomDirection < 0 ? Int(ceil(clampedFactor)) : Int(floor(clampedFactor))
                            gridZoomStep = clampStep(liveStep)

                            let nextStep = clampStep(gridZoomStep + zoomDirection)
                            let progress = transitionProgress(currentStep: gridZoomStep, factor: clampedFactor)
                            activeGridSpacing = interpolatedValue(
                                from: gridSpacing[gridZoomStep],
                                to: gridSpacing[nextStep],
                                progress: progress
                            )
                        }
                        .onEnded { _ in
                            let finalStep = clampStep(Int(continuousZoomFactor.rounded()))

                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.78, blendDuration: 0.2)) {
                                gridZoomStep = finalStep
                                continuousZoomFactor = CGFloat(finalStep)
                                activeGridSpacing = gridSpacing[finalStep]
                            }

                            gestureStartZoomStep = nil
                            zoomDirection = -1
                        }
                )
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func gridLayer(metrics: ViewLayoutMetrics) -> some View {
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

    // MARK: - Zoom Transition
    private func zoomTransition(in size: CGSize) -> ZoomTransitionState {
        let availableWidth = size.width - (gridPadding * 2)
        let currentStep = clampStep(gridZoomStep)
        let nextStep = clampStep(currentStep + zoomDirection)
        let progress = clamp(transitionProgress(currentStep: currentStep, factor: continuousZoomFactor), lower: 0, upper: 1)

        let currentMetrics = layoutMetrics(
            forStep: currentStep,
            in: size,
            interpolatingTo: nextStep,
            progress: progress
        )
        let nextMetrics = layoutMetrics(forStep: nextStep, in: size)

        let nextOpacity = nextStep == currentStep ? 0 : Double(progress <= thresholdForNextStep ? 0 : (progress - thresholdForNextStep) / (1 - thresholdForNextStep))

        return ZoomTransitionState(
            currentStep: currentStep,
            nextStep: nextStep,
            progress: progress,
            currentMetrics: currentMetrics,
            nextMetrics: nextMetrics,
            currentOpacity: 1.0 - nextOpacity,
            nextOpacity: nextOpacity
        )
    }

    private func transitionProgress(currentStep: Int, factor: CGFloat) -> CGFloat {
        let current = CGFloat(currentStep)
        if zoomDirection < 0 {
            return current - factor
        } else {
            return factor - current
        }
    }

    // MARK: - Layout Calculations
    private func layoutMetrics(forStep step: Int, in size: CGSize, interpolatingTo nextStep: Int? = nil, progress: CGFloat = 0) -> ViewLayoutMetrics {
        let safeStep = clampStep(step)
        let availableWidth = size.width - (gridPadding * 2)
        let columns = calculateGridColumns(availableWidth: availableWidth, forStep: safeStep)
        let cardWidth = calculateCardWidth(availableWidth: availableWidth, columns: columns, forStep: safeStep)

        let finalCardWidth: CGFloat
        if let nextStep {
            let safeNextStep = clampStep(nextStep)
            let nextColumns = calculateGridColumns(availableWidth: availableWidth, forStep: safeNextStep)
            let nextCardWidth = calculateCardWidth(availableWidth: availableWidth, columns: nextColumns, forStep: safeNextStep)
            finalCardWidth = interpolatedValue(from: cardWidth, to: nextCardWidth, progress: progress)
        } else {
            finalCardWidth = cardWidth
        }

        let cardHeight = finalCardWidth / cardAspectRatio
        return ViewLayoutMetrics(
            availableWidth: availableWidth,
            columns: columns,
            cardSize: CGSize(width: finalCardWidth, height: cardHeight)
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

    private func interpolatedValue(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + ((end - start) * clamp(progress, lower: 0, upper: 1))
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
