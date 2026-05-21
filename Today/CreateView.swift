//
//  CreateView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/11/26.
//

import SwiftUI
import SwiftData

struct CreateView: View {
    enum Page {
        case menu
        case video
        case audio
        case save
    }
    
    private enum TransitionDirection {
        case forward
        case backward
    }
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var transitionDirection: TransitionDirection = .forward
    @State private var recordedAudioURL: URL? = nil
    @State private var recordedAudioWaveform: CodableAudioWaveform? = nil
    @State private var recordedVideoURL: URL? = nil
    @State private var activePage: Page = .menu
    @State private var entryTitle: String = ""
    @State private var entryNote: String = ""
    @State private var showDismissConfirmation: Bool = false
    
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
                    colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 12)
                .ignoresSafeArea()
                
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
                        .padding(.horizontal, 24)
                        .transition(pageTransition)
                        
                    case .video:
                        VideoRecordingView(
                            activePage: $activePage,
                            recordedURL: $recordedVideoURL
                        ) {
                            transitionDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activePage = .menu
                            }
                        }
                        .padding(24)
                        .transition(pageTransition)
                        
                    case .audio:
                        AudioRecordingView(
                            activePage: $activePage,
                            recordedURL: $recordedAudioURL,
                            recordedWaveform: $recordedAudioWaveform
                        ) {
                            transitionDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activePage = .menu
                            }
                        }
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
                                        dismiss()
                                    }
                                }) {
                                    Text("Save Entry")
                                        .frame(maxWidth: .infinity)
                                        .font(.headline)
                                        .padding(8)
                                }
                                .buttonStyle(.glassProminent)
                                
                                Button(action: {
                                    transitionDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        recordedAudioURL = nil
                                        recordedAudioWaveform = nil
                                        recordedVideoURL = nil
                                        activePage = .menu
                                    }
                                }) {
                                    Text("Back")
                                        .frame(maxWidth: .infinity)
                                        .font(.headline)
                                        .padding(8)
                                }
                                .buttonStyle(.glass)
                                
                            }
                            .padding(24)
                            .transition(pageTransition)
                        }
                    }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if activePage == .menu {
                            dismiss()
                        } else if !showDismissConfirmation {
                            showDismissConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Cancel")
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .alert(
                "Are you sure you want to discard this entry?",
                isPresented: $showDismissConfirmation
            ) {
                Button("Discard Entry", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {
                    showDismissConfirmation = false
                }
            }
        }
    }
}

#Preview {
    CreateView()
}
