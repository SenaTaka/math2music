import Foundation
import Observation
import SwiftUI

/// A saved formula + settings snapshot.
struct FavoriteFormula: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amplitudes: [Double]
    var baseFrequency: Double
    var tempoBpm: Double
    var minFrequencyHz: Double
    var maxFrequencyHz: Double
    var themeId: String
    var scaleId: String
    /// Optional so favorites saved before the waveform feature still decode
    /// (missing key → nil → sine, see `applyFavorite`).
    var waveformId: String?
}

/// Central observable state — the port of the React state in `app/page.tsx`,
/// with UserDefaults persistence replacing the URL query sync.
@Observable
final class AppState {
    private struct PersistedSettings: Codable {
        var amplitudes: [Double]
        var baseFrequency: Double
        var activePresetId: String?
        var volume: Double
        var tempoBpm: Double
        var minFrequencyHz: Double
        var maxFrequencyHz: Double
        var themeId: String
        var scaleId: String
        var hapticsEnabled: Bool
        /// Optional so settings persisted before the waveform feature still
        /// decode (missing key → nil → sine, see `init`).
        var waveformId: String?
    }

    private static let settingsKey = "math2music.settings"
    private static let favoritesKey = "math2music.favorites"

    // MARK: Formula
    var amplitudes: [Double] {
        didSet {
            audio.parameters.setHarmonics(amplitudes)
            persist()
        }
    }
    /// Bumped when a whole new formula is applied (preset / randomize /
    /// favorite) so the visualizer clears its wave trail — but NOT on
    /// individual slider edits, which morph continuously.
    var formulaGeneration = 0
    var baseFrequency: Double {
        didSet { persist() }
    }
    var activePresetId: String? {
        didSet { persist() }
    }
    /// Elemental shape for every additive term — a global choice, independent
    /// of presets/favorites (applying one never changes it).
    var baseWaveform: BaseWaveform {
        didSet {
            audio.parameters.waveform = baseWaveform
            persist()
        }
    }

    // MARK: Playback
    var isPlaying = false
    var volume: Double {
        didSet {
            audio.setVolume(volume)
            persist()
        }
    }
    var tempoBpm: Double {
        didSet {
            haptics.update(bpm: tempoBpm)
            persist()
        }
    }
    var minFrequencyHz: Double {
        didSet { persist() }
    }
    var maxFrequencyHz: Double {
        didSet { persist() }
    }
    var scale: MusicalScale {
        didSet { persist() }
    }
    var themeId: String {
        didSet { persist() }
    }
    var hapticsEnabled: Bool {
        didSet {
            if !hapticsEnabled {
                haptics.stop()
            } else if isPlaying {
                haptics.start(bpm: tempoBpm)
            }
            persist()
        }
    }

    // MARK: Export
    var isExporting = false
    var exportProgress = 0.0
    var exportedVideoURL: URL?
    var exportDuration = 6.0
    var exportResolution = ExportResolution.fullHD
    /// Non-nil switches the live visualizer into phase-locked loop mode.
    var loopPreviewStart: Date?
    /// Snapshot of the duration the running export uses, so the preview
    /// cannot diverge from the file being written.
    var loopPreviewDuration = 6.0

    // MARK: Misc
    var favorites: [FavoriteFormula]
    var message = ""

    let audio = AudioEngineController()
    private let haptics = HapticsController()
    private var isLoaded = false

    var theme: NeonTheme {
        return NeonTheme.theme(id: themeId)
    }

    var formulaLabel: String {
        return Formula.label(for: amplitudes, waveform: baseWaveform)
    }

    var speedFactor: Double {
        return tempoBpm / 120.0
    }

    /// Tempo scales the base frequency, mirroring `buildPresetWithParameters`.
    var effectiveBaseFrequency: Double {
        return baseFrequency * tempoBpm / 120.0
    }

    init() {
        let defaultPreset = FormulaPreset.defaultPreset
        var settings = PersistedSettings(
            amplitudes: defaultPreset.amplitudes,
            baseFrequency: defaultPreset.baseFrequency,
            activePresetId: defaultPreset.id,
            volume: 0.18,
            tempoBpm: 120,
            minFrequencyHz: 60,
            maxFrequencyHz: 2000,
            themeId: NeonTheme.defaultTheme.id,
            scaleId: MusicalScale.off.rawValue,
            hapticsEnabled: true,
            waveformId: BaseWaveform.sine.rawValue
        )
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let stored = try? JSONDecoder().decode(PersistedSettings.self, from: data),
           stored.amplitudes.count == Formula.harmonicCount {
            settings = stored
        }
        amplitudes = settings.amplitudes
        baseFrequency = settings.baseFrequency
        activePresetId = settings.activePresetId
        volume = min(max(settings.volume, 0), 0.8)
        tempoBpm = min(max(settings.tempoBpm, 60), 180)
        minFrequencyHz = min(max(settings.minFrequencyHz, 20), 500)
        maxFrequencyHz = min(max(settings.maxFrequencyHz, 500), 5000)
        themeId = settings.themeId
        scale = MusicalScale(rawValue: settings.scaleId) ?? .off
        hapticsEnabled = settings.hapticsEnabled
        baseWaveform = BaseWaveform(rawValue: settings.waveformId ?? "") ?? .sine

        if let data = UserDefaults.standard.data(forKey: Self.favoritesKey),
           let stored = try? JSONDecoder().decode([FavoriteFormula].self, from: data) {
            favorites = stored
        } else {
            favorites = []
        }

        isLoaded = true
        audio.parameters.setHarmonics(amplitudes)
        audio.parameters.waveform = baseWaveform
        audio.setVolume(volume)
        audio.onInterruption = { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.haptics.stop()
        }
    }

    // MARK: - Actions

