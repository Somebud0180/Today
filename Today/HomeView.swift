//
//  HomeView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/27/26.
//

import SwiftUI
import SwiftData

struct ViewLayoutMetrics {
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
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.editMode) private var editMode
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
    @State private var isPad = UIDevice.current.userInterfaceIdiom == .pad
    @State private var topBarHeight: CGFloat = 0.0
    @State private var showDeleteConfirmaton: Bool = false
    @State private var dateOnScreen: Date?
    
    @State private var selectedEntries: [JournalEntry] = []
    @State private var isPreparingShare = false
    @State private var sharedURLs: [URL] = []
    @State private var showShareSheet = false
    
    private let minimumCardWidth: [CGFloat] = [60, 80, 100, 120, 150]
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: [CGFloat] = [4, 8, 12, 16, 20]
    private let gridPadding: CGFloat = 10
    private let welcomeScreenID = Date.distantFuture
    
    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                let transition = zoomTransition(in: proxy.size)
                let blurHeight = topBarHeight
                let titleHorizontalPadding = TitlePadding.horizontal(proxy, isPad: isPad)
                let titleTopPadding = TitlePadding.top(proxy, isPad: isPad)
                
                ZStack(alignment: .top) {
                    ScrollViewReader { reader in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
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
                                .padding(gridPadding)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 24)
                                
                                welcomeScreen
                                    .containerRelativeFrame(.vertical)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .ignoresSafeArea(.all, edges: .bottom)
                                    .id(welcomeScreenID)
                                    .scrollTransition(.animated, axis: .vertical) { content, phase in
                                        content.opacity(phase.isIdentity ? 1 : 0.4)
                                    }
                            }
                        }
                        .scrollTargetBehavior(.welcomeBoundary)
                        .scrollPosition($scrollPosition)
                        .onAppear {
                            DispatchQueue.main.async {
                                withAnimation(.snappy) {
                                    scrollPosition.scrollTo(id: welcomeScreenID, anchor: .bottom)
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
                                    dateOnScreen = nil
                                } else if let latestVisibleEntry = journalDates.last {
                                    dateOnScreen = latestVisibleEntry
                                } else {
                                    dateOnScreen = nil
                                }
                            }
                        }
                        .onChange(of: proxy.size) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.snappy) {
                                    if dateOnScreen == nil {
                                        scrollPosition.scrollTo(id: welcomeScreenID, anchor: .bottom)
                                    } else if let currentDate = dateOnScreen {
                                        scrollPosition.scrollTo(id: currentDate, anchor: .bottom)
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
                        .frame(height: blurHeight)
                        .ignoresSafeArea()
                    
                    
                    VariableBlurView(maxBlurRadius: 10)
                        .frame(height: blurHeight)
                        .ignoresSafeArea()
                    
                    VStack(alignment: .leading) {
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(titleSubtext)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, titleHorizontalPadding)
                    .padding(.top, titleTopPadding)
                    .animation(.snappy, value: titleHorizontalPadding)
                    .animation(.snappy, value: titleTopPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ignoresSafeArea()
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
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(
                        items: sharedURLs,
                        completion: { activityType, completed, _, error in
                            if completed {
                                debugPrint("Share succeeded! Activity: \(activityType?.rawValue ?? "Unknown")")
                            } else if let error = error {
                                debugPrint("Share failed: \(error.localizedDescription)")
                            }
                        }
                    )
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        
                        ControlGroup {
                            if isPreparingShare {
                                Label("Exporting", systemImage: "progress.indicator")
                                    .labelStyle(.iconOnly)
                                    .symbolEffect(.variableColor.iterative.nonReversing, options: .repeat(.continuous))
                                    .padding(.vertical)
                            }
                            
                            if editMode?.wrappedValue.isEditing == true {
                                Group {
                                    Button(action: {
                                        Task { await prepareEntriesForSharing(selectedEntries) }
                                    }, label: {
                                        Label("Export Selected Entries", systemImage: "square.and.arrow.up")
                                            .labelStyle(.iconOnly)
                                    })
                                    .disabled(isPreparingShare)
                                    
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
                            } else {
                                Button(action: {
                                    withAnimation(.snappy) { editMode?.wrappedValue = .active }
                                }, label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                        .labelStyle(.titleOnly)
                                })
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
                .background(
                    Image(selectedBackground)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(.all)
                        .animation(.easeInOut(duration: 0.5), value: colorScheme)
                )
            }
        }
    }
    
    var welcomeScreen: some View {
        VStack {
            VStack {
                if journalEntries.isEmpty {
                    Text("You don't have any entries yet")
                } else {
                    Image(systemName: "chevron.compact.down")
                    Text("Swipe down to access your entries")
                }
            }
            .foregroundStyle(.secondary)
            .font(.footnote)
            
            Spacer()
            
            Text("Good day")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .shadow(radius: 4)
            
            Text("How are you feeling today?")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(radius: 4)
            
            Spacer()
        }
        .padding()
    }
    
    var titleSubtext: String {
        if isPreparingShare {
            return "Exporting entry..."
        } else if let dateOnScreen {
            return dateOnScreen.formatted(date: .long, time: .omitted)
        } else {
            return Date().formatted(date: .long, time: .omitted)
        }
    }
    
    @ViewBuilder
    private func gridLayer(metrics: ViewLayoutMetrics) -> some View {
        LazyVGrid(columns: metrics.columns, alignment: .center, spacing: metrics.spacing) {
            ForEach(journalEntries) { journalEntry in
                let isEditing = editMode?.wrappedValue.isEditing == true
                let isSelected = selectedEntries.contains(journalEntry)
                
                NavigationLink {
                    JournalView(selectedEntry: journalEntry)
                        .toolbar(.hidden, for: .tabBar)
                        .environmentObject(transcriptionManager)
                        .navigationTransition(.zoom(sourceID: journalEntry, in: namespace))
                } label: {
                    GridCardView(for: journalEntry, size: metrics.cardSize)
                        .matchedTransitionSource(id: journalEntry, in: namespace)
                }
                .buttonStyle(.plain)
                .id(journalEntry.date)
                .allowsHitTesting(!isEditing)
                .opacity(isEditing && !isSelected ? 0.7 : 1.0)
                .contextMenu {
                    Button {
                        Task { await prepareEntryForSharing(journalEntry) }
                    } label: {
                        Label("Export Entry", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(journalEntry)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                }
                .background(
                    Group {
                        if isEditing {
                            Color.clear
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                                .onTapGesture {
                                    withAnimation(.snappy) {
                                        if isSelected {
                                            selectedEntries = selectedEntries.filter { $0 != journalEntry }
                                        } else {
                                            selectedEntries.append(journalEntry)
                                        }
                                    }
                                }
                        }
                    }
                )
                .overlay(
                    Group {
                        if isEditing && isSelected {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                )
            }
        }
        .scrollTargetLayout()
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
    
    private func prepareEntryForSharing(_ entry: JournalEntry) async {
        await prepareEntriesForSharing([entry])
    }
    
    private func prepareEntriesForSharing(_ selectedEntries: [JournalEntry]) async {
        await MainActor.run {
            withAnimation(.snappy) {
                isPreparingShare = true
            }
        }
        
        var urls: [URL] = []
        for entry in selectedEntries {
            if let url = await entry.exportMediaURLForSharing() {
                urls.append(url)
            }
        }
        
        await MainActor.run {
            self.sharedURLs = urls
            
            withAnimation(.snappy) {
                self.isPreparingShare = false
            }
            
            if !urls.isEmpty {
                showShareSheet = true
            }
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
    HomeView()
        .modelContainer(for: JournalEntry.self)
}
