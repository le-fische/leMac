//
//  FullscreenMediaDetection.swift
//  boringNotch
//
//  Created by Richard Kunkli on 06/09/2024.
//

import Foundation
import Combine
import Defaults
import MacroVisionKit
import IOKit
import IOKit.pwr_mgt
import AppKit

@MainActor
final class FullscreenMediaDetector: ObservableObject {
    static let shared = FullscreenMediaDetector()
    
    @Published var fullscreenStatus: [String: Bool] = [:]
    
    private var monitorTask: Task<Void, Never>?
    private var videoCheckTimer: Timer?
    private var cachedSpaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Dedicated video player applications that should always hide the notch in fullscreen
    private static let dedicatedVideoPlayerBundleIDs: Set<String> = [
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.firecore.infuse",
        "com.infuse",
        "com.movist.Movist",
        "com.movist.MovistPro",
        "tv.plex.desktop",
        "com.plexapp.plex",
        "io.mpv",
        "com.elmedia.free",
        "com.eltima.player",
        "org.xbmc.kodi",
        "com.amazon.aiv.AIVApp",
        "com.netflix.Netflix"
    ]
    
    private init() {
        startMonitoring()
        setupNotificationObservers()
    }
    
    deinit {
        monitorTask?.cancel()
        videoCheckTimer?.invalidate()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func setupNotificationObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let appActivateObs = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reEvaluateStatus()
            }
        }
        notificationObservers.append(appActivateObs)
        
        // React immediately if user changes the full screen behavior setting
        Defaults.publisher(.hideNotchOption)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reEvaluateStatus()
            }
            .store(in: &cancellables)
    }
    
    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                self.cachedSpaces = spaces
                self.reEvaluateStatus()
            }
        }
    }
    
    /// Checks if any process of the fullscreen application (or its helpers) is actively asserting display sleep prevention
    private static func hasDisplaySleepAssertion(forApps apps: [String]) -> Bool {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        let status = IOPMCopyAssertionsByProcess(&assertionsByProcess)
        guard status == kIOReturnSuccess,
              let cfDict = assertionsByProcess?.takeRetainedValue() as? [NSNumber: [NSDictionary]] else {
            return false
        }
        
        let targetBundles = Set(apps.map { $0.lowercased() })
        
        for (pidNum, assertions) in cfDict {
            let hasDisplaySleep = assertions.contains { a in
                guard let type = a["AssertType"] as? String else { return false }
                return type == "PreventUserIdleDisplaySleep" || type == "NoDisplaySleepAssertion"
            }
            
            guard hasDisplaySleep else { continue }
            
            let pid = pidNum.int32Value
            if let app = NSRunningApplication(processIdentifier: pid) {
                let bundle = (app.bundleIdentifier ?? "").lowercased()
                let name = (app.localizedName ?? "").lowercased()
                
                for target in targetBundles {
                    if !bundle.isEmpty && (bundle == target || bundle.hasPrefix(target) || target.hasPrefix(bundle)) {
                        return true
                    }
                    if !name.isEmpty && target.contains(name) {
                        return true
                    }
                }
            }
            
            for a in assertions {
                let assertName = (a["AssertName"] as? String ?? "").lowercased()
                let assertDetails = (a["AssertDetails"] as? String ?? "").lowercased()
                for target in targetBundles {
                    let simpleName = target.components(separatedBy: ".").last ?? target
                    if !simpleName.isEmpty && (assertName.contains(simpleName) || assertDetails.contains(simpleName)) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    /// Checks whether an app in the fullscreen space is displaying a true full-bleed video window (no toolbars/tabs)
    private static func hasFullScreenVideoWindow(forApps apps: [String], screenUUID: String?) -> Bool {
        guard let uuid = screenUUID, let screen = NSScreen.screen(withUUID: uuid) else {
            return false
        }
        let screenFrame = screen.frame
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        let targetBundles = Set(apps.map { $0.lowercased() })
        var foundFullBleed = false
        var hasBrowserChromeBars = false
        
        for info in windowList {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            
            let pid = info[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let ownerName = (info[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            
            var isTargetApp = false
            if let runningApp = NSRunningApplication(processIdentifier: pid),
               let bundle = runningApp.bundleIdentifier?.lowercased() {
                if targetBundles.contains(bundle) {
                    isTargetApp = true
                }
            }
            if !isTargetApp {
                for target in targetBundles {
                    let simpleName = (target.components(separatedBy: ".").last ?? target).lowercased()
                    if !simpleName.isEmpty && ownerName.contains(simpleName) {
                        isTargetApp = true
                        break
                    }
                }
            }
            guard isTargetApp else { continue }
            
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let w = boundsDict["Width"] as? CGFloat,
                  let h = boundsDict["Height"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat else { continue }
            
            // Detect browser tabs or URL bars (present when browsing, hidden when watching video in full screen)
            if y >= 35 && y <= 110 && h <= 60 {
                hasBrowserChromeBars = true
            }
            
            // True full-bleed window covering 100% of the display
            let tol: CGFloat = 4
            if abs(w - screenFrame.width) <= tol && abs(h - screenFrame.height) <= tol && y <= tol {
                foundFullBleed = true
            }
        }
        
        return foundFullBleed && !hasBrowserChromeBars
    }
    
    /// Determines whether video playback or a dedicated movie player is currently active in the specified space
    private static func isVideoPlayingInSpace(_ space: MacroVisionKit.FullScreenMonitor.SpaceInfo) -> Bool {
        // 1. Dedicated video players in fullscreen are always playing/displaying video
        for app in space.runningApps {
            if dedicatedVideoPlayerBundleIDs.contains(app) {
                return true
            }
        }
        
        // 2. Power assertion check: HTML5 video in Chrome/Safari/Firefox/Arc prevents display sleep
        if hasDisplaySleepAssertion(forApps: space.runningApps) {
            return true
        }
        
        // 3. Window geometry check: full bleed window with tabs/URL bar hidden
        if hasFullScreenVideoWindow(forApps: space.runningApps, screenUUID: space.screenUUID) {
            return true
        }
        
        return false
    }
    
    private func reEvaluateStatus() {
        let option = Defaults[.hideNotchOption]
        var newStatus: [String: Bool] = [:]
        var hasActiveFullScreenSpace = false
        
        for space in cachedSpaces {
            if let uuid = space.screenUUID {
                hasActiveFullScreenSpace = true
                let shouldHide: Bool
                switch option {
                case .never:
                    shouldHide = false
                case .always:
                    shouldHide = true
                case .videoOnly, .nowPlayingOnly:
                    shouldHide = Self.isVideoPlayingInSpace(space)
                }
                newStatus[uuid] = shouldHide
            }
        }
        
        if self.fullscreenStatus != newStatus {
            self.fullscreenStatus = newStatus
        }
        
        // Run a lightweight 0.5s check ONLY while an active fullscreen space exists in videoOnly mode
        let needsTimer = hasActiveFullScreenSpace && option.isVideoOnly
        if needsTimer && videoCheckTimer == nil {
            videoCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reEvaluateStatus()
                }
            }
        } else if !needsTimer && videoCheckTimer != nil {
            videoCheckTimer?.invalidate()
            videoCheckTimer = nil
        }
    }
}
