import SwiftUI

/// One-time overlay explaining the core interaction in seconds.
struct OnboardingOverlay: View {
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Math2Music")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    onboardingRow(
                        icon: "slider.vertical.3",
                        text: String(localized: "Each slider is one sin(nx) term — sculpt your own formula.")
                    )
                    onboardingRow(
                        icon: "waveform",
                        text: String(localized: "The drawn wave drives the pitch in real time.")
                    )
                    onboardingRow(
                        icon: "film",
                        text: String(localized: "Export a perfectly seamless loop video for social media.")
                    )
                }
                Button {
                    dismiss()
                } label: {
                    Text("Start")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.cyan.opacity(0.5)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
    }

    private func onboardingRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 26)
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
