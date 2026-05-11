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
    private let minimumCardWidth: CGFloat = 150
    private let cardAspectRatio: CGFloat = 2 / 3
    private let gridSpacing: CGFloat = 24
    private let gridPadding: CGFloat = 12
    
    var body: some View {
        NavigationStack {
            ScrollView {
                GeometryReader { proxy in
                    let availableWidth = proxy.size.width - (gridPadding * 2)
                    let columns = calculateGridColumns(availableWidth: availableWidth)
                    let cardWidth = calculateCardWidth(availableWidth: availableWidth, columns: columns)
                    let cardHeight = cardWidth / cardAspectRatio
                    let cardSize = CGSize(width: cardWidth, height: cardHeight)
                    
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(journalEntries) { journalEntry in
                            NavigationLink {
                                JournalView(selectedEntry: journalEntry)
                            } label: {
                                gridCard(for: journalEntry, size: cardSize)
                            }
                        }
                    }
                    .padding(gridPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
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
    
    private func calculateGridColumns(availableWidth: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int((availableWidth + gridSpacing) / (minimumCardWidth + gridSpacing)))
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    private func calculateCardWidth(availableWidth: CGFloat, columns: [GridItem]) -> CGFloat {
        let columnCount = CGFloat(columns.count)
        let totalSpacingWidth = (columnCount - 1) * gridSpacing
        return max(minimumCardWidth, (availableWidth - totalSpacingWidth) / columnCount)
    }
    
    private func gridCard(for journalEntry: JournalEntry, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            
            let inset: CGFloat = 6
            let innerSize = CGSize(width: size.width - inset * 2,
                                   height: size.height - inset * 2)
            
            if let uiImage = generateThumbnail(journalEntry.videoName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerSize.width, height: innerSize.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: innerSize.width, height: innerSize.height)
            }
            
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
        .frame(width: size.width, height: size.height)
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
