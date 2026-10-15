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
    @ObservedObject var volumeManager = VolumeManager.shared
    let cornerRadius: CGFloat
    let isMinimized: Bool

    var body: some View {
        if Defaults[.enableExpandedVisualizerGlow] && musicManager.isPlaying {
            // Volume-scaled aura halo:
            // Base volume <= 50% (0.50): volumeProgress = 0.0
            // Above 50% up to 100%: volumeProgress smoothly scales from 0.0 to 1.0
            let vol = CGFloat(volumeManager.isMuted ? 0.0 : volumeManager.rawVolume)
            let volumeProgress = max(0.0, min(1.0, (vol - 0.50) / 0.50))

            if isMinimized {
                // Mini notch display: preserved exactly as approved ("small display is good enough")
                let kick = CGFloat(audioMonitor.bandLevels.subBass * 0.70 + audioMonitor.bandLevels.bass * 0.50)
                let snare = CGFloat(audioMonitor.bandLevels.mid * 0.70 + audioMonitor.bandLevels.highMid * 0.50)
                let beatPulse = CGFloat(audioMonitor.beatLevel)
                let pulseEnergy = max(beatPulse, kick, snare)

                let scale: CGFloat = 1.10 + pulseEnergy * 0.06 + volumeProgress * 0.05
                let blurRadius: CGFloat = 2.4 + pulseEnergy * 1.0 + volumeProgress * 1.2
                let opacity: Double = Double(0.68 + pulseEnergy * 0.26)

                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(1.6)
                    .brightness(0.0)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(scale)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.07), value: pulseEnergy)
            } else {
                // Main expanded display: punchy, unmistakable POP on beat transients (kicks, snares, 808s)
                let beat = CGFloat(audioMonitor.beatLevel)
                let kickAccent = max(0.0, CGFloat(audioMonitor.bandLevels.subBass) - 0.25) / 0.75
                let snareAccent = max(0.0, CGFloat(audioMonitor.bandLevels.mid) - 0.25) / 0.75
                let rawPop = max(beat, kickAccent * 0.90, snareAccent * 0.85)
                let pop = pow(max(0.0, min(1.0, rawPop)), 1.6)

                let baseScale: CGFloat = 1.04 + volumeProgress * 0.10
                let scale: CGFloat = baseScale + pop * 0.24

                let baseBlur: CGFloat = 10.0 + volumeProgress * 8.0
                let blurRadius: CGFloat = baseBlur + pop * 18.0

                let baseOpacity: Double = 0.38 + Double(volumeProgress) * 0.08
                let opacity: Double = baseOpacity + Double(pop) * 0.54

                let brightness: Double = 0.04 + Double(pop) * 0.14

                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .saturation(1.7)
                    .brightness(brightness)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .scaleEffect(scale)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
                    .allowsHitTesting(false)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.60, blendDuration: 0), value: pop)
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

