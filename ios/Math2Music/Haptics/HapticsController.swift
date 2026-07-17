import Foundation
import UIKit

/// Soft haptic pulse on every beat while playing.
///
/// Uses chained one-shot timers in `.common` run-loop mode so beats keep
/// firing while the user drags a slider (`.tracking` mode), and so tempo
/// changes simply retime the NEXT beat instead of restarting the schedule
/// (a repeating timer restarted on every slider tick would never fire).
final class HapticsController {
    private var timer: Timer?
    private var bpm = 120.0
    private var isRunning = false
    private let generator = UIImpactFeedbackGenerator(style: .soft)

    func start(bpm: Double) {
        self.bpm = bpm
        guard !isRunning else { return }
        isRunning = true
        generator.prepare()
        scheduleNextBeat()
    }

    /// Tempo changes take effect on the next beat; no restart.
    func update(bpm: Double) {
        self.bpm = bpm
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextBeat() {
        guard isRunning else { return }
        let interval = 60.0 / max(bpm, 1)
        let next = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.generator.impactOccurred(intensity: 0.7)
            self.scheduleNextBeat()
        }
        next.tolerance = 0.02
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
}
