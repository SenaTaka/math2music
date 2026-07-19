import Foundation
import SwiftUI

@main
struct Math2MusicApp: App {
    init() {
        // Debug-only perf harness; inert unless EXPORT_BENCH=1 is set in the
        // launch environment. See ExportBenchmark.swift.
        if ProcessInfo.processInfo.environment["EXPORT_BENCH"] == "1" {
            Task.detached(priority: .userInitiated) {
                await ExportBenchmark.run()
                exit(0)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
