import Foundation
import UIKit
import ImageIO
import AVFoundation

actor ThumbnailLoader {
    static let shared = ThumbnailLoader()
    private let images = NSCache<NSString, UIImage>()
    private var waveformCache: [UUID: (Int, [Float])] = [:]

    init() { images.totalCostLimit = 32 * 1024 * 1024 }

    @concurrent nonisolated static func videoData(url: URL) async throws -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        let image = try await generator.image(at: .zero).image
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }

    func image(filename: String, pixelSize: Int) async throws -> UIImage? {
        try Task.checkCancellation()
        let key = "\(filename)-\(pixelSize)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let url = MediaStore.urlForMediaFilename(filename) else { return nil }
        for _ in 0..<60 {
            try Task.checkCancellation()
            if MediaStore.downloadIfNeeded(at: url),
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelSize
               ] as CFDictionary) {
                let result = UIImage(cgImage: image)
                images.setObject(result, forKey: key, cost: image.bytesPerRow * image.height)
                return result
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        return nil
    }

    func waveform(id: UUID, data: Data, maxBars: Int) throws -> [CGFloat] {
        try Task.checkCancellation()
        let samples: [Float]
        if let cached = waveformCache[id], cached.0 == data.hashValue { samples = cached.1 }
        else {
            let waveform = try JSONDecoder().decode(CodableAudioWaveform.self, from: data)
            // Only retain the central preview, not the full recording's waveform.
            let count = min(256, waveform.samplesLinear.count)
            let start = (waveform.samplesLinear.count - count) / 2
            samples = Array(waveform.samplesLinear[start..<(start + count)])
            if waveformCache.count >= 100 { waveformCache.removeAll() }
            waveformCache[id] = (data.hashValue, samples)
        }
        let count = min(max(1, maxBars), samples.count)
        let start = (samples.count - count) / 2
        return samples[start..<(start + count)].map { CGFloat($0) }
    }
}
