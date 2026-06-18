//
//  NoteCardView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/23/26.
//

import SwiftUI
import SwiftData
import FluidAudio

struct NoteCardView: View {
    @EnvironmentObject var transcriptionManager: AudioTranscriptionManager
    @Environment(\.modelContext) private var modelContext
    
    var entry: JournalEntry
    @Binding var isLandscape: Bool
    
    @State private var isExpanded: Bool = false
    @State private var selectedTab: Int = 0
    @State private var transcriptionInProgress: Bool = false
    @State private var finishedTranscription: Bool = false
    
    @FocusState private var isEditing: Bool
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var expandedDragOffset: CGFloat = 0
    
    private let dragThreshold: CGFloat = 32
    
    var body: some View {
        var cardTitle: String {
            switch selectedTab {
            case 0: return "Note"
            default: return "Transcript"
            }
        }
        
        ZStack {
            // Background overlay (only visible when expanded)
            if isExpanded {
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Collapsed state - bottom positioned card
            if !isExpanded {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 5)
                    
                    TabView(selection: $selectedTab) {
                        NotePreviewView
                            .tag(0)
                        
                        TranscriptPreviewView
                            .tag(1)
                    }
                    .tabViewStyle(.page)
                    .frame(maxHeight: 96)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, abs(dragOffset * 2))
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
                        .ignoresSafeArea(edges: .bottom)
                }
                .frame(maxWidth: isLandscape ? 512 : nil, maxHeight: .infinity, alignment: .bottom)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = min(max(value.translation.height, -dragThreshold), 0)
                        }
                        .onEnded { value in
                            let verticalDistance = value.translation.height
                            if verticalDistance < -dragThreshold {
                                withAnimation(.snappy) {
                                    isExpanded = true
                                }
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.snappy) {
                        isExpanded = true
                    }
                }
                .transition(.move(edge: .bottom))
            }
            
            // Expanded state - centered overlay card
            if isExpanded {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                        
                        Text(cardTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    
                    Divider()
                    
                    TabView(selection: $selectedTab) {
                        NoteExpandedView
                            .tag(0)
                        
                        TranscriptExpandedView
                            .tag(1)
                    }
                    .tabViewStyle(.page)
                    .onChange(of: selectedTab) {
                        if selectedTab > 0 {
                            isEditing = false
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 500)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(isLandscape ? 72 : 24)
                .padding(.horizontal, isLandscape ? 72 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: expandedDragOffset)
                .gesture(
                    DragGesture()
                        .updating($expandedDragOffset) { value, state, _ in
                            state = min(dragThreshold, max(0, value.translation.height))
                        }
                        .onEnded { value in
                            let verticalDistance = value.translation.height
                            if verticalDistance > dragThreshold {
                                withAnimation(.snappy) {
                                    isExpanded = false
                                    isEditing = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    isEditing = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    var NotePreviewView: some View {
        Text(entry.note.isEmpty ? "Enter a note..." : entry.note)
            .fontWeight(.medium)
            .foregroundStyle(entry.note.isEmpty ? Color.secondary : Color.white)
            .padding(.horizontal)
            .lineLimit(1)
            .onTapGesture {
                withAnimation(.snappy) {
                    isExpanded = true
                    isEditing = true
                }
            }
    }
    
    var TranscriptPreviewView: some View {
        Text(entry.transcript.isEmpty ? "No transcript" : entry.transcript)
            .fontWeight(.medium)
            .foregroundStyle(entry.transcript.isEmpty ? Color.secondary : Color.white)
            .padding(.horizontal)
            .lineLimit(1)
            .onTapGesture {
                withAnimation(.snappy) {
                    isExpanded = true
                }
            }
    }
    
    var NoteExpandedView: some View {
        Group {
            VStack(spacing: 0) {
                TextField("Enter a note...", text: bindingFor(\.note), axis: .vertical)
                    .focused($isEditing)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding()
                
                Spacer()
            }
        }
    }
    
    var TranscriptExpandedView: some View {
        VStack {
            if entry.transcript.isEmpty {
                Spacer()
                
                Group {
                    Image(systemName: "waveform.slash")
                        .resizable()
                        .frame(maxWidth: 72, maxHeight: 72)
                    
                    Text("No Transcript")
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding()
                
                Button("Transcribe Entry", action: {
                    Task {
                        await transcribeEntry()
                    }
                })
                .buttonStyle(.glass)
                .disabled(transcriptionInProgress || finishedTranscription)
                
                if finishedTranscription {
                    Text("The entry couldn't be transcribed. It may not be recognizable by the app.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                
                Spacer()
            } else {
                Text(entry.transcript)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding()
                
                Spacer()
            }
        }
    }
    
    func transcribeEntry() async {
        guard entry.transcript.isEmpty && !transcriptionInProgress && !finishedTranscription else { return }
        
        transcriptionInProgress = true
        
        let result: (ASRResult?, Bool)
        if entry.mediaType == .audio, let audioURL = entry.mediaURL  {
            result = await transcriptionManager.transcribeAudio(audioURL)
        } else if entry.mediaType == .video, let videoURL = entry.mediaURL {
            result = await transcriptionManager.transcribeVideo(videoURL)
        } else {
            result = (.none, false)
        }
        
        if let transcript = result.0?.text {
            Task { @MainActor in
                withAnimation(.snappy) {
                    entry.transcript = transcript
                    transcriptionInProgress = false
                    finishedTranscription = true
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func bindingFor<Value>(_ keyPath: ReferenceWritableKeyPath<JournalEntry, Value>) -> Binding<Value> {
        Binding(
            get: { entry[keyPath: keyPath] },
            set: { newValue in
                entry[keyPath: keyPath] = newValue
                try? modelContext.save()
            }
        )
    }
}
