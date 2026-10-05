//
//  AsyncThumbnailView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/8/26.
//

import SwiftUI

struct AsyncThumbnailView: View {
    let entry: JournalEntry
    let targetSize: CGSize
    
    @Environment(\.displayScale) private var displayScale
    @State private var uiImage: UIImage? = nil
    @State private var isDownloading: Bool = false
    
    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: targetSize.width, height: targetSize.height)
            } else if isDownloading {
                ProgressView()
                    .scaleEffect(targetSize.width > 100 ? 1.0 : 0.7)
                    .frame(width: targetSize.width, height: targetSize.height)
            } else {
                ZStack {
                    Color.black.opacity(0.15)
                    Image(systemName: entry.mediaType == .video ? "video.slash" : "waveform")
                        .font(.system(size: min(targetSize.width * 0.3, 24)))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(width: targetSize.width, height: targetSize.height)
            }
        }
        .task(id: "\(entry.thumbnailURLString ?? "")-\(pixelSize)") {
            await loadThumbnail()
        }
    }
    
    private var pixelSize: Int {
        // Bucket dimensions so pinch gestures reuse nearby cached sizes.
        max(128, Int(ceil(max(targetSize.width, targetSize.height) * displayScale / 128)) * 128)
    }

    private func loadThumbnail() async {
        guard let filename = entry.thumbnailURLString else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let image = try await ThumbnailLoader.shared.image(filename: filename, pixelSize: pixelSize)
            try Task.checkCancellation()
            uiImage = image
        } catch { /* Cancellation leaves the existing thumbnail in place. */ }
    }
}
