import Foundation

/// Pure, allocation-free DSP core mirroring the web app's Web Audio chain
/// (`lib/audio.ts`), tuned for musical comfort rather than 1:1 web parity:
///
///   additive oscillator (selectable base shape) + 0.18·triangle sub-osc
///   (0.5× freq)
///     → lowpass biquad (Q 2.0 dB) → highshelf 1200 Hz (gentler than web)
///     → tanh soft-clip safety ceiling (unity gain at low level, only the
///       rare filter/shelf peak actually gets rounded off)
///     → equal-power pan → gain × (volume + 0.08·sin(2π·6.5·t))
///
/// The original web-matching saturator was `(1+k)x/(1+k|x|)` with k = 280 —
/// a near-brickwall limiter whose zero-signal slope is (1+k) = 281×, so it
/// slammed almost any nonzero sample to within a hair of ±1 regardless of
/// how quiet the passage was. That is what made every preset sound like a
/// harsh, constantly-clipped square wave. `tanh(x)` has unity gain at zero
/// and only compresses the genuine peaks (the additive sum is already
/// bounded to ±1 by construction; only the resonant lowpass/highshelf stage
/// can push a sample past that), so normal playing stays clean while big
/// transients still can't clip or crackle.
///
/// No AVFoundation dependency — the same core drives the realtime
/// AVAudioSourceNode and the offline loop-video export, so live and
/// exported audio (and the base waveform) are always identical.
struct FormulaSynthDSP {
    enum EnvelopeStage {
        case idle
        case active
        case releasing
    }

    static let tremoloFrequency = 6.5
    static let tremoloDepth = 0.08
    static let subOscGain = 0.18
    /// tanh drive: 1.0 = unity gain at low level, gentle rounding near ±1.
    static let saturationDrive = 1.1
    static let lowpassQDecibels = 2.0
    static let shelfFrequency = 1200.0

    let sampleRate: Double
    private let nyquist: Double

    private var mainPhase = 0.0
    private var subPhase = 0.0
    private var lfoPhase = 0.0

    private var frequency: SmoothedParameter
    private var subOscFrequency: SmoothedParameter
    private var cutoff: SmoothedParameter
    private var pan: SmoothedParameter
    private var shelfGain: SmoothedParameter
    private var volume: SmoothedParameter
    private var harmonicAmps: [SmoothedParameter]

    private var lowpass = Biquad()
    private var highshelf = Biquad()
    private var lastCutoff = 2800.0
    private var lastShelfGain = 4.0
    private var coefficientCountdown = 0
    private var waveform = BaseWaveform.sine

