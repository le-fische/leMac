//
//  MusicVisualizer.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//
//  Updated to drive bars from real system audio levels
//  (via SystemAudioMonitor) instead of random values.
//

import AppKit
import Cocoa
import Defaults
import SwiftUI

class AudioSpectrum: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = true
    private var animationTimer: Timer?

    /// Current per-band levels (0…1) fed from SystemAudioMonitor.
    private var bandLevels: [Float] = [0, 0, 0, 0]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth: CGFloat = 2
        let barCount = 5
        let spacing: CGFloat = 1.5
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let totalHeight: CGFloat = 14
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0 ..< barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.fillColor = NSColor.white.cgColor
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            let path = NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )
            barLayer.path = path.cgPath
            barLayers.append(barLayer)
            barScales.append(0.15)
            layer?.addSublayer(barLayer)
        }
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        // 60 fps for ultra-smooth visualizer updates in .common run loop mode
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateBars()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }

    private func updateBars() {
        let levels = SystemAudioMonitor.shared.sampleLevels()
        let levelsArray = levels.asArray

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]
            let level = CGFloat(i < levelsArray.count ? levelsArray[i] : 0)
            let targetScale = max(0.14, min(1.0, level))
            // Fast attack, smooth natural decay
            let factor: CGFloat = targetScale > currentScale ? 0.60 : 0.22
            let newScale = currentScale + factor * (targetScale - currentScale)
            barScales[i] = newScale
            barLayer.transform = CATransform3DMakeScale(1, newScale, 1)
        }
        CATransaction.commit()
    }

    private func resetBars() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.transform = CATransform3DMakeScale(1, 0.15, 1)
            barScales[i] = 0.15
        }
        CATransaction.commit()
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    /// Updates levels directly if passed externally.
    func updateLevels(_ levels: AudioBandLevels) {
        bandLevels = levels.asArray
    }
}

// MARK: - SwiftUI Bridge

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool
    var bandLevels: AudioBandLevels? = nil

    init(isPlaying: Binding<Bool>, bandLevels: AudioBandLevels? = nil) {
        self._isPlaying = isPlaying
        self.bandLevels = bandLevels
    }

    func makeNSView(context: Context) -> AudioSpectrum {
        let spectrum = AudioSpectrum()
        spectrum.setPlaying(isPlaying)
        if let bandLevels = bandLevels {
            spectrum.updateLevels(bandLevels)
        }
        return spectrum
    }

    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setPlaying(isPlaying)
        if let bandLevels = bandLevels {
            nsView.updateLevels(bandLevels)
        }
    }
}

// MARK: - Beat-Reactive Edge Glow View

struct AlbumEdgeGlowView: View {
    @ObservedObject var audioMonitor = SystemAudioMonitor.shared
    @ObservedObject var musicManager = MusicManager.shared
    let cornerRadius: CGFloat
    let isMinimized: Bool

