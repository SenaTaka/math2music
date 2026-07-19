import Foundation

/// A formula is a partial Fourier series y = Σ aₙ·sin(nx), n = 1...8.
/// The 8 amplitudes are the user-editable "formula" — presets are just
/// starting slider configurations.
enum Formula {
    static let harmonicCount = 8
    static let amplitudeLimit = 5.0

    /// Human-readable formula label, e.g. "y = 2.0sin(x) + 0.7sin(3x)".
    static func label(for amplitudes: [Double], waveform: BaseWaveform) -> String {
        var parts: [String] = []
        for (index, amplitude) in amplitudes.enumerated() {
            let rounded = (amplitude * 10).rounded() / 10
            guard rounded != 0 else { continue }
            let n = index + 1
            let magnitude = abs(rounded)
            let coefficient = String(format: "%.1f", magnitude)
            let argument = n == 1 ? "x" : "\(n)x"
            let term = "\(coefficient)\(waveform.symbol)(\(argument))"
            if parts.isEmpty {
                parts.append(rounded < 0 ? "−\(term)" : term)
            } else {
                parts.append(rounded < 0 ? "− \(term)" : "+ \(term)")
            }
        }
        guard !parts.isEmpty else { return "y = 0" }
        return "y = " + parts.joined(separator: " ")
    }

    static func clampAmplitude(_ value: Double) -> Double {
        return min(max(value, -amplitudeLimit), amplitudeLimit)
    }
}

struct FormulaPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let baseFrequency: Double
    /// Always `Formula.harmonicCount` elements; index i is harmonic n = i + 1.
    let amplitudes: [Double]
}

extension FormulaPreset {
    /// The web app's four presets adapted into the 8-harmonic slider space,
    /// plus four new paid-tier presets.
    static let all: [FormulaPreset] = [
        FormulaPreset(
            id: "smooth",
            name: "Smooth",
            baseFrequency: 110,
            // 1.5 / sqrt(n) for n = 1...7 (web original)
            amplitudes: [1.5, 1.061, 0.866, 0.75, 0.671, 0.612, 0.567, 0]
        ),
        FormulaPreset(
            id: "punch",
            name: "Punch",
            baseFrequency: 132,
            // y = 5sin(x) - sin(5x) (web original)
            amplitudes: [5, 0, 0, 0, -1, 0, 0, 0]
        ),
        FormulaPreset(
            id: "square",
            name: "Square",
            baseFrequency: 147,
            // 2 / n for odd n (web original, first four odd harmonics)
            amplitudes: [2, 0, 0.667, 0, 0.4, 0, 0.286, 0]
        ),
        FormulaPreset(
            id: "chaos",
            name: "Chaos",
            baseFrequency: 165,
            // 6 / n for odd n >= 3 (web original folded into the 8-harmonic space)
            amplitudes: [0, 0, 2, 0, 1.2, 0, 0.857, 0]
        ),
        FormulaPreset(
            id: "saw",
            name: "Saw",
            baseFrequency: 124,
            // 2·(-1)^(n+1) / n — sawtooth series
            amplitudes: [2, -1, 0.667, -0.5, 0.4, -0.333, 0.286, -0.25]
        ),
        FormulaPreset(
            id: "organ",
            name: "Organ",
            baseFrequency: 110,
            // drawbar-style octaves: 1, 2, 4, 8
            amplitudes: [2, 1.2, 0, 1, 0, 0, 0, 0.8]
        ),
        FormulaPreset(
            id: "bell",
            name: "Bell",
            baseFrequency: 196,
            // sparse upper partials for a bell-like shimmer
            amplitudes: [1.5, 0, 0, 1, 0.8, 0, 0.6, 0]
        ),
        FormulaPreset(
            id: "pulse",
            name: "Pulse",
            baseFrequency: 138,
            // 25%-duty pulse series: sin(nπ/4)/n scaled by 3
            amplitudes: [2.1, 1.5, 0.7, 0, -0.4, -0.5, -0.3, 0]
        ),
    ]

    static let defaultPreset = all[0]
}
