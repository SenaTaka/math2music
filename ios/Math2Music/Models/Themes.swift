import CoreGraphics
import SwiftUI

/// Plain sRGB triple usable from both SwiftUI and CoreGraphics.
struct RGBColor: Hashable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255.0
        green = Double((hex >> 8) & 0xFF) / 255.0
        blue = Double(hex & 0xFF) / 255.0
    }

    func cgColor(alpha: Double = 1) -> CGColor {
        return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        return Color(red: red, green: green, blue: blue)
    }
}

/// A neon color set applied to the visualizer and exported videos.
struct NeonTheme: Identifiable, Hashable {
    let id: String
    let name: String
    /// Main waveform stroke color.
    let waveColor: RGBColor
    /// Cycled per epicycle circle (7 entries, mirrors the web NEON_COLORS).
    let epicycleColors: [RGBColor]
    /// Inner tint of the pulsing background gradient.
    let backgroundInner: RGBColor
    /// Mid stop of the pulsing background gradient.
    let backgroundMid: RGBColor
}

extension NeonTheme {
    static let all: [NeonTheme] = [
        NeonTheme(
            id: "cyan",
            name: "Neon Cyan",
            waveColor: RGBColor(0x63E6FF),
            epicycleColors: [
                RGBColor(0x63E6FF), RGBColor(0xA78BFA), RGBColor(0xFF7AC6),
                RGBColor(0xFFE066), RGBColor(0x2CEAA3), RGBColor(0xF87171),
                RGBColor(0x60A5FA),
            ],
            backgroundInner: RGBColor(0x63E6FF),
            backgroundMid: RGBColor(0xA78BFA)
        ),
        NeonTheme(
            id: "magenta",
            name: "Magenta Pop",
            waveColor: RGBColor(0xF472FF),
            epicycleColors: [
                RGBColor(0xF472FF), RGBColor(0xFF7AC6), RGBColor(0xA78BFA),
                RGBColor(0xFF9E7A), RGBColor(0xFFE066), RGBColor(0x63E6FF),
                RGBColor(0xF87171),
            ],
            backgroundInner: RGBColor(0xF472FF),
            backgroundMid: RGBColor(0xFF7AC6)
        ),
        NeonTheme(
            id: "amber",
            name: "Amber Glow",
            waveColor: RGBColor(0xFFE066),
            epicycleColors: [
                RGBColor(0xFFE066), RGBColor(0xFFB347), RGBColor(0xFF7A5C),
                RGBColor(0xFF9E7A), RGBColor(0xF5D0A9), RGBColor(0xF472FF),
                RGBColor(0xFF6B6B),
            ],
            backgroundInner: RGBColor(0xFFE066),
            backgroundMid: RGBColor(0xFF9E40)
        ),
        NeonTheme(
            id: "matrix",
            name: "Matrix",
            waveColor: RGBColor(0x2CEAA3),
            epicycleColors: [
                RGBColor(0x2CEAA3), RGBColor(0x5CF28C), RGBColor(0x9DFC7C),
                RGBColor(0x30D5C8), RGBColor(0x63E6FF), RGBColor(0x8AFFC1),
                RGBColor(0x00FFA2),
            ],
            backgroundInner: RGBColor(0x2CEAA3),
            backgroundMid: RGBColor(0x30D5C8)
        ),
    ]

    static let defaultTheme = all[0]

    static func theme(id: String) -> NeonTheme {
        return all.first { $0.id == id } ?? defaultTheme
    }
}
