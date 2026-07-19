import CoreGraphics
import Foundation

/// Draws one frame of the epicycle + waveform scene into a CGContext using a
/// TOP-LEFT origin coordinate system (like HTML canvas). The same renderer is
/// used by the live SwiftUI Canvas (`GraphicsContext.withCGContext`, already
/// top-left) and by the offline video exporter (which flips its bitmap
/// context before calling in).
///
/// All drawing constants are ported verbatim from `FourierVisualizer.tsx`.
enum SceneRenderer {
    struct FrameInput {
        let amplitudes: [Double]
        let theme: NeonTheme
        /// Radians. Continuous mode: seconds × 1.6 × speedFactor.
        /// Loop mode: loopProgress × 2π.
        let phaseTime: Double
        let effectBoost: Double
        /// Non-nil enables loop mode: the waveform is computed analytically
        /// so frame 0 and frame N match exactly.
        let loopProgress: Double?
        /// Elemental shape used to combine harmonic terms into the drawn
        /// waveform (audio uses the same shape — see FormulaSynthDSP).
        let waveform: BaseWaveform
    }

    static let waveStep = 2.25

    /// Renders a frame and returns the normalized wave amplitude
    /// (endY − originY) / (0.4 × height), the value that drives the audio.
    @discardableResult
    static func draw(
        in ctx: CGContext,
        size: CGSize,
        input: FrameInput,
        waveBuffer: inout [Double]
    ) -> Double {
        let width = Double(size.width)
        let height = Double(size.height)
        guard width > 1 && height > 1 else { return 0 }

        let originX = width * 0.2
        let originY = height * 0.5
        let waveStartX = width * 0.56
        let rightPadding = 18.0
        let orbitSpan = min(width * 0.28, height * 0.45)
        let boost = min(max(abs(input.effectBoost), 0), 2)
        // Loop mode enforces the phase invariant internally, so a caller can
        // never pass a phaseTime that disagrees with loopProgress.
        let phaseTime = input.loopProgress.map { $0 * 2.0 * Double.pi } ?? input.phaseTime
        let theme = input.theme

        let trace = EpicycleModel.buildTrace(
            amplitudes: input.amplitudes,
            originX: originX,
            originY: originY,
            orbitSpan: orbitSpan,
            phaseTime: phaseTime
        )
        let endX = trace.endX
        let endY = trace.endY

        // --- Background: black + pulsing radial gradient ---
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let pulse = 0.16 + sin(phaseTime * 0.7) * 0.07 + boost * 0.04
        let gradientColors = [
            theme.backgroundInner.cgColor(alpha: max(0, min(1, pulse))),
            theme.backgroundMid.cgColor(alpha: 0.12),
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.92),
        ] as CFArray
        let locations: [CGFloat] = [0, 0.4, 1]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: gradientColors,
            locations: locations
        ) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: width * 0.34, y: height * 0.42),
                startRadius: 12,
                endCenter: CGPoint(x: width * 0.5, y: height * 0.5),
                endRadius: CGFloat(width * 0.9),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        // --- Epicycle circles + connector segments ---
        let colors = theme.epicycleColors
        for (index, circle) in trace.circles.enumerated() {
            let next = index + 1 < trace.circles.count ? trace.circles[index + 1] : nil
            let nextX = next?.centerX ?? endX
            let nextY = next?.centerY ?? endY
            let color = colors[circle.colorIndex % colors.count]
            let glow = 16.0 + boost * 10.0

            ctx.setStrokeColor(color.cgColor())
            ctx.setShadow(offset: .zero, blur: CGFloat(glow), color: color.cgColor())
            ctx.setLineWidth(CGFloat(1.15 + Double(index) * 0.08))
            ctx.strokeEllipse(in: CGRect(
                x: circle.centerX - circle.radius,
                y: circle.centerY - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            ))

            ctx.setLineWidth(1.9)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: circle.centerX, y: circle.centerY))
            ctx.addLine(to: CGPoint(x: nextX, y: nextY))
            ctx.strokePath()
        }

        // --- Endpoint dot ---
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        ctx.setFillColor(white)
        ctx.setShadow(offset: .zero, blur: CGFloat(24.0 + boost * 10.0), color: white)
        let dotRadius = 3.2 + boost * 0.7
        ctx.fillEllipse(in: CGRect(
            x: endX - dotRadius,
            y: endY - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))

        // --- Waveform samples ---
        let maxPoints = max(36, Int((width - waveStartX - rightPadding) / waveStep))
        var wavePoints: [Double] = []
        if let loopProgress = input.loopProgress {
            wavePoints.reserveCapacity(maxPoints)
            for index in 0..<maxPoints {
                let sampleProgress = EpicycleModel.normalizeUnit(
                    loopProgress - Double(index) / Double(maxPoints)
                )
                let offset = EpicycleModel.endOffsetY(
                    amplitudes: input.amplitudes,
                    phaseTime: sampleProgress * 2.0 * Double.pi,
                    waveform: input.waveform
                )
                wavePoints.append(originY + offset * orbitSpan)
            }
        } else {
            // The rotating rings stay literal circular motion (endX/endY,
            // drawn above); the drawn wave trail instead uses the same
            // generalized shape as the audio synth so picture and sound
            // always agree, even when the base waveform isn't sine.
            let sampleY = originY + EpicycleModel.endOffsetY(
                amplitudes: input.amplitudes,
                phaseTime: phaseTime,
                waveform: input.waveform
            ) * orbitSpan
            waveBuffer.insert(sampleY, at: 0)
            if waveBuffer.count > maxPoints {
                waveBuffer.removeLast(waveBuffer.count - maxPoints)
            }
            wavePoints = waveBuffer
        }

        let normalizedAmplitude = EpicycleModel.endOffsetY(
            amplitudes: input.amplitudes,
            phaseTime: phaseTime,
            waveform: input.waveform
        )

        // --- Axes ---
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        let faintWhite = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35)
        ctx.setStrokeColor(faintWhite)
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: waveStartX, y: originY))
        ctx.addLine(to: CGPoint(x: width - rightPadding, y: originY))
        ctx.strokePath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: waveStartX, y: originY - height * 0.4))
        ctx.addLine(to: CGPoint(x: waveStartX, y: originY + height * 0.4))
        ctx.strokePath()

        // --- Dashed connector from the dot to the wave head ---
        ctx.setLineDash(phase: 0, lengths: [4, 6])
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.45))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: endX, y: endY))
        ctx.addLine(to: CGPoint(x: waveStartX, y: wavePoints.first ?? endY))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // --- Main waveform stroke (two passes: crisp + wide glow) ---
        if !wavePoints.isEmpty {
            let wavePath = CGMutablePath()
            for (index, pointY) in wavePoints.enumerated() {
                let pointX = waveStartX + Double(index) * waveStep
                if index == 0 {
                    wavePath.move(to: CGPoint(x: pointX, y: pointY))
                } else {
                    wavePath.addLine(to: CGPoint(x: pointX, y: pointY))
                }
            }
            let waveColor = theme.waveColor.cgColor()
            ctx.setStrokeColor(waveColor)
            ctx.setShadow(offset: .zero, blur: CGFloat(28.0 + boost * 14.0), color: waveColor)
            ctx.setLineWidth(CGFloat(2.4 + boost * 0.5))
            ctx.beginPath()
            ctx.addPath(wavePath)
            ctx.strokePath()

            ctx.setAlpha(0.35)
            ctx.setLineWidth(CGFloat(5.4 + boost))
            ctx.beginPath()
            ctx.addPath(wavePath)
            ctx.strokePath()
            ctx.setAlpha(1)

            // --- Ghost reflection ---
            ctx.setStrokeColor(faintWhite)
            ctx.setShadow(offset: .zero, blur: 16, color: faintWhite)
            ctx.setLineWidth(1.1)
            ctx.beginPath()
            for (index, pointY) in wavePoints.enumerated() {
                let pointX = waveStartX + Double(index) * waveStep
                let ghostY = originY + (originY - pointY) * 0.32
                if index == 0 {
                    ctx.move(to: CGPoint(x: pointX, y: ghostY))
                } else {
                    ctx.addLine(to: CGPoint(x: pointX, y: ghostY))
                }
            }
            ctx.strokePath()
        }

        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        return normalizedAmplitude
    }
}
