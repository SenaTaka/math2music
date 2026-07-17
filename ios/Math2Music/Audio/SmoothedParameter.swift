import Foundation

/// One-pole smoother equivalent to Web Audio's `setTargetAtTime`:
/// v(t) = target + (v0 − target)·e^(−t/τ)  ⇒  per sample:
/// v = target + (v − target)·coeff, with coeff = e^(−1/(τ·sr)).
struct SmoothedParameter {
    private(set) var value: Double
    var target: Double
    private let coeff: Double

    init(initialValue: Double, tau: Double, sampleRate: Double) {
        value = initialValue
        target = initialValue
        coeff = exp(-1.0 / (tau * sampleRate))
    }

    /// Advance one sample toward the target.
    mutating func advance() {
        value = target + (value - target) * coeff
    }

    /// Jump instantly (used when starting a note to avoid a glide from stale state).
    mutating func snapToTarget() {
        value = target
    }
}