    func setAmplitude(_ value: Double, at index: Int) {
        guard index >= 0 && index < amplitudes.count else { return }
        amplitudes[index] = Formula.clampAmplitude(value)
        activePresetId = nil
    }

    func applyPreset(_ preset: FormulaPreset) {
        amplitudes = preset.amplitudes
        baseFrequency = preset.baseFrequency
        activePresetId = preset.id
        formulaGeneration += 1
    }

    func randomize() {
        var next: [Double] = []
        next.reserveCapacity(Formula.harmonicCount)
        for index in 0..<Formula.harmonicCount {
            // Bias energy toward lower harmonics so results stay musical.
            let ceiling = Formula.amplitudeLimit / Double(index + 1)
            let value = Double.random(in: -ceiling...ceiling)
            next.append((value * 10).rounded() / 10)
        }
        // Guarantee an audible fundamental.
        if abs(next[0]) < 0.8 {
            next[0] = next[0] < 0 ? -1.5 : 1.5
        }
        amplitudes = next
        activePresetId = nil
        formulaGeneration += 1
    }

    func togglePlay() {
        if isPlaying {
            audio.noteOff()
            isPlaying = false
            haptics.stop()
            return
        }
        do {
            try audio.prepare()
            audio.parameters.setHarmonics(amplitudes)
            audio.parameters.waveform = baseWaveform
            audio.setVolume(volume)
            // Seed the realtime targets at the base frequency so the note
            // starts exactly there (web start() behavior) instead of gliding
            // from a default or stale pitch.
            audio.updateRealtime(
                normalizedAmplitude: 0,
                baseFrequency: effectiveBaseFrequency,
                minHz: minFrequencyHz,
                maxHz: maxFrequencyHz,
                scale: scale
            )
            audio.noteOn()
            isPlaying = true
            if hapticsEnabled {
                haptics.start(bpm: tempoBpm)
            }
            message = ""
        } catch {
            message = String(localized: "Audio could not start. Check the silent switch and try again.")
        }
    }

    /// Called every visualizer frame with the current normalized wave
    /// amplitude — the visual → audio coupling loop.
    func visualizerDidRender(normalizedAmplitude: Double) {
        guard isPlaying else { return }
        audio.updateRealtime(
            normalizedAmplitude: normalizedAmplitude,
            baseFrequency: effectiveBaseFrequency,
            minHz: minFrequencyHz,
            maxHz: maxFrequencyHz,
            scale: scale
        )
    }

    // MARK: - Favorites

    func saveCurrentAsFavorite() {
        let favorite = FavoriteFormula(
            name: formulaLabel,
            amplitudes: amplitudes,
            baseFrequency: baseFrequency,
            tempoBpm: tempoBpm,
            minFrequencyHz: minFrequencyHz,
            maxFrequencyHz: maxFrequencyHz,
            themeId: themeId,
            scaleId: scale.rawValue,
            waveformId: baseWaveform.rawValue
        )
        favorites.insert(favorite, at: 0)
        persistFavorites()
    }

    func applyFavorite(_ favorite: FavoriteFormula) {
        guard favorite.amplitudes.count == Formula.harmonicCount else { return }
        amplitudes = favorite.amplitudes
        baseFrequency = favorite.baseFrequency
        tempoBpm = favorite.tempoBpm
        minFrequencyHz = favorite.minFrequencyHz
        maxFrequencyHz = favorite.maxFrequencyHz
        themeId = favorite.themeId
        scale = MusicalScale(rawValue: favorite.scaleId) ?? .off
        baseWaveform = BaseWaveform(rawValue: favorite.waveformId ?? "") ?? .sine
        activePresetId = nil
        formulaGeneration += 1
    }

    func deleteFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        persistFavorites()
    }

    // MARK: - Export

    func startExport() {
        guard !isExporting else { return }
        isExporting = true
        exportProgress = 0
        exportedVideoURL = nil
        loopPreviewDuration = exportDuration
        loopPreviewStart = Date()
        let config = LoopVideoExporter.Config(
            duration: exportDuration,
            size: exportResolution.size,
            amplitudes: amplitudes,
            theme: theme,
            baseFrequency: effectiveBaseFrequency,
            minFrequencyHz: minFrequencyHz,
            maxFrequencyHz: maxFrequencyHz,
            volume: volume,
            scale: scale,
            waveform: baseWaveform
        )
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let url = try await LoopVideoExporter.export(config: config) { progress in
                    Task { @MainActor [weak self] in
                        self?.exportProgress = progress
                    }
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.exportedVideoURL = url
                    self.isExporting = false
                    self.loopPreviewStart = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.message = String(localized: "Export failed. Please try again.")
                    self.isExporting = false
                    self.loopPreviewStart = nil
                }
            }
        }
    }

    // MARK: - Persistence

    @ObservationIgnored private var persistWorkItem: DispatchWorkItem?

    /// Debounced: slider drags fire didSet dozens of times per second, but
    /// the settings only need to become durable once things settle.
    private func persist() {
        guard isLoaded else { return }
        persistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistNow()
        }
        persistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// Called when the scene leaves the foreground so nothing is lost.
    func flushPersistence() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        persistNow()
    }

    private func persistNow() {
        guard isLoaded else { return }
        let settings = PersistedSettings(
            amplitudes: amplitudes,
            baseFrequency: baseFrequency,
            activePresetId: activePresetId,
            volume: volume,
            tempoBpm: tempoBpm,
            minFrequencyHz: minFrequencyHz,
            maxFrequencyHz: maxFrequencyHz,
            themeId: themeId,
            scaleId: scale.rawValue,
            hapticsEnabled: hapticsEnabled,
            waveformId: baseWaveform.rawValue
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: Self.favoritesKey)
        }
    }
}
