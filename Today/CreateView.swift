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
    @State private var recordedAudioPowerFrames: [AudioRecorderManager.RecordedPowerFrame]? = nil
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
                switch activePage {
                case .menu:
                    GeometryReader { proxy in
                        let isLandscape = proxy.size.width > proxy.size.height
                        let menuLayout: AnyLayout = isLandscape
                        ? AnyLayout(HStackLayout(spacing: 24))
                        : AnyLayout(VStackLayout(spacing: 48))
                        
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
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
                    .transition(pageTransition)
                    
                case .audio:
                    AudioRecordingView(
                        activePage: $activePage,
                        recordedURL: $recordedAudioURL,
                        recordedPowerFrames: $recordedAudioPowerFrames
                    ) {
                        transitionDirection = .backward
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activePage = .menu
                        }
                    }
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
                                // Convert audio power frames to Codable format if available
                                var powerFrames: [CodableRecordedPowerFrame]? = nil
                                if mediaType == .audio, let audioFrames = recordedAudioPowerFrames {
                                    powerFrames = audioFrames.map { frame in
                                        CodableRecordedPowerFrame(
                                            time: frame.time,
                                            metrics: frame.metrics.map { metric in
                                                CodablePowerMetrics(
                                                    channelName: metric.channelName,
                                                    channelNumber: metric.channelNumber,
                                                    average: metric.average,
                                                    peak: metric.peak
                                                )
                                            }
                                        )
                                    }
                                }
                                
                                let entry = JournalEntry(
                                    title: entryTitle,
                                    note: entryNote,
                                    mediaData: try! Data(contentsOf: activeURL),
                                    fileExtension: fileExtension,
                                    mediaType: mediaType,
                                    powerFrames: powerFrames
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
                                    recordedAudioPowerFrames = nil
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
                        .transition(pageTransition)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Create Entry")
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
                        Label("Cancel", systemImage: "chevron.left")
                    }
                }
            }
            .confirmationDialog(
                "Are you sure you want to discard this entry?",
                isPresented: $showDismissConfirmation,
                titleVisibility: .visible
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