    private var envelope = 0.0
    private var stage = EnvelopeStage.idle
    private var sustainImmediately = false
    private let attackStep: Double
    private let releaseFactor: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        nyquist = sampleRate * 0.5
        frequency = SmoothedParameter(initialValue: 110, tau: 0.018, sampleRate: sampleRate)
        subOscFrequency = SmoothedParameter(initialValue: 55, tau: 0.02, sampleRate: sampleRate)
        cutoff = SmoothedParameter(initialValue: 2800, tau: 0.04, sampleRate: sampleRate)
        pan = SmoothedParameter(initialValue: 0, tau: 0.07, sampleRate: sampleRate)
        shelfGain = SmoothedParameter(initialValue: 4.0, tau: 0.06, sampleRate: sampleRate)
        volume = SmoothedParameter(initialValue: 0.18, tau: 0.015, sampleRate: sampleRate)
        harmonicAmps = (0..<Formula.harmonicCount).map { _ in
            SmoothedParameter(initialValue: 0, tau: 0.01, sampleRate: sampleRate)
        }
        // Linear 0 → 1 over 0.08 s (web attack ramps 0 → volume over 0.08 s).
        attackStep = 1.0 / (0.08 * sampleRate)
        // Exponential decay reaching ~0.5% in 0.5 s (web: ramp to 0.001 over 0.5 s).
        releaseFactor = pow(0.001 / 0.2, 1.0 / (0.5 * sampleRate))
        lowpass.configureLowpass(frequency: 2800, qDecibels: Self.lowpassQDecibels, sampleRate: sampleRate)
        highshelf.configureHighshelf(frequency: Self.shelfFrequency, gainDecibels: 4.0, sampleRate: sampleRate)
    }

    /// Offline export: start in full sustain, skipping the attack ramp.
    mutating func prepareSustain() {
        sustainImmediately = true
    }

    /// Pull the latest targets from the shared parameter block.
    /// Called once per render buffer — safe on the audio thread.
    mutating func syncTargets(from parameters: SynthParameters) {
        waveform = parameters.waveform
        frequency.target = parameters.targetMainFrequency
        subOscFrequency.target = parameters.targetSubFrequency
        cutoff.target = parameters.targetCutoff
        pan.target = parameters.targetPan
        shelfGain.target = parameters.targetShelfGain
        volume.target = parameters.targetVolume
        for index in 0..<harmonicAmps.count {
            harmonicAmps[index].target = parameters.harmonicAmplitude(index)
        }

        let noteOn = parameters.isNoteOn
        if noteOn && stage == .idle {
            stage = .active
            envelope = sustainImmediately ? 1.0 : 0.0
            sustainImmediately = false  // one-shot (offline export only)
            // Start clean: no glide from stale realtime state, no filter ring.
            frequency.snapToTarget()
            subOscFrequency.snapToTarget()
            cutoff.snapToTarget()
            pan.snapToTarget()
            shelfGain.snapToTarget()
            volume.snapToTarget()
            for index in 0..<harmonicAmps.count {
                harmonicAmps[index].snapToTarget()
            }
            lowpass.reset()
            highshelf.reset()
        } else if noteOn && stage == .releasing {
            // Fast retrigger: re-attack immediately from the current
            // envelope instead of waiting ~0.5 s for the release to finish
            // (the web app restarts its node graph instantly).
            stage = .active
        } else if !noteOn && stage == .active {
            stage = .releasing
        }
    }

    /// Render one stereo sample. Allocation-free.
    mutating func renderSample() -> (left: Double, right: Double) {
        frequency.advance()
        subOscFrequency.advance()
        cutoff.advance()
        pan.advance()
        shelfGain.advance()
        volume.advance()

        coefficientCountdown -= 1
        if coefficientCountdown <= 0 {
            coefficientCountdown = 32
            if abs(cutoff.value - lastCutoff) > 0.5 {
                lastCutoff = cutoff.value
                lowpass.configureLowpass(
                    frequency: lastCutoff,
                    qDecibels: Self.lowpassQDecibels,
                    sampleRate: sampleRate
                )
            }
            if abs(shelfGain.value - lastShelfGain) > 0.01 {
                lastShelfGain = shelfGain.value
                highshelf.configureHighshelf(
                    frequency: Self.shelfFrequency,
                    gainDecibels: lastShelfGain,
                    sampleRate: sampleRate
                )
            }
        }

        var totalAmplitude = 0.0
        for index in 0..<harmonicAmps.count {
            harmonicAmps[index].advance()
            totalAmplitude += abs(harmonicAmps[index].value)
        }
        let divisor = totalAmplitude > 0 ? totalAmplitude : 1.0

        let f = frequency.value
        var sample = 0.0
        for index in 0..<harmonicAmps.count {
            let amplitude = harmonicAmps[index].value
            if amplitude == 0 { continue }
            let n = Double(index + 1)
            if n * f >= nyquist { continue }
            sample += (amplitude / divisor) * waveform.shape(n * mainPhase)
        }

        // Sub oscillator: naive triangle, unit phase in [0, 1).
        let triangle = 4.0 * abs(subPhase - 0.5) - 1.0
        var x = sample + Self.subOscGain * triangle

        x = lowpass.process(x)
        x = highshelf.process(x)

        // Gentle safety ceiling: unity gain for normal levels, smooth
        // rounding only as |x| approaches/exceeds 1 (see the type doc for
        // why this replaced the old near-brickwall limiter).
        x = tanh(x * Self.saturationDrive)

        switch stage {
        case .idle:
            envelope = 0
        case .active:
            if envelope < 1.0 {
                envelope = min(1.0, envelope + attackStep)
            }
        case .releasing:
            envelope *= releaseFactor
            if envelope < 0.005 {
                envelope = 0
                stage = .idle
            }
        }

        let tremoloScale = stage == .active ? 1.0 : envelope
        let tremolo = stage == .idle
            ? 0.0
            : Self.tremoloDepth * sin(2.0 * Double.pi * lfoPhase) * tremoloScale
        let gain = envelope * volume.value + tremolo

        // Equal-power pan (Web Audio StereoPannerNode).
        let u = (min(max(pan.value, -1.0), 1.0) + 1.0) * 0.5
        let angle = u * Double.pi / 2.0
        let left = x * cos(angle) * gain
        let right = x * sin(angle) * gain

        mainPhase += 2.0 * Double.pi * f / sampleRate
        if mainPhase >= 2.0 * Double.pi {
            mainPhase -= 2.0 * Double.pi
        }
        subPhase += subOscFrequency.value / sampleRate
        if subPhase >= 1.0 {
            subPhase -= 1.0
        }
        lfoPhase += Self.tremoloFrequency / sampleRate
        if lfoPhase >= 1.0 {
            lfoPhase -= 1.0
        }

        return (left, right)
    }

    /// Realtime path: fill two non-interleaved Float32 channel buffers.
    mutating func render(
        parameters: SynthParameters,
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        syncTargets(from: parameters)
        for frame in 0..<frameCount {
            let sample = renderSample()
            left[frame] = Float(sample.left)
            right[frame] = Float(sample.right)
        }
    }

    /// Offline path: fill an interleaved stereo Float32 buffer.
    mutating func renderInterleaved(
        parameters: SynthParameters,
        into buffer: inout [Float],
        frameCount: Int
    ) {
        syncTargets(from: parameters)
        for frame in 0..<frameCount {
            let sample = renderSample()
            buffer[frame * 2] = Float(sample.left)
            buffer[frame * 2 + 1] = Float(sample.right)
        }
    }
}