    var body: some View {
        if Defaults[.enableExpandedVisualizerGlow] && musicManager.isPlaying {
            // Beat transient detection: kicks, 808s, snares, claps
            let beat = CGFloat(audioMonitor.beatLevel)
            let kick = CGFloat(audioMonitor.bandLevels.subBass)
            let snare = CGFloat(audioMonitor.bandLevels.mid)
            let impulse = max(beat, max(0.0, kick - 0.40) * 1.8, max(0.0, snare - 0.40) * 1.8)

            // Two distinct states: Strong Beat vs Weak Beat
            let isStrongBeat = impulse > 0.35

            if isMinimized {
                // Mini notch display: pure opacity pulse (no brightness boost so it never overwhelms album art)
                let beat = CGFloat(audioMonitor.beatLevel)
                let kick = CGFloat(audioMonitor.bandLevels.subBass)
                let snare = CGFloat(audioMonitor.bandLevels.mid)
                let impulse = max(beat, max(0.0, kick - 0.40) * 1.8, max(0.0, snare - 0.40) * 1.8)
                let isStrongBeat = impulse > 0.35

                let scale: CGFloat = 1.12
                let blurRadius: CGFloat = 2.8
                // Subtle opacity modulation without touching brightness
                let opacity: Double = isStrongBeat ? 0.82 : 0.52

                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(1.5)
                    .brightness(0.0)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(scale)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.10), value: isStrongBeat)
            } else {
                // Main expanded display: permanent, beautiful ambient album halo
                let scale: CGFloat = 1.22
                let blurRadius: CGFloat = 20.0
                let opacity: Double = 0.65

                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(1.5)
                    .brightness(0.04)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(scale)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Audiophile Vinyl Turntable Player View

struct VinylRecordView: View {
    @ObservedObject var musicManager = MusicManager.shared
    let isMinimized: Bool
    var cornerRadius: CGFloat = 12

    var body: some View {
        if isMinimized {
            // Mini notch: compact spinning LP disc with silver rim
            miniVinylView
        } else {
            // Main expanded notch: full turntable with chrome platter and tracking tonearm
            expandedTurntableView
        }
    }

    // MARK: - Mini Notch Vinyl
    private var miniVinylView: some View {
        TimelineView(.animation(paused: !musicManager.isPlaying)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotation = (time * 100.0).truncatingRemainder(dividingBy: 360)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                ZStack {
                    // Outer Black Rim
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(white: 0.18), Color(white: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )

                    // Black Vinyl Disc
                    Circle()
                        .fill(Color(white: 0.06))
                        .padding(1)

                    // Subtle Groove
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        .frame(width: size * 0.72, height: size * 0.72)

                    // Rotating Center Album Label
                    let labelSize = size * 0.50
                    ZStack {
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: labelSize, height: labelSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )

                        // Center Spindle
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: size * 0.12, height: size * 0.12)
                            .overlay(
                                Circle().stroke(Color(white: 0.20), lineWidth: 0.5)
                            )
                    }
                    .rotationEffect(.degrees(rotation))
                }
                .frame(width: size, height: size)
            }
        }
    }

    // MARK: - Expanded Turntable Player
    private var expandedTurntableView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // 1. Dark Brushed Plinth (Turntable Deck)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.14),
                                Color(white: 0.09),
                                Color(white: 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                // Turntable Speed Controls & Labels (Bottom-Left)
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.white.opacity(0.20)).frame(width: 3.5, height: 3.5)
                        Text("33")
                            .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.30))
                        Circle().fill(Color.white.opacity(0.12)).frame(width: 3.5, height: 3.5)
                        Text("45")
                            .font(.system(size: 6.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.20))
                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 7)
                }

                // 2. Matte Black Platter Rim (Full stealth black finish, no silver rim)
                let platterSize = size * 0.84
                let platterCenterX = size * 0.44
                let platterCenterY = size * 0.50

                ZStack {
                    // Outer matte black platter edge
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.18),
                                    Color(white: 0.08),
                                    Color(white: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.0
                        )
                        .frame(width: platterSize, height: platterSize)
                        .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1.5)

                    // Inner recessed slipmat
                    Circle()
                        .fill(Color(white: 0.04))
                        .frame(width: platterSize - 4, height: platterSize - 4)
                }
                .position(x: platterCenterX, y: platterCenterY)

                // 3. Spinning Vinyl LP Record
                let vinylSize = size * 0.79
                TimelineView(.animation(paused: !musicManager.isPlaying)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let rotation = (time * 100.0).truncatingRemainder(dividingBy: 360)

                    ZStack {
                        // Deep Black Vinyl Disc
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(white: 0.12),
                                        Color(white: 0.06),
                                        Color(white: 0.02)
                                    ],
                                    center: .center,
                                    startRadius: vinylSize * 0.16,
                                    endRadius: vinylSize * 0.50
                                )
                            )

                        // Fine Sound Grooves
                        Group {
                            Circle().stroke(Color.white.opacity(0.04), lineWidth: 0.75).frame(width: vinylSize * 0.94)
                            Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.75).frame(width: vinylSize * 0.87)
                            Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.75).frame(width: vinylSize * 0.80)
                            Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.75).frame(width: vinylSize * 0.72)
                            Circle().stroke(Color.white.opacity(0.04), lineWidth: 0.75).frame(width: vinylSize * 0.63)
                            Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.75).frame(width: vinylSize * 0.53)
                            // Run-out groove band
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1.0).frame(width: vinylSize * 0.43)
                        }

                        // Anisotropic Specular Light Sheen (Two opposing light reflection fans)
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: Color.white.opacity(0.18), location: 0.13),
                                        .init(color: .clear, location: 0.26),
                                        .init(color: .clear, location: 0.50),
                                        .init(color: Color.white.opacity(0.18), location: 0.63),
                                        .init(color: .clear, location: 0.76),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    center: .center
                                )
                            )
                            .blendMode(.plusLighter)

                        // Center Circular Album Artwork Label
                        let labelSize = vinylSize * 0.38
                        ZStack {
                            Image(nsImage: musicManager.albumArt)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: labelSize, height: labelSize)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.75)
                                )

                            // Center Stealth Black Spindle
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(white: 0.22),
                                            Color(white: 0.10),
                                            Color(white: 0.04)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: vinylSize * 0.035
                                    )
                                )
                                .frame(width: vinylSize * 0.065, height: vinylSize * 0.065)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                        }
                    }
                    .frame(width: vinylSize, height: vinylSize)
                    .rotationEffect(.degrees(rotation))
                }
                .position(x: platterCenterX, y: platterCenterY)

                // 4. Audiophile Tonearm (Pivoting with stylus tracking the grooves)
                TonearmView(
                    size: size,
                    isPlaying: musicManager.isPlaying,
                    progress: CGFloat(musicManager.songDuration > 0 ? musicManager.elapsedTime / musicManager.songDuration : 0)
                )
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Audiophile Tonearm View

