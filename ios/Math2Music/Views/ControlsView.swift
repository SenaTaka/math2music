import SwiftUI

/// Preset chips, transport buttons, sheet launchers, and the compact
/// parameter sliders. Auxiliary options live in small sheets so the main
/// screen never scrolls.
struct ControlsView: View {
    @Bindable var state: AppState
    @State private var showExportSheet = false
    @State private var showFavoritesSheet = false

    var body: some View {
        VStack(spacing: 8) {
            presetRow
            transportRow
            sliderGrid
            if !state.message.isEmpty {
                Text(verbatim: state.message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(state: state)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showFavoritesSheet) {
            FavoritesSheet(state: state)
                .presentationDetents([.medium])
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FormulaPreset.all) { preset in
                    Button {
                        state.applyPreset(preset)
                    } label: {
                        Text(verbatim: preset.name)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    state.activePresetId == preset.id
                                        ? state.theme.waveColor.color.opacity(0.35)
                                        : Color.white.opacity(0.08)
                                )
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    state.randomize()
                } label: {
                    Image(systemName: "dice")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Randomize"))
            }
        }
    }

    private var transportRow: some View {
        HStack(spacing: 8) {
            Button {
                state.togglePlay()
            } label: {
                Label(
                    state.isPlaying ? String(localized: "Stop") : String(localized: "Play"),
                    systemImage: state.isPlaying ? "stop.fill" : "play.fill"
                )
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(
                        state.isPlaying
                            ? Color.white.opacity(0.16)
                            : state.theme.waveColor.color.opacity(0.4)
                    )
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                showExportSheet = true
            } label: {
                Label(String(localized: "Export"), systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            scaleMenu
            themeMenu

            Button {
                showFavoritesSheet = true
            } label: {
                Image(systemName: "star")
                    .font(.system(size: 13, weight: .bold))
                    .padding(9)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Favorites"))
        }
    }

    private var scaleMenu: some View {
        Menu {
            Picker(String(localized: "Scale"), selection: $state.scale) {
                ForEach(MusicalScale.allCases) { scale in
                    Text(verbatim: scale.displayName).tag(scale)
                }
            }
        } label: {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .bold))
                .padding(9)
                .background(
                    Circle().fill(
                        state.scale == .off
                            ? Color.white.opacity(0.12)
                            : state.theme.waveColor.color.opacity(0.4)
                    )
                )
                .foregroundStyle(.white)
        }
        .accessibilityLabel(Text("Scale"))
    }

    private var themeMenu: some View {
        Menu {
            Picker(String(localized: "Theme"), selection: $state.themeId) {
                ForEach(NeonTheme.all) { theme in
                    Text(verbatim: theme.name).tag(theme.id)
                }
            }
            Toggle(String(localized: "Haptics"), isOn: $state.hapticsEnabled)
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 13, weight: .bold))
                .padding(9)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(Text("Theme"))
    }

    private var sliderGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                compactSlider(String(localized: "VOL"), value: $state.volume, in: 0...0.8)
                compactSlider(String(localized: "BPM"), value: $state.tempoBpm, in: 60...180)
            }
            HStack(spacing: 10) {
                compactSlider(String(localized: "LOW"), value: $state.minFrequencyHz, in: 20...500)
                compactSlider(String(localized: "HIGH"), value: $state.maxFrequencyHz, in: 500...5000)
            }
        }
    }

    private func compactSlider(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            Slider(value: value, in: range)
                .tint(state.theme.waveColor.color.opacity(0.7))
        }
    }
}
