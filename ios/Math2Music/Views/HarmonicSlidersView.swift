import SwiftUI

/// Eight drawbar-style vertical sliders — the free formula editor.
/// Each bar sets one harmonic amplitude aₙ (n = 1...8, −5...+5, center = 0).
struct HarmonicSlidersView: View {
    var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<Formula.harmonicCount, id: \.self) { index in
                VerticalHarmonicSlider(
                    value: Binding(
                        get: { state.amplitudes[index] },
                        set: { state.setAmplitude($0, at: index) }
                    ),
                    color: state.theme.epicycleColors[index % state.theme.epicycleColors.count].color,
                    label: "\(index + 1)"
                )
            }
        }
    }
}

struct VerticalHarmonicSlider: View {
    @Binding var value: Double
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let height = geo.size.height
                let fraction = min(max(value / Formula.amplitudeLimit, -1), 1)
                let barHeight = abs(fraction) * height / 2

                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 1)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.9))
                        .frame(height: max(barHeight, 3))
                        .offset(y: fraction >= 0 ? -barHeight / 2 : barHeight / 2)
                        .shadow(color: color.opacity(0.8), radius: 5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard height > 0 else { return }
                            let raw = (height / 2 - drag.location.y) / (height / 2)
                            let clamped = min(max(raw, -1), 1)
                            let next = clamped * Formula.amplitudeLimit
                            // Quantize to 0.1 so labels stay tidy.
                            value = (next * 10).rounded() / 10
                        }
                )
            }
            Text(verbatim: label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
