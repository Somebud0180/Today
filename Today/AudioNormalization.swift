import Foundation
import CoreGraphics

/// Default noise floor threshold in dBFS used for normalization
public let DefaultNoiseFloorThreshold: Float = -50.0

/// Convert a dBFS value into a 0..1 normalized linear amplitude for waveform rendering.
/// - Parameters:
///   - db: dBFS value (negative numbers typically down to -160 for silence)
///   - noiseFloorThreshold: the dB level below which audio is treated as silence
///   - silenceDb: a sentinel dB value used when gating below the noise floor (default -160)
/// - Returns: normalized linear amplitude in 0...1
public func normalizeDbToLinear(_ db: Float, noiseFloorThreshold: Float = DefaultNoiseFloorThreshold, silenceDb: Float = -160.0) -> Float {
    // Treat values below the noise floor as silence
    guard db >= noiseFloorThreshold else { return 0 }

    // Convert dBFS to linear amplitude (0..1)
    let linear = pow(10.0, db / 20.0)

    // Remap the small linear range so the configured noise floor maps to 0 and 0 dB maps to 1.
    // This keeps the perceptual log curve while giving the UI more usable dynamic range.
    let minLinear = pow(10.0, noiseFloorThreshold / 20.0)
    let normalized = (linear - minLinear) / (1.0 - minLinear)
    return max(0, min(1, normalized))
}
