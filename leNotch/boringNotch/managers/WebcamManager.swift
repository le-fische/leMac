//
//  WebcamManager.swift
//  boringNotch
//
//  Inert stub: Webcam / mirror feature removed per user request.
//

import AVFoundation
import SwiftUI

final class WebcamManager: NSObject, ObservableObject {
    static let shared = WebcamManager()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isSessionRunning: Bool = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var cameraAvailable: Bool = false

    private override init() { super.init() }
    func startSession() {}
    func stopSession() {}
    func checkAndRequestVideoAuthorization() {}
}
