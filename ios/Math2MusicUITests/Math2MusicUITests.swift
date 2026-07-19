import XCTest

/// Drives the real app UI to produce the 5 App Store screenshot states.
/// Screenshots themselves are captured *externally* via
/// `xcrun simctl io <udid> screenshot` (so the PNG is the exact device
/// resolution). This test only drives the UI and hands off timing via a
/// simple ready/consumed file handshake in /tmp, so the external capture
/// script never has to guess sleep durations.
///
/// Two entry points (`testScreenshotFlowEN` / `testScreenshotFlowJA`) exist
/// because several button/menu titles are localized (Play/Stop, Export,
/// Scale, Settings, Done, "Harmonic N") — running with the simulator's
/// language already set to the matching locale keeps the raw screenshots
/// authentic to what real users see.
final class Math2MusicUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private struct L10n {
        let start, play, export, scale, settings, done, harmonic3: String
    }
    private let en = L10n(start: "Start", play: "Play", export: "Export",
                           scale: "Scale", settings: "Settings", done: "Done",
                           harmonic3: "Harmonic 3")
    private let ja = L10n(start: "はじめる", play: "再生", export: "書き出し",
                           scale: "スケール", settings: "設定", done: "完了",
                           harmonic3: "倍音 3")

    func testScreenshotFlowEN() throws {
        try runFlow(lang: "en", strings: en)
    }

    func testScreenshotFlowJA() throws {
        try runFlow(lang: "ja", strings: ja)
    }

    private let shotsDir = "/tmp/m2m_shots"

    private func handoff(_ name: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: shotsDir, withIntermediateDirectories: true)
        let consumed = "\(shotsDir)/consumed_\(name)"
        try? fm.removeItem(atPath: consumed)
        fm.createFile(atPath: "\(shotsDir)/ready_\(name)", contents: Data())
        let deadline = Date().addingTimeInterval(25)
        while !fm.fileExists(atPath: consumed) && Date() < deadline {
            usleep(200_000)
        }
    }

    private func runFlow(lang: String, strings s: L10n) throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons[s.start]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        // --- 01: main screen, playing, default Neon Cyan theme ---
        let playButton = app.buttons[s.play]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        playButton.tap()
        Thread.sleep(forTimeInterval: 0.6)
        handoff("\(lang)_01_main")

        // --- 02: harmonic sliders moved away from default preset ---
        // These are custom DragGesture(minimumDistance: 0) controls, not
        // native UISlider, so XCUIElement has no increment()/decrement();
        // a plain tap near the top/bottom of the drag area sets the value
        // directly (minimumDistance 0 means touch-down alone is a "drag").
        let slider3 = app.otherElements[s.harmonic3]
        if slider3.waitForExistence(timeout: 3) {
            slider3.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        let slider6 = app.otherElements[lang == "ja" ? "倍音 6" : "Harmonic 6"]
        if slider6.waitForExistence(timeout: 3) {
            slider6.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
        handoff("\(lang)_02_sliders")

        // --- 03: scale menu expanded ---
        let scaleButton = app.buttons[s.scale]
        XCTAssertTrue(scaleButton.waitForExistence(timeout: 5))
        scaleButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
        handoff("\(lang)_03_scale")
        // Dismiss by tapping a safe area outside the menu (top of the
        // visualizer canvas has no gesture recognizer attached).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        Thread.sleep(forTimeInterval: 0.3)

        // --- 04: export sheet ---
        let exportButton = app.buttons[s.export]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        Thread.sleep(forTimeInterval: 0.6)
        handoff("\(lang)_04_export")
        let doneButton = app.buttons[s.done]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        }
        Thread.sleep(forTimeInterval: 0.3)

        // --- 05: Magenta Pop theme, main screen ---
        let settingsButton = app.buttons[s.settings]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        Thread.sleep(forTimeInterval: 0.3)
        // Theme is a nested Picker inside the Settings menu; SwiftUI may
        // render it as a flat item or a submenu trigger depending on menu
        // content — try the submenu trigger first, fall back to a direct
        // tap (theme names like "Magenta Pop" are not localized).
        let themeSubmenu = app.buttons["Theme"]
        if themeSubmenu.waitForExistence(timeout: 2) {
            themeSubmenu.tap()
        }
        let magentaPop = app.buttons["Magenta Pop"]
        XCTAssertTrue(magentaPop.waitForExistence(timeout: 3))
        magentaPop.tap()
        Thread.sleep(forTimeInterval: 0.6)
        handoff("\(lang)_05_theme")
    }
}
