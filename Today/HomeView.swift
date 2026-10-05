//
//  HomeView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/27/26.
//

import SwiftUI
import SwiftData
import VariableBlur

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
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]
    
    @Binding var backgroundBlur: CGFloat
    
    @Namespace private var namespace
    @GestureState private var isMagnifying = false
    @State private var gridZoomStep: Int = 4
    @State private var gestureStartZoomStep: Int? = nil
    @State private var continuousZoomFactor: CGFloat = 4.0
    @State private var scrollPosition: ScrollPosition = .init(idType: Date.self)
    @State private var isFollowingBottom: Bool = true
    @State private var isInWelcomeScreen: Bool = true
    @State private var didPerformInitialScroll = false
    @State private var isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    @State private var topBarHeight: CGFloat = 0.0
    @State private var pendingDeletion: [JournalEntry] = []
    @State private var dateOnScreen: Date?
    @State private var lastOpenedEntryDate: Date?
    
    @State private var selectedEntries: [JournalEntry] = []
    @State private var shareHelper: ShareHelper = ShareHelper()
    
    private let minimumCardWidth: [CGFloat] = [60, 80, 100, 120, 150]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: [CGFloat] = [4, 8, 12, 16, 20]
    private let gridPadding: CGFloat = 10
    @State private var outerPage: Int? = 1
    @State private var gridOwnsScroll = false
    @State private var gridBottomOverscroll: CGFloat = 0
    @State private var suppressWelcomeUntilNextDrag = false
    @State private var gridScrollPhase: ScrollPhase = .idle
    
    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                let transition = zoomTransition(in: proxy.size)
                let blurHeight = topBarHeight + TitlePadding.top(proxy, isPad: isPad)
                
                ZStack(alignment: .topLeading) {
                    GeometryReader { innerProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ScrollView(.vertical, showsIndicators: false) {
                                    ZStack(alignment: .topLeading) {
                                        gridLayer(metrics: transition.currentMetrics)
                                            .scaleEffect(transition.currentScale, anchor: .center)
                                            .opacity(transition.currentOpacity)

                                        if transition.nextStep != transition.currentStep {
                                            gridLayer(metrics: transition.nextMetrics)
                                                .scaleEffect(transition.nextScale, anchor: .center)
                                                .opacity(transition.nextOpacity)
                                                .allowsHitTesting(false)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .padding(.top, blurHeight)
                                    .padding(.bottom, proxy.safeAreaInsets.bottom)
                                    .padding(gridPadding)
                                }
                                .defaultScrollAnchor(.bottom)
                                .defaultScrollAnchor(.top, for: .alignment)
                                .scrollPosition($scrollPosition)
                                .scrollDisabled(!gridOwnsScroll)
                                .scrollBounceBehavior(.always, axes: .vertical)
                                .scrollEdgeEffectStyle(.soft, for: .vertical)
                                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                                    let bottom = max(-geometry.contentInsets.top,
                                        geometry.contentSize.height - geometry.containerSize.height + geometry.contentInsets.bottom)
                                    return max(0, geometry.contentOffset.y - bottom)
                                } action: { _, overscroll in
                                    gridBottomOverscroll = overscroll
                                }
                                .onScrollPhaseChange { oldPhase, newPhase in
                                    gridScrollPhase = newPhase
                                    // A pinch can resize content and interrupt a pan. Only a fresh
                                    // drag after the pinch may hand scrolling back to the pager.
                                    if (newPhase == .tracking || (oldPhase == .idle && newPhase == .interacting)),
                                       !isMagnifying, gestureStartZoomStep == nil {
                                        suppressWelcomeUntilNextDrag = false
                                        gridBottomOverscroll = 0
                                    }
                                    if gridOwnsScroll, !suppressWelcomeUntilNextDrag, !isMagnifying,
                                       oldPhase == .interacting,
                                       newPhase != .interacting, gridBottomOverscroll > 72 {
                                        gridOwnsScroll = false
                                        withAnimation(.snappy) { outerPage = 1 }
                                    }
                                    resetZoomHandoffIfIdle()
                                }
                                .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.2) { visibleIDs in
                                    isFollowingBottom = journalEntries.last.map { visibleIDs.contains($0.date) } ?? true
                                    if let firstDate = visibleIDs.min() {
                                        dateOnScreen = firstDate
                                    }
                                }
                                .onAppear {
                                    guard !didPerformInitialScroll else { return }
                                    didPerformInitialScroll = true
                                    if let lastOpenedEntryDate {
                                        scrollPosition.scrollTo(id: lastOpenedEntryDate, anchor: .bottom)
                                    }
                                }
                                .onChange(of: journalEntries.last?.date) { _, newDate in
                                    guard let newDate, isFollowingBottom else { return }
                                    withAnimation(.easeOut) {
                                        scrollPosition.scrollTo(id: newDate, anchor: .bottom)
                                    }
                                }
                                .onChange(of: proxy.size) {
                                    if let dateOnScreen {
                                        scrollPosition.scrollTo(id: dateOnScreen, anchor: .bottom)
                                    }
                                }
                                .frame(height: innerProxy.size.height)
                                .id(0)

                                welcomeScreen
                                    .padding(.top, blurHeight)
                                    .frame(height: innerProxy.size.height)
                                    .id(1)
                            }
                            .scrollTargetLayout()
                            .background(HomePagedInteraction(isEnabled: !gridOwnsScroll))
                        }
                        .defaultScrollAnchor(.bottom)
                        .scrollPosition(id: $outerPage)
                        .scrollTargetBehavior(.paging)
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            geometry.contentOffset.y <= 1
                        } action: { _, isAtGrid in
                            // Lock the pager as soon as it reaches the grid, including
                            // when a second touch interrupts the paging deceleration.
                            if isAtGrid, outerPage == 0 {
                                gridOwnsScroll = true
                            }
                        }
                        .onScrollPhaseChange { _, phase in
                            if phase == .idle, outerPage == 0 {
                                gridOwnsScroll = true
                            }
                        }
                        .onChange(of: outerPage) { _, page in
                            isInWelcomeScreen = page != 0
                        }
                    }
                    .ignoresSafeArea()
                    
                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 4)
                    .frame(height: blurHeight + 8)
                    .offset(y: -8)
                    .ignoresSafeArea()
                    
                    VariableBlurView(maxBlurRadius: 4)
                        .frame(height: blurHeight)
                        .ignoresSafeArea()
                }
                .simultaneousGesture(zoomGesture)
                .onChange(of: isMagnifying) { _, active in
                    if !active {
                        finishZoom()
                        resetZoomHandoffIfIdle()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .journalDeletion($pendingDeletion) {
                    editMode?.wrappedValue = .inactive
                    selectedEntries.removeAll()
                }
                .sheet(isPresented: $shareHelper.showShareSheet) {
                    ShareSheet(
                        items: shareHelper.sharedURLs,
                        completion: { activityType, completed, _, error in
                            if completed {
                                debugPrint("Share succeeded! Activity: \(activityType?.rawValue ?? "Unknown")")
                            } else if let error = error {
                                debugPrint("Share failed: \(error.localizedDescription)")
                            }
                        }
                    )
                }
                .onChange(of: dateOnScreen) { _, newValue in
                    if !isInWelcomeScreen, let newValue {
                        UIAccessibility.post(notification: .announcement, argument: newValue.formatted(date: .long, time: .omitted))
                    }
                }
                .onChange(of: shareHelper.isPreparingShare) {
                    if shareHelper.isPreparingShare {
                        UIAccessibility.post(notification: .announcement, argument: "Exporting entry")
                    } else {
                        UIAccessibility.post(notification: .announcement, argument: "Export finished")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(alignment: .leading) {
                            Text("Today")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text(titleSubtext)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        withAnimation(.snappy) {
                                            topBarHeight = geo.size.height
                                        }
                                    }
                                    .onChange(of: geo.size.height) {
                                        withAnimation(.snappy) {
                                            topBarHeight = geo.size.height
                                        }
                                    }
                            }
                        )
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ControlGroup {
                            if shareHelper.isPreparingShare {
                                Label("Exporting", systemImage: "progress.indicator")
                                    .labelStyle(.iconOnly)
                                    .symbolEffect(.variableColor.iterative.nonReversing, options: .repeat(.continuous))
                                    .padding(.vertical)
                            }
                            
                            if editMode?.wrappedValue.isEditing == true {
                                Group {
                                    Button(action: {
                                        Task { await shareHelper.prepareEntriesForSharing(selectedEntries) }
                                    }, label: {
                                        Label("Export Selected Entries", systemImage: "square.and.arrow.up")
                                            .labelStyle(.iconOnly)
                                    })
                                    .disabled(shareHelper.isPreparingShare)
                                    
                                    Button(action: {
                                        pendingDeletion = selectedEntries
                                    }, label: {
                                        Label("Delete Selected Entries", systemImage: "trash.fill")
                                            .labelStyle(.iconOnly)
                                    })
                                }
                                .disabled(selectedEntries.isEmpty)
                                
                                Button(action: {
                                    withAnimation(.snappy) {
                                        editMode?.wrappedValue = .inactive
                                        selectedEntries.removeAll()
                                    }
                                }, label: {
                                    Label("Done", systemImage: "checkmark")
                                        .labelStyle(.iconOnly)
                                })
                                .buttonBorderShape(.capsule)
                            } else {
                                Button(action: {
                                    withAnimation(.snappy) { editMode?.wrappedValue = .active }
                                }, label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                        .labelStyle(.titleOnly)
                                })
                                .buttonBorderShape(.capsule)
                            }
                        }
                        
                        NavigationLink(
                            destination: SettingsView().environmentObject(transcriptionManager),
                            label: {
                                Label("Settings", systemImage: "gearshape")
                                    .labelStyle(.iconOnly)
                            })
                    }
                }
                .toolbarRole(.editor) // Forces left aligned principal item https://iifx.dev/en/articles/457777731/bypassing-the-liquid-glass-left-aligned-toolbar-text-in-swiftui-ios-26
                .background(
                    GeometryReader { proxy in
                        Image(selectedBackground)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                            .clipped()
                            .blur(radius: backgroundBlur, opaque: true)
                            .animation(.smooth(duration: 0.4)) { content in
                                content.blur(radius: backgroundBlur, opaque: true)
                            }
                            .accessibilityHidden(true)
                            .animation(.easeInOut(duration: 0.5), value: colorScheme)
                    }
                        .ignoresSafeArea(.all)
                )
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }
    
    var welcomeScreen: some View {
        VStack {
            VStack {
                if journalEntries.isEmpty {
                    Text("You don't have any entries yet")
                        .accessibilityLabel("You don't have any entries yet")
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.compact.down")
                        Text("Swipe down to access your entries")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Swipe down to access your entries")
                }
            }
            .foregroundStyle(.secondary)
            .font(.footnote)
            
            Spacer()
            
            Group {
                Text("Good day")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                
                Text("How are you feeling today?")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Good day. How are you feeling today?")
            
            Spacer()
        }
        .padding()
    }
    
    var titleSubtext: String {
        if shareHelper.isPreparingShare {
            return "Exporting entry..."
        } else if !isInWelcomeScreen, let dateOnScreen {
            return dateOnScreen.formatted(date: .long, time: .omitted)
        } else {
            return "\(journalEntries.count.formatted(.number)) Entries"
        }
    }
    
    @ViewBuilder
    private func gridLayer(metrics: ViewLayoutMetrics) -> some View {
        JournalGridView(
            selectedEntries: $selectedEntries,
            entries: journalEntries,
            metrics: metrics,
            isEditing: editMode?.wrappedValue.isEditing == true,
            namespace: namespace,
            destination: { journalEntry in
                JournalView(selectedEntry: journalEntry)
                    .toolbar(.hidden, for: .tabBar)
                    .environmentObject(transcriptionManager)
                    .navigationTransition(.zoom(sourceID: journalEntry, in: namespace))
                    .onAppear {
                        lastOpenedEntryDate = journalEntry.date
                        isFollowingBottom = false
                    }
            },
            onShare: { entry in
                Task { await shareHelper.prepareEntryForSharing(entry) }
            }
        )
    }
    
    // MARK: - Zoom Transition
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($isMagnifying) { _, active, _ in
                active = true
            }
            .onChanged { value in
                guard gridOwnsScroll else { return }
                suppressWelcomeUntilNextDrag = true
                gridBottomOverscroll = 0
                if gestureStartZoomStep == nil {
                    gestureStartZoomStep = gridZoomStep
                }
                continuousZoomFactor = zoomFactor(for: value.magnification)
            }
            .onEnded { value in
                guard gestureStartZoomStep != nil else { return }
                continuousZoomFactor = zoomFactor(for: value.magnification)
                finishZoom()
            }
    }

    private func zoomFactor(for magnification: CGFloat) -> CGFloat {
        let maxStep = CGFloat(gridSpacing.count - 1)
        return clamp(CGFloat(gestureStartZoomStep ?? gridZoomStep)
                     + (magnification - 1) * maxStep, lower: 0, upper: maxStep)
    }

    private func finishZoom() {
        // GestureState resets on cancellation too; onEnded alone misses that case.
        guard gestureStartZoomStep != nil else { return }
        let finalStep = clampStep(Int(round(continuousZoomFactor)))
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.78, blendDuration: 0.2)) {
            gridZoomStep = finalStep
            continuousZoomFactor = CGFloat(finalStep)
        }
        gestureStartZoomStep = nil
        // Keep the welcome handoff suppressed through any remaining pan/deceleration.
        gridBottomOverscroll = 0
    }

    private func resetZoomHandoffIfIdle() {
        // A stationary pinch may finish without another scroll-phase callback.
        // Reset from both gesture completion and scroll idle, after exit evaluation.
        guard gridScrollPhase == .idle, !isMagnifying, gestureStartZoomStep == nil else { return }
        suppressWelcomeUntilNextDrag = false
        gridBottomOverscroll = 0
    }

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
            spacing: layoutSpacing(availableWidth: availableWidth, forStep: safeStep)
        )
    }
    
    private func columnCount(availableWidth: CGFloat, forStep step: Int) -> Int {
        max(1, Int((availableWidth + gridSpacing[step]) / (minimumCardWidth[step] + gridSpacing[step])))
    }

    private func layoutSpacing(availableWidth: CGFloat, forStep step: Int) -> CGFloat {
        let count = columnCount(availableWidth: availableWidth, forStep: step)
        var lastMatchingStep = step
        // Retain the original columns and the largest stop's spacing. Stops with
        // identical columns must also share spacing so zooming in cannot shrink cards.
        while lastMatchingStep + 1 < gridSpacing.count,
              columnCount(availableWidth: availableWidth, forStep: lastMatchingStep + 1) == count {
            lastMatchingStep += 1
        }
        return gridSpacing[lastMatchingStep]
    }

    private func calculateGridColumns(availableWidth: CGFloat, forStep step: Int) -> [GridItem] {
        let safeStep = clampStep(step)
        let count = columnCount(availableWidth: availableWidth, forStep: safeStep)
        let spacing = layoutSpacing(availableWidth: availableWidth, forStep: safeStep)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem], forStep step: Int) -> CGFloat {
        let safeStep = clampStep(step)
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * layoutSpacing(availableWidth: availableWidth, forStep: safeStep)
        return max(minimumCardWidth[safeStep], (availableWidth - totalSpacingWidth) / columnCount)
    }

    private func clampStep(_ step: Int) -> Int {
        max(0, min(gridSpacing.count - 1, step))
    }
    
    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(upper, value))
    }
    
    private func toggleSelection(_ entry: JournalEntry, isSelected: Bool) {
        if isSelected {
            selectedEntries = selectedEntries.filter { $0 != entry }
        } else {
            selectedEntries.append(entry)
        }
    }
}

#Preview {
    HomeView(backgroundBlur: .constant(0))
        .modelContainer(for: [JournalEntry.self, MediaDeletion.self], inMemory: true)
}
