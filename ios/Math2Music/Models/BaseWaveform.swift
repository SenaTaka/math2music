import Foundation

/// The elemental periodic shape used for every additive term
/// (aₙ·shape(n·x)) — a generalization of the original sin-only series.
/// All shapes are phase-aligned with sine (zero-crossing, rising, at θ = 0)
/// so switching waveforms mid-play does not jump the perceived downbeat.
enum BaseWaveform: String, CaseIterable, Identifiable, Codable, Sendable {
    case sine
    case cosine
    case triangle
    case sawtooth
    case square

    var id: String { rawValue }

    /// Short math symbol used in the formula label, e.g. "y = 2.0tri(x)".
    var symbol: String {
        switch self {
        case .sine: return "sin"
        case .cosine: return "cos"
        case .triangle: return "tri"
        case .sawtooth: return "saw"
        case .square: return "sq"
        }
    }

    var displayName: String {
        switch self {
        case .sine: return String(localized: "Sine")
        case .cosine: return String(localized: "Cosine")
        case .triangle: return String(localized: "Triangle")
        case .sawtooth: return String(localized: "Sawtooth")
        case .square: return String(localized: "Square")
        }
    }

    /// Periodic shape function, period 2π, range [-1, 1], phase-aligned with sin.
    @inline(__always)
    func shape(_ theta: Double) -> Double {
        switch self {
        case .sine:
            return sin(theta)
        case .cosine:
            return cos(theta)
        case .triangle:
            // Triangle wave sharing sin's zero-crossings and peak location.
            return (2.0 / Double.pi) * asin(sin(theta))
        case .sawtooth:
            let x = theta / (2.0 * Double.pi)
            return 2.0 * (x - (x + 0.5).rounded(.down))
        case .square:
            return sin(theta) >= 0 ? 1.0 : -1.0
        }
    }
}
