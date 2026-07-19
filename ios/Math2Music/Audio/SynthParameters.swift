import Atomics
import Foundation

/// Lock-free parameter block shared between the main thread (writer) and the
/// audio render thread (reader). Doubles are stored as raw bit patterns in
/// 64-bit atomics; no locks or allocations happen on the render thread.
final class SynthParameters: @unchecked Sendable {
    private let mainFrequency: ManagedAtomic<UInt64>
    private let subFrequency: ManagedAtomic<UInt64>
    private let cutoffFrequency: ManagedAtomic<UInt64>
    private let panPosition: ManagedAtomic<UInt64>
    private let shelfGainDecibels: ManagedAtomic<UInt64>
    private let masterVolume: ManagedAtomic<UInt64>
    private let noteOn: ManagedAtomic<Bool>
    private let harmonics: [ManagedAtomic<UInt64>]
    private let waveformIndex: ManagedAtomic<Int>

    init() {
        mainFrequency = ManagedAtomic(Double(110).bitPattern)
        subFrequency = ManagedAtomic(Double(55).bitPattern)
        cutoffFrequency = ManagedAtomic(Double(2800).bitPattern)
        panPosition = ManagedAtomic(Double(0).bitPattern)
        shelfGainDecibels = ManagedAtomic(Double(5.5).bitPattern)
        masterVolume = ManagedAtomic(Double(0.18).bitPattern)
        noteOn = ManagedAtomic(false)
        harmonics = (0..<Formula.harmonicCount).map { _ in
            ManagedAtomic(Double(0).bitPattern)
        }
        waveformIndex = ManagedAtomic(0)
    }

    private static func read(_ atomic: ManagedAtomic<UInt64>) -> Double {
        return Double(bitPattern: atomic.load(ordering: .relaxed))
    }

    private static func write(_ value: Double, to atomic: ManagedAtomic<UInt64>) {
        atomic.store(value.bitPattern, ordering: .relaxed)
    }

    var targetMainFrequency: Double {
        get { return Self.read(mainFrequency) }
        set { Self.write(newValue, to: mainFrequency) }
    }

    var targetSubFrequency: Double {
        get { return Self.read(subFrequency) }
        set { Self.write(newValue, to: subFrequency) }
    }

    var targetCutoff: Double {
        get { return Self.read(cutoffFrequency) }
        set { Self.write(newValue, to: cutoffFrequency) }
    }

    var targetPan: Double {
        get { return Self.read(panPosition) }
        set { Self.write(newValue, to: panPosition) }
    }

    var targetShelfGain: Double {
        get { return Self.read(shelfGainDecibels) }
        set { Self.write(newValue, to: shelfGainDecibels) }
    }

    var targetVolume: Double {
        get { return Self.read(masterVolume) }
        set { Self.write(newValue, to: masterVolume) }
    }

    var isNoteOn: Bool {
        get { return noteOn.load(ordering: .relaxed) }
        set { noteOn.store(newValue, ordering: .relaxed) }
    }

    /// The elemental shape (sin/cos/triangle/sawtooth/square) applied to
    /// every additive term — read once per render buffer on the audio thread.
    var waveform: BaseWaveform {
        get {
            let all = BaseWaveform.allCases
            let index = waveformIndex.load(ordering: .relaxed)
            guard index >= 0 && index < all.count else { return .sine }
            return all[index]
        }
        set {
            if let index = BaseWaveform.allCases.firstIndex(of: newValue) {
                waveformIndex.store(index, ordering: .relaxed)
            }
        }
    }

    /// Upload a full amplitude set; missing entries are zero-padded.
    /// Single shared path for live playback and offline export.
    func setHarmonics(_ amplitudes: [Double]) {
        for index in 0..<harmonics.count {
            let amplitude = index < amplitudes.count ? amplitudes[index] : 0
            Self.write(amplitude, to: harmonics[index])
        }
    }

    func harmonicAmplitude(_ index: Int) -> Double {
        guard index >= 0 && index < harmonics.count else { return 0 }
        return Self.read(harmonics[index])
    }
}
