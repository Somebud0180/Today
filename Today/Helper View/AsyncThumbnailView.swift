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
        .task(id: entry.thumbnailURLString) {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard entry.mediaType == .video else { return }
        
        guard let thumbURL = entry.thumbnailURL else {
            return
        }
        
        isDownloading = true
        
        for _ in 0..<30 {
            if MediaStore.downloadIfNeeded(at: thumbURL) {
                if let data = try? Data(contentsOf: thumbURL),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.uiImage = image
                        self.isDownloading = false
                    }
                    return
                }
            }
            
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
        
        await MainActor.run { isDownloading = false }
    }
}
