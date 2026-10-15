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

// MARK: - Spinning Vinyl Record Player View

struct VinylRecordView: View {
    @ObservedObject var musicManager = MusicManager.shared
    let isMinimized: Bool

    var body: some View {
        TimelineView(.animation(paused: !musicManager.isPlaying)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // ~33 RPM aesthetic spin (1 full revolution every ~3.6 seconds = 100 deg/s)
            let rotation = (time * 100.0).truncatingRemainder(dividingBy: 360)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                ZStack {
                    // Outer Black Vinyl Disc
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(white: 0.15),
                                    Color(white: 0.08),
                                    Color(white: 0.04)
                                ],
                                center: .center,
                                startRadius: size * 0.18,
                                endRadius: size * 0.50
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: isMinimized ? 1 : 4, x: 0, y: isMinimized ? 1 : 2)

                    // Concentric Grooves
                    if !isMinimized {
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: size * 0.88, height: size * 0.88)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: size * 0.76, height: size * 0.76)
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: size * 0.64, height: size * 0.64)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: size * 0.54, height: size * 0.54)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            .frame(width: size * 0.82, height: size * 0.82)
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            .frame(width: size * 0.65, height: size * 0.65)
                    }

                    // Vinyl sheen / light reflections (angular sheen)
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(isMinimized ? 0.08 : 0.12),
                                    Color.clear,
                                    Color.white.opacity(isMinimized ? 0.06 : 0.10),
                                    Color.clear,
                                    Color.white.opacity(isMinimized ? 0.08 : 0.12),
                                    Color.clear,
                                    Color.white.opacity(isMinimized ? 0.06 : 0.10),
                                    Color.clear
                                ]),
                                center: .center
                            )
                        )
                        .blendMode(.plusLighter)

                    // Center Album Label
                    let labelSize = size * (isMinimized ? 0.48 : 0.42)
                    ZStack {
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: labelSize, height: labelSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.20), lineWidth: isMinimized ? 0.5 : 1)
                            )

                        // Center Spindle Hole
                        Circle()
                            .fill(Color.black)
                            .frame(width: size * (isMinimized ? 0.12 : 0.08), height: size * (isMinimized ? 0.12 : 0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
            }
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

