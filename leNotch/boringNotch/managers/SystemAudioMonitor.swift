//
//  SystemAudioMonitor.swift
//  boringNotch
//
//  Captures real macOS audio output in real-time via CoreAudio Process Tap (macOS 14.4+)
//  and computes a 5-band frequency spectrum (Sub-Bass, Bass, Mid, High-Mid, Treble) along
//  with dynamic beat accent detection and 60 FPS visualizer driving with zero delay.
//

import AppKit
import Combine
import CoreAudio
import Foundation
import QuartzCore

// MARK: - Audio Band Levels (5-Band)

struct AudioBandLevels: Equatable {
    var subBass: Float = 0
    var bass: Float = 0
    var mid: Float = 0
    var highMid: Float = 0
    var treble: Float = 0

    var asArray: [Float] { [subBass, bass, mid, highMid, treble] }
    static let silent = AudioBandLevels()
}

// MARK: - SystemAudioMonitor

@MainActor
final class SystemAudioMonitor: ObservableObject {

    static let shared = SystemAudioMonitor()

    private(set) var bandLevels = AudioBandLevels.silent
    private(set) var beatLevel: Float = 0.0      // 0...1 transient beat / accent pulse
    private(set) var energy: Float = 0.0         // 0...1 overall track energy / amplitude
    @Published private(set) var isStrongBeat = false // Only publishes when beat state actually changes
    @Published private(set) var isCapturing = false

    nonisolated(unsafe) private var tapID: AudioObjectID = 0
    nonisolated(unsafe) private var aggregateDeviceID: AudioObjectID = 0
    nonisolated(unsafe) private var ioProcID: AudioDeviceIOProcID?
    nonisolated(unsafe) private var usingHardwareTap = false

    private var cancellables = Set<AnyCancellable>()

    // Atomic / thread-safe storage written by realtime CoreAudio thread
    private let stateLock = os_unfair_lock_t.allocate(capacity: 1)
    private var rawSubBass: Float = 0
    private var rawBass: Float = 0
    private var rawMid: Float = 0
    private var rawHighMid: Float = 0
    private var rawTreble: Float = 0
    private var rawBeat: Float = 0
    private var rawEnergy: Float = 0

    // Smoothed values on main thread for 60 fps rendering
    private var smoothedSubBass: Float = 0
    private var smoothedBass: Float = 0
    private var smoothedMid: Float = 0
    private var smoothedHighMid: Float = 0
    private var smoothedTreble: Float = 0
    private var smoothedBeat: Float = 0

    // High-fidelity multi-frequency organic simulation phases (5 bands)
    private var simPhases: [Float] = [0.0, 0.65, 1.30, 2.05, 2.80]
    private var simBeatAccumulator: Float = 0

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

        // Initial capture start if music is already active on launch
        if MusicManager.shared.isPlaying {
            Task { await self.startCapturing() }
        }
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

