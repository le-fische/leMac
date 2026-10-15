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
        let barCount = 4
        let spacing: CGFloat = barWidth
        let totalWidth = CGFloat(barCount) * (barWidth + spacing)
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

        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]

            // Use real audio band level; add subtle organic jitter,
            // then clamp to a minimum so bars never fully vanish while playing.
            let level = CGFloat(i < levelsArray.count ? levelsArray[i] : 0)
            let jitter = CGFloat.random(in: -0.02 ... 0.02)
            let targetScale = max(0.15, min(1.0, level + jitter))

            barScales[i] = targetScale

            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = currentScale
            animation.toValue = targetScale
            animation.duration = 1.0 / 60.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            barLayer.add(animation, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.15, 1)
            barScales[i] = 0.15
        }
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

#Preview {
    AudioSpectrumView(
        isPlaying: .constant(true),
        bandLevels: AudioBandLevels(bass: 0.7, lowMid: 0.5, highMid: 0.3, treble: 0.2)
    )
    .frame(width: 16, height: 20)
    .padding()
}
