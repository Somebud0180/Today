//
//  GridCardView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/8/26.
//

import SwiftUI

struct GridCardView: View {
    var journalEntry: JournalEntry
    var size: CGSize
    
    init(for journalEntry: JournalEntry, size: CGSize) {
        self.journalEntry = journalEntry
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if journalEntry.mediaType == .video {
                AsyncThumbnailView(entry: journalEntry, targetSize: size)
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else if let waveformLevels = journalEntry.audioWaveformThumbnailLevels(maxBars: max(1, Int(size.width / 7))) {
                WaveformView(levels: waveformLevels, isThumbnailView: true)
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            
            if size.width > 100 {
                VStack(alignment: .leading) {
                    Text(
                        journalEntry.title.isEmpty ? journalEntry.date.formatted(date: .numeric, time: .omitted) : journalEntry.title
                    )
                    .lineLimit(2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !journalEntry.title.isEmpty {
                        Text(journalEntry.date.formatted(date: .numeric, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    
                    Spacer()
                }
                .padding(12)
            } else {
                VStack(alignment: .leading) {
                    let date = journalEntry.date.formatted(date: .abbreviated, time: .omitted)
                    Text(date.dropLast(6))
                        .lineLimit(2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing)
                    
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: size.width, height: size.height)
    }
}
