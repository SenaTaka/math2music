import Foundation

/// Pure geometry port of the web `buildEpicycle` (FourierVisualizer.tsx):
/// chained circles whose radii are the normalized harmonic amplitudes and
/// whose angles advance at n × phaseTime. The chain endpoint traces the
/// waveform and drives the audio.
enum EpicycleModel {
    struct Circle {
        let centerX: Double
        let centerY: Double
        let radius: Double
        let colorIndex: Int
    }

    struct Trace {
        let circles: [Circle]
        let endX: Double
        let endY: Double
    }

    static func normalizeUnit(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1.0)
        return wrapped < 0 ? wrapped + 1.0 : wrapped
    }

    static func totalAmplitude(_ amplitudes: [Double]) -> Double {
        var total = 0.0
        for amplitude in amplitudes {
            total += abs(amplitude)
        }
        return total > 0 ? total : 1.0
    }

    static func buildTrace(
        amplitudes: [Double],
        originX: Double,
        originY: Double,
        orbitSpan: Double,
        phaseTime: Double
    ) -> Trace {
        let total = totalAmplitude(amplitudes)
        var circles: [Circle] = []
        circles.reserveCapacity(amplitudes.count)
        var x = originX
        var y = originY
        for (index, amplitude) in amplitudes.enumerated() {
            guard amplitude != 0 else { continue }
            let n = Double(index + 1)
            let radius = (abs(amplitude) / total) * orbitSpan
            // Negative amplitude becomes a π phase flip (web behavior).
            let angle = phaseTime * n + (amplitude < 0 ? Double.pi : 0)
            let nextX = x + radius * cos(angle)
            let nextY = y + radius * sin(angle)
            // Color by ordinal position among the ACTIVE terms (web keys
            // NEON_COLORS by position in the compact terms array).
            circles.append(Circle(centerX: x, centerY: y, radius: radius, colorIndex: circles.count))
            x = nextX
            y = nextY
        }
        return Trace(circles: circles, endX: x, endY: y)
    }

    /// Vertical endpoint offset from the origin in units of `orbitSpan`.
    /// Used by the offline audio pass to reproduce the visual → audio
    /// coupling analytically, and by the live/loop wave trace so the drawn
    /// waveform always matches the selected base waveform (the rotating
    /// epicycle rings themselves stay literal circular motion — only the
    /// composite waveform value changes with the selected shape).
    static func endOffsetY(amplitudes: [Double], phaseTime: Double, waveform: BaseWaveform) -> Double {
        let total = totalAmplitude(amplitudes)
        var offset = 0.0
        for (index, amplitude) in amplitudes.enumerated() {
            guard amplitude != 0 else { continue }
            let n = Double(index + 1)
            let angle = phaseTime * n + (amplitude < 0 ? Double.pi : 0)
            offset += (abs(amplitude) / total) * waveform.shape(angle)
        }
        return offset
    }
}
