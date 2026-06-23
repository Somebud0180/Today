//
//  SearchView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/22/26.
//
 
import SwiftUI
import SwiftData

struct SearchView: View {
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.editMode) private var editMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .forward) private var journalEntries: [JournalEntry]
    
    @Binding var searchText: String
    @Binding var searchPresented: Bool
    
    @Namespace private var namespace
    @State private var showDeleteConfirmaton: Bool = false
    @State private var topBarHeight: CGFloat = 0.0
    @State private var isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    @State private var selectedEntries: [JournalEntry] = []
    @State private var isPreparingShare = false
    @State private var sharedURLs: [URL] = []
    @State private var showShareSheet = false
    
    private let minimumCardWidth: CGFloat = 120
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: CGFloat = 16
    private let gridPadding: CGFloat = 10
    
    var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return journalEntries }
        let query = searchText.lowercased()
        
        func matches(_ entry: JournalEntry) -> Bool {
            // Adjust property names to match your model
            let title = entry.title.lowercased()
            let transcript = entry.transcript.lowercased()
            // Create a few date strings to match against
            let dateLong = entry.date.formatted(date: .long, time: .omitted).lowercased()
            let dateAbbrev = entry.date.formatted(date: .abbreviated, time: .omitted).lowercased()
            let dateNumeric = entry.date.formatted(.dateTime.year().month().day()).lowercased()
            
            return title.contains(query)
            || transcript.contains(query)
            || dateLong.contains(query)
            || dateAbbrev.contains(query)
            || dateNumeric.contains(query)
        }
        
        return journalEntries.filter(matches)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let metrics = layoutMetrics(in: proxy.size)
            let blurHeight = topBarHeight + TitlePadding.top(proxy, isPad: isPad)
            let isEditing = editMode?.wrappedValue.isEditing == true
            
            NavigationStack {
                ZStack(alignment: .topLeading) {
                    ScrollView(.vertical, showsIndicators: true) {
                        JournalGridView(
                            entries: filteredEntries,
                            metrics: metrics,
                            isEditing: isEditing,
                            selectedEntries: $selectedEntries,
                            destination: { journalEntry in
                                JournalView(selectedEntry: journalEntry)
                                    .toolbar(.hidden, for: .tabBar)
                                    .environmentObject(transcriptionManager)
                                    .navigationTransition(.zoom(sourceID: journalEntry, in: namespace))
                            },
                            namespace: namespace
                        )
                            .padding(gridPadding)
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
                .onChange(of: isPreparingShare) { _, isPreparing in
                    if isPreparing {
                        UIAccessibility.post(notification: .announcement, argument: "Exporting entry")
                    } else {
                        UIAccessibility.post(notification: .announcement, argument: "Export finished")
                    }
                }
                .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
                .toolbar(isEditing ? .visible : .hidden, for: .bottomBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Search")
                            .font(.largeTitle)
                            .fontWeight(.bold)
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
                        if isPreparingShare {
                            Label("Exporting", systemImage: "progress.indicator")
                                .labelStyle(.iconOnly)
                                .symbolEffect(.variableColor.iterative.nonReversing, options: .repeat(.continuous))
                                .padding(.vertical)
                        }
                        
                        if isEditing {
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
                                withAnimation(.snappy) {
                                    editMode?.wrappedValue = .active
                                    searchPresented = false
                                }
                            }, label: {
                                Label("Select", systemImage: "checkmark.circle")
                                    .labelStyle(.titleOnly)
                            })
                        }
                    }
                    
                    if isEditing {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button(action: {
                                Task { await prepareEntriesForSharing(selectedEntries) }
                            }, label: {
                                Label("Export Selected Entries", systemImage: "square.and.arrow.up")
                                    .labelStyle(.iconOnly)
                            })
                            .disabled(isPreparingShare)
                            .disabled(selectedEntries.isEmpty)
                            
                            Spacer()
                            Text(selectedEntries.count < 1 ? "Select Entries" : "\(selectedEntries.count) Selected")
                                .font(.subheadline)
                                .padding(.horizontal)
                            Spacer()
                            
                            Button(action: {
                                showDeleteConfirmaton = true
                            }, label: {
                                Label("Delete Selected Entries", systemImage: "trash.fill")
                                    .labelStyle(.iconOnly)
                            })
                            .disabled(selectedEntries.isEmpty)
                        }
                    }
                }
                .background(
                    Image(selectedBackground)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(.all)
                        .animation(.easeInOut(duration: 0.5), value: colorScheme)
                        .accessibilityHidden(true)
                )
            }
        }
    }
    
    // MARK: - Layout Calculations
    private func layoutMetrics(in size: CGSize) -> ViewLayoutMetrics {
        let availableWidth = size.width - (gridPadding * 2)
        let columns = calculateGridColumns(availableWidth: availableWidth)
        let cardWidth = calculateCardWidth(availableWidth: availableWidth, columns: columns)
        let cardHeight = cardWidth / cardAspectRatio
        
        return ViewLayoutMetrics(
            availableWidth: availableWidth,
            columns: columns,
            cardSize: CGSize(width: cardWidth, height: cardHeight),
            spacing: gridSpacing
        )
    }
    
    private func calculateGridColumns(availableWidth: CGFloat) -> [GridItem] {
        let columnCount = max(3, Int((availableWidth + gridSpacing) / (minimumCardWidth + gridSpacing)))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem]) -> CGFloat {
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing
        return (availableWidth - totalSpacingWidth) / columnCount
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

#Preview {
    @Previewable @State var searchPresented: Bool = false
    SearchView(searchText: .constant(""), searchPresented: $searchPresented)
        .modelContainer(for: JournalEntry.self)
}
