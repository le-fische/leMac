//
//  SystemAudioMonitor.swift
//  boringNotch
//
//  Drives the music visualizer bars based on system volume level.
//  Bars scale proportionally to the current output volume,
//  with per-bar randomised variation for an organic look.
//  No extra permissions required — uses CoreAudio volume data
//  that VolumeManager already provides.
//

import Combine
import Foundation
import QuartzCore

// MARK: - Audio Band Levels

struct AudioBandLevels: Equatable {
    var bass: Float = 0
    var lowMid: Float = 0
    var highMid: Float = 0
    var treble: Float = 0

    var asArray: [Float] { [bass, lowMid, highMid, treble] }
    static let silent = AudioBandLevels()
}

// MARK: - SystemAudioMonitor

@MainActor
final class SystemAudioMonitor: ObservableObject {

    static let shared = SystemAudioMonitor()

    @Published private(set) var bandLevels = AudioBandLevels.silent
    @Published private(set) var isCapturing = false

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Per-band phase offsets for organic-feeling independent motion.
    private var phases: [Float] = [0, 0.7, 1.4, 2.1]

    // Smoothed values calibrated for 60 fps.
    private var smoothed: [Float] = [0, 0, 0, 0]
    private let smoothUp: Float = 0.35
    private let smoothDown: Float = 0.10

    private init() {}

    // MARK: - Public API

    /// Samples audio band levels for the current frame (e.g. at 60 fps)
    /// without forcing SwiftUI full-tree view invalidation.
    func sampleLevels() -> AudioBandLevels {
        tick()
        return bandLevels
    }

    func startCapturing() async {
        guard !isCapturing else { return }
        isCapturing = true
    }

    func stopCapturing() async {
        isCapturing = false
        smoothed = [0, 0, 0, 0]
        bandLevels = .silent
    }

    // MARK: - Animation tick

    private func tick() {
        let volume = VolumeManager.shared.rawVolume  // 0…1
        let muted = VolumeManager.shared.isMuted

        // If muted or volume is zero, decay to silence.
        guard !muted, volume > 0.001 else {
            for i in 0..<4 {
                smoothed[i] += smoothDown * (0 - smoothed[i])
            }
            bandLevels = AudioBandLevels(
                bass: smoothed[0], lowMid: smoothed[1],
                highMid: smoothed[2], treble: smoothed[3]
            )
            return
        }

        // Volume envelope: map system volume to a base amplitude.
        let envelope = sqrtf(volume)
        let time = Float(CACurrentMediaTime())
        let bandWeights: [Float] = [1.0, 0.85, 0.7, 0.55]

        for i in 0..<4 {
            phases[i] += Float.random(in: 0.025...0.075)

            // Layered noise: slow sine wave + fast random for organic motion.
            let slowWave = sinf(time * (1.8 + Float(i) * 0.4) + phases[i])
            let fastNoise = Float.random(in: -0.25...0.25)
            let combined = (slowWave * 0.5 + 0.5) + fastNoise

            // Scale by volume envelope and band weight.
            let target = max(0.08, min(1.0, combined * envelope * bandWeights[i]))

            // Smooth.
            let factor = target > smoothed[i] ? smoothUp : smoothDown
            smoothed[i] += factor * (target - smoothed[i])
        }

        bandLevels = AudioBandLevels(
            bass: smoothed[0], lowMid: smoothed[1],
            highMid: smoothed[2], treble: smoothed[3]
        )
    }
}
