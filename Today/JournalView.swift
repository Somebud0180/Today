//
//  JournalView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/7/26.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject var videoViewModel: VideoViewModel
    @StateObject var audioViewModel: AudioViewModel
    let selectedEntry: JournalEntry
    
    init(selectedEntry: JournalEntry) {
        self.selectedEntry = selectedEntry
        
        let waveform = selectedEntry.decodedWaveform()
        
        _videoViewModel = StateObject(wrappedValue: VideoViewModel(fileURL: selectedEntry.mediaURL!))
        _audioViewModel = StateObject(wrappedValue: AudioViewModel(
            fileURL: selectedEntry.mediaURL!,
            preloadedWaveform: waveform
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if selectedEntry.mediaType == .video {
                    VideoPlayerView(player: videoViewModel.player)
                } else if selectedEntry.mediaType == .audio {
                    AudioPlayerView(viewModel: audioViewModel)
                }
                
                playButton()
                
                VStack {
                    Spacer()
                    NoteCardView(note: bindingFor(\.note))
                }
                .ignoresSafeArea()
            }
            .preferredColorScheme(.dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()
            }
            .navigationTitle(selectedEntry.title.isEmpty ? selectedEntry.date.formatted(date: .numeric, time: .omitted) : selectedEntry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(
                        role: .destructive,
                        action: {
                            modelContext.delete(selectedEntry)
                            try? modelContext.save()
                            dismiss()
                        }) {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red)
                }
            }
            .onAppear {
                if selectedEntry.mediaType == .video {
                    videoViewModel.play()
                } else if selectedEntry.mediaType == .audio {
                    audioViewModel.play()
                }
            }
            .onDisappear { saveChanges() }
        }
    }
    
    private func bindingFor<Value>(_ keyPath: ReferenceWritableKeyPath<JournalEntry, Value>) -> Binding<Value> {
        Binding(
            get: { selectedEntry[keyPath: keyPath] },
            set: { newValue in
                selectedEntry[keyPath: keyPath] = newValue
                saveChanges()
            }
        )
    }
    
    private func saveChanges() {
        try? modelContext.save()
    }
    
    private func playButton() -> some View {
        if selectedEntry.mediaType == .video {
            return Group {
                Button(action: {
                    videoViewModel.togglePlayback()
                }) {
                    Image(systemName: videoViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(16)
                        .glassEffect(
                            .clear
                                .interactive(),
                            in: Circle())
                }
            }
        }  else {
            return Group {
                Button(action: {
                    audioViewModel.togglePlayback()
                }) {
                    Image(systemName: audioViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(16)
                        .glassEffect(
                            .clear
                                .interactive(),
                            in: Circle())
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var entry = JournalEntry(
        title: "Sample Entry",
        note: "This is a sample journal entry.",
        mediaData: try! Data(contentsOf: Bundle.main.url(forResource: "example", withExtension: "mp4")!),
        fileExtension: "mp4",
        mediaType: .video
    )
    
    JournalView(selectedEntry: entry!)
}
