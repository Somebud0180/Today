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
    var titleTopPadding: CGFloat = 0
    var titleHorizontalPadding: CGFloat = 0
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]
    
    @Namespace private var namespace
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
                
                ZStack(alignment: .top) {
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
                        .blurScroll(4, blurHeight: 0.08, blurPosition: .top, coordinateSpaceName: "homeScrollSpace", viewportHeight: proxy.size.height)
                    }
                    .coordinateSpace(name: "homeScrollSpace")
                    .scrollEdgeEffectHidden()
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
                    
                    VStack(alignment: .leading) {
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(Date().formatted(date: .long, time: .omitted))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.leading, getTitleHorizontalPadding(proxy: proxy))
                    .padding(.top, getTitleTopPadding(proxy: proxy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ignoresSafeArea(edges: .all)
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($magnifyBy) { value, gestureState, _ in
                            gestureState = value.magnification
                            
                            if gestureStartZoomStep == nil {
                                gestureStartZoomStep = gridZoomStep
                            }
                            
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
            .background(
                Image("Background1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: colorScheme)
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") {
                        // Edit
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func gridLayer(metrics: ViewLayoutMetrics) -> some View {
        LazyVGrid(columns: metrics.columns, alignment: .center, spacing: metrics.spacing) {
            ForEach(journalEntries) { journalEntry in
                NavigationLink {
                    JournalView(selectedEntry: journalEntry)
                        .toolbar(.hidden, for: .tabBar)
                        .navigationTransition(.zoom(sourceID: journalEntry, in: namespace))
                } label: {
                    GridCardView(for: journalEntry, size: metrics.cardSize)
                        .matchedTransitionSource(id: journalEntry, in: namespace)
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
    
    // MARK: - Zoom Transition
    private func zoomTransition(in size: CGSize) -> ZoomTransitionState {
        let currentStep = clampStep(Int(floor(continuousZoomFactor)))
        let nextStep = clampStep(Int(ceil(continuousZoomFactor)))
        let progress = clamp(continuousZoomFactor - CGFloat(currentStep), lower: 0, upper: 1)
        
        let currentMetrics = layoutMetrics(forStep: currentStep, in: size)
        let nextMetrics = layoutMetrics(forStep: nextStep, in: size)
        
        let wCurrent = currentMetrics.cardSize.width
        let wNext = nextMetrics.cardSize.width
        
        let currentScale: CGFloat
        let nextScale: CGFloat
        
        if currentStep == nextStep {
            currentScale = 1.0
            nextScale = 1.0
        } else {
            let idealWidth = wCurrent + progress * (wNext - wCurrent)
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
    
    private func getTitleTopPadding(proxy: GeometryProxy) -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isPad {
            return proxy.safeAreaInsets.top / 2 - 16
        } else {
            if proxy.size.width > proxy.size.height {
                return 16
            } else {
                return proxy.safeAreaInsets.top / 2
            }
        }
    }
    
    private func getTitleHorizontalPadding(proxy: GeometryProxy) -> CGFloat {
        if proxy.size.width > proxy.size.height {
            return proxy.safeAreaInsets.leading / 2 + 16
        } else {
            return 24
        }
    }
}