/// Shared mapping from the visual waveform amplitude to synth targets —
/// the port of `FormulaAudioEngine.setRealtimeFrequency` in `lib/audio.ts`.
/// Used by both the live view and the offline export so they sound identical.
enum RealtimeMapper {
    static func apply(
        normalizedAmplitude: Double,
        baseFrequency: Double,
        minHz: Double,
        maxHz: Double,
        scale: MusicalScale,
        to parameters: SynthParameters
    ) {
        let a = normalizedAmplitude
        // REVERSED mapping (web comment): waveform up (+1) → low frequency,
        // center (0) → base frequency, down (−1) → high frequency.
        var freq: Double
        if a >= 0 {
            freq = baseFrequency + a * (minHz - baseFrequency)
        } else {
            freq = baseFrequency + a * (maxHz - baseFrequency)
        }
        freq = min(max(freq, 20.0), 5000.0)
        freq = scale.snap(freq)
        parameters.targetMainFrequency = freq
        parameters.targetSubFrequency = max(20.0, freq * 0.5)
        parameters.targetCutoff = min(max(1400.0 + abs(a) * 2200.0, 900.0), 4800.0)
        parameters.targetPan = min(max(a * 0.9, -0.95), 0.95)
        // Gentler brightness swing than the web original (was up to +7.5 dB)
        // — the wide shelf boost combined with the old hard limiter was a
        // major contributor to the harsh/fatiguing top end.
        parameters.targetShelfGain = 2.5 + abs(a) * 2.5
    }
}
