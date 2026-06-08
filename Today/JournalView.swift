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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen: Bool = DefaultSettings.autoPlayOnOpen
    
    let selectedEntry: JournalEntry
    @State private var isLandscape: Bool = false
    
    // Track loading state explicitly
    @State private var resolvedURL: URL? = nil
    @State private var isDownloading: Bool = false
    @State private var errorMessage: String? = nil
    
    // Hold reference to viewmodels as optionals that activate post-load
    @State private var videoViewModel: VideoViewModel? = nil
    @State private var audioViewModel: AudioViewModel? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Core Content Layout based on state
                if let resolvedURL {
                    if selectedEntry.mediaType == .video, let vm = videoViewModel {
                        VideoPlayerView(player: vm.player)
                    } else if selectedEntry.mediaType == .audio, let vm = audioViewModel {
                        AudioPlayerView(viewModel: vm)
                    }
                    
                    playButton()
                    
                    VStack {
                        Spacer()
                        NoteCardView(note: bindingFor(\.note), isLandscape: $isLandscape)
                    }
                    .ignoresSafeArea()
                    
                } else if isDownloading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Downloading...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    
                } else if let errorMessage {
                    // 3. Error UI Fallback
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { proxy in
                    Color.gray.opacity(0.8)
                        .background(
                            Image("Background1")
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 24)
                                .ignoresSafeArea()
                                .animation(.easeInOut(duration: 0.5), value: colorScheme)
                        )
                        .ignoresSafeArea()
                        .onAppear { isLandscape = proxy.size.width > proxy.size.height }
                        .onChange(of: proxy.size) { isLandscape = proxy.size.width > proxy.size.height }
                }
            }
            .navigationTitle(selectedEntry.title.isEmpty ? selectedEntry.date.formatted(date: .numeric, time: .omitted) : selectedEntry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: {
                        modelContext.delete(selectedEntry)
                        try? modelContext.save()
                        dismiss()
                    }) {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
            // Trigger asynchronous verification sequence as soon as view mounts
            .task {
                await resolveAndPrepareMedia()
            }
            .onDisappear { saveChanges() }
        }
    }
    
    /// Asynchronously monitors and updates downloading states until the file turns up.
    private func resolveAndPrepareMedia() async {
        guard let targetURL = selectedEntry.mediaURL else {
            errorMessage = "Media location identifier is missing."
            return
        }
        
        isDownloading = true
        
        // Loop check: Wait for up to 30 seconds for the cloud asset to download
        for _ in 0..<60 {
            if MediaStore.downloadIfNeeded(at: targetURL) {
                // File is active on local disk! Initialize view models safely
                resolvedURL = targetURL
                
                if selectedEntry.mediaType == .video {
                    videoViewModel = VideoViewModel(fileURL: targetURL)
                    if autoPlayOnOpen { videoViewModel?.play() }
                } else if selectedEntry.mediaType == .audio {
                    audioViewModel = AudioViewModel(fileURL: targetURL, preloadedWaveform: selectedEntry.decodedWaveform())
                    if autoPlayOnOpen { audioViewModel?.play() }
                }
                
                isDownloading = false
                return
            }
            
            // Wait 0.5 seconds before re-checking download status
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
        
        isDownloading = false
        errorMessage = "Download timed out. Check your internet connection."
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
    
    @ViewBuilder
    private func playButton() -> some View {
        if selectedEntry.mediaType == .video, let vm = videoViewModel {
            Button(action: { vm.togglePlayback() }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(16)
                    .glassEffect(.clear.interactive(), in: Circle())
            }
        } else if selectedEntry.mediaType == .audio, let vm = audioViewModel {
            Button(action: { vm.togglePlayback() }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(16)
                    .glassEffect(.clear.interactive(), in: Circle())
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
