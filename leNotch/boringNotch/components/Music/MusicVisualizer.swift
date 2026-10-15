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
            let beat = CGFloat(audioMonitor.beatLevel)
            let bass = CGFloat(audioMonitor.bandLevels.bass)
            let sub = CGFloat(audioMonitor.bandLevels.subBass)
            let pulseEnergy = max(beat, (bass * 0.6 + sub * 0.4))

            // Robust scales so the glow clearly radiates well beyond the black borders
            let innerScale: CGFloat = isMinimized
                ? (1.20 + pulseEnergy * 0.22)
                : (1.10 + pulseEnergy * 0.12)
            let outerScale: CGFloat = isMinimized
                ? (1.42 + pulseEnergy * 0.32)
                : (1.25 + pulseEnergy * 0.20)

            let innerBlur: CGFloat = isMinimized
                ? (3.5 + pulseEnergy * 2.5)
                : (12.0 + pulseEnergy * 8.0)
            let outerBlur: CGFloat = isMinimized
                ? (8.0 + pulseEnergy * 4.0)
                : (28.0 + pulseEnergy * 14.0)

            let innerOpacity: Double = isMinimized
                ? Double(0.95 + pulseEnergy * 0.05)
                : Double(0.90 + pulseEnergy * 0.10)
            let outerOpacity: Double = isMinimized
                ? Double(0.70 + pulseEnergy * 0.25)
                : Double(0.65 + pulseEnergy * 0.25)

            ZStack {
                // Wide ambient atmospheric bloom in album edge colors
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(2.0)
                    .brightness(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(outerScale)
                    .blur(radius: outerBlur)
                    .opacity(outerOpacity)

                // Intense tight edge rim glow
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(2.2)
                    .brightness(0.22)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(innerScale)
                    .blur(radius: innerBlur)
                    .opacity(innerOpacity)

                // Edge tint backing to guarantee vibrant glow even on pitch-black album borders
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.8))
                    .scaleEffect(innerScale * 0.98)
                    .blur(radius: innerBlur * 1.2)
                    .opacity(Double(0.35 + pulseEnergy * 0.35))
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.08), value: pulseEnergy)
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

