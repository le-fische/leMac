//
//  TimerLiveActivityManager.swift
//  boringNotch
//
//  Created for boringNotch Timer & Pomodoro Live Activity.
//

import AppKit
import Combine
import Defaults
import Foundation

@MainActor
final class TimerLiveActivityManager: ObservableObject {
    static let shared = TimerLiveActivityManager()

    @Published var isRunning: Bool = false
    @Published var totalSeconds: TimeInterval = 25 * 60
    @Published var remainingSeconds: TimeInterval = 25 * 60
    @Published var title: String = "Focus"

    private var timerCancellable: AnyCancellable?
    private var endTimestamp: Date?

    private init() {}

    var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(max(0, min(1, 1.0 - (remainingSeconds / totalSeconds))))
    }

    var formattedTime: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    func start(durationMinutes: Int = 25, label: String = "Focus") {
        totalSeconds = TimeInterval(durationMinutes * 60)
        remainingSeconds = totalSeconds
        title = label
        resume()
    }

    func resume() {
        guard !isRunning else { return }
        isRunning = true
        endTimestamp = Date().addingTimeInterval(remainingSeconds)

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self, let end = self.endTimestamp else { return }
                let diff = end.timeIntervalSince(now)
                if diff <= 0 {
                    self.timerFinished()
                } else {
                    self.remainingSeconds = diff
                }
            }

        if Defaults[.enablePomodoroTimer] {
            BoringViewCoordinator.shared.toggleSneakPeek(
                status: true,
                type: .timer,
                duration: 2.5,
                value: 0.0,
                icon: "timer",
                title: title,
                subtitle: formattedTime
            )
        }
    }

    func pause() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        pause()
        remainingSeconds = totalSeconds
    }

    private func timerFinished() {
        pause()
        remainingSeconds = 0
        NSSound.beep()
        
        if Defaults[.enablePomodoroTimer] {
            BoringViewCoordinator.shared.toggleSneakPeek(
                status: true,
                type: .timer,
                duration: 4.0,
                value: 1.0,
                icon: "bell.fill",
                title: "\(title) Completed!",
                subtitle: "Time's up"
            )
        }
    }
}
