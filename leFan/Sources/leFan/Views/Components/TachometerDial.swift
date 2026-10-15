import SwiftUI

public struct TachometerDial: View {
    let actualRPM: Double
    let minRPM: Double
    let maxRPM: Double
    let targetRPM: Double
    let isManual: Bool
    let modeTitle: String

    @State private var rotationAngle: Double = 0

    private var percentage: Double {
        guard maxRPM > minRPM else { return 0 }
        let clamped = min(max(actualRPM, minRPM), maxRPM)
        return (clamped - minRPM) / (maxRPM - minRPM)
    }

    private var gaugeColor: LinearGradient {
        if percentage > 0.75 {
            return LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if percentage > 0.45 {
            return LinearGradient(
                colors: [.cyan, .mint, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    public var body: some View {
        ZStack {
            // Background arc track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.primary.opacity(0.08),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(90))

            // Active glowing progress arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * CGFloat(percentage)))
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .shadow(color: (percentage > 0.7 ? Color.red : Color.cyan).opacity(0.35), radius: 8, x: 0, y: 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: percentage)

            // Center details
            VStack(spacing: 3) {
                // Spinning Fan Icon
                Image(systemName: "fanblades.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(gaugeColor)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        startSpinAnimation()
                    }
                    .onChange(of: actualRPM) { _, _ in
                        startSpinAnimation()
                    }

                // RPM readout
                Text("\(Int(actualRPM))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("RPM")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                // Mode & % Badge
                HStack(spacing: 4) {
                    Text(isManual ? "MANUAL" : "AUTO")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isManual ? Color.purple.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(isManual ? .purple : .green)
                        .clipShape(Capsule())

                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            // Min & Max label ticks
            VStack {
                Spacer()
                HStack {
                    Text("\(Int(minRPM))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(maxRPM))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
            }
        }
        .frame(width: 190, height: 190)
    }

    private func startSpinAnimation() {
        // Higher RPM = faster spin
        let speedFactor = max(actualRPM / 3000.0, 0.4)
        withAnimation(.linear(duration: 2.0 / speedFactor).repeatForever(autoreverses: false)) {
            rotationAngle += 360
        }
    }
}
