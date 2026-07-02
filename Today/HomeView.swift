//
//  HomeView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/27/26.
//

import SwiftUI
import SwiftData

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
    @GestureState private var magnifyBy = 1.0
    @State private var gridZoomStep: Int = 4
    @State private var gestureStartZoomStep: Int? = nil
    @State private var continuousZoomFactor: CGFloat = 4.0
    @State private var scrollPosition: ScrollPosition = .init(idType: Date.self)
    @State private var isFollowingBottom: Bool = true
    @State private var isInWelcomeScreen: Bool = false
    @State private var didPerformInitialScroll = false
    @State private var isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    @State private var topBarHeight: CGFloat = 0.0
    @State private var showDeleteConfirmaton: Bool = false
    @State private var dateOnScreen: Date?
    @State private var lastOpenedEntryDate: Date?
    
    @State private var selectedEntries: [JournalEntry] = []
    @State private var shareHelper: ShareHelper = ShareHelper()
    
    private let minimumCardWidth: [CGFloat] = [60, 80, 100, 120, 150]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: [CGFloat] = [4, 8, 12, 16, 20]
    private let gridPadding: CGFloat = 10
    private let welcomeScreenID = Date.distantFuture
    
    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                let transition = zoomTransition(in: proxy.size)
                let blurHeight = topBarHeight + TitlePadding.top(proxy, isPad: isPad)
                
                ZStack(alignment: .topLeading) {
                    ScrollViewReader { reader in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                ZStack(alignment: .topLeading) {
                                    gridLayer(metrics: transition.currentMetrics)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                        .scaleEffect(transition.currentScale, anchor: .center)
                                        .opacity(transition.currentOpacity)
                                    
                                    if transition.nextStep != transition.currentStep {
                                        gridLayer(metrics: transition.nextMetrics)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                            .scaleEffect(transition.nextScale, anchor: .center)
                                            .opacity(transition.nextOpacity)
                                    }
                                }
                                .padding(gridPadding)
                                .frame(maxWidth: .infinity, minHeight: proxy.size.height - blurHeight - 24, alignment: .top)
                                
                                welcomeScreen
                                    .containerRelativeFrame(.vertical)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .id(welcomeScreenID)
                                    .scrollTransition(.animated, axis: .vertical) { content, phase in
                                        content.opacity(phase.isIdentity ? 1 : 0)
                                    }
                            }
                        }
                        .scrollTargetBehavior(.welcomeBoundary)
                        .scrollPosition($scrollPosition)
                        .scrollEdgeEffectStyle(.soft, for: .top)
                        .onAppear {
                            if !didPerformInitialScroll {
                                didPerformInitialScroll = true
                                DispatchQueue.main.async {
                                    withAnimation(.snappy) {
                                        scrollPosition.scrollTo(id: welcomeScreenID, anchor: .bottom)
                                    }
                                }
                            } else if let lastOpenedEntryDate {
                                DispatchQueue.main.async {
                                    withAnimation(.snappy) {
                                        scrollPosition.scrollTo(id: lastOpenedEntryDate, anchor: .bottom)
                                    }
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
                        .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.2) { visibleIDs in
                            if let lastDate = journalEntries.last?.date {
                                isFollowingBottom = visibleIDs.contains(lastDate)
                            } else {
                                isFollowingBottom = true
                            }
                            
                            let hasWelcomeScreen = visibleIDs.contains(welcomeScreenID)
                            let journalDates = visibleIDs.filter { $0 != welcomeScreenID }.sorted()
                            
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if hasWelcomeScreen {
                                    isInWelcomeScreen = true
                                    dateOnScreen = nil
                                } else if let earliestVisibleEntry = journalDates.first {
                                    dateOnScreen = earliestVisibleEntry
                                } else {
                                    dateOnScreen = nil
                                }
                            }
                        }
                        .onChange(of: proxy.size) {
                            guard dateOnScreen != nil || isInWelcomeScreen else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.snappy) {
                                    if dateOnScreen == nil && isInWelcomeScreen {
                                        scrollPosition.scrollTo(id: welcomeScreenID, anchor: .bottom)
                                    } else {
                                        scrollPosition.scrollTo(id: dateOnScreen, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
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
                .navigationBarTitleDisplayMode(.inline)
                .alert("Delete Entries?", isPresented: $showDeleteConfirmaton, actions: {
                    Button("Cancel", role: .cancel) {}
                    
                    Button("Delete", role: .destructive) {
                        withAnimation(.snappy) {
                            for entry in selectedEntries {
                                modelContext.delete(entry)
                            }
                            
                            editMode?.wrappedValue = .inactive
                            selectedEntries.removeAll()
                        }
                    }
                })
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
                    if let newValue {
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
                                        showDeleteConfirmaton = true
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
                            .accessibilityHidden(true)
                            .animation(.smooth(duration: 0.4), value: backgroundBlur)
                            .animation(.easeInOut(duration: 0.5), value: colorScheme)
                    }
                        .ignoresSafeArea(.all)
                )
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
                    // Combine the icon and text for VO
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
        } else if let dateOnScreen {
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
            }
            .onEnded { _ in
                let finalStep = clampStep(Int(round(continuousZoomFactor)))
                
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.78, blendDuration: 0.2)) {
                    gridZoomStep = finalStep
                    continuousZoomFactor = CGFloat(finalStep)
                }
                
                gestureStartZoomStep = nil
            }
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
    
    private func toggleSelection(_ entry: JournalEntry, isSelected: Bool) {
        if isSelected {
            selectedEntries = selectedEntries.filter { $0 != entry }
        } else {
            selectedEntries.append(entry)
        }
    }
}

struct WelcomeBoundaryBehavior: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard context.contentSize.height > context.containerSize.height else { return }
        
        let maxOffset = context.contentSize.height - context.containerSize.height
        let welcomeHeight = context.containerSize.height
        let gridBottomOffset = maxOffset - welcomeHeight
        
        if target.rect.minY >= gridBottomOffset - 150 {
            
            let velocity = context.velocity.dy
            
            if velocity > 0.2 {
                target.rect.origin.y = maxOffset
            } else if velocity < -0.2 {
                target.rect.origin.y = gridBottomOffset
            } else {
                if target.rect.minY > gridBottomOffset + (welcomeHeight * 0.15) {
                    target.rect.origin.y = maxOffset
                } else {
                    target.rect.origin.y = gridBottomOffset
                }
            }
        }
    }
}

extension ScrollTargetBehavior where Self == WelcomeBoundaryBehavior {
    static var welcomeBoundary: WelcomeBoundaryBehavior { .init() }
}

#Preview {
    HomeView(backgroundBlur: .constant(0))
        .modelContainer(for: JournalEntry.self)
}
