import Foundation

/// Renders the loop audio offline with the exact same DSP core as live
/// playback, driven by the analytic epicycle amplitude per video frame.
///
/// Seamlessness strategy:
/// 1. Render one full warm-up loop first so smoothers and filter states
///    settle into their periodic steady state; keep only the second pass.
/// 2. The 6.5 Hz tremolo completes an integer (or half-integer) number of
///    cycles per loop, so its gain curve matches at the seam.
/// 3. A 30 ms equal-power crossfade of the post-loop tail into the head
///    removes any residual oscillator-phase click.
enum OfflineAudioRenderer {
    struct RenderedAudio {
        let samples: [Float]  // interleaved stereo
        let sampleRate: Double
    }

    static func renderLoop(
        config: LoopVideoExporter.Config,
        sampleRate: Double = 44100
    ) -> RenderedAudio {
        var dsp = FormulaSynthDSP(sampleRate: sampleRate)
        dsp.prepareSustain()
        let parameters = SynthParameters()
        parameters.setHarmonics(config.amplitudes)
        parameters.targetVolume = config.volume
        parameters.isNoteOn = true

        let frameRate = Double(LoopVideoExporter.frameRate)
        let videoFrames = max(1, Int(config.duration * frameRate))
        let framesPerChunk = Int(sampleRate / frameRate)
        let crossfadeFrames = Int(0.03 * sampleRate)

        // Analytic amplitude in [-1, 1] — the exact same function the live
        // view feeds to the synth (VisualizerView), so the exported audio is
        // identical to live playback by construction, independent of any
        // canvas geometry.
        func updateTargets(progress: Double) {
            let offset = EpicycleModel.endOffsetY(
                amplitudes: config.amplitudes,
                phaseTime: progress * 2.0 * Double.pi
            )
            RealtimeMapper.apply(
                normalizedAmplitude: offset,
                baseFrequency: config.baseFrequency,
                minHz: config.minFrequencyHz,
                maxHz: config.maxFrequencyHz,
                scale: config.scale,
                to: parameters
            )
        }

        var captured: [Float] = []
        captured.reserveCapacity(videoFrames * framesPerChunk * 2)
        var chunk = [Float](repeating: 0, count: framesPerChunk * 2)

        for pass in 0..<2 {
            for frame in 0..<videoFrames {
                updateTargets(progress: Double(frame) / Double(videoFrames))
                dsp.renderInterleaved(
                    parameters: parameters,
                    into: &chunk,
                    frameCount: framesPerChunk
                )
                if pass == 1 {
                    captured.append(contentsOf: chunk)
                }
            }
        }

        // Post-loop tail (drive wraps back to progress 0), crossfaded into
        // the head with equal-power curves.
        var tail = [Float](repeating: 0, count: crossfadeFrames * 2)
        updateTargets(progress: 0)
        dsp.renderInterleaved(
            parameters: parameters,
            into: &tail,
            frameCount: crossfadeFrames
        )
        for frame in 0..<crossfadeFrames {
            let t = Double(frame) / Double(crossfadeFrames)
            let fadeIn = sin(t * Double.pi / 2.0)
            let fadeOut = cos(t * Double.pi / 2.0)
            for channel in 0..<2 {
                let index = frame * 2 + channel
                let head = Double(captured[index])
                let tailSample = Double(tail[index])
                captured[index] = Float(head * fadeIn + tailSample * fadeOut)
            }
        }

        return RenderedAudio(samples: captured, sampleRate: sampleRate)
    }
}
