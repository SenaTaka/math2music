import AVFoundation
import Foundation

/// Owns the AVAudioEngine + AVAudioSourceNode and bridges UI state to the
/// lock-free `SynthParameters` block read by the render thread.
final class AudioEngineController {
    /// Render-thread-owned DSP state; captured by the source node closure so
    /// the closure never touches the controller itself.
    private final class RenderCore: @unchecked Sendable {
        var dsp: FormulaSynthDSP
        let parameters: SynthParameters

        init(dsp: FormulaSynthDSP, parameters: SynthParameters) {
            self.dsp = dsp
            self.parameters = parameters
        }
    }

    let parameters = SynthParameters()
    private var engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var core: RenderCore
    private(set) var sampleRate: Double
    var onInterruption: (() -> Void)?

    init() {
        let sessionRate = AVAudioSession.sharedInstance().sampleRate
        sampleRate = sessionRate > 0 ? sessionRate : 44100
        core = RenderCore(
            dsp: FormulaSynthDSP(sampleRate: sampleRate),
            parameters: parameters
        )
        observeNotifications()
    }

    /// Configure the session and start the engine. Idempotent; call before
    /// the first note (i.e. from a user gesture, mirroring the web app's
    /// resume-after-interaction requirement).
    func prepare() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let sessionRate = session.sampleRate
        if sessionRate > 0 && sessionRate != sampleRate {
            // Rebuild node + DSP together for the new rate. Stop the engine
            // FIRST so the render thread cannot be mid-render while the DSP
            // struct is replaced (data race), and so the node's AVAudioFormat
            // never disagrees with the DSP's rate (pitch shift).
            engine.stop()
            if let node = sourceNode {
                engine.detach(node)
                sourceNode = nil
            }
            sampleRate = sessionRate
            core.dsp = FormulaSynthDSP(sampleRate: sessionRate)
        }

        if sourceNode == nil {
            guard let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 2
            ) else {
                throw NSError(
                    domain: "Math2Music",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported audio format"]
                )
            }
            let renderCore = core
            let node = AVAudioSourceNode(format: format) { (_, _, frameCount, audioBufferList) -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                guard buffers.count >= 2,
                      let leftRaw = buffers[0].mData,
                      let rightRaw = buffers[1].mData else {
                    return noErr
                }
                let left = leftRaw.assumingMemoryBound(to: Float.self)
                let right = rightRaw.assumingMemoryBound(to: Float.self)
                renderCore.dsp.render(
                    parameters: renderCore.parameters,
                    left: left,
                    right: right,
                    frameCount: Int(frameCount)
                )
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNode = node
        }

        if !engine.isRunning {
            try engine.start()
        }
    }

    func noteOn() {
        parameters.isNoteOn = true
    }

    func noteOff() {
        parameters.isNoteOn = false
    }

    func setVolume(_ volume: Double) {
        parameters.targetVolume = min(max(volume, 0), 1)
    }

    /// Per-frame coupling from the visualizer (port of `setRealtimeFrequency`).
    func updateRealtime(
        normalizedAmplitude: Double,
        baseFrequency: Double,
        minHz: Double,
        maxHz: Double,
        scale: MusicalScale
    ) {
        RealtimeMapper.apply(
            normalizedAmplitude: normalizedAmplitude,
            baseFrequency: baseFrequency,
            minHz: minHz,
            maxHz: maxHz,
            scale: scale,
            to: parameters
        )
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        _ = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if rawType == AVAudioSession.InterruptionType.began.rawValue {
                self.parameters.isNoteOn = false
                self.onInterruption?()
            }
        }
        // object: nil — the engine instance is replaced after a media
        // services reset, and this app only ever owns one engine.
        _ = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if !self.engine.isRunning {
                do {
                    try self.engine.start()
                } catch {
                    // Engine could not recover: stop the note and tell the
                    // UI, otherwise haptics/Stop-state run over dead audio.
                    self.parameters.isNoteOn = false
                    self.onInterruption?()
                }
            }
        }
        _ = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Everything audio-related is invalid now; rebuild lazily on the
            // next prepare() and surface the stop to the UI.
            self.parameters.isNoteOn = false
            self.engine.stop()
            self.engine = AVAudioEngine()
            self.sourceNode = nil
            self.onInterruption?()
        }
    }
}
