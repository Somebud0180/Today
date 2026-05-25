//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI
import SwiftData

private enum TransitionDirection {
    case forward
    case backward
}

struct CreateView: View {
    enum Page {
        case menu
        case video
        case audio
        case save
    }
    
    @Environment(\.modelContext) private var modelContext
    @Binding var tabSelection: Int
    
    @State private var animateGradient: Bool = false
    @State private var gradientColors: [Color] = [
        Color.purple.opacity(0.5),
        Color.blue.opacity(0.5)
    ]
    
    @State private var screenHasRecording: Bool = false
    @State private var childShouldReset: Bool = false
    @State private var transitionDirection: TransitionDirection = .forward
    @State private var recordedAudioURL: URL? = nil
    @State private var recordedAudioWaveform: CodableAudioWaveform? = nil
    @State private var recordedVideoURL: URL? = nil
    @State private var activePage: Page = .menu
    @State private var entryTitle: String = ""
    @State private var entryNote: String = ""
    
    private var pageTransition: AnyTransition {
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 12)
                .hueRotation(.degrees(animateGradient ? 45 : -45))
                .ignoresSafeArea()
                .task {
                    // From https://www.codespeedy.com/gradient-animation-in-swiftui/
                    withAnimation(
                        .easeInOut(duration: 3)
                        .repeatForever())
                    {
                        animateGradient.toggle()
                    }
                }
                
                switch activePage {
                case .menu:
                    GeometryReader { proxy in
                        let isLandscape = proxy.size.width > proxy.size.height
                        let menuLayout: AnyLayout = isLandscape
                        ? AnyLayout(HStackLayout(spacing: 24))
                        : AnyLayout(VStackLayout(spacing: 32))
                        
                        VStack {
                            Text("What are we feeling today?")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            
                            menuLayout {
                                Button(action: {
                                    transitionDirection = .forward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        activePage = .video
                                    }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.blue)
                                            .glassEffect(
                                                .regular.interactive(),
                                                in: RoundedRectangle(cornerRadius: 24)
                                            )
                                        
                                        VStack(spacing: 24) {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 64))
                                            
                                            Text("Create Video Entry")
                                                .font(.largeTitle)
                                                .fontWeight(.bold)
                                                .fontDesign(.rounded)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    transitionDirection = .forward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        activePage = .audio
                                    }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.gray)
                                            .glassEffect(
                                                .regular.interactive(),
                                                in: RoundedRectangle(cornerRadius: 24)
                                            )
                                        
                                        VStack(spacing: 24) {
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 64))
                                                .foregroundStyle(.black)
                                            
                                            Text("Create Audio Entry")
                                                .foregroundStyle(.black)
                                                .font(.largeTitle)
                                                .fontWeight(.bold)
                                                .fontDesign(.rounded)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom)
                    .padding(.horizontal, 24)
                    .transition(pageTransition)
                    
                case .video:
                    VideoRecordingView(
                        activePage: $activePage,
                        recordedURL: $recordedVideoURL,
                        hasTemporaryRecording: $screenHasRecording
                    ) {
                        transitionDirection = .backward
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activePage = .menu
                        }
                    }
                    .transition(pageTransition)
                    
                case .audio:
                    AudioRecordingView(
                        activePage: $activePage,
                        recordedURL: $recordedAudioURL,
                        recordedWaveform: $recordedAudioWaveform,
                        hasTemporaryRecording: $screenHasRecording
                    ) {
                        transitionDirection = .backward
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activePage = .menu
                        }
                    }
                    .padding(.bottom)
                    .padding(24)
                    .transition(pageTransition)
                    
                case .save:
                    if let activeURL = recordedVideoURL ?? recordedAudioURL {
                        let mediaType: MediaType = recordedVideoURL != nil ? .video : .audio
                        let fileExtension = activeURL.pathExtension.isEmpty
                        ? (mediaType == .video ? "mov" : "m4a")
                        : activeURL.pathExtension
                        
                        VStack {
                            Spacer()
                            TextField(
                                Date().formatted(date: .numeric, time: .omitted),
                                text: $entryTitle,
                                axis: .vertical
                            )
                            .font(.largeTitle)
                            
                            TextField(
                                "Add a note (optional)",
                                text: $entryNote
                            )
                            Spacer()
                            Button(action: {
                                let entry = JournalEntry(
                                    title: entryTitle,
                                    note: entryNote,
                                    mediaData: try! Data(contentsOf: activeURL),
                                    fileExtension: fileExtension,
                                    mediaType: mediaType,
                                    waveform: mediaType == .audio ? recordedAudioWaveform : nil
                                )
                                
                                if let entry = entry {
                                    modelContext.insert(entry)
                                    try? modelContext.save()
                                    resetVariables()
                                    tabSelection = 0
                                }
                            }) {
                                Text("Save Entry")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline)
                                    .padding(12)
                            }
                            .buttonStyle(.glassProminent)
                            
                            Button(action: {
                                transitionDirection = .backward
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if recordedAudioURL != nil {
                                        activePage = .audio
                                    } else if recordedVideoURL != nil {
                                        activePage = .video
                                    } else {
                                        recordedAudioURL = nil
                                        recordedAudioWaveform = nil
                                        recordedVideoURL = nil
                                        activePage = .menu
                                    }
                                }
                            }) {
                                Text("Back")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline)
                                    .padding(12)
                            }
                            .buttonStyle(.glass)
                            
                        }
                        .padding(.bottom)
                        .padding(24)
                        .transition(pageTransition)
                    }
                }
            }
        }
    }
    
    func resetVariables() {
        screenHasRecording = false
        childShouldReset = false
        transitionDirection = .forward
        recordedAudioURL = nil
        recordedAudioWaveform = nil
        recordedVideoURL = nil
        activePage = .menu
        entryTitle = ""
        entryNote = ""
    }
}

#Preview {
    @Previewable @State var tabSelection: Int = 1
    CreateView(tabSelection: $tabSelection)
}
