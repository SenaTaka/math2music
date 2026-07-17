import SwiftUI

/// The entire app on one non-scrolling screen:
/// visualizer → formula label → harmonic sliders → controls.
struct ContentView: View {
    @State private var state = AppState()
    @AppStorage("math2music.hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                VisualizerView(state: state)
                    .frame(height: geo.size.height * 0.37)

                Text(verbatim: state.formulaLabel)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)

                HarmonicSlidersView(state: state)
                    .frame(height: geo.size.height * 0.2)

                ControlsView(state: state)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.05, green: 0.02, blue: 0.1),
                    Color.black,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay {
            if !hasSeenOnboarding {
                OnboardingOverlay {
                    hasSeenOnboarding = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                // The realtime pitch modulation is driven by the visible
                // canvas; with rendering paused the note would freeze on one
                // pitch. This is a visual-first app — stop cleanly instead.
                if state.isPlaying {
                    state.togglePlay()
                }
                state.flushPersistence()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
