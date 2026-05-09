//
//  ContentView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/6/26.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    let gridRows = [GridItem(.adaptive(minimum: 150))]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridRows, spacing: 24) {
                    ForEach(journalEntries) { journalEntry in
                        NavigationLink {
                            JournalView(selectedEntry: journalEntry)
                        } label: {
                            gridCard(for: journalEntry)
                        }
                    }
                }
                .padding(12)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        let newEntry = JournalEntry(videoName: "example", note: "")
                        modelContext.insert(newEntry)
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func gridCard(for journalEntry: JournalEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 16)
                )
                
            
            // Use GeometryReader so the card defines its own size (2:3) and the image fills that area
            GeometryReader { proxy in
                let inset: CGFloat = 6
                let innerSize = CGSize(width: proxy.size.width - inset * 2,
                                       height: proxy.size.height - inset * 2)

                if let uiImage = generateThumbnail(journalEntry.videoName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: innerSize.width, height: innerSize.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // center inside the GeometryReader
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                } else {
                    // Fallback placeholder when thumbnail can't be generated
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: innerSize.width, height: innerSize.height)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .padding(6)
            
            VStack(alignment: .leading) {
                Spacer()
                Text(
                    journalEntry.title.isEmpty ? journalEntry.date.formatted(date: .numeric, time: .omitted) : journalEntry.title
                )
                .lineLimit(2)
                .fontWeight(.heavy)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        // Ensure the card itself defines the 2:3 aspect ratio so the image fills it
        .aspectRatio(2/3, contentMode: .fit)
    }
    
    private func generateThumbnail(_ videoName: String) -> UIImage? {
        // Step 1: Get video URL from bundle
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") else {
            print("Video file not found.")
            return nil
        }
        
        // Step 2: Create AVAsset
        let asset = AVURLAsset(url: videoURL)
        
        // Step 3: Configure image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 200)
        
        // Step 4: Generate thumbnail at 1 second
        let time = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
        
        do {
            var actualTime = CMTime.zero
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
            let thumbnail = UIImage(cgImage: cgImage)
            return thumbnail
        } catch {
            print("Thumbnail generation error: \(error)")
            return nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntries.self, inMemory: true)
}
