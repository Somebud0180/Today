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
            
            ViewThatFits {
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
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                        
                    Spacer()
                }
                .padding(12)
                
                VStack(alignment: .leading) {
                    let date = journalEntry.date.formatted(.dateTime.month(.abbreviated).day())
                    Text(date)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens the journal entry")
        .accessibilityAddTraits(.isButton)
    }
}

extension GridCardView {
    /// Returns a human-friendly media type string for accessibility.
    private var accessibilityMediaType: String {
        switch journalEntry.mediaType {
        case .video: return "Video"
        case .audio: return "Audio"
        }
    }
    
    /// Title if present; otherwise a formatted date string.
    private var accessibilityPrimaryText: String {
        if !journalEntry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return journalEntry.title
        } else {
            return journalEntry.date.formatted(date: .long, time: .omitted)
        }
    }
    
    /// Full label announced by VoiceOver, e.g. "Video, Family Picnic" or "Audio, June 23, 2026".
    var accessibilityTitle: String {
        "\(accessibilityMediaType) entry, \(accessibilityPrimaryText)"
    }
    
    /// Secondary value for additional context. If a title exists, provide the date; otherwise empty.
    var accessibilityValue: String {
        if !journalEntry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return journalEntry.date.formatted(date: .long, time: .omitted)
        } else {
            return ""
        }
    }
    
    static func accessibilityTitle(for entry: JournalEntry) -> String {
        let mediaType: String
        switch entry.mediaType {
        case .video: mediaType = "Video"
        case .audio: mediaType = "Audio"
        }
        let primary: String
        if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            primary = entry.title
        } else {
            primary = entry.date.formatted(date: .long, time: .omitted)
        }
        return "\(mediaType) entry, \(primary)"
    }

    static func accessibilityValue(for entry: JournalEntry) -> String {
        if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry.date.formatted(date: .long, time: .omitted)
        } else {
            return ""
        }
    }
}