struct TonearmView: View {
    let size: CGFloat
    let isPlaying: Bool
    let progress: CGFloat

    // Tonearm tracking angles:
    // When playing: arm rotates inward over the record (22° at track start -> 30° near label)
    // When paused: arm rests off the record on the armrest clasp (0°)
    private var armAngle: Double {
        if isPlaying {
            return 22.0 + Double(max(0.0, min(1.0, progress))) * 8.0
        } else {
            return 0.0
        }
    }

    var body: some View {
        let pivotX = size * 0.88
        let pivotY = size * 0.15
        let armLength = size * 0.54

        ZStack {
            // Fixed Arm Rest Post (on the plinth)
            Circle()
                .fill(Color(white: 0.20))
                .frame(width: size * 0.038, height: size * 0.038)
                .position(x: pivotX, y: size * 0.44)

            // Fixed Gimbal / Pivot Base Assembly
            ZStack {
                // Gimbal outer ring (matte dark charcoal)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.24), Color(white: 0.10)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.075
                        )
                    )
                    .frame(width: size * 0.14, height: size * 0.14)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 2.5, x: 1, y: 2)

                // Gimbal center pivot cap (dark gunmetal)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.28), Color(white: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.045, height: size * 0.045)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            }
            .position(x: pivotX, y: pivotY)

            // Swiveling Arm Wand & Headshell
            ZStack {
                // Counterweight cylinder (behind pivot, stealth black finish)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.26), Color(white: 0.12), Color(white: 0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.055, height: size * 0.075)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .offset(y: -size * 0.075)

                // Tubular Arm Wand (dark matte black metallic wand)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.26), Color(white: 0.10), Color(white: 0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.024, height: armLength)
                    .offset(y: armLength / 2)

                // Headshell & Stylus Cartridge (at the wand tip)
                ZStack(alignment: .top) {
                    // Angular Cartridge Body (matte stealth black)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.08))
                        .frame(width: size * 0.052, height: size * 0.11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5)
                                .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                        )

                    // Vintage Perforated Headshell Holes
                    VStack(spacing: size * 0.012) {
                        HStack(spacing: size * 0.010) {
                            Circle().fill(Color.black).frame(width: size * 0.009, height: size * 0.009)
                            Circle().fill(Color.black).frame(width: size * 0.009, height: size * 0.009)
                        }
                        HStack(spacing: size * 0.010) {
                            Circle().fill(Color.black).frame(width: size * 0.009, height: size * 0.009)
                            Circle().fill(Color.black).frame(width: size * 0.009, height: size * 0.009)
                        }
                    }
                    .padding(.top, size * 0.026)

                    // Dark Stylus Needle Tip
                    Rectangle()
                        .fill(Color(white: 0.28))
                        .frame(width: size * 0.020, height: size * 0.018)
                        .offset(y: size * 0.10)

                    // Finger Lift Hook (anodized dark)
                    Path { path in
                        path.move(to: CGPoint(x: size * 0.052, y: size * 0.075))
                        path.addQuadCurve(
                            to: CGPoint(x: size * 0.082, y: size * 0.095),
                            control: CGPoint(x: size * 0.078, y: size * 0.075)
                        )
                    }
                    .stroke(Color(white: 0.30), lineWidth: 1.0)
                }
                .rotationEffect(.degrees(-18))
                .offset(y: armLength + size * 0.035)
            }
            .position(x: pivotX, y: pivotY)
            .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: pivotX / size, y: pivotY / size))
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: isPlaying)
            .shadow(color: .black.opacity(0.4), radius: 2.5, x: 1.5, y: 2.5)
        }
    }
}

#Preview {
    AudioSpectrumView(
        isPlaying: .constant(true),
        bandLevels: AudioBandLevels(subBass: 0.8, bass: 0.7, mid: 0.5, highMid: 0.3, treble: 0.2)
    )
    .frame(width: 16, height: 20)
    .padding()
}

