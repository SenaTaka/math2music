import SwiftUI

/// Live epicycle + waveform canvas. TimelineView drives ~60–120 fps redraws;
/// each frame reports the analytic wave amplitude back to the synth
/// (the visual → audio coupling from the web app).
struct VisualizerView: View {
    var state: AppState

    /// Reference holder so the Canvas closure can mutate per-frame scratch
    /// state without touching observable state during rendering.
    final class WaveStore {
        var points: [Double] = []
        var lastGeneration = -1
        var lastSize = CGSize.zero
        /// Accumulated phase advanced by dt × 1.6 × speedFactor each frame,
        /// so BPM changes alter speed continuously instead of teleporting
        /// the phase (which absolute-time × speed would do).
        var phase = 0.0
        var lastTimestamp: Date?
    }

    @State private var waveStore = WaveStore()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let amplitudes = state.amplitudes
                let theme = state.theme
                let store = waveStore

                // Reset the wave trail when a whole new formula is applied
                // (preset / randomize / favorite) or the canvas resizes —
                // stored Y coordinates are absolute, so a resize invalidates
                // them. Individual slider edits keep the trail and morph.
                if store.lastGeneration != state.formulaGeneration || store.lastSize != size {
                    store.lastGeneration = state.formulaGeneration
                    store.lastSize = size
                    store.points.removeAll(keepingCapacity: true)
                }

                // Advance the continuous phase by elapsed time × speed.
                if let last = store.lastTimestamp {
                    let dt = min(max(now.timeIntervalSince(last), 0), 0.1)
                    store.phase += dt * 1.6 * state.speedFactor
                }
                store.lastTimestamp = now

                var loopProgress: Double? = nil
                var phaseTime = store.phase
                if let loopStart = state.loopPreviewStart {
                    let progress = EpicycleModel.normalizeUnit(
                        now.timeIntervalSince(loopStart) / max(state.loopPreviewDuration, 0.001)
                    )
                    loopProgress = progress
                    phaseTime = progress * 2.0 * Double.pi
                }

                let input = SceneRenderer.FrameInput(
                    amplitudes: amplitudes,
                    theme: theme,
                    phaseTime: phaseTime,
                    effectBoost: loopProgress != nil ? 1.3 : 0.65,
                    loopProgress: loopProgress
                )

                context.withCGContext { cg in
                    SceneRenderer.draw(
                        in: cg,
                        size: size,
                        input: input,
                        waveBuffer: &store.points
                    )
                }

                // Analytic amplitude in [-1, 1] (canvas-size independent) —
                // the same function the offline export uses, so live playback
                // and exported audio are identical by construction.
                let normalizedAmplitude = EpicycleModel.endOffsetY(
                    amplitudes: amplitudes,
                    phaseTime: phaseTime
                )
                state.visualizerDidRender(normalizedAmplitude: normalizedAmplitude)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
