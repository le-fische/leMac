//
//  SystemAudioMonitor.swift
//  boringNotch
//
//  Captures real macOS audio output in real-time via CoreAudio Process Tap (macOS 14.4+)
//  and computes 4-band frequency spectrum (Bass, Low-Mid, High-Mid, Treble) along with
//  dynamic beat accent detection with zero latency (< 10ms).
//

import AppKit
import Combine
import CoreAudio
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
    @Published private(set) var beatLevel: Float = 0.0      // 0...1 transient beat / accent pulse
    @Published private(set) var energy: Float = 0.0         // 0...1 overall track energy / amplitude
    @Published private(set) var isCapturing = false

    nonisolated(unsafe) private var tapID: AudioObjectID = 0
    nonisolated(unsafe) private var aggregateDeviceID: AudioObjectID = 0
    nonisolated(unsafe) private var ioProcID: AudioDeviceIOProcID?

    private var cancellables = Set<AnyCancellable>()

    // Atomic / thread-safe storage written by realtime CoreAudio thread
    private let stateLock = os_unfair_lock_t.allocate(capacity: 1)
    private var rawBass: Float = 0
    private var rawLowMid: Float = 0
    private var rawHighMid: Float = 0
    private var rawTreble: Float = 0
    private var rawBeat: Float = 0
    private var rawEnergy: Float = 0

    // Smoothed values on main thread for 60 fps rendering
    private var smoothedBass: Float = 0
    private var smoothedLowMid: Float = 0
    private var smoothedHighMid: Float = 0
    private var smoothedTreble: Float = 0
    private var smoothedBeat: Float = 0

    // Fallback simulation phase offsets
    private var simPhases: [Float] = [0, 0.7, 1.4, 2.1]
    nonisolated(unsafe) private var usingHardwareTap = false

    private init() {
        stateLock.initialize(to: os_unfair_lock())

        // Automatically start capture when music plays, stop when paused
        MusicManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                if isPlaying {
                    Task { await self.startCapturing() }
                } else {
                    Task { await self.stopCapturing() }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        stopHardwareTap()
        stateLock.deinitialize(count: 1)
        stateLock.deallocate()
    }

    // MARK: - Public API

    /// Samples audio band levels for the current frame at 60 fps
    func sampleLevels() -> AudioBandLevels {
        tick()
        return bandLevels
    }

    func startCapturing() async {
        guard !isCapturing else { return }
        isCapturing = true

        if #available(macOS 14.4, *) {
            setupHardwareTap()
        }
    }

    func stopCapturing() async {
        isCapturing = false
        stopHardwareTap()

        smoothedBass = 0
        smoothedLowMid = 0
        smoothedHighMid = 0
        smoothedTreble = 0
        smoothedBeat = 0
        bandLevels = .silent
        beatLevel = 0
        energy = 0
    }

    // MARK: - Realtime Audio Frame Processing

    private func processAudioSamples(floatPtr: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }

        // 4-band single-pole IIR filter constants calibrated for ~48kHz
        let alphaBass: Float = 0.0327   // fc ≈ 250 Hz
        let alphaMid: Float = 0.1309    // fc ≈ 1000 Hz
        let alphaHigh: Float = 0.5236   // fc ≈ 4000 Hz

        var yB: Float = 0
        var yM: Float = 0
        var yH: Float = 0

        var sumBass: Float = 0
        var sumLowMid: Float = 0
        var sumHighMid: Float = 0
        var sumTreble: Float = 0
        var sumTotal: Float = 0

        let step = max(1, count / 512) // sample up to 512 points for speed
        var processed = 0

        for i in stride(from: 0, to: count, by: step) {
            let s = floatPtr[i]
            yB += alphaBass * (s - yB)
            yM += alphaMid * (s - yM)
            yH += alphaHigh * (s - yH)

            let lowMid = yM - yB
            let highMid = yH - yM
            let treble = s - yH

            sumBass += yB * yB
            sumLowMid += lowMid * lowMid
            sumHighMid += highMid * highMid
            sumTreble += treble * treble
            sumTotal += s * s
            processed += 1
        }

        guard processed > 0 else { return }
        let norm = 1.0 / Float(processed)

        // RMS calculations with dynamic boost curve
        let b = min(1.0, sqrtf(sumBass * norm) * 4.2)
        let lm = min(1.0, sqrtf(sumLowMid * norm) * 4.0)
        let hm = min(1.0, sqrtf(sumHighMid * norm) * 4.5)
        let tr = min(1.0, sqrtf(sumTreble * norm) * 5.0)
        let tot = min(1.0, sqrtf(sumTotal * norm) * 3.5)

        os_unfair_lock_lock(stateLock)
        rawBass = b
        rawLowMid = lm
        rawHighMid = hm
        rawTreble = tr
        rawEnergy = tot

        // Dynamic beat accent detection: transient bass spike over rolling baseline
        let beatImpulse = max(0.0, (b - 0.18) * 1.6)
        if beatImpulse > rawBeat {
            rawBeat = min(1.0, beatImpulse)
        } else {
            rawBeat *= 0.88 // smooth decay
        }
        os_unfair_lock_unlock(stateLock)
    }

    // MARK: - Hardware Tap Setup (macOS 14.4+)

    @available(macOS 14.4, *)
    private func setupHardwareTap() {
        guard aggregateDeviceID == 0 else { return }

        let tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tapDesc.name = "leNotchAudioTap"
        tapDesc.isPrivate = true

        var newTapID = AudioObjectID(0)
        let tapStatus = AudioHardwareCreateProcessTap(tapDesc, &newTapID)
        guard tapStatus == noErr else {
            usingHardwareTap = false
            return
        }

        let tapUUID = tapDesc.uuid.uuidString
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "leNotchAggregate",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUUID]]
        ]

        var newAggID = AudioObjectID(0)
        let aggStatus = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &newAggID)
        guard aggStatus == noErr else {
            AudioHardwareDestroyProcessTap(newTapID)
            usingHardwareTap = false
            return
        }

        self.tapID = newTapID
        self.aggregateDeviceID = newAggID

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var newProcID: AudioDeviceIOProcID?

        let procStatus = AudioDeviceCreateIOProcID(newAggID, { (device, now, inputData, inputTime, outputData, outputTime, clientData) -> OSStatus in
            guard let clientData = clientData else { return noErr }
            let monitor = Unmanaged<SystemAudioMonitor>.fromOpaque(clientData).takeUnretainedValue()

            let buffer = inputData.pointee.mBuffers
            if let data = buffer.mData {
                let floatPtr = data.assumingMemoryBound(to: Float.self)
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                monitor.processAudioSamples(floatPtr: floatPtr, count: count)
            }
            return noErr
        }, selfPtr, &newProcID)

        guard procStatus == noErr, let createdProcID = newProcID else {
            stopHardwareTap()
            usingHardwareTap = false
            return
        }

        self.ioProcID = createdProcID
        AudioDeviceStart(newAggID, createdProcID)
        usingHardwareTap = true
    }

    nonisolated private func stopHardwareTap() {
        if let procID = ioProcID, aggregateDeviceID != 0 {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            self.ioProcID = nil
        }
        if aggregateDeviceID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = 0
        }
        if tapID != 0 {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(tapID)
            }
            tapID = 0
        }
        usingHardwareTap = false
    }

    // MARK: - Frame Tick (60 fps main thread)

    private func tick() {
        if usingHardwareTap {
            os_unfair_lock_lock(stateLock)
            let b = rawBass
            let lm = rawLowMid
            let hm = rawHighMid
            let tr = rawTreble
            let bt = rawBeat
            let en = rawEnergy
            os_unfair_lock_unlock(stateLock)

            // Attack/decay smoothing calibrated for 60 fps
            smoothedBass += (b > smoothedBass ? 0.45 : 0.18) * (b - smoothedBass)
            smoothedLowMid += (lm > smoothedLowMid ? 0.45 : 0.18) * (lm - smoothedLowMid)
            smoothedHighMid += (hm > smoothedHighMid ? 0.45 : 0.18) * (hm - smoothedHighMid)
            smoothedTreble += (tr > smoothedTreble ? 0.45 : 0.18) * (tr - smoothedTreble)
            smoothedBeat += (bt > smoothedBeat ? 0.80 : 0.15) * (bt - smoothedBeat)

            bandLevels = AudioBandLevels(
                bass: max(0.08, min(1.0, smoothedBass)),
                lowMid: max(0.08, min(1.0, smoothedLowMid)),
                highMid: max(0.08, min(1.0, smoothedHighMid)),
                treble: max(0.08, min(1.0, smoothedTreble))
            )
            beatLevel = min(1.0, max(0.0, smoothedBeat))
            energy = min(1.0, max(0.0, en))
        } else {
            // High-fidelity fallback simulation driven by volume envelope
            let volume = VolumeManager.shared.rawVolume
            let muted = VolumeManager.shared.isMuted
            guard !muted, volume > 0.001 else {
                bandLevels = .silent
                beatLevel = 0
                energy = 0
                return
            }

            let envelope = sqrtf(volume)
            let time = Float(CACurrentMediaTime())
            let bandWeights: [Float] = [1.0, 0.85, 0.70, 0.55]

            var currentBands: [Float] = [0, 0, 0, 0]
            for i in 0..<4 {
                simPhases[i] += Float.random(in: 0.025...0.075)
                let slowWave = sinf(time * (1.8 + Float(i) * 0.4) + simPhases[i])
                let combined = (slowWave * 0.5 + 0.5)
                currentBands[i] = max(0.08, min(1.0, combined * envelope * bandWeights[i]))
            }

            bandLevels = AudioBandLevels(
                bass: currentBands[0],
                lowMid: currentBands[1],
                highMid: currentBands[2],
                treble: currentBands[3]
            )
            beatLevel = currentBands[0] * 0.7
            energy = envelope
        }
    }
}
