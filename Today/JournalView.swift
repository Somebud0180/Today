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
    @StateObject var viewModel = VideoViewModel(video: "example")
    let selectedEntry: JournalEntry
    
    var body: some View {
        NavigationStack {
            ZStack {
                VideoPlayerView(player: self.viewModel.player, videoName: selectedEntry.videoName)
                self.playButton
                
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: 256, alignment: .bottom)
                }
                
                VStack {
                    Spacer()
                    TextField("Enter a note...", text: bindingFor(\.note), axis: .vertical)
                        .fontWeight(.medium)
                        .shadow(radius: 12)
                        .lineLimit(5)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxHeight: 256, alignment: .bottom)
                        .padding()
                }
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
            .onAppear { self.viewModel.play() }
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
    
    private var playButton: some View {
        Button(action: {
            self.viewModel.togglePlayback()
        }) {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
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

#Preview {
    @Previewable @State var entry = JournalEntry(videoName: "example", note: "This is a note.")
    JournalView(selectedEntry: entry)
}