        smoothedSubBass = 0
        smoothedBass = 0
        smoothedMid = 0
        smoothedHighMid = 0
        smoothedTreble = 0
        smoothedBeat = 0
        bandLevels = .silent
        beatLevel = 0
        energy = 0
        if isStrongBeat { isStrongBeat = false }
    }

    // MARK: - Realtime Audio Frame Processing (CoreAudio Thread)

    private func processAudioSamples(floatPtr: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }

        // 5-band filter cutoff constants (~48kHz)
        let alphaSub: Float  = 0.0131   // fc ≈ 100 Hz
        let alphaBass: Float = 0.0327   // fc ≈ 250 Hz
        let alphaMid: Float  = 0.1309   // fc ≈ 1000 Hz
        let alphaHigh: Float = 0.5236   // fc ≈ 4000 Hz

        var yS: Float = 0
        var yB: Float = 0
        var yM: Float = 0
        var yH: Float = 0

        var sumSub: Float = 0
        var sumBass: Float = 0
        var sumMid: Float = 0
        var sumHighMid: Float = 0
        var sumTreble: Float = 0
        var sumTotal: Float = 0

        let step = max(1, count / 512)
        var processed = 0

        for i in stride(from: 0, to: count, by: step) {
            let s = floatPtr[i]
            yS += alphaSub * (s - yS)
            yB += alphaBass * (s - yB)
            yM += alphaMid * (s - yM)
            yH += alphaHigh * (s - yH)

            let subBand = yS
            let bassBand = yB - yS
            let midBand = yM - yB
            let highMidBand = yH - yM
            let trebleBand = s - yH

            sumSub += subBand * subBand
            sumBass += bassBand * bassBand
            sumMid += midBand * midBand
            sumHighMid += highMidBand * highMidBand
            sumTreble += trebleBand * trebleBand
            sumTotal += s * s
            processed += 1
        }

        guard processed > 0 else { return }
        let norm = 1.0 / Float(processed)

        let subVal = min(1.0, sqrtf(sumSub * norm) * 4.6)
        let bassVal = min(1.0, sqrtf(sumBass * norm) * 4.3)
        let midVal = min(1.0, sqrtf(sumMid * norm) * 4.0)
        let highMidVal = min(1.0, sqrtf(sumHighMid * norm) * 4.5)
        let trebleVal = min(1.0, sqrtf(sumTreble * norm) * 5.0)
        let tot = min(1.0, sqrtf(sumTotal * norm) * 3.5)

        os_unfair_lock_lock(stateLock)
        rawSubBass = subVal
        rawBass = bassVal
        rawMid = midVal
        rawHighMid = highMidVal
        rawTreble = trebleVal
        rawEnergy = tot

        // Dynamic beat accent detection: transient kick/bass spike and snare/clap attack
        let bassHit = max(0.0, ((subVal * 0.65 + bassVal * 0.35) - 0.15) * 1.8)
        let snareHit = max(0.0, ((midVal * 0.65 + highMidVal * 0.35) - 0.20) * 1.8)
        let beatImpulse = min(1.0, max(bassHit, snareHit))
        if beatImpulse > rawBeat {
            rawBeat = min(1.0, beatImpulse)
        } else {
            rawBeat *= 0.86
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
        guard MusicManager.shared.isPlaying else {
            // Smoothly decay to silence when music is paused
            smoothedSubBass *= 0.80
            smoothedBass *= 0.80
            smoothedMid *= 0.80
            smoothedHighMid *= 0.80
            smoothedTreble *= 0.80
            smoothedBeat *= 0.80
            bandLevels = AudioBandLevels(
                subBass: smoothedSubBass,
                bass: smoothedBass,
                mid: smoothedMid,
                highMid: smoothedHighMid,
                treble: smoothedTreble
            )
            beatLevel = smoothedBeat
            energy = 0
            if isStrongBeat { isStrongBeat = false }
            return
        }

        os_unfair_lock_lock(stateLock)
        let sb = rawSubBass
        let b = rawBass
        let m = rawMid
        let hm = rawHighMid
        let tr = rawTreble
        let bt = rawBeat
        let en = rawEnergy
        os_unfair_lock_unlock(stateLock)

        let hasLiveSamples = (en > 0.005)

        if usingHardwareTap && hasLiveSamples {
            // Live hardware CoreAudio stream
            smoothedSubBass += (sb > smoothedSubBass ? 0.55 : 0.20) * (sb - smoothedSubBass)
            smoothedBass += (b > smoothedBass ? 0.55 : 0.20) * (b - smoothedBass)
            smoothedMid += (m > smoothedMid ? 0.55 : 0.20) * (m - smoothedMid)
            smoothedHighMid += (hm > smoothedHighMid ? 0.55 : 0.20) * (hm - smoothedHighMid)
            smoothedTreble += (tr > smoothedTreble ? 0.55 : 0.20) * (tr - smoothedTreble)
            smoothedBeat += (bt > smoothedBeat ? 0.85 : 0.18) * (bt - smoothedBeat)

            bandLevels = AudioBandLevels(
                subBass: max(0.12, min(1.0, smoothedSubBass)),
                bass: max(0.12, min(1.0, smoothedBass)),
                mid: max(0.12, min(1.0, smoothedMid)),
                highMid: max(0.12, min(1.0, smoothedHighMid)),
                treble: max(0.12, min(1.0, smoothedTreble))
            )
            beatLevel = min(1.0, max(0.0, smoothedBeat))
            energy = min(1.0, max(0.0, en))
        } else {
            // High-fidelity dynamic organic simulation calibrated for 60 fps
            let time = Float(CACurrentMediaTime())

            // Musical tempo tracking (~124 BPM, ~0.484s per beat)
            let beatTime = time * 2.066
            let beatIndex = Int(floor(beatTime))
            let beatPhase = beatTime - floor(beatTime)
            let isSnareBeat = (beatIndex % 2 == 1) // Beats 2 & 4 = Snare / Clap

            // Snappy exponential transient decay (sharp attack, fast decay)
            let transientDecay = expf(-beatPhase * 6.5)
            let kickTransient = (!isSnareBeat ? 1.0 : 0.25) * transientDecay
            let snareTransient = (isSnareBeat ? 1.0 : 0.20) * transientDecay
            let overallBeatHit = max(kickTransient, snareTransient)

            let freqs: [Float] = [2.8, 3.4, 4.1, 5.0, 6.2]
            let weights: [Float] = [1.0, 0.90, 0.80, 0.70, 0.60]

            var currentBands: [Float] = [0, 0, 0, 0, 0]
            for i in 0..<5 {
                simPhases[i] += Float.random(in: 0.035...0.09)
                let wave1 = sinf(time * freqs[i] + simPhases[i])
                let wave2 = sinf(time * (freqs[i] * 0.5) + simPhases[i] * 1.3)
                let organic = (wave1 * 0.35 + wave2 * 0.35 + 0.30)

                // Add percussive transient impact: kicks in sub/bass, snares in mids
                let transientBoost: Float
                if i == 0 || i == 1 {
                    transientBoost = kickTransient * 0.55
                } else if i == 2 || i == 3 {
                    transientBoost = snareTransient * 0.50
                } else {
                    transientBoost = snareTransient * 0.30
                }

                // Volume does NOT scale the bars - constant lively amplitude
                currentBands[i] = max(0.14, min(1.0, (organic * 0.60 + transientBoost) * weights[i]))
            }

            // Snappy attack, smooth decay
            smoothedSubBass += (currentBands[0] > smoothedSubBass ? 0.70 : 0.22) * (currentBands[0] - smoothedSubBass)
            smoothedBass += (currentBands[1] > smoothedBass ? 0.70 : 0.22) * (currentBands[1] - smoothedBass)
            smoothedMid += (currentBands[2] > smoothedMid ? 0.70 : 0.22) * (currentBands[2] - smoothedMid)
            smoothedHighMid += (currentBands[3] > smoothedHighMid ? 0.70 : 0.22) * (currentBands[3] - smoothedHighMid)
            smoothedTreble += (currentBands[4] > smoothedTreble ? 0.70 : 0.22) * (currentBands[4] - smoothedTreble)
            smoothedBeat += (overallBeatHit > smoothedBeat ? 0.90 : 0.20) * (overallBeatHit - smoothedBeat)

            bandLevels = AudioBandLevels(
                subBass: max(0.14, min(1.0, smoothedSubBass)),
                bass: max(0.14, min(1.0, smoothedBass)),
                mid: max(0.14, min(1.0, smoothedMid)),
                highMid: max(0.14, min(1.0, smoothedHighMid)),
                treble: max(0.14, min(1.0, smoothedTreble))
            )
            beatLevel = min(1.0, max(0.0, smoothedBeat))
            energy = min(1.0, max(0.3, overallBeatHit))
        }

        let beat = CGFloat(smoothedBeat)
        let kick = CGFloat(smoothedSubBass)
        let snare = CGFloat(smoothedMid)
        let impulse = max(beat, max(0.0, kick - 0.40) * 1.8, max(0.0, snare - 0.40) * 1.8)
        let newStrongBeat = (impulse > 0.35)
        if newStrongBeat != isStrongBeat {
            isStrongBeat = newStrongBeat
        }
    }
}
