//
//  JournalView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/7/26.
//

import SwiftUI

struct JournalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel = VideoViewModel(video: "example")
    
    var body: some View {
        NavigationView {
            ZStack {
                VideoPlayerView(player: self.viewModel.player, videoName: "example")
                // Add modifiers here easily: .padding() .blur() etc.
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
                    Text("Enter a note...")
                        .foregroundStyle(.secondary)
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
            .navigationTitle("05/07/26")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onAppear { self.viewModel.play() }
        }
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
    JournalView()
}
