import SwiftUI

// MARK: - Splash View
// Shown on first launch before any HealthKit data has been loaded.

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo mark
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.08 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Image(systemName: "heart.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(Color.red)
                }

                VStack(spacing: 8) {
                    Text("OpenHealth")
                        .font(.largeTitle.bold())

                    Text("Deine Gesundheitsdaten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.red)

                    Text("Verbinde mit HealthKit...")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { pulse = true }
    }
}

#Preview {
    SplashView()
}
