//
//  ContentView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/6/26.
//

import SwiftUI
import SwiftData

struct DefaultSettings {
    static let preferredColorTheme: PreferredColorScheme = .system
    static let selectedBackground: String = "Waving Hills"
    static let autoPlayOnOpen: Bool = false
    static let remindMeToJournal: Bool = true
    static let reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    static let enableTranscription: Bool = false
    static let transcriptionLocale: String = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    static let transcribeOnSave: Bool = false
    static let hasCompletedOnboarding: Bool = false
}

struct ContentView: View {
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var journalEntries: [JournalEntry]
    @Query private var mediaDeletions: [MediaDeletion]
    
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = DefaultSettings.hasCompletedOnboarding
    
    @State private var showOnboarding: Bool = false
    @State private var searchText: String = ""
    @State private var searchPresented: Bool = false
    @State private var backgroundBlur: CGFloat = 0.0
    @State private var hasOpenedCreate: Bool = false
    @State private var isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    @State var tabSelection: Int = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(backgroundBlur: $backgroundBlur)
                    .preferredColorScheme(preferredColorScheme.colorScheme)
                    .environmentObject(transcriptionManager)
            }
            
            Tab("Create Entry", systemImage: "note.text.badge.plus", value: 1) {
                CreateView(tabSelection: $tabSelection, backgroundBlur: $backgroundBlur)
                    .preferredColorScheme(preferredColorScheme.colorScheme)
                    .environmentObject(transcriptionManager)
            }
            
            Tab("Jog Book", systemImage: "ellipsis.calendar", value: 2) {
                JogBookView(backgroundBlur: $backgroundBlur)
                    .preferredColorScheme(preferredColorScheme.colorScheme)
            }
            
            Tab(value: 3, role: .search) {
                SearchView(searchText: $searchText, searchPresented: $searchPresented, backgroundBlur: $backgroundBlur)
                    .searchable(text: $searchText, isPresented: $searchPresented, placement: isPad ? .navigationBarDrawer(displayMode: .always) : .automatic, prompt: "Search entries...")
                    .preferredColorScheme(preferredColorScheme.colorScheme)
                    .environmentObject(transcriptionManager)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .tabViewSearchActivation(.searchTabSelection)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .searchToolbarBehavior(.automatic)
        .task(id: Set(mediaDeletions.flatMap(\.filenames))) {
            try? await MediaMaintenance.shared.run(deletions: Set(mediaDeletions.flatMap(\.filenames)))
            if hasCompletedOnboarding { NotificationsManager.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { try? await MediaMaintenance.shared.run(deletions: Set(mediaDeletions.flatMap(\.filenames))) }
            if hasCompletedOnboarding { NotificationsManager.refresh() }
        }
        .onAppear {
            showOnboarding = !hasCompletedOnboarding
        }
        .onChange(of: tabSelection) {
            backgroundBlur = tabSelection == 1 ? 24 : 0
            
            if tabSelection == 3 {
                searchPresented = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}

extension Color {
    var light: Self {
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        return Color(resolve(in: environment))
    }
    
    var dark: Self {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        return Color(resolve(in: environment))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntry.self, MediaDeletion.self], inMemory: true)
}
