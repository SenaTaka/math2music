import Foundation

/// Optional musical quantization for the waveform-driven pitch.
/// Frequencies are snapped to 12-TET notes of the selected scale, rooted at A.
enum MusicalScale: String, CaseIterable, Identifiable, Codable {
    case off
    case pentatonic
    case major
    case minor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return String(localized: "Free")
        case .pentatonic:
            return String(localized: "Pentatonic")
        case .major:
            return String(localized: "Major")
        case .minor:
            return String(localized: "Minor")
        }
    }

    /// Allowed pitch classes relative to the root A (A = 0).
    private var pitchClasses: [Int]? {
        switch self {
        case .off:
            return nil
        case .pentatonic:
            // A minor pentatonic: A C D E G
            return [0, 3, 5, 7, 10]
        case .major:
            return [0, 2, 4, 5, 7, 9, 11]
        case .minor:
            return [0, 2, 3, 5, 7, 8, 10]
        }
    }

    /// Snap a frequency to the nearest scale note (12-TET, A4 = 440 Hz).
    func snap(_ frequency: Double) -> Double {
        guard let classes = pitchClasses, frequency > 0 else { return frequency }
        let midi = 69.0 + 12.0 * log2(frequency / 440.0)
        let center = Int(midi.rounded())
        var best = midi.rounded()
        var bestDistance = Double.infinity
        for candidate in (center - 12)...(center + 12) {
            let pitchClass = ((candidate - 69) % 12 + 12) % 12
            guard classes.contains(pitchClass) else { continue }
            let distance = abs(Double(candidate) - midi)
            if distance < bestDistance {
                bestDistance = distance
                best = Double(candidate)
            }
        }
        return 440.0 * pow(2.0, (best - 69.0) / 12.0)
    }
}
