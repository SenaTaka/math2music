import Foundation

/// RBJ biquad configured to match Web Audio's BiquadFilterNode semantics.
struct Biquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0
    private var a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0
    private var y1 = 0.0, y2 = 0.0

    /// Web Audio interprets lowpass Q in DECIBELS (spec), so the web app's
    /// Q = 5.4 means a linear resonance of 10^(5.4/20) ≈ 1.862.
    mutating func configureLowpass(frequency: Double, qDecibels: Double, sampleRate: Double) {
        let q = max(1e-4, pow(10.0, qDecibels / 20.0))
        let clamped = min(max(frequency, 10.0), sampleRate * 0.45)
        let w0 = 2.0 * Double.pi * clamped / sampleRate
        let cosw0 = cos(w0)
        let alpha = sin(w0) / (2.0 * q)
        let a0 = 1.0 + alpha
        b0 = ((1.0 - cosw0) / 2.0) / a0
        b1 = (1.0 - cosw0) / a0
        b2 = b0
        a1 = (-2.0 * cosw0) / a0
        a2 = (1.0 - alpha) / a0
    }

    /// Web Audio's highshelf ignores Q and uses shelf slope S = 1
    /// with A = 10^(dB/40).
    mutating func configureHighshelf(frequency: Double, gainDecibels: Double, sampleRate: Double) {
        let amp = pow(10.0, gainDecibels / 40.0)
        let clamped = min(max(frequency, 10.0), sampleRate * 0.45)
        let w0 = 2.0 * Double.pi * clamped / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        // alpha for S = 1: sin(w0)/2 · sqrt((A + 1/A)(1/S − 1) + 2) = sin(w0)/2 · sqrt(2)
        let alpha = sinw0 / 2.0 * sqrt(2.0)
        let twoSqrtAAlpha = 2.0 * sqrt(amp) * alpha
        let a0 = (amp + 1.0) - (amp - 1.0) * cosw0 + twoSqrtAAlpha
        b0 = (amp * ((amp + 1.0) + (amp - 1.0) * cosw0 + twoSqrtAAlpha)) / a0
        b1 = (-2.0 * amp * ((amp - 1.0) + (amp + 1.0) * cosw0)) / a0
        b2 = (amp * ((amp + 1.0) + (amp - 1.0) * cosw0 - twoSqrtAAlpha)) / a0
        a1 = (2.0 * ((amp - 1.0) - (amp + 1.0) * cosw0)) / a0
        a2 = ((amp + 1.0) - (amp - 1.0) * cosw0 - twoSqrtAAlpha) / a0
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return y
    }

    mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}
